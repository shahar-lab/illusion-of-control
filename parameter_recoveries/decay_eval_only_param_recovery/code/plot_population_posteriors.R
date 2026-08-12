#### PLOT POPULATION-LEVEL POSTERIORS ####

pop_draws         <- readRDS(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(
  file.path(artifacts_dir, "population_params.csv"),
  show_col_types = FALSE
)

true_alpha_per <- plogis(population_params$mu[population_params$param == "alpha_per"])
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

# alpha_per
draws_alpha_per <- pop_draws$alpha_per_pop
med_alpha_per   <- median(draws_alpha_per)
range_alpha_per <- range(c(draws_alpha_per, true_alpha_per))
pad_alpha_per   <- 0.20 * diff(range_alpha_per)

p1 <- ggplot(data.frame(value = draws_alpha_per), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_alpha_per, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_alpha_per, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_alpha_per, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_alpha_per, true_alpha_per),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "alpha_per (population)") +
  coord_cartesian(
    xlim = c(range_alpha_per[1] - pad_alpha_per, range_alpha_per[2] + pad_alpha_per),
    ylim = c(0, 1.3), clip = "off"
  )

# beta_per
draws_beta_per <- pop_draws$beta_per_pop
med_beta_per   <- median(draws_beta_per)
range_beta_per <- range(c(draws_beta_per, true_beta_per))
pad_beta_per   <- 0.20 * diff(range_beta_per)

p2 <- ggplot(data.frame(value = draws_beta_per), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_beta_per, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_beta_per, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_beta_per, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_beta_per, true_beta_per),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "beta_per (population)") +
  coord_cartesian(
    xlim = c(range_beta_per[1] - pad_beta_per, range_beta_per[2] + pad_beta_per),
    ylim = c(0, 1.3), clip = "off"
  )

fig <- (p1 / p2) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(file.path(output_dir, "population_posteriors.pdf"), fig,
       width = 10, height = 6, bg = "white")
ggsave(file.path(output_dir, "population_posteriors.png"), fig,
       width = 10, height = 6, dpi = 300, bg = "white")

cat("Saved: population_posteriors.pdf / .png\n")
