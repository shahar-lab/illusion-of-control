rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)
library(posterior)

DRAWS_DIR <- "bayesian_draws_r"
OUT_DIR   <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

GREY30 <- "#4d4d4d"
GREY40 <- "#666666"
GREY65 <- "#a6a6a6"
GREY80 <- "#cccccc"

# ── load draws ────────────────────────────────────────────────────────────────
draws_group <- read_csv(file.path(DRAWS_DIR, "posterior_draws_group_m1.csv"), show_col_types = FALSE)

# ── posterior panel builder ───────────────────────────────────────────────────
posterior_panel <- function(draws_vec, xlabel, is_effect = FALSE) {
  med  <- median(draws_vec)
  pd   <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
  ci90 <- quantile(draws_vec, c(0.05, 0.95))

  ann_label <- if (is_effect) sprintf("[median = %.2f, pd = %.1f%%]", med, pd) else sprintf("[median = %.2f]", med)

  df <- data.frame(x = draws_vec)

  p <- ggplot(df, aes(x = x)) +
    stat_density(aes(y = after_stat(density / max(density))), geom = "area", fill = GREY80, colour = NA, bw = "SJ") +
    annotate("segment", x = ci90[1], xend = ci90[2], y = -0.08, yend = -0.08,
             colour = GREY30, linewidth = 0.9) +
    annotate("point",   x = med, y = -0.08, colour = GREY30, size = 2) +
    geom_vline(xintercept = med, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
    annotate("text", x = med, y = 1.05, label = ann_label,
             hjust = 0, vjust = 0, size = 2.5, colour = GREY40) +
    labs(x = xlabel) +
    coord_cartesian(ylim = c(-0.16, 1.35), clip = "off") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid    = element_blank(),
      axis.title.y  = element_blank(),
      axis.text.y   = element_blank(),
      axis.ticks.y  = element_blank(),
      axis.line.x   = element_line(colour = GREY30),
      axis.title.x  = element_text(size = 16, colour = "black"),
      axis.text.x   = element_text(size = 9),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )

  if (is_effect)
    p <- p + geom_vline(xintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.7)

  p
}

# ── build panels ──────────────────────────────────────────────────────────────
pA <- posterior_panel(draws_group$alpha_pop, "α  (learning rate)",      is_effect = FALSE)
pB <- posterior_panel(draws_group$beta_pop,  "β  (inverse temperature)", is_effect = TRUE)
pC <- posterior_panel(draws_group$kappa_pop, "κ  (perseveration)",       is_effect = TRUE)
pD <- posterior_panel(draws_group$delta_pop, "δ  (decay rate)",          is_effect = FALSE)

fig <- (pA | pB) / (pC | pD) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 17))

ggsave(file.path(OUT_DIR, "param_estimation_m1_population.png"), fig,
       width = 12, height = 7, dpi = 150, bg = "white")
cat("Saved: figures/param_estimation_m1_population.png\n")
