rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(stringr)
library(posterior)

DATA_TASK <- "../../data/ioc-all-fixed-pilot/task"
DATA_WM   <- "../../data/ioc-all-fixed-pilot/wm"
OUT_PNG   <- "wm_wsls.png"

COL_YES <- "#0072B2"
COL_NO  <- "#E69F00"

MISUNDERSTOOD <- c(
  "67dae998d8f2cfb8a8e3bf03",
  "6a087d170d5521dd2055e045",
  "6a0ac6bc5fb56e6d7f8e6569"
)
FELT_DIFFERENT <- c(
  "677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
  "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2",
  "5c41f9ce4fe4f800016dfaac", "651d64e4756ee3358eeb981f",
  "6982544679288685d8a0199f", "69a7048762f2aacbfb3c2f02",
  "69de2b262f16bdb2c0122847", "6a01c4c8248651c0157c76c5"
)

GREY30 <- "#4d4d4d"
GREY40 <- "#666666"
GREY65 <- "#a6a6a6"
GREY80 <- "#cccccc"

# ── 1. WM K scores ────────────────────────────────────────────────────────────
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
  n_valid_ss <- sum(!is.na(k_vals))
  if (n_valid_ss < 2) warning(sprintf("Subject %s: only %d set size(s) have data - K may be unreliable", pid, n_valid_ss))
  data.frame(participant = pid, wm_k = mean(k_vals, na.rm = TRUE))
}) |> bind_rows()

# ── 2. WSLS per-subject betas (lag-1 logistic regression) ────────────────────
task_files <- list.files(DATA_TASK, pattern = "^ioc-all_[a-f0-9]{24}_SESSION.*\\.csv$", full.names = TRUE)
df_raw <- lapply(task_files, \(f) {
  pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
  read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
    mutate(participant = pid)
}) |> bind_rows()

gb <- df_raw |>
  filter(task == "gambling_choice", as.character(block_number) != "training") |>
  mutate(block_number = as.character(block_number),
         trial_number = as.numeric(trial_number),
         reward       = as.numeric(reward)) |>
  arrange(participant, block_number, trial_number)

records <- list()
for (key in unique(paste(gb$participant, gb$block_number, sep = "__"))) {
  parts <- strsplit(key, "__")[[1]]
  pid <- parts[1]; blk <- parts[2]
  grp <- gb |> filter(participant == pid, block_number == blk)
  n   <- nrow(grp)
  if (n <= 1) next
  for (i in 2:n) {
    row   <- grp[i, ]; nback <- grp[i - 1, ]
    if (!isTRUE(as.logical(row$is_choice_valid))) next
    if (!isTRUE(as.logical(nback$is_choice_valid))) next
    if (is.na(nback$choice_key) || is.na(nback$reward)) next
    records[[length(records) + 1]] <- data.frame(
      participant  = pid,
      stay         = as.integer(row$choice_key == nback$choice_key),
      reward_nback = as.integer(as.numeric(nback$reward))
    )
  }
}
df_wsls <- bind_rows(records)

# Hierarchical logistic: per-subject beta via individual GLMs (median of posteriors)
wsls_betas <- df_wsls |>
  group_by(participant) |>
  summarise(wsls_beta = {
    fit <- glm(stay ~ reward_nback, family = binomial(), data = pick(everything()))
    coef(fit)["reward_nback"]
  }, .groups = "drop")

# ── 3. Merge and regression ───────────────────────────────────────────────────
merged <- wm |>
  inner_join(wsls_betas, by = "participant") |>
  filter(!is.na(wm_k), !is.na(wsls_beta)) |>
  mutate(
    understood_eq_felt = !(participant %in% MISUNDERSTOOD) & !(participant %in% FELT_DIFFERENT),
    color_grp = if_else(understood_eq_felt, "understood = felt", "understood != felt")
  )

cat(sprintf("\nMerged subjects: %d\n", nrow(merged)))

wm_k_mean <- mean(merged$wm_k); wm_k_sd <- sd(merged$wm_k)
merged$wm_k_z <- (merged$wm_k - wm_k_mean) / wm_k_sd

# Bayesian regression via normal approximation of GLM
reg_fit      <- lm(wsls_beta ~ wm_k_z, data = merged)
slope_mean   <- coef(reg_fit)["wm_k_z"]
slope_se     <- summary(reg_fit)$coefficients["wm_k_z", "Std. Error"]
int_mean     <- coef(reg_fit)["(Intercept)"]
int_se       <- summary(reg_fit)$coefficients["(Intercept)", "Std. Error"]

