rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(tibble)

ROOT <- "/home/user/illusion-of-control/analysis"

DATA_WM   <- file.path(ROOT, "../data/ioc-all-fixed-pilot/wm")
OUT_CSV   <- file.path(ROOT, "posterior_stats.csv")

# ── helpers ───────────────────────────────────────────────────────────────────
bf10_savage_dickey <- function(draws, prior_sigma, prior_mu = 0.0) {
  prior_dens_at_0 <- dnorm(0.0, mean = prior_mu, sd = prior_sigma)
  kde             <- density(draws, bw = "SJ")
  post_dens_at_0  <- approx(kde$x, kde$y, xout = 0.0)$y
  if (is.na(post_dens_at_0) || post_dens_at_0 < 1e-12) return(Inf)
  prior_dens_at_0 / post_dens_at_0
}

make_row <- function(label, draws, prior_sigma = NULL, skip_bf = FALSE) {
  med  <- median(draws)
  lo   <- quantile(draws, 0.05)
  hi   <- quantile(draws, 0.95)
  pd   <- max(mean(draws > 0), mean(draws < 0)) * 100
  bf   <- if (!skip_bf && !is.null(prior_sigma)) bf10_savage_dickey(draws, prior_sigma) else NA_real_
  tibble(
    Parameter = label,
    Median    = round(med, 3),
    `90% CI`  = sprintf("[%.3f, %.3f]", lo, hi),
    `pd (%)`  = round(pd, 1),
    BF10      = if (!is.na(bf)) round(bf, 2) else NA_real_
  )
}

# ── WM K scores (to get wm_k_sd for slope conversion) ────────────────────────
wm_files <- list.files(DATA_WM, pattern = "^ioc-wm_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
wm <- lapply(wm_files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  df  <- read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character()))
  exp <- df |>
    filter(trial_name == "test_squares", block_type == "exp") |>
    mutate(set_size = as.numeric(set_size),
           acc_bool = tolower(as.character(accuracy)) == "true")
  k_vals <- sapply(c(4, 8), \(ss) {
    t <- exp |> filter(set_size == ss)
    if (nrow(t) == 0) return(NA)
    d <- t |> filter(condition == "d")
    s <- t |> filter(condition == "s")
    if (nrow(d) == 0 || nrow(s) == 0) return(NA)
    ss * (mean(d$acc_bool) + mean(s$acc_bool) - 1)
  })
  data.frame(participant = pid, wm_k = mean(k_vals, na.rm = TRUE))
}) |> bind_rows()

wm_k_sd <- sd(wm$wm_k, na.rm = TRUE)
cat(sprintf("WM K SD: %.4f\n", wm_k_sd))

# ── load draws ────────────────────────────────────────────────────────────────
wsls_n18 <- read_csv(file.path(ROOT, "running_wsls/wsls_draws_n18.csv"), show_col_types = FALSE)$beta_mu
wsls_n13 <- read_csv(file.path(ROOT, "running_wsls/wsls_draws_n13.csv"), show_col_types = FALSE)$beta_mu
reg      <- read_csv(file.path(ROOT, "wm_wsls/reg_draws.csv"),           show_col_types = FALSE)$slope

slope_raw <- reg / wm_k_sd

grp <- read_csv(file.path(ROOT, "param_estimation/bayesian_draws_r/posterior_draws_group.csv"),
                show_col_types = FALSE)

# ── compute rows ──────────────────────────────────────────────────────────────
rows <- bind_rows(
  make_row("WSLS β_μ — All N=18",                wsls_n18,         prior_sigma = 2.0),
  make_row("WSLS β_μ — N=13 (understood=felt)",  wsls_n13,         prior_sigma = 2.0),
  make_row("WM→WSLS slope (original K scale)",   slope_raw,        prior_sigma = 2.0 / wm_k_sd),
  make_row("M1 α — group mean",                  grp$alpha_pop,    skip_bf = TRUE),
  make_row("M1 β — group mean",                  grp$beta_pop,     prior_sigma = 3.0),
  make_row("M1 κ — group mean",                  grp$kappa_pop,    prior_sigma = 2.0),
  make_row("M1 δ — group mean",                  grp$delta_pop,    skip_bf = TRUE),
  make_row("M2 κ — group mean",                  grp$kappa_m2_pop, prior_sigma = 2.0),
  make_row("M2 δ — group mean",                  grp$delta_m2_pop, skip_bf = TRUE)
)

# ── print and save ────────────────────────────────────────────────────────────
print(rows, n = Inf)
write_csv(rows, OUT_CSV)
cat(sprintf("\nSaved → %s\n", OUT_CSV))
