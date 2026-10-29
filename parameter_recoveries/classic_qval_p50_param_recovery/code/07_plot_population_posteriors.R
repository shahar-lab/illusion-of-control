# reads: artifacts/population_posteriors.rds, population_params.csv · writes: output/07_population_posteriors.{pdf,png}

#### PLOT POPULATION-LEVEL POSTERIORS ####

pop_draws         <- read_rds(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(file.path(artifacts_dir, "population_params.csv"), show_col_types = FALSE)

param_labels <- c(mu_alpha = "mu[alpha]", mu_beta = "mu[beta]", sigma_alpha = "sigma[alpha]", sigma_beta = "sigma[beta]")

true_values <- tibble(
  variable   = c("mu_alpha", "mu_beta", "sigma_alpha", "sigma_beta"),
  true_value = c(population_params$mu, population_params$sigma)
)

draws_long <- pop_draws |>
  as_tibble() |>
  select(all_of(names(param_labels))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "value") |>
  left_join(true_values, by = "variable") |>
  mutate(label = factor(param_labels[variable], levels = param_labels))

# Per-panel x-range: draws and true value widened 20% at each end
panel_info <- draws_long |>
  group_by(label) |>
  summarise(
    median_value = median(value),
    true_value   = first(true_value),
    lo           = min(c(value, true_value)),
    hi           = max(c(value, true_value)),
    .groups      = "drop"
  ) |>
  mutate(x_min = lo - 0.20 * (hi - lo), x_max = hi + 0.20 * (hi - lo))

# Slab: kernel density over the draws' range, tallest panel scaled to 0.9 (ggdist's stat_slab look)
slab_data <- draws_long |>
  group_by(label) |>
  reframe(as_tibble(density(value, n = 512, from = min(value), to = max(value))[c("x", "y")])) |>
  mutate(y = 0.9 * y / max(y))

interval_data <- draws_long |>
  group_by(label) |>
  summarise(median_value = median(value), lower = quantile(value, 0.05), upper = quantile(value, 0.95), .groups = "drop")

panel_limits <- panel_info |>
  select(label, x_min, x_max) |>
  pivot_longer(c(x_min, x_max), values_to = "value")

p <- ggplot() +
  geom_ribbon(data = slab_data, aes(x = x, ymin = 0, ymax = y), fill = "gray80") +
  geom_segment(data = interval_data, aes(x = lower, xend = upper, y = 0, yend = 0), linewidth = 1) +
  geom_point(data = interval_data, aes(x = median_value, y = 0), size = 3) +
  geom_blank(data = panel_limits, aes(x = value, y = 0)) +
  geom_vline(data = panel_info, aes(xintercept = median_value), linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  geom_vline(data = panel_info, aes(xintercept = true_value), linetype = "dotted", colour = "blue", linewidth = 0.8) +
  geom_text(data = panel_info, aes(x = median_value, y = 1.25, label = sprintf("[median = %.2f]", median_value)),
            hjust = -0.05, size = 3.2, colour = "grey40") +
  facet_wrap(~ label, ncol = 2, scales = "free_x", labeller = label_parsed) +
  coord_cartesian(ylim = c(0, 1.3), clip = "off") +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.x  = element_line(colour = "grey30"),
    strip.text   = element_text(size = 14)
  ) +
  labs(x = "Population parameter (unconstrained scale)")

plot_name <- "07_population_posteriors"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = p, width = 10, height = 6, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = p, width = 10, height = 6, dpi = 300, bg = "white")
write_rds(p, file.path(artifacts_dir, "07_population_posteriors_plot.rds"))
