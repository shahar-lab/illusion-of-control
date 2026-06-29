rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(posterior)
library(rstanarm)

# Accept DATA_DIR as optional command-line argument
args     <- commandArgs(trailingOnly = TRUE)
DATA_DIR <- if (length(args) >= 1) args[1] else "../../data/ioc-all-fixed-pilot/task"
OUT_DIR  <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)
dir.create("bayesian_draws_r", showWarnings = FALSE)

# ── style constants (plot-posterior + plot-colors skills) ─────────────────────
GREY30 <- "#4d4d4d"
GREY40 <- "#666666"
GREY65 <- "#a6a6a6"
GREY80 <- "#cccccc"
OI_BLUE   <- "#56B4E9"
OI_ORANGE <- "#E69F00"
BASE_FS <- 11

posterior_theme <- theme_minimal(base_size = BASE_FS) +
  theme(
    panel.grid    = element_blank(),
    axis.title.y  = element_blank(),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    axis.line.y   = element_blank(),
    axis.line.x   = element_line(colour = GREY30),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA)
  )

box_theme <- theme_minimal(base_size = BASE_FS) +
  theme(
    panel.grid    = element_blank(),
    axis.line.x   = element_line(colour = GREY30),
    axis.line.y   = element_line(colour = GREY30),
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA)
  )

