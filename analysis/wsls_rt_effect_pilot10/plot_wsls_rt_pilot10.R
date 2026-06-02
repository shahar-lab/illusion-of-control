rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(readr)
library(patchwork)

res_1 <- read_csv("bayesian_draws/wsls_rt_1back.csv", show_col_types = FALSE) |> mutate(lag = "1-back")
res_2 <- read_csv("bayesian_draws/wsls_rt_2back.csv", show_col_types = FALSE) |> mutate(lag = "2-back")
res_3 <- read_csv("bayesian_draws/wsls_rt_3back.csv", show_col_types = FALSE) |> mutate(lag = "3-back")

make_scatter <- function(df, lag_label, show_x = FALSE) {
  all_vals <- c(df$beta_fast_lo, df$beta_fast_hi, df$beta_slow_lo, df$beta_slow_hi)
  lim_pad  <- max(abs(all_vals), na.rm = TRUE) * 1.15
  lim      <- c(-lim_pad, lim_pad)

  ggplot(df, aes(x = beta_fast, y = beta_slow)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
    geom_hline(yintercept = 0, linetype = "dotted", color = "gray70", linewidth = 0.4) +
    geom_vline(xintercept = 0, linetype = "dotted", color = "gray70", linewidth = 0.4) +
    geom_errorbar(aes(ymin = beta_slow_lo, ymax = beta_slow_hi),
                  width = 0, color = "gray60", linewidth = 0.5) +
    geom_errorbarh(aes(xmin = beta_fast_lo, xmax = beta_fast_hi),
                   height = 0, color = "gray60", linewidth = 0.5) +
    geom_point(size = 2.5, color = "#0072B2") +
    coord_cartesian(xlim = lim, ylim = lim) +
    labs(
      x     = if (show_x) "β fast (reward effect on log-odds of staying)" else NULL,
      y     = "β slow (reward effect on log-odds of staying)",
      title = lag_label
    ) +
    theme_classic(base_size = 12)
}

p1 <- make_scatter(res_1, "1-back")
p2 <- make_scatter(res_2, "2-back")
p3 <- make_scatter(res_3, "3-back", show_x = TRUE)

combined <- p1 / p2 / p3 +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/wsls_rt_beta_scatter.png", combined,
       width = 6, height = 12, dpi = 150, bg = "white")
message("Saved: figures/wsls_rt_beta_scatter.png")
