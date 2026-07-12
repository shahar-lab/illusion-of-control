# Complete working example: Single posterior with annotations
# This example is self-contained and can be run independently with synthetic data.

library(ggplot2)
library(ggdist)

# ---- Setup ----
# In real use, draws would be loaded from artifacts/ and output_dir would be defined in main.R
# For this standalone example, we use synthetic data and a temp directory.

set.seed(42)
draws <- rnorm(4000, mean = 0.3, sd = 0.5)
df    <- data.frame(theta = draws)

output_dir <- tempdir()  # Replace with actual output_dir in real use

# ---- Compute statistics for annotations ----
med_val <- median(draws)
pd_val  <- max(mean(draws > 0), mean(draws < 0)) * 100
max_abs <- max(abs(range(draws)))

# ---- Create plot ----
p <- ggplot(df, aes(x = theta, y = 0)) +
  # Slab: uniform fill, no CI banding
  stat_slab(fill = "gray80") +
  # CI lines + median point only
  stat_pointinterval(
    .width     = c(0.80, 0.90),
    point_size = 3,
    linewidth  = c(2, 1)
  ) +
  # Reference lines
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(xintercept = med_val, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  # Annotations
  annotate(
    "text", x = med_val, y = Inf,
    label  = sprintf("[median = %.2f, pd = %.2f%%]", med_val, pd_val),
    hjust  = -0.05, vjust = 1.4, size = 3.2, colour = "grey40"
  ) +
  # Theme
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  labs(x = "Effect Size") +
  coord_cartesian(xlim = c(-max_abs, max_abs), ylim = c(0, 1.3), clip = "off")

# ---- Export (dual format) ----
plot_name <- "posterior_effect"

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
