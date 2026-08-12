#### PLOT POPULATION-LEVEL POSTERIORS ####

pop_draws         <- readRDS(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(
  file.path(artifacts_dir, "population_params.csv"),
  show_col_types = FALSE
)

true_decay_rl <- plogis(population_params$mu[population_params$param == "decay_rl"])
true_decay_h  <- plogis(population_params$mu[population_params$param == "decay_h"])
true_rho_rl   <- population_params$mu[population_params$param == "rho_rl"]
true_rho_h    <- population_params$mu[population_params$param == "rho_h"]

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

# decay_rl
draws_decay_rl <- pop_draws$decay_rl_pop
med_decay_rl   <- median(draws_decay_rl)
range_decay_rl <- range(c(draws_decay_rl, true_decay_rl))
pad_decay_rl   <- 0.20 * diff(range_decay_rl)

p1 <- ggplot(data.frame(value = draws_decay_rl), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_decay_rl, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_decay_rl, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_decay_rl, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_decay_rl, true_decay_rl),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "decay_rl (population)") +
  coord_cartesian(
    xlim = c(range_decay_rl[1] - pad_decay_rl, range_decay_rl[2] + pad_decay_rl),
    ylim = c(0, 1.3), clip = "off"
  )

# decay_h
draws_decay_h <- pop_draws$decay_h_pop
med_decay_h   <- median(draws_decay_h)
range_decay_h <- range(c(draws_decay_h, true_decay_h))
pad_decay_h   <- 0.20 * diff(range_decay_h)

p2 <- ggplot(data.frame(value = draws_decay_h), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_decay_h, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_decay_h, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_decay_h, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_decay_h, true_decay_h),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "decay_h (population)") +
  coord_cartesian(
    xlim = c(range_decay_h[1] - pad_decay_h, range_decay_h[2] + pad_decay_h),
    ylim = c(0, 1.3), clip = "off"
  )

# rho_rl
draws_rho_rl <- pop_draws$rho_rl_pop
med_rho_rl   <- median(draws_rho_rl)
range_rho_rl <- range(c(draws_rho_rl, true_rho_rl))
pad_rho_rl   <- 0.20 * diff(range_rho_rl)

p3 <- ggplot(data.frame(value = draws_rho_rl), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_rho_rl, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_rho_rl, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_rho_rl, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_rho_rl, true_rho_rl),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "rho_rl (population)") +
  coord_cartesian(
    xlim = c(range_rho_rl[1] - pad_rho_rl, range_rho_rl[2] + pad_rho_rl),
    ylim = c(0, 1.3), clip = "off"
  )

# rho_h
draws_rho_h <- pop_draws$rho_h_pop
med_rho_h   <- median(draws_rho_h)
range_rho_h <- range(c(draws_rho_h, true_rho_h))
pad_rho_h   <- 0.20 * diff(range_rho_h)

p4 <- ggplot(data.frame(value = draws_rho_h), aes(x = value, y = 0)) +
  stat_slab(fill = "gray80") +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  geom_vline(xintercept = true_rho_h, linetype = "dashed",
             colour = "#EE6677", linewidth = 0.7) +
  geom_vline(xintercept = med_rho_h, linetype = "dashed",
             colour = "grey65", linewidth = 0.4) +
  annotate("text", x = med_rho_h, y = Inf,
           label = sprintf("[median = %.2f, true = %.2f]", med_rho_h, true_rho_h),
           hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
  posterior_theme +
  labs(x = "rho_h (population)") +
  coord_cartesian(
    xlim = c(range_rho_h[1] - pad_rho_h, range_rho_h[2] + pad_rho_h),
    ylim = c(0, 1.3), clip = "off"
  )

fig <- (p1 / p2 / p3 / p4) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

ggsave(file.path(output_dir, "population_posteriors.pdf"), fig,
       width = 10, height = 11, bg = "white")
ggsave(file.path(output_dir, "population_posteriors.png"), fig,
       width = 10, height = 11, dpi = 300, bg = "white")

cat("Saved: population_posteriors.pdf / .png\n")
