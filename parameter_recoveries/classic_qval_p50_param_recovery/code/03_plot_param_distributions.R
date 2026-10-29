# reads: artifacts/individual_params.csv · writes: output/03_param_distributions.{pdf,png}

#### PLOT TRUE PARAMETER DISTRIBUTIONS ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)

# Dots plus the generating density, rescaled to the height of the tallest stack
dot_panel <- function(values, full_range, axis_breaks, density_fun, x_label) {
  p <- ggplot(tibble(x = values), aes(x = x)) +
    geom_dots(layout = "bin", binwidth = NA, fill = "gray50", colour = "gray30") +
    scale_x_continuous(breaks = axis_breaks) +
    coord_cartesian(xlim = full_range, clip = "off") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(x = x_label)

  built       <- ggplot_build(p)$data[[1]]
  max_count   <- built |> count(bin) |> pull(n) |> max()
  tick_counts <- round(seq(0, max_count, length.out = 4))

  density_grid <- tibble(x = seq(full_range[1], full_range[2], length.out = 400)) |>
    mutate(density = density_fun(x)) |>
    filter(is.finite(density)) |>
    mutate(density = density / max(density) * max(built$y))

  p +
    geom_line(data = density_grid, aes(x = x, y = density), colour = "#0072B2", linewidth = 0.8) +
    scale_y_continuous(name = "Count", breaks = seq(0, max(built$y), length.out = 4), labels = tick_counts)
}

alpha_density <- function(x) dnorm(qlogis(x), mu_alpha, sigma_alpha) / (x * (1 - x))
beta_density  <- function(x) dlnorm(x, mu_beta, sigma_beta)

beta_range  <- c(0, ceiling(max(individual_params$beta) * 1.1))
beta_breaks <- pretty(beta_range, n = 5)

p_alpha <- dot_panel(individual_params$alpha, c(0, 1), seq(0, 1, 0.25), alpha_density, "True alpha")
p_beta  <- dot_panel(individual_params$beta, beta_range, beta_breaks, beta_density, "True beta")

fig <- (p_alpha | p_beta) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "03_param_distributions"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = 10, height = 5, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = 10, height = 5, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "03_param_distributions_plot.rds"))
