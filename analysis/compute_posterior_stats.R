rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(tibble)

ROOT    <- "/home/user/illusion-of-control/analysis"
OUT_CSV <- file.path(ROOT, "posterior_stats.csv")

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

# ── load draws ────────────────────────────────────────────────────────────────
wsls_n18 <- read_csv(file.path(ROOT, "running_wsls/wsls_draws_n18.csv"), show_col_types = FALSE)$beta_mu
wsls_n13 <- read_csv(file.path(ROOT, "running_wsls/wsls_draws_n13.csv"), show_col_types = FALSE)$beta_mu

grp <- read_csv(file.path(ROOT, "param_estimation/bayesian_draws_r/posterior_draws_group.csv"),
                show_col_types = FALSE)

# ── compute rows ──────────────────────────────────────────────────────────────
rows <- bind_rows(
  make_row("WSLS β_μ — All N=18",                wsls_n18,         prior_sigma = 2.0),
  make_row("WSLS β_μ — N=13 (understood=felt)",  wsls_n13,         prior_sigma = 2.0),
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
