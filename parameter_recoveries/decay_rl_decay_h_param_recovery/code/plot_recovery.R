#### PLOT PARAMETER RECOVERY ####

individual_params <- read_csv(
  file.path(artifacts_dir, "individual_params.csv"),
  show_col_types = FALSE
)
recovered <- read_csv(
  file.path(artifacts_dir, "recovered_medians.csv"),
  show_col_types = FALSE
)

scatter_theme <- theme_minimal(base_size = 13) + theme(panel.grid.minor = element_blank())

# decay_rl
df_decay_rl     <- data.frame(true_val = individual_params$decay_rl, recovered_val = recovered$decay_rl) |> na.omit()
lim_decay_rl    <- range(c(df_decay_rl$true_val, df_decay_rl$recovered_val))
breaks_decay_rl <- round(seq(lim_decay_rl[1], lim_decay_rl[2], length.out = 4), 2)
r_decay_rl      <- cor(df_decay_rl$true_val, df_decay_rl$recovered_val, method = "pearson")

p1 <- ggplot(df_decay_rl, aes(x = true_val, y = recovered_val)) +
  geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", r_decay_rl),
           hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
  scale_x_continuous(breaks = breaks_decay_rl) +
  scale_y_continuous(breaks = breaks_decay_rl) +
  coord_equal(xlim = lim_decay_rl, ylim = lim_decay_rl, clip = "off") +
  scatter_theme +
  labs(x = "True decay_rl", y = "Recovered decay_rl")

# decay_h
df_decay_h     <- data.frame(true_val = individual_params$decay_h, recovered_val = recovered$decay_h) |> na.omit()
lim_decay_h    <- range(c(df_decay_h$true_val, df_decay_h$recovered_val))
breaks_decay_h <- round(seq(lim_decay_h[1], lim_decay_h[2], length.out = 4), 2)
r_decay_h      <- cor(df_decay_h$true_val, df_decay_h$recovered_val, method = "pearson")

p2 <- ggplot(df_decay_h, aes(x = true_val, y = recovered_val)) +
  geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", r_decay_h),
           hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
  scale_x_continuous(breaks = breaks_decay_h) +
  scale_y_continuous(breaks = breaks_decay_h) +
  coord_equal(xlim = lim_decay_h, ylim = lim_decay_h, clip = "off") +
  scatter_theme +
  labs(x = "True decay_h", y = "Recovered decay_h")

# rho_rl
df_rho_rl     <- data.frame(true_val = individual_params$rho_rl, recovered_val = recovered$rho_rl) |> na.omit()
lim_rho_rl    <- range(c(df_rho_rl$true_val, df_rho_rl$recovered_val))
breaks_rho_rl <- round(seq(lim_rho_rl[1], lim_rho_rl[2], length.out = 4), 2)
r_rho_rl      <- cor(df_rho_rl$true_val, df_rho_rl$recovered_val, method = "pearson")

p3 <- ggplot(df_rho_rl, aes(x = true_val, y = recovered_val)) +
  geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", r_rho_rl),
           hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
  scale_x_continuous(breaks = breaks_rho_rl) +
  scale_y_continuous(breaks = breaks_rho_rl) +
  coord_equal(xlim = lim_rho_rl, ylim = lim_rho_rl, clip = "off") +
  scatter_theme +
  labs(x = "True rho_rl", y = "Recovered rho_rl")

# rho_h
df_rho_h     <- data.frame(true_val = individual_params$rho_h, recovered_val = recovered$rho_h) |> na.omit()
lim_rho_h    <- range(c(df_rho_h$true_val, df_rho_h$recovered_val))
breaks_rho_h <- round(seq(lim_rho_h[1], lim_rho_h[2], length.out = 4), 2)
r_rho_h      <- cor(df_rho_h$true_val, df_rho_h$recovered_val, method = "pearson")

p4 <- ggplot(df_rho_h, aes(x = true_val, y = recovered_val)) +
  geom_point(colour = "#4477AA", alpha = 0.6, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  annotate("text", x = Inf, y = Inf, label = sprintf("[Pearson r = %.2f]", r_rho_h),
           hjust = 1.05, vjust = 1.4, size = 3.5, colour = "grey30") +
  scale_x_continuous(breaks = breaks_rho_h) +
  scale_y_continuous(breaks = breaks_rho_h) +
  coord_equal(xlim = lim_rho_h, ylim = lim_rho_h, clip = "off") +
  scatter_theme +
  labs(x = "True rho_h", y = "Recovered rho_h")

fig <- (p1 | p2) / (p3 | p4)

ggsave(file.path(output_dir, "param_recovery.pdf"), fig, width = 10, height = 8, bg = "white")
ggsave(file.path(output_dir, "param_recovery.png"), fig, width = 10, height = 8, dpi = 300, bg = "white")

cat("Saved: param_recovery.pdf / .png\n")