slope_draws <- rnorm(4000, slope_mean, slope_se)
int_draws   <- rnorm(4000, int_mean,   int_se)
slope_raw   <- slope_draws / wm_k_sd   # back to per-K-unit scale

# Posterior predictive band
x_grid   <- seq(0, max(merged$wm_k) * 1.05, length.out = 200)
x_grid_z <- (x_grid - wm_k_mean) / wm_k_sd
y_grid   <- outer(int_draws, rep(1, 200)) + outer(slope_draws, x_grid_z)
y_lo  <- apply(y_grid, 2, quantile, 0.05)
y_med <- apply(y_grid, 2, quantile, 0.50)
y_hi  <- apply(y_grid, 2, quantile, 0.95)
df_band <- data.frame(x = x_grid, y_lo = y_lo, y_med = y_med, y_hi = y_hi)

r_pearson <- cor(merged$wm_k, merged$wsls_beta)

# ── 4. Scatter panel ─────────────────────────────────────────────────────────
p_scatter <- ggplot(merged, aes(x = wm_k, y = wsls_beta)) +
  geom_ribbon(data = df_band, aes(x = x, ymin = y_lo, ymax = y_hi),
              inherit.aes = FALSE, fill = "#56B4E9", alpha = 0.25) +
  geom_line(data = df_band, aes(x = x, y = y_med),
            inherit.aes = FALSE, colour = "#0072B2", linewidth = 1.5) +
  geom_point(aes(colour = color_grp), size = 2.5, alpha = 0.85) +
  scale_colour_manual(
    values = c("understood = felt" = COL_YES, "understood != felt" = COL_NO),
    name   = NULL
  ) +
  annotate("text", x = max(merged$wm_k) * 0.97,
           y = max(merged$wsls_beta) + diff(range(merged$wsls_beta)) * 0.08,
           label = sprintf("Pearson r = %.2f", r_pearson),
           hjust = 1, size = 3, colour = "#555555") +
  labs(x = "Working memory capacity (K)",
       y = expression("WSLS reward effect (" * beta[j] * ", log-odds)")) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid    = element_blank(),
    axis.line.x   = element_line(colour = GREY30),
    axis.line.y   = element_line(colour = GREY30),
    axis.title    = element_text(size = 16),
    axis.text     = element_text(size = 8),
    legend.text   = element_text(size = 12),
    legend.position = "bottom",
    plot.background = element_rect(fill = "white", colour = NA)
  )

# ── 5. Slope posterior panel ──────────────────────────────────────────────────
med_slope <- median(slope_raw)
ci90      <- quantile(slope_raw, c(0.05, 0.95))
pd_val    <- max(mean(slope_raw > 0), mean(slope_raw < 0)) * 100

df_slope <- data.frame(x = slope_raw)

p_post <- ggplot(df_slope, aes(x = x)) +
  stat_density(aes(y = after_stat(density / max(density))), geom = "area", fill = GREY80, colour = NA, bw = "SJ") +
  geom_vline(xintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.9) +
  geom_vline(xintercept = med_slope, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
  annotate("segment", x = ci90[1], xend = ci90[2], y = -0.08, yend = -0.08,
           colour = GREY30, linewidth = 0.9) +
  annotate("point",   x = med_slope, y = -0.08, colour = GREY30, size = 2) +
  annotate("text", x = med_slope, y = 1.22,
           label = sprintf("median = %.2f\npd = %.1f%%", med_slope, pd_val),
           hjust = 0.5, vjust = 1, size = 2.5, colour = "#555555") +
  labs(x = expression("Slope (WSLS " * beta * " per K unit)"),
       title = "Slope posterior\n(Bayesian linear regression)") +
  coord_cartesian(ylim = c(-0.23, 1.5), clip = "off") +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid    = element_blank(),
    axis.title.y  = element_blank(),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    axis.line.x   = element_line(colour = GREY30),
    axis.title.x  = element_text(size = 16),
    axis.text.x   = element_text(size = 8),
    plot.title    = element_text(size = 16, hjust = 0.5),
    plot.background = element_rect(fill = "white", colour = NA)
  )

# ── 6. Combine and save ───────────────────────────────────────────────────────
fig <- p_scatter | p_post
ggsave(OUT_PNG, fig, width = 10, height = 4.5, dpi = 150, bg = "white")
cat(sprintf("\nSaved → %s\n", OUT_PNG))
