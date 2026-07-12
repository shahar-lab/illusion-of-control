#### PLOT PARAMETER RECOVERY ####

fit         <- readRDS(file.path(artifacts_dir, "fit.rds"))
true_params <- read_csv(file.path(artifacts_dir, "true_params.csv"), show_col_types = FALSE)

Nsubjects <- nrow(true_params)

# Extract posterior means for all subject-level parameters
recovered <- tibble(
  subject   = 1:Nsubjects,
  alpha_rl  = fit$summary(paste0("alpha_rl_sbj[",  1:Nsubjects, "]"))$mean,
  alpha_per = fit$summary(paste0("alpha_per_sbj[", 1:Nsubjects, "]"))$mean,
  beta_rl   = fit$summary(paste0("beta_rl_sbj[",   1:Nsubjects, "]"))$mean,
  beta_per  = fit$summary(paste0("beta_per_sbj[",  1:Nsubjects, "]"))$mean
)

# Save for summary_table.R
write_csv(recovered, file.path(artifacts_dir, "recovered_means.csv"))

# One scatter panel per parameter — helper follows the plot-scatter skill spec
make_panel <- function(true_vec, rec_vec, param_label) {
  df <- data.frame(true_val = true_vec, recovered_val = rec_vec)
  df <- df[complete.cases(df), ]

  shared_limits <- range(c(df$true_val, df$recovered_val), na.rm = TRUE)
  axis_breaks   <- seq(shared_limits[1], shared_limits[2], length.out = 4)
  pearson_r     <- cor(df$true_val, df$recovered_val, method = "pearson")

  ggplot(df, aes(x = true_val, y = recovered_val)) +
    geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
    geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
    annotate(
      "text", x = Inf, y = Inf,
      label  = sprintf("[Pearson r = %.2f]", pearson_r),
      hjust  = 1.05, vjust = 1.4, size = 3.5, colour = "grey30"
    ) +
    scale_x_continuous(breaks = round(axis_breaks, 2)) +
    scale_y_continuous(breaks = round(axis_breaks, 2)) +
    coord_equal(xlim = shared_limits, ylim = shared_limits, clip = "off") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank()) +
    labs(x = paste("True", param_label), y = paste("Recovered", param_label))
}

p1 <- make_panel(true_params$alpha_rl,  recovered$alpha_rl,  "alpha_rl")
p2 <- make_panel(true_params$alpha_per, recovered$alpha_per, "alpha_per")
p3 <- make_panel(true_params$beta_rl,   recovered$beta_rl,   "beta_rl")
p4 <- make_panel(true_params$beta_per,  recovered$beta_per,  "beta_per")

fig <- (p1 | p2) / (p3 | p4)

ggsave(file.path(output_dir, "param_recovery.pdf"), fig, width = 10, height = 8, bg = "white")
ggsave(file.path(output_dir, "param_recovery.png"), fig, width = 10, height = 8, dpi = 300, bg = "white")

cat("Saved: param_recovery.pdf / .png\n")
