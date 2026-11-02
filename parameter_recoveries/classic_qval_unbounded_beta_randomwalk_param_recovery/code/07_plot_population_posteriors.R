# reads: artifacts/population_posteriors.rds, population_params.csv · writes: output/07_population_posteriors.{pdf,png}

#### PLOT POPULATION-LEVEL POSTERIORS ####

pop_draws         <- read_rds(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(file.path(artifacts_dir, "population_params.csv"), show_col_types = FALSE)

# The model reports population parameters on the natural scale
# (alpha_pop = inv_logit(mu_alpha), beta_pop = mu_beta, identity link), so the true generating
# mu values get the same link applied before they are drawn as reference lines.
true_alpha <- plogis(population_params$mu[population_params$param == "alpha"])
true_beta  <- population_params$mu[population_params$param == "beta"]

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

# alpha
draws_alpha <- pop_draws$alpha_pop
med_alpha   <- median(draws_alpha)
range_alpha <- range(c(draws_alpha, true_alpha))
pad_alpha   <- 0.20 * diff(range_alpha)

p_alpha <- ggplot(data.frame(value = draws_alpha), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_alpha, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_alpha, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_alpha, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_alpha, true_alpha),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "alpha (population)") +
  coord_cartesian(
    xlim = c(range_alpha[1] - pad_alpha, range_alpha[2] + pad_alpha),
    ylim = c(0, 1.3), clip = "off"
  )

# beta
draws_beta <- pop_draws$beta_pop
med_beta   <- median(draws_beta)
range_beta <- range(c(draws_beta, true_beta))
pad_beta   <- 0.20 * diff(range_beta)

p_beta <- ggplot(data.frame(value = draws_beta), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_beta, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_beta, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_beta, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_beta, true_beta),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "beta (population)") +
  coord_cartesian(
    xlim = c(range_beta[1] - pad_beta, range_beta[2] + pad_beta),
    ylim = c(0, 1.3), clip = "off"
  )

fig <- (p_alpha / p_beta) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "07_population_posteriors"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = 10, height = 6, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = 10, height = 6, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "07_population_posteriors_plot.rds"))
