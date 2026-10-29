# reads: artifacts/individual_params.csv, recovered_summary.csv · writes: output/06_param_recovery.{pdf,png}

#### PLOT PARAMETER RECOVERY ####

individual_params <- read_csv(file.path(artifacts_dir, "individual_params.csv"), show_col_types = FALSE)
recovered_summary <- read_csv(file.path(artifacts_dir, "recovered_summary.csv"), show_col_types = FALSE)

recovery_df <- individual_params |>
  pivot_longer(c(alpha, beta), names_to = "param", values_to = "true_val") |>
  left_join(recovered_summary |> select(subject, param, recovered_val = median), by = c("subject", "param"))

# Same-scale scatter: true vs posterior median, identity and OLS lines
scatter_panel <- function(param_name) {
  df <- recovery_df |> filter(param == param_name)
  df <- df[complete.cases(df$true_val, df$recovered_val), ]

  shared_limits <- range(c(df$true_val, df$recovered_val))
  axis_breaks   <- round(seq(shared_limits[1], shared_limits[2], length.out = 4), 2)
  pearson_r     <- cor(df$true_val, df$recovered_val, method = "pearson")

  ggplot(df, aes(x = true_val, y = recovered_val)) +
    geom_point(colour = "#4477AA", alpha = 0.75, size = 2) +
    geom_smooth(method = "lm", formula = y ~ x, se = FALSE, colour = "#EE6677", linewidth = 0.8) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.6) +
    annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", pearson_r),
             hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
    scale_x_continuous(breaks = axis_breaks) +
    scale_y_continuous(breaks = axis_breaks) +
    coord_equal(xlim = shared_limits, ylim = shared_limits, clip = "off") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(x = paste("True", param_name), y = paste("Recovered", param_name))
}

fig <- (scatter_panel("alpha") | scatter_panel("beta")) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "06_param_recovery"

ggsave(file.path(output_dir, paste0(plot_name, ".pdf")), plot = fig, width = 10, height = 5, bg = "white")
ggsave(file.path(output_dir, paste0(plot_name, ".png")), plot = fig, width = 10, height = 5, dpi = 300, bg = "white")
write_rds(fig, file.path(artifacts_dir, "06_param_recovery_plot.rds"))
