rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(ggplot2)
library(ggdist)
library(patchwork)

DRAWS_DIR <- "bayesian_draws_qde"
OUT_DIR   <- "figures"
dir.create(OUT_DIR, showWarnings = FALSE)

draws_group <- read_csv(file.path(DRAWS_DIR, "posterior_draws_group.csv"), show_col_types = FALSE)

#### BUILD PANELS ####

# Panel A: alpha_rl_pop
draws_vec <- draws_group$alpha_rl_pop
med_a     <- median(draws_vec)
pd_a      <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
r_a       <- range(draws_vec); span_a <- diff(r_a)
df_a      <- data.frame(x = draws_vec)

p_alpha_rl <- ggplot(df_a, aes(x = x, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_a, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate(
    "text", x = med_a, y = Inf,
    label = sprintf("[median = %.2f, pd = %.2f%%]", med_a, pd_a),
    hjust = -0.05, vjust = 1.4, size = 3.0, colour = "grey40"
  ) +
  labs(x = "alpha_rl  (RL learning rate)") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  coord_cartesian(
    xlim = c(r_a[1] - 0.20 * span_a, r_a[2] + 0.20 * span_a),
    ylim = c(0, 1.3), clip = "off"
  )

# Panel B: alpha_per_pop
draws_vec <- draws_group$alpha_per_pop
med_b     <- median(draws_vec)
pd_b      <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
r_b       <- range(draws_vec); span_b <- diff(r_b)
df_b      <- data.frame(x = draws_vec)

p_alpha_per <- ggplot(df_b, aes(x = x, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_b, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate(
    "text", x = med_b, y = Inf,
    label = sprintf("[median = %.2f, pd = %.2f%%]", med_b, pd_b),
    hjust = -0.05, vjust = 1.4, size = 3.0, colour = "grey40"
  ) +
  labs(x = "alpha_per  (persev. learning rate)") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  coord_cartesian(
    xlim = c(r_b[1] - 0.20 * span_b, r_b[2] + 0.20 * span_b),
    ylim = c(0, 1.3), clip = "off"
  )

# Panel C: beta_rl_pop (positive, log-normal — non-effect)
draws_vec <- draws_group$beta_rl_pop
med_c     <- median(draws_vec)
pd_c      <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
r_c       <- range(draws_vec); span_c <- diff(r_c)
df_c      <- data.frame(x = draws_vec)

p_beta_rl <- ggplot(df_c, aes(x = x, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = med_c, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate(
    "text", x = med_c, y = Inf,
    label = sprintf("[median = %.2f, pd = %.2f%%]", med_c, pd_c),
    hjust = -0.05, vjust = 1.4, size = 3.0, colour = "grey40"
  ) +
  labs(x = "beta_rl  (RL inverse temperature)") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  coord_cartesian(
    xlim = c(r_c[1] - 0.20 * span_c, r_c[2] + 0.20 * span_c),
    ylim = c(0, 1.3), clip = "off"
  )

# Panel D: beta_per_pop (unbounded perseveration weight — zero reference meaningful)
draws_vec <- draws_group$beta_per_pop
med_d     <- median(draws_vec)
pd_d      <- max(mean(draws_vec > 0), mean(draws_vec < 0)) * 100
max_abs_d <- max(abs(range(draws_vec)))
df_d      <- data.frame(x = draws_vec)

p_beta_per <- ggplot(df_d, aes(x = x, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = 0,     linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(xintercept = med_d, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate(
    "text", x = med_d, y = Inf,
    label = sprintf("[median = %.2f, pd = %.2f%%]", med_d, pd_d),
    hjust = -0.05, vjust = 1.4, size = 3.0, colour = "grey40"
  ) +
  labs(x = "beta_per  (persev. weight)") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  coord_cartesian(xlim = c(-max_abs_d, max_abs_d), ylim = c(0, 1.3), clip = "off")

#### COMPOSE AND EXPORT ####
fig <- (p_alpha_rl | p_alpha_per) / (p_beta_rl | p_beta_per) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "param_estimation_qde"

ggsave(
  file.path(OUT_DIR, paste0(plot_name, ".pdf")),
  plot   = fig,
  width  = 10, height = 8, bg = "white"
)

ggsave(
  file.path(OUT_DIR, paste0(plot_name, ".png")),
  plot   = fig,
  width  = 10, height = 8, dpi = 300, bg = "white"
)

cat("Saved:", file.path(OUT_DIR, plot_name), ".pdf and .png\n")
