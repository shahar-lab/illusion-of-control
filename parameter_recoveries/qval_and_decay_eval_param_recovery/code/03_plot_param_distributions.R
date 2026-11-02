# reads: artifacts/individual_params.csv · writes: output/03_param_distributions.{pdf,png}

#### PLOT TRUE PARAMETER DISTRIBUTIONS ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)

dist_theme <- theme_minimal(base_size = 13) +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank()
  )

dist_panel <- function(param_name, link) {
  values <- individual_params[[param_name]]
  bw     <- if (link == "inv_logit") 1 / 30 else diff(range(values)) / 30

  p <- ggplot(tibble(value = values), aes(x = value)) +
    geom_dotplot(binwidth = bw, fill = "#4477AA", colour = "white") +
    dist_theme +
    labs(x = param_name, y = NULL)

  if (link == "inv_logit") p <- p + scale_x_continuous(limits = c(0, 1))
  p
}

fig <- wrap_plots(Map(dist_panel, population_params$param, population_params$link), nrow = 1) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name  <- "03_param_distributions"
fig_width  <- 5 * nrow(population_params)

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = fig_width, height = 5, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = fig_width, height = 5, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "03_param_distributions_plot.rds"))
