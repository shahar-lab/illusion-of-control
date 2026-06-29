rm(list = ls())

#### SETUP ####
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(patchwork)

DRAWS_DIR <- "bayesian_draws_r"
OUT_DIR   <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

GREY30   <- "#4d4d4d"
GREY40   <- "#666666"
GREY65   <- "#a6a6a6"
GREY80   <- "#cccccc"
OI_BLUE  <- "#0072B2"
OI_ORANGE <- "#E69F00"

COL_M1   <- "#bcd4e6"
COL_M2   <- "#f5c6a0"

draws_group   <- read_csv(file.path(DRAWS_DIR, "posterior_draws_group.csv"), show_col_types = FALSE)
draws_subject <- read_csv(file.path(DRAWS_DIR, "posterior_draws_subject.csv"), show_col_types = FALSE)

# ── posterior panel builder (top row) ────────────────────────────────────────
posterior_panel <- function(draws_vec, xlabel, is_effect = FALSE, fill_col = GREY80) {
  med  <- median(draws_vec)
  pd   <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
  ci90 <- quantile(draws_vec, c(0.05, 0.95))

  ann_label <- if (is_effect) sprintf("[median = %.2f, pd = %.1f%%]", med, pd) else sprintf("[median = %.2f]", med)

  df <- data.frame(x = draws_vec)

  p <- ggplot(df, aes(x = x)) +
    stat_density(aes(y = after_stat(density / max(density))), geom = "area",
                 fill = fill_col, colour = NA, bw = "SJ") +
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
      axis.title.x  = element_text(size = 13, colour = "black"),
      axis.text.x   = element_text(size = 9),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )

  if (is_effect)
    p <- p + geom_vline(xintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.7)

  p
}

# ── subject dot-plot builder (bottom row) ────────────────────────────────────
subject_panel <- function(param_name, xlabel) {
  df <- draws_subject |>
    filter(param == param_name) |>
    arrange(median) |>
    mutate(
      rank  = row_number(),
      color = if_else(understood_eq_felt, OI_BLUE, OI_ORANGE)
    )

  ggplot(df, aes(x = median, y = rank)) +
    geom_errorbarh(aes(xmin = lo90, xmax = hi90, colour = understood_eq_felt),
                   height = 0, linewidth = 0.5, alpha = 0.7) +
    geom_point(aes(colour = understood_eq_felt), size = 1.8, alpha = 0.9) +
    scale_colour_manual(values = c("TRUE" = OI_BLUE, "FALSE" = OI_ORANGE), guide = "none") +
    labs(x = xlabel) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid    = element_blank(),
      axis.title.y  = element_blank(),
      axis.text.y   = element_blank(),
      axis.ticks.y  = element_blank(),
      axis.line.x   = element_line(colour = GREY30),
      axis.line.y   = element_line(colour = GREY30),
      axis.title.x  = element_text(size = 13, colour = "black"),
      axis.text.x   = element_text(size = 9),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )
}

# ── build row 1: group posteriors ────────────────────────────────────────────
p_delta_m1  <- posterior_panel(draws_group$delta_pop,    "δ-M1  (decay rate)",         is_effect = FALSE, fill_col = COL_M1)
p_delta_m2  <- posterior_panel(draws_group$delta_m2_pop, "δ-M2  (decay rate)",         is_effect = FALSE, fill_col = COL_M2)
p_kappa_m1  <- posterior_panel(draws_group$kappa_pop,    "κ-M1  (perseveration)",      is_effect = TRUE,  fill_col = COL_M1)
p_kappa_m2  <- posterior_panel(draws_group$kappa_m2_pop, "κ-M2  (perseveration)",      is_effect = TRUE,  fill_col = COL_M2)
p_alpha     <- posterior_panel(draws_group$alpha_pop,    "α  (learning rate)",         is_effect = FALSE, fill_col = GREY80)
p_beta      <- posterior_panel(draws_group$beta_pop,     "β  (inverse temperature)",   is_effect = TRUE,  fill_col = GREY80)

# ── build row 2: subject posteriors ──────────────────────────────────────────
s_delta_m1  <- subject_panel("delta_m1", "δ-M1")
s_delta_m2  <- subject_panel("delta_m2", "δ-M2")
s_kappa_m1  <- subject_panel("kappa_m1", "κ-M1")
s_kappa_m2  <- subject_panel("kappa_m2", "κ-M2")
s_alpha     <- subject_panel("alpha_m1", "α")
s_beta      <- subject_panel("beta_m1",  "β")

# ── combine ───────────────────────────────────────────────────────────────────
top_row    <- p_delta_m1 | p_delta_m2 | p_kappa_m1 | p_kappa_m2 | p_alpha | p_beta
bottom_row <- s_delta_m1 | s_delta_m2 | s_kappa_m1 | s_kappa_m2 | s_alpha | s_beta

fig <- top_row / bottom_row +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(file.path(OUT_DIR, "param_estimation.png"), fig,
       width = 16, height = 10, dpi = 150, bg = "white")
cat("Saved: figures/param_estimation.png\n")
