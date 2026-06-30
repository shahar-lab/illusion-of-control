rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(ggdist)
library(patchwork)

DRAWS_DIR <- "bayesian_draws"

draws_1 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_1back.csv"), show_col_types = FALSE)
draws_2 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_2back.csv"), show_col_types = FALSE)
draws_3 <- read_csv(file.path(DRAWS_DIR, "posterior_draws_3back.csv"), show_col_types = FALSE)

props_1 <- read_csv(file.path(DRAWS_DIR, "subj_props_1back.csv"), show_col_types = FALSE)
props_2 <- read_csv(file.path(DRAWS_DIR, "subj_props_2back.csv"), show_col_types = FALSE)
props_3 <- read_csv(file.path(DRAWS_DIR, "subj_props_3back.csv"), show_col_types = FALSE)

beta_lims <- c(-0.4, 1.1)

posterior_theme <- theme_classic(base_size = 12) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), axis.line.y = element_blank())

box_theme <- theme_classic(base_size = 12) +
  theme(legend.position = "none")

FILL_NR <- "#E69F00"
FILL_R  <- "#56B4E9"
COL_NR  <- "#9A6B00"
COL_R   <- "#1A6FA8"

make_beta_panel <- function(draws, lag_label, add_x_label = FALSE) {
  ann <- sprintf("[median = %.2f, pd = %.1f%%]",
                 median(draws$beta), mean(draws$beta > 0) * 100)
  ggplot(draws, aes(x = beta, y = 0)) +
    stat_halfeye(fill = "gray75", color = NA, .width = 0.95,
      point_color = "black", point_fill = "black", point_size = 1.5,
      interval_color = "black", linewidth = 0.8) +
    geom_vline(xintercept = 0,                   linetype = "dashed", color = "gray40", linewidth = 0.5) +
    geom_vline(xintercept = median(draws$beta),  linetype = "dotted", color = "gray50", linewidth = 0.5) +
    scale_x_continuous(limits = beta_lims, breaks = c(-0.5, 0, 0.5, 1.0)) +
    labs(
      x        = if (add_x_label) "β (reward effect on log-odds of staying)" else NULL,
      y        = NULL,
      title    = lag_label,
      subtitle = ann
    ) +
    posterior_theme +
    theme(plot.subtitle = element_text(size = 9, color = "gray40"))
}

make_box_panel <- function(props, add_x_label = FALSE, add_legend = FALSE) {
  df_plot <- props |>
    mutate(
      condition = factor(condition,
        levels = c("Not rewarded", "Rewarded"),
        labels = c("p(stay|no reward)", "p(stay|reward)")
      ),
      p_switch = 1 - p_stay
    ) |>
    pivot_longer(c(p_stay, p_switch), names_to = "measure", values_to = "value") |>
    mutate(
      measure = factor(measure,
        levels = c("p_stay", "p_switch"),
        labels = c("p(stay|reward)", "p(switch|reward)")
      )
    ) |>
    filter(condition == "p(stay|reward)")

  # For each subject, compute p(stay|reward) and p(switch|reward)
  df_box <- props |>
    filter(condition == "Rewarded") |>
    mutate(p_switch = 1 - p_stay) |>
    pivot_longer(c(p_stay, p_switch), names_to = "measure", values_to = "value") |>
    mutate(
      measure = factor(measure,
        levels = c("p_stay", "p_switch"),
        labels = c("p(stay|reward)", "p(switch|reward)")
      ),
      fill_col = ifelse(measure == "p(stay|reward)", FILL_R, FILL_NR)
    )

  ggplot(df_box, aes(x = measure, y = value, fill = measure)) +
    geom_boxplot(width = 0.5, outlier.size = 1.5, outlier.alpha = 0.6) +
    geom_jitter(width = 0.1, size = 1, alpha = 0.5, color = "gray30") +
    scale_fill_manual(values = c("p(stay|reward)" = FILL_R, "p(switch|reward)" = FILL_NR)) +
    scale_y_continuous(limits = c(0, 1)) +
    labs(
      x    = if (add_x_label) "Condition" else NULL,
      y    = if (add_x_label) "Proportion" else NULL,
      fill = NULL
    ) +
    box_theme
}

dir.create("figures", showWarnings = FALSE)

pA1 <- make_beta_panel(draws_1, "1-back")
pB1 <- make_box_panel(props_1)

pA2 <- make_beta_panel(draws_2, "2-back")
pB2 <- make_box_panel(props_2)

pA3 <- make_beta_panel(draws_3, "3-back", add_x_label = TRUE)
pB3 <- make_box_panel(props_3, add_x_label = TRUE)

combined <- (pA1 | pB1) / (pA2 | pB2) / (pA3 | pB3) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave("figures/wsls_pilot_all_lags.png", combined,
       width = 10, height = 10, dpi = 150, bg = "white")

message("Saved: figures/wsls_pilot_all_lags.png")
