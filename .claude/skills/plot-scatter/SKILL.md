---
name: plot-scatter
description: Create or review scatter plots in R using ggplot2. Use whenever the user asks for a scatter plot, correlation plot, x-y plot, observed-vs-predicted plot, parameter recovery scatter, or any point plot comparing two numeric variables. Always apply the plot-colors skill for color choices.
user-invocable: true
allowed-tools: Read Write Bash
argument-hint: [x variable, y variable, and data frame]
---

## Purpose

Use this skill whenever creating or reviewing a scatter plot in R. Scatter plots must be made with **ggplot2**, and any color choices must follow the **plot-colors** skill so the plot remains colorblind-safe and avoids strong pure hues.

## Required Data Check

The x and y variables must always have the same length. This is extremely important: before plotting, verify that the vector used for the x-axis and the vector used for the y-axis contain the same number of observations after filtering, removing missing values, or joining data. Never silently recycle values, never rely on ggplot2 to fail later, and never plot if the two vectors do not represent matched observations.

## Equal Axis Length

Every scatter plot must have x and y axes of the same visual length. Use a fixed coordinate ratio with `coord_equal()` or `coord_fixed(ratio = 1)` so one unit on the x-axis occupies the same distance as one unit on the y-axis. This requirement applies even when the x and y variables are not on the same measurement scale.

## Same-Scale Limits

If the x and y variables are on the same scale, the x-axis and y-axis must use exactly the same limits. Compute one shared range from both variables and apply it to both axes with `coord_equal(xlim = shared_limits, ylim = shared_limits)` or equivalent code. This is required for observed-vs-predicted plots, parameter recovery plots, repeated-measure comparisons, and any plot where the diagonal line represents equality.

## Tick Marks

Use exactly four tick marks on each axis unless the user specifically asks for another number. When x and y use shared same-scale limits, use the same four tick values on both axes. Prefer `seq(limits[1], limits[2], length.out = 4)` or a similarly explicit break calculation.

## Required Layers

Every scatter plot must include the data points, a linear trend line, and a dashed gray diagonal reference line. Use `geom_smooth(method = "lm", se = FALSE)` for the linear line unless the user explicitly asks for uncertainty bands. Use `geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60")` for the diagonal line.

## Pearson Annotation

Every scatter plot must annotate the Pearson correlation in the top-right corner using the exact text form `[Pearson r = ...]`. Compute Pearson's r with matched complete cases, then place the label inside the plotting area with `annotate("text", x = Inf, y = Inf, hjust = 1.05, vjust = 1.4, ...)`. Round the value consistently, usually to two decimal places.

## Theme

Use a clean ggplot2 theme such as `theme_minimal(base_size = 13)`. Remove unnecessary visual clutter, avoid heavy gridlines, and keep axis labels clear. Do not add titles, subtitles, or captions unless the user explicitly requests them.

## Color Dependency

When points, groups, or lines use color, apply the **plot-colors** skill. Prefer colorblind-safe palettes such as Okabe-Ito, Paul Tol, or viridis depending on whether the color mapping is categorical or continuous.

## R Template

Use this template as the default structure and adapt variable names, labels, and palette choices as needed.

```r
library(ggplot2)

plot_df <- data.frame(
  x = x_values,
  y = y_values
)

plot_df <- plot_df[complete.cases(plot_df$x, plot_df$y), ]
stopifnot(length(plot_df$x) == length(plot_df$y))

shared_limits <- range(c(plot_df$x, plot_df$y), na.rm = TRUE)
axis_breaks <- seq(shared_limits[1], shared_limits[2], length.out = 4)
pearson_r <- cor(plot_df$x, plot_df$y, method = "pearson")

ggplot(plot_df, aes(x = x, y = y)) +
  geom_point(colour = "#4477AA", alpha = 0.75, size = 2) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey60") +
  annotate(
    "text",
    x = Inf,
    y = Inf,
    label = sprintf("[Pearson r = %.2f]", pearson_r),
    hjust = 1.05,
    vjust = 1.4,
    size = 3.5,
    colour = "grey30"
  ) +
  scale_x_continuous(breaks = axis_breaks) +
  scale_y_continuous(breaks = axis_breaks) +
  coord_equal(xlim = shared_limits, ylim = shared_limits, clip = "off") +
  theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank()) +
  labs(x = "X label", y = "Y label")
```