# ── load data ─────────────────────────────────────────────────────────────────
files <- list.files(DATA_DIR, pattern = "[a-f0-9]{24}.*\\.csv$", full.names = TRUE)
df_raw <- files |>
  lapply(\(f) {
    pid <- regmatches(f, regexpr("[a-f0-9]{24}", f))
    read_csv(f, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
      mutate(participant = pid)
  }) |>
  bind_rows()

cat(sprintf("Loaded %d subjects\n", n_distinct(df_raw$participant)))

# ── per-lag preparation ───────────────────────────────────────────────────────
prepare_lag <- function(df_raw, lag) {
  gb <- df_raw |>
    filter(task == "gambling_choice", as.character(block_number) != "training") |>
    mutate(block_number = as.character(block_number)) |>
    arrange(participant, block_number, trial_number)

  records <- list()
  for (key in unique(paste(gb$participant, gb$block_number, sep = "__"))) {
    parts <- strsplit(key, "__")[[1]]
    pid   <- parts[1]; blk <- parts[2]
    grp   <- gb |> filter(participant == pid, block_number == blk)
    n     <- nrow(grp)
    if (n <= lag) next
    for (i in (lag + 1):n) {
      row   <- grp[i, ]
      nback <- grp[i - lag, ]
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
  bind_rows(records)
}

# ── Bayesian logistic regression via rstanarm (matching PyMC priors) ──────────
fit_bayesian <- function(df_lag) {
  fit <- stan_glm(
    stay ~ reward_nback, data = df_lag, family = binomial(),
    prior_intercept = normal(0, 2),
    prior           = normal(0, 2),
    chains = 4, iter = 2000, warmup = 1000,
    seed = 42, refresh = 0
  )
  as.vector(as.matrix(fit)[, "reward_nback"])
}

# ── per-subject proportions ───────────────────────────────────────────────────
subj_props <- function(df_lag) {
  df_lag |>
    group_by(participant, reward_nback) |>
    summarise(p_stay = mean(stay), .groups = "drop") |>
    rename(reward = reward_nback)
}

# ── panel builders ────────────────────────────────────────────────────────────
beta_panel <- function(beta_draws, lag_label, add_xlabel = FALSE) {
  med  <- median(beta_draws)
  pd   <- max(mean(beta_draws > 0), mean(beta_draws < 0)) * 100
  ci90 <- quantile(beta_draws, c(0.05, 0.95))

  df_kde <- data.frame(x = beta_draws)

  ann_label <- sprintf("[median = %.2f, pd = %.1f%%]", med, pd)

  p <- ggplot(df_kde, aes(x = x)) +
    stat_density(aes(y = after_stat(density / max(density))), geom = "area", fill = GREY80, colour = NA, bw = "SJ") +
    annotate("segment", x = ci90[1], xend = ci90[2], y = -0.09, yend = -0.09,
             colour = GREY30, linewidth = 0.9) +
    annotate("point",   x = med, y = -0.09, colour = GREY30, size = 1.8) +
    geom_vline(xintercept = med, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
    annotate("text", x = med, y = 0.88, label = ann_label,
             hjust = 0, vjust = 0, size = 2.5, colour = GREY40) +
    scale_x_continuous(limits = c(0, max(beta_draws) * 1.10)) +
    coord_cartesian(ylim = c(-0.17, 1.35), clip = "off") +
    labs(title = lag_label,
         x = if (add_xlabel) "β  (reward effect on log-odds of staying)" else NULL) +
    posterior_theme +
    theme(axis.title.x = element_text(size = 17, colour = "black"))

  p
}

box_panel <- function(props, add_xlabel = FALSE) {
  df_plot <- props |>
    mutate(condition = ifelse(reward == 0, "p(stay | no reward)", "p(stay | reward)"),
           condition = factor(condition, levels = c("p(stay | no reward)", "p(stay | reward)")),
           col = ifelse(reward == 0, OI_ORANGE, OI_BLUE))

  set.seed(0)
  p <- ggplot(df_plot, aes(x = condition, y = p_stay, fill = condition)) +
    geom_boxplot(width = 0.45, outlier.shape = NA, colour = "black",
                 linewidth = 0.4, alpha = 0.75) +
    geom_jitter(aes(colour = condition), width = 0.13, size = 1.5,
                alpha = 0.85, show.legend = FALSE) +
    scale_fill_manual(values  = c("p(stay | no reward)" = OI_ORANGE, "p(stay | reward)" = OI_BLUE)) +
    scale_colour_manual(values = c("p(stay | no reward)" = OI_ORANGE, "p(stay | reward)" = OI_BLUE)) +
    scale_y_continuous(limits = c(0, 1.05), breaks = c(0, 0.25, 0.5, 0.75, 1),
                       labels = c("0", ".25", ".50", ".75", "1")) +
    labs(y = "Proportion",
         x = if (add_xlabel) "Condition" else NULL) +
    box_theme +
    theme(
      legend.position  = "none",
      axis.text.x      = element_text(size = 14, colour = "black"),
      axis.title.y     = element_text(size = 14, colour = "black"),
      axis.title.x     = element_text(size = 18, colour = "black", margin = margin(t = 10))
    )
  p
}

# ── run lags ──────────────────────────────────────────────────────────────────
lag_results <- list()
for (lag in 1:3) {
  cat(sprintf("\n=== LAG %d ===\n", lag))
  df_lag <- prepare_lag(df_raw, lag)
  cat(sprintf("  Obs: %d  |  P(stay|reward): %.3f\n",
              nrow(df_lag), mean(df_lag$stay[df_lag$reward_nback == 1])))
  beta_draws <- fit_bayesian(df_lag)
  props      <- subj_props(df_lag)
  lag_results[[lag]] <- list(beta_draws = beta_draws, props = props)
  cat(sprintf("  beta median = %.3f\n", median(beta_draws)))
}

# ── assemble figure ───────────────────────────────────────────────────────────
panel_labels <- LETTERS[1:6]
plots <- list()
for (row in 1:3) {
  add_xl <- (row == 3)
  plots[[2 * row - 1]] <- beta_panel(lag_results[[row]]$beta_draws,
                                      sprintf("%d-back", row), add_xlabel = add_xl)
  plots[[2 * row]]     <- box_panel(lag_results[[row]]$props, add_xlabel = add_xl)
}

fig <- (plots[[1]] | plots[[2]]) /
       (plots[[3]] | plots[[4]]) /
       (plots[[5]] | plots[[6]]) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = BASE_FS + 2))

ggsave(file.path(OUT_DIR, "wsls_pilot_all_lags_r.png"), fig,
       width = 10, height = 9, dpi = 150, bg = "white")
cat("\nSaved: figures/wsls_pilot_all_lags_r.png\n")
