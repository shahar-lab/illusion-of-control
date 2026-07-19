#### PLOT POPULATION-LEVEL POSTERIORS ####
# NOTE: see SKILL.md's "Note on posterior plots" — this raw-ggdist pattern is what every
# model in this lab actually uses, but check whether the /plot-posterior skill can now
# express this "posterior + true-value reference line, multi-panel" layout before
# defaulting to copying this template into a new model.

pop_draws         <- readRDS(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(
  file.path(artifacts_dir, "population_params.csv"),
  show_col_types = FALSE
)

# The model reports population parameters on the natural scale
# (alpha_*_pop = inv_logit(mu), beta_rl_pop = exp(mu)), so the true generating
# mu values get the same link applied before they are drawn as reference lines.
true_alpha_rl  <- plogis(population_params$mu[population_params$param == "alpha_rl"])
true_alpha_per <- plogis(population_params$mu[population_params$param == "alpha_per"])
true_beta_rl   <- exp(population_params$mu[population_params$param == "beta_rl"])
true_beta_per  <- population_params$mu[population_params$param == "beta_per"]

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

# One panel per parameter — repeat this block, swapping the column/variable names.

# alpha_rl
draws_alpha_rl <- pop_draws$alpha_rl_pop
med_alpha_rl   <- median(draws_alpha_rl)
range_alpha_rl <- range(c(draws_alpha_rl, true_alpha_rl))
pad_alpha_rl   <- 0.20 * diff(range_alpha_rl)

p1 <- ggplot(data.frame(value = draws_alpha_rl), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_alpha_rl, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_alpha_rl, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_alpha_rl, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_alpha_rl, true_alpha_rl),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "alpha_rl (population)") +
  coord_cartesian(
    xlim = c(range_alpha_rl[1] - pad_alpha_rl, range_alpha_rl[2] + pad_alpha_rl),
    ylim = c(0, 1.3), clip = "off"
  )

# ... repeat for alpha_per (p2), beta_rl (p3), beta_per (p4) ...

# 4 parameters: stacked column (p1/p2/p3/p4), height=11. 2 parameters: (p1/p2), height=6.
fig <- (p1 / p2 / p3 / p4) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(file.path(output_dir, "population_posteriors.pdf"), fig,
       width = 10, height = 11, bg = "white")
ggsave(file.path(output_dir, "population_posteriors.png"), fig,
       width = 10, height = 11, dpi = 300, bg = "white")

cat("Saved: population_posteriors.pdf / .png\n")
