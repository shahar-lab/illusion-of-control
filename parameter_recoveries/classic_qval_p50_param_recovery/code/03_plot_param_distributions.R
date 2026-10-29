# reads: artifacts/individual_params.csv · writes: output/03_param_distributions.{pdf,png}

#### PLOT TRUE PARAMETER DISTRIBUTIONS ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)

# Stacked dots per fixed-width bin, with the generating density scaled to expected counts
dot_panel <- function(values, full_range, axis_breaks, density_fun, x_label, n_bins = 20) {
  binwidth <- diff(full_range) / n_bins
  dots <- tibble(x = values) |>
    mutate(bin = pmin(floor((x - full_range[1]) / binwidth), n_bins - 1),
           x_center = full_range[1] + (bin + 0.5) * binwidth) |>
    group_by(bin) |>
    mutate(count = row_number() - 0.5) |>
    ungroup()
  dot_size <- min(2.6, 90 / max(dots$count + 0.5))

  density_grid <- tibble(x = seq(full_range[1], full_range[2], length.out = 400)) |>
    mutate(density = density_fun(x) * length(values) * binwidth) |>
    filter(is.finite(density))

  ggplot(dots, aes(x = x_center, y = count)) +
    geom_point(shape = 21, size = dot_size, fill = "gray50", colour = "gray30") +
    geom_line(data = density_grid, aes(x = x, y = density), colour = "#0072B2", linewidth = 0.8) +
    scale_x_continuous(breaks = axis_breaks) +
    scale_y_continuous(name = "Count", breaks = function(lims) pretty(c(0, floor(lims[2])), n = 4) |> round() |> unique(),
                       expand = expansion(mult = c(0, 0.05))) +
    expand_limits(y = 0) +
    coord_cartesian(xlim = full_range, clip = "off") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(x = x_label)
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
