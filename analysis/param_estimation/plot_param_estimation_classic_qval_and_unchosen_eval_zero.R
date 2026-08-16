rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(ggplot2)
library(patchwork)

DRAWS_DIR <- "bayesian_draws_classic_qval_and_unchosen_eval_zero"
OUT_DIR   <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

GREY30    <- "#4d4d4d"
GREY40    <- "#666666"
GREY65    <- "#a6a6a6"
GREY80    <- "#cccccc"
OI_BLUE   <- "#0072B2"
OI_ORANGE <- "#E69F00"

draws_group   <- read_csv(file.path(DRAWS_DIR, "posterior_draws_group.csv"), show_col_types = FALSE)
draws_subject <- read_csv(file.path(DRAWS_DIR, "posterior_draws_subject.csv"), show_col_types = FALSE)

# ── posterior panel builder (top row) ────────────────────────────────────────
posterior_panel <- function(draws_vec, xlabel, is_effect = FALSE, fill_col = GREY80) {
  med  <- median(draws_vec)
  pd   <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
  ci80 <- quantile(draws_vec, c(0.10, 0.90))
  ci90 <- quantile(draws_vec, c(0.05, 0.95))

  ann_label <- if (is_effect) sprintf("[median = %.2f, pd = %.1f%%]", med, pd) else sprintf("[median = %.2f]", med)

  df <- data.frame(x = draws_vec)

  p <- ggplot(df, aes(x = x)) +
    geom_vline(xintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.7) +
    stat_density(aes(y = after_stat(density / max(density))), geom = "area",
                 fill = fill_col, colour = NA, bw = "SJ") +
    annotate("segment", x = ci90[1], xend = ci90[2], y = -0.14, yend = -0.14,
             colour = GREY30, linewidth = 0.6) +
    annotate("segment", x = ci80[1], xend = ci80[2], y = -0.08, yend = -0.08,
             colour = GREY30, linewidth = 1.3) +
    annotate("point",   x = med, y = -0.08, colour = GREY30, size = 2.2) +
    geom_vline(xintercept = med, colour = GREY65, linetype = "dashed", linewidth = 0.4) +
    annotate("text", x = med, y = 1.05, label = ann_label,
             hjust = 0.5, vjust = 0, size = 2.6, colour = GREY40) +
    labs(x = xlabel) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid    = element_blank(),
      axis.title.y  = element_blank(),
      axis.text.y   = element_blank(),
      axis.ticks.y  = element_blank(),
      axis.line.y   = element_blank(),
      axis.line.x   = element_line(colour = GREY30),
      axis.title.x  = element_text(size = 13, colour = "black"),
      axis.text.x   = element_text(size = 9),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA)
    )

  if (is_effect) {
    max_abs <- max(abs(range(draws_vec)))
    p <- p +
      geom_vline(xintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.7) +
      coord_cartesian(xlim = c(-max_abs, max_abs), ylim = c(-0.20, 1.35), clip = "off")
  } else {
    r <- range(draws_vec); span <- diff(r)
    p <- p +
      coord_cartesian(xlim = c(r[1] - 0.20 * span, r[2] + 0.20 * span),
                      ylim = c(-0.20, 1.35), clip = "off")
  }

  p
}

# ── subject dot-plot builder (bottom row) ────────────────────────────────────
subject_panel <- function(param_name, xlabel) {
  df <- draws_subject |>
    filter(param == param_name) |>
    arrange(median) |>
    mutate(rank = row_number())

  ggplot(df, aes(x = median, y = rank)) +
    geom_vline(xintercept = 0, colour = GREY40, linetype = "dashed", linewidth = 0.7) +
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
p_alpha_rl <- posterior_panel(draws_group$alpha_rl_pop, "alpha_rl  (learning rate)",       is_effect = FALSE)
p_delta    <- posterior_panel(draws_group$delta_pop,    "delta  (perseveration decay)",    is_effect = FALSE)
p_beta_rl  <- posterior_panel(draws_group$beta_rl_pop,  "beta_rl  (Q sensitivity)",        is_effect = FALSE)
p_beta_per <- posterior_panel(draws_group$beta_per_pop, "beta_per  (E sensitivity)",       is_effect = TRUE)

# ── build row 2: subject posteriors ──────────────────────────────────────────
s_alpha_rl <- subject_panel("alpha_rl",  "alpha_rl")
s_delta    <- subject_panel("delta",     "delta")
s_beta_rl  <- subject_panel("beta_rl",  "beta_rl")
s_beta_per <- subject_panel("beta_per", "beta_per")

# ── combine ───────────────────────────────────────────────────────────────────
top_row    <- p_alpha_rl | p_delta | p_beta_rl | p_beta_per
bottom_row <- s_alpha_rl | s_delta | s_beta_rl | s_beta_per

fig <- top_row / bottom_row +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(file.path(OUT_DIR, "param_estimation_classic_qval_and_unchosen_eval_zero.png"), fig,
       width = 14, height = 7, dpi = 150, bg = "white")
cat("Saved: figures/param_estimation_classic_qval_and_unchosen_eval_zero.png\n")
