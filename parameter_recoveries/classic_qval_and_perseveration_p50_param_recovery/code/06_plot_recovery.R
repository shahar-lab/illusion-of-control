# reads: artifacts/individual_params.csv, recovered_summary.csv · writes: output/06_param_recovery.{pdf,png}, 06_alpha_error_vs_beta.{pdf,png}

#### PLOT PARAMETER RECOVERY ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_summary <- read_csv(file.path(artifacts_dir, "recovered_summary.csv"), show_col_types = FALSE)

recovery_df <- individual_params |>
  pivot_longer(all_of(population_params$param), names_to = "param", values_to = "true_val") |>
  left_join(recovered_summary |> select(subject, param, recovered_val = median), by = c("subject", "param"))

# Same-scale scatter: true vs posterior median, identity and OLS lines
scatter_panel <- function(param_name) {
  df <- recovery_df |> filter(param == param_name)
  df <- df[complete.cases(df$true_val, df$recovered_val), ]

  shared_limits <- range(c(df$true_val, df$recovered_val))
  axis_breaks   <- round(seq(shared_limits[1], shared_limits[2], length.out = 4), 2)
  pearson_r     <- cor(df$true_val, df$recovered_val, method = "pearson")

  ggplot(df, aes(x = true_val, y = recovered_val)) +
    geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
    geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "#EE6677", linewidth = 0.8) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
    annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", pearson_r),
             hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
    scale_x_continuous(breaks = axis_breaks) +
    scale_y_continuous(breaks = axis_breaks) +
    coord_equal(xlim = shared_limits, ylim = shared_limits, clip = "off") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(x = paste("True", param_name), y = paste("Recovered", param_name))
}

n_params <- nrow(population_params)
n_cols   <- if (n_params == 4) 2 else n_params

fig <- wrap_plots(lapply(population_params$param, scatter_panel), ncol = n_cols) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name  <- "06_param_recovery"
fig_width  <- 5 * n_cols
fig_height <- 5 * ceiling(n_params / n_cols)

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = fig_width, height = fig_height, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = fig_width, height = fig_height, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "06_param_recovery_plot.rds"))


#### LEARNING-RATE ERROR BY TRUE INVERSE TEMPERATURE ####

recovery_wide <- recovery_df |>
  select(subject, param, true_val, recovered_val) |>
  pivot_wider(names_from = param, values_from = c(true_val, recovered_val))

# One panel per error_pairs row: error in `target` against true `by` (log axis for exp-linked, |by| if by_abs)
error_panel <- function(target, by, by_abs) {
  by_link <- population_params$link[population_params$param == by]
  df <- tibble(
    x     = recovery_wide[[paste0("true_val_", by)]],
    error = recovery_wide[[paste0("recovered_val_", target)]] - recovery_wide[[paste0("true_val_", target)]]
  )
  if (by_abs) df$x <- abs(df$x)
  x_label <- if (by_abs) paste0("|True ", by, "|") else paste("True", by)

  p <- ggplot(df, aes(x = x, y = error)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
    geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
    geom_smooth(method = "loess", formula = y ~ x, se = FALSE, colour = "#EE6677", linewidth = 0.8) +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(x = x_label, y = paste(target, "error (posterior median - true)"))

  if (by_link == "exp") p <- p + scale_x_log10() + labs(x = paste(x_label, "(log scale)"))
  p
}

fig_error <- wrap_plots(Map(error_panel, error_pairs$target, error_pairs$by, error_pairs$by_abs), nrow = 1)
if (nrow(error_pairs) > 1) {
  fig_error <- fig_error +
    plot_annotation(tag_levels = "A") &
    theme(plot.tag = element_text(face = "bold", size = 14))
}

plot_name <- "06_alpha_error_vs_beta"
fig_width <- 7 * nrow(error_pairs)

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig_error, width = fig_width, height = 5, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig_error, width = fig_width, height = 5, dpi = 300, bg = "white")
write_rds(fig_error, file.path(artifacts_dir, "06_alpha_error_vs_beta_plot.rds"))
