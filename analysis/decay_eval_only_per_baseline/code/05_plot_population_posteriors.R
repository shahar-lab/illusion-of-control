# reads: artifacts/fit.rds · writes: output/05_population_posteriors.{pdf,png}

#### LOAD DRAWS ####

fit <- readRDS(file.path(artifacts_dir, "fit.rds"))

alpha_draws <- as.numeric(fit$draws("alpha_per_pop"))
beta_draws  <- as.numeric(fit$draws("beta_per_pop"))

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

#### PANEL A: ALPHA_PER_POP (bounded) ####

alpha_med <- median(alpha_draws)

panel_a <- ggplot(data.frame(theta = alpha_draws), aes(x = theta, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = 0.90, point_size = 3) +
  geom_vline(xintercept = alpha_med, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = alpha_med, y = Inf, label = sprintf("[median = %.2f]", alpha_med),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "alpha_per (population)") +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1.3), clip = "off")

#### PANEL B: BETA_PER_POP (effect) ####

beta_med <- median(beta_draws)
beta_pd  <- max(mean(beta_draws > 0), mean(beta_draws < 0)) * 100
max_abs  <- max(abs(range(beta_draws)))

panel_b <- ggplot(data.frame(theta = beta_draws), aes(x = theta, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = 0.90, point_size = 3) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(xintercept = beta_med, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate("text", x = beta_med, y = Inf,
           label = sprintf("[median = %.2f, pd = %.2f%%]", beta_med, beta_pd),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "beta_per (population)") +
  coord_cartesian(xlim = c(-max_abs, max_abs), ylim = c(0, 1.3), clip = "off")

#### EXPORT ####

p_final <- (panel_a / panel_b) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "05_population_posteriors"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = p_final, width = 10, height = 8, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = p_final, width = 10, height = 8, dpi = 300, bg = "white")
