# reads: artifacts/population_posteriors.rds, population_params.csv · writes: output/07_population_posteriors.{pdf,png}

#### PLOT POPULATION-LEVEL POSTERIORS ####

pop_draws         <- read_rds(file.path(artifacts_dir, "population_posteriors.rds"))
population_params <- read_csv(file.path(artifacts_dir, "population_params.csv"), show_col_types = FALSE)

# The model reports population parameters on the natural scale
# (<param>_pop = link(mu_<param>)), so the true generating mu values get the same
# link applied before they are drawn as reference lines.
link_fun <- list(inv_logit = plogis, exp = exp, identity = identity)

posterior_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  )

posterior_panel <- function(param_name, mu, link) {
  draws  <- pop_draws[[paste0(param_name, "_pop")]]
  true   <- link_fun[[link]](mu)
  med    <- median(draws)
  limits <- range(c(draws, true))
  pad    <- 0.20 * diff(limits)

  ggplot(data.frame(value = draws), aes(x = value, y = 0)) +
    stat_slab(fill = "gray80") +
    stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
    geom_vline(xintercept = true, linetype = "dashed",
               colour = "#EE6677", linewidth = 0.7) +
    geom_vline(xintercept = med, linetype = "dashed",
               colour = "grey65", linewidth = 0.4) +
    annotate("text", x = med, y = Inf,
             label = sprintf("[median = %.2f, true = %.2f]", med, true),
             hjust = -0.05, vjust = 1.4, size = 3.2, colour = "grey40") +
    posterior_theme +
    labs(x = paste(param_name, "(population)")) +
    coord_cartesian(
      xlim = c(limits[1] - pad, limits[2] + pad),
      ylim = c(0, 1.3), clip = "off"
    )
}

fig <- wrap_plots(Map(posterior_panel, population_params$param, population_params$mu, population_params$link), ncol = 1) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name  <- "07_population_posteriors"
fig_height <- 3 * nrow(population_params)

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = 10, height = fig_height, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = 10, height = fig_height, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "07_population_posteriors_plot.rds"))
