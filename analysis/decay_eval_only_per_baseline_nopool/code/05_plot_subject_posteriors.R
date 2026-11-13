# reads: artifacts/subject_draws.rds · writes: output/05_subject_posteriors.{pdf,png}

#### LOAD DRAWS ####

subject_draws <- readRDS(file.path(artifacts_dir, "subject_draws.rds"))

okabe_ito <- c("#E69F00", "#56B4E9", "#009E73", "#0072B2", "#D55E00", "#CC79A7", "#000000")
pal       <- setNames(okabe_ito[seq_along(unique(subject_draws$label))], sort(unique(subject_draws$label)))

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid             = element_blank(),
    axis.title.y           = element_blank(),
    axis.text.y            = element_blank(),
    axis.ticks.y           = element_blank(),
    axis.line.y            = element_blank(),
    axis.line.x            = element_line(colour = "grey30"),
    legend.position        = "inside",
    legend.position.inside = c(1, 0.95),
    legend.justification   = c("right", "top"),
    legend.background      = element_blank(),
    legend.key             = element_blank()
  )

#### PANEL A: ALPHA_PER (bounded) ####

alpha_stats <- subject_draws |>
  group_by(label) |>
  summarise(med = median(alpha_per), .groups = "drop") |>
  mutate(text = sprintf("%s: [median = %.2f]", label, med))

panel_a <- ggplot(subject_draws, aes(x = alpha_per, y = 0, fill = label, colour = label)) +
  stat_slab(alpha = 0.50) +
  stat_pointinterval(.width = 0.90, point_size = 3) +
  geom_text(data = alpha_stats, aes(x = med, y = Inf, label = text, colour = label),
            hjust = -0.05, vjust = seq(1.4, by = 1.4, length.out = nrow(alpha_stats)),
            size = 3.2, show.legend = FALSE) +
  scale_fill_manual(values = pal, guide = guide_legend(override.aes = list(alpha = 0.7))) +
  scale_colour_manual(values = pal, guide = "none") +
  posterior_theme +
  labs(x = "alpha_per", fill = NULL) +
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1.3), clip = "off")

#### PANEL B: BETA_PER (effect) ####

beta_stats <- subject_draws |>
  group_by(label) |>
  summarise(med = median(beta_per),
            pd  = max(mean(beta_per > 0), mean(beta_per < 0)) * 100,
            .groups = "drop") |>
  mutate(text = sprintf("%s: [median = %.2f, pd = %.2f%%]", label, med, pd))

max_abs <- max(abs(range(subject_draws$beta_per)))

panel_b <- ggplot(subject_draws, aes(x = beta_per, y = 0, fill = label, colour = label)) +
  stat_slab(alpha = 0.50) +
  stat_pointinterval(.width = 0.90, point_size = 3) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(data = beta_stats, aes(xintercept = med, colour = label),
             linetype = "dashed", linewidth = 0.4, show.legend = FALSE) +
  geom_text(data = beta_stats, aes(x = med, y = Inf, label = text, colour = label),
            hjust = -0.05, vjust = seq(1.4, by = 1.4, length.out = nrow(beta_stats)),
            size = 3.2, show.legend = FALSE) +
  scale_fill_manual(values = pal, guide = guide_legend(override.aes = list(alpha = 0.7))) +
  scale_colour_manual(values = pal, guide = "none") +
  posterior_theme +
  labs(x = "beta_per", fill = NULL) +
  coord_cartesian(xlim = c(-max_abs, max_abs), ylim = c(0, 1.3), clip = "off")

#### EXPORT ####

p_final <- (panel_a / panel_b) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "05_subject_posteriors"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = p_final, width = 10, height = 8, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = p_final, width = 10, height = 8, dpi = 300, bg = "white")
