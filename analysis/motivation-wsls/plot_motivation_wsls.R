rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggdist)
library(patchwork)

DRAWS_DIR <- "bayesian_draws"

#### LOAD DRAWS ####
draws_1 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_motiv_1back.csv"), show_col_types = FALSE) |>
  mutate(lag = "1-back")
draws_2 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_motiv_2back.csv"), show_col_types = FALSE) |>
  mutate(lag = "2-back")
draws_3 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_motiv_3back.csv"), show_col_types = FALSE) |>
  mutate(lag = "3-back")

# gamma draws (one row per MCMC draw — same for all subjects within a draw)
gamma_1 <- draws_1 |> distinct(.draw, gamma) |> mutate(lag = "1-back")
gamma_2 <- draws_2 |> distinct(.draw, gamma) |> mutate(lag = "2-back")
gamma_3 <- draws_3 |> distinct(.draw, gamma) |> mutate(lag = "3-back")

#### ANNOTATION HELPERS ####
ann <- function(d) sprintf("[median = %.2f, pd = %.1f%%]",
  median(d$gamma), mean(d$gamma > 0) * 100)

ann_1 <- ann(gamma_1)
ann_2 <- ann(gamma_2)
ann_3 <- ann(gamma_3)

#### SHARED THEME ####
theme_post <- theme_classic(base_size = 12) +
  theme(
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank()
  )

#### PANEL A: gamma posteriors for each lag ####
gamma_lims <- range(c(gamma_1$gamma, gamma_2$gamma, gamma_3$gamma)) * 1.1

make_gamma_panel <- function(draws_gamma, lag_label, ann_text, show_x = FALSE) {
  ggplot(draws_gamma, aes(x = gamma, y = 0)) +
    stat_halfeye(fill = "gray75", color = NA, .width = 0.95,
      point_color = "black", point_fill = "black", point_size = 1.5,
      interval_color = "black", linewidth = 0.8) +
    geom_vline(xintercept = 0,                     linetype = "dashed", color = "gray40", linewidth = 0.5) +
    geom_vline(xintercept = median(draws_gamma$gamma), linetype = "dotted", color = "gray50", linewidth = 0.5) +
    scale_x_continuous(limits = gamma_lims) +
    labs(
      x        = if (show_x) expression(gamma ~ "(motivation effect on WSLS" ~ beta ~ ")") else NULL,
      y        = NULL,
      title    = lag_label,
      subtitle = ann_text
    ) +
    theme_post +
    theme(plot.subtitle = element_text(size = 9, color = "gray40"))
}

pA1 <- make_gamma_panel(gamma_1, "1-back", ann_1)
pA2 <- make_gamma_panel(gamma_2, "2-back", ann_2)
pA3 <- make_gamma_panel(gamma_3, "3-back", ann_3, show_x = TRUE)

#### PANEL B: per-subject beta vs. motivation score ####
make_scatter_panel <- function(draws_df, lag_label, show_x = FALSE) {
  subj_summary <- draws_df |>
    group_by(participant, motivation) |>
    summarise(beta_med = median(beta), .groups = "drop")

  stopifnot(nrow(subj_summary) == length(unique(draws_df$participant)))

  pearson_r <- cor(subj_summary$motivation, subj_summary$beta_med, method = "pearson")
  x_breaks  <- seq(min(subj_summary$motivation), max(subj_summary$motivation), length.out = 4)
  y_lim     <- range(quantile(draws_df$beta, c(0.01, 0.99)))
  y_breaks  <- seq(y_lim[1], y_lim[2], length.out = 4)

  ggplot(draws_df, aes(x = motivation, y = beta, group = participant)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.6) +
    geom_smooth(
      data        = subj_summary,
      aes(x = motivation, y = beta_med, group = NULL),
      method      = "lm",
      se          = FALSE,
      colour      = "#EE6677",
      linewidth   = 0.8,
      inherit.aes = FALSE
    ) +
    stat_pointinterval(
      .width     = c(0.80, 0.90),
      point_size = 2,
      linewidth  = 0.8,
      colour     = "#4477AA"
    ) +
    annotate(
      "text", x = Inf, y = Inf,
      label = sprintf("[Pearson r = %.2f]", pearson_r),
      hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30"
    ) +
    scale_x_continuous(breaks = round(x_breaks, 1)) +
    scale_y_continuous(breaks = round(y_breaks, 2)) +
    coord_fixed(xlim = range(subj_summary$motivation), ylim = y_lim, clip = "off") +
    labs(
      x     = if (show_x) "Overall motivation score (IMI)" else NULL,
      y     = expression(beta ~ "(WSLS effect)"),
      title = lag_label
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      axis.title.x     = element_text(size = 11)
    )
}

pB1 <- make_scatter_panel(draws_1, "1-back")
pB2 <- make_scatter_panel(draws_2, "2-back")
pB3 <- make_scatter_panel(draws_3, "3-back", show_x = TRUE)

#### COMBINE AND SAVE ####
combined <- (pA1 | pB1) / (pA2 | pB2) / (pA3 | pB3) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/motivation_wsls_effect.png", combined,
       width = 11, height = 11, dpi = 150, bg = "white")
message("Saved: figures/motivation_wsls_effect.png")
