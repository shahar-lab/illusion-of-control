rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(patchwork)

draws_1 <- read_csv("bayesian_draws/wsls_results_1back.csv", show_col_types = FALSE)
draws_2 <- read_csv("bayesian_draws/wsls_results_2back.csv", show_col_types = FALSE)
draws_3 <- read_csv("bayesian_draws/wsls_results_3back.csv", show_col_types = FALSE)

# Colors matching existing pilot20 scripts (Okabe-Ito palette)
cols    <- c("Not rewarded" = "#E69F00", "Rewarded" = "#56B4E9")
cols_dk <- c("Not rewarded" = "#9A6B00", "Rewarded" = "#1A6FA8")

make_panels <- function(draws_df, lag_label, show_x = FALSE) {
  med_beta <- median(draws_df$beta)
  pd_beta  <- mean(draws_df$beta > 0) * 100
  ann      <- sprintf("[median = %.2f, pd = %.1f%%]", med_beta, pd_beta)
  beta_lim <- max(abs(quantile(draws_df$beta, c(0.005, 0.995)))) * 1.15

  pA <- ggplot(draws_df, aes(x = beta)) +
    geom_density(fill = "gray75", color = NA, alpha = 0.9) +
    geom_vline(xintercept = 0,        linetype = "dashed", color = "gray40", linewidth = 0.5) +
    geom_vline(xintercept = med_beta, linetype = "dotted", color = "gray50", linewidth = 0.5) +
    annotate("text", x = med_beta, y = Inf,
      label = ann, hjust = -0.05, vjust = 1.5, size = 2.8, color = "gray40") +
    coord_cartesian(xlim = c(-beta_lim, beta_lim), clip = "off") +
    labs(
      x     = if (show_x) "β (reward effect on log-odds of staying)" else NULL,
      y     = NULL,
      title = lag_label
    ) +
    theme_classic(base_size = 12) +
    theme(
      axis.text.y  = element_blank(),
      axis.ticks.y = element_blank(),
      axis.line.y  = element_blank()
    )

  draws_long <- draws_df |>
    select(p_stay_noreward, p_stay_reward) |>
    pivot_longer(everything(), names_to = "condition", values_to = "p_stay") |>
    mutate(condition = factor(condition,
      levels = c("p_stay_noreward", "p_stay_reward"),
      labels = c("Not rewarded", "Rewarded")
    ))

  pB <- ggplot(draws_long, aes(x = p_stay, fill = condition, color = condition)) +
    geom_density(alpha = 0.75, linewidth = 0.5) +
    scale_fill_manual(values  = cols) +
    scale_color_manual(values = cols_dk) +
    labs(
      x     = if (show_x) "P(stay)" else NULL,
      y     = NULL,
      fill  = NULL,
      color = NULL
    ) +
    theme_classic(base_size = 12) +
    theme(
      axis.text.y      = element_blank(),
      axis.ticks.y     = element_blank(),
      axis.line.y      = element_blank(),
      legend.position  = "right"
    )

  list(pA, pB)
}

p1 <- make_panels(draws_1, "1-back")
p2 <- make_panels(draws_2, "2-back")
p3 <- make_panels(draws_3, "3-back", show_x = TRUE)

combined <- (p1[[1]] | p1[[2]]) / (p2[[1]] | p2[[2]]) / (p3[[1]] | p3[[2]]) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/wsls_posterior_all_lags.png", combined,
       width = 10, height = 10, dpi = 150, bg = "white")
message("Saved: figures/wsls_posterior_all_lags.png")
