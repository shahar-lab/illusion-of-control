# Complete working example: Parameter recovery scatter plot
# This example is self-contained and can be run independently with synthetic data.

library(ggplot2)

# ---- Setup ----
# In real use, data would be loaded from artifacts/ and output_dir would be defined in main.R
# For this standalone example, we use synthetic data and a temp directory.

set.seed(42)
true_params  <- rnorm(50, mean = 0, sd = 1)
recovered_params <- true_params + rnorm(50, mean = 0, sd = 0.15)

plot_df <- data.frame(
  true_val      = true_params,
  recovered_val = recovered_params
)

output_dir <- tempdir()  # Replace with actual output_dir in real use

# ---- Verify matched pairs ----
plot_df <- plot_df[complete.cases(plot_df), ]
stopifnot(length(plot_df$true_val) == length(plot_df$recovered_val))

# ---- Compute statistics ----
shared_limits <- range(c(plot_df$true_val, plot_df$recovered_val), na.rm = TRUE)
axis_breaks <- seq(shared_limits[1], shared_limits[2], length.out = 4)
pearson_r <- cor(plot_df$true_val, plot_df$recovered_val, method = "pearson")

# ---- Create plot ----
p <- ggplot(plot_df, aes(x = true_val, y = recovered_val)) +
  geom_point(colour = "#4477AA", alpha = 0.75, size = 2.5) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60", linewidth = 0.6) +
  annotate(
    "text",
    x = Inf, y = Inf,
    label = sprintf("[Pearson r = %.2f]", pearson_r),
    hjust = 1.05, vjust = 1.4,
    size = 3.5, colour = "grey30"
  ) +
  scale_x_continuous(breaks = axis_breaks) +
  scale_y_continuous(breaks = axis_breaks) +
  coord_equal(xlim = shared_limits, ylim = shared_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "True Parameter Value", y = "Recovered Parameter Value")

# ---- Export (dual format) ----
plot_name <- "parameter_recovery_scatter"

ggsave(
  file.path(output_dir, paste0(plot_name, ".pdf")),
  plot = p,
  width = 10, height = 8, bg = "white"
)

ggsave(
  file.path(output_dir, paste0(plot_name, ".png")),
  plot = p,
  width = 10, height = 8, dpi = 300, bg = "white"
)

message(sprintf("✓ Exported %s.pdf and %s.png to %s", plot_name, plot_name, output_dir))
