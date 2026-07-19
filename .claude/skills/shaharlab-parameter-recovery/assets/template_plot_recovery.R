#### PLOT PARAMETER RECOVERY ####

individual_params <- read_csv(
  file.path(artifacts_dir, "individual_params.csv"),
  show_col_types = FALSE
)
recovered <- read_csv(
  file.path(artifacts_dir, "recovered_medians.csv"),
  show_col_types = FALSE
)

# Shared visual style
scatter_theme <- theme_minimal(base_size = 13) + theme(panel.grid.minor = element_blank())

# One panel per parameter — repeat this block for each free parameter, swapping the
# column name / axis labels. Shown here for alpha_rl; do the same for alpha_per,
# beta_rl, beta_per (or whatever the model's actual parameters are).

# alpha_rl
df_alpha_rl     <- data.frame(true_val = individual_params$alpha_rl, recovered_val = recovered$alpha_rl) |> na.omit()
lim_alpha_rl    <- range(c(df_alpha_rl$true_val, df_alpha_rl$recovered_val))
breaks_alpha_rl <- round(seq(lim_alpha_rl[1], lim_alpha_rl[2], length.out = 4), 2)
r_alpha_rl      <- cor(df_alpha_rl$true_val, df_alpha_rl$recovered_val, method = "pearson")

p1 <- ggplot(df_alpha_rl, aes(x = true_val, y = recovered_val)) +
  geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", r_alpha_rl),
           hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
  scale_x_continuous(breaks = breaks_alpha_rl) +
  scale_y_continuous(breaks = breaks_alpha_rl) +
  coord_equal(xlim = lim_alpha_rl, ylim = lim_alpha_rl, clip = "off") +
  scatter_theme +
  labs(x = "True alpha_rl", y = "Recovered alpha_rl")

# ... repeat for alpha_per (p2), beta_rl (p3), beta_per (p4) ...

# 4 parameters: 2x2 grid, width=10 height=8. 2 parameters: single row (p1 | p2), height=5.
fig <- (p1 | p2) / (p3 | p4)

ggsave(file.path(output_dir, "param_recovery.pdf"), fig, width = 10, height = 8, bg = "white")
ggsave(file.path(output_dir, "param_recovery.png"), fig, width = 10, height = 8, dpi = 300, bg = "white")

cat("Saved: param_recovery.pdf / .png\n")
