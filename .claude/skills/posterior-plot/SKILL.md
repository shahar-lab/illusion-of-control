---
name: posterior-plot
description: Plot, visualize, or display a posterior distribution, Bayesian estimate, credible interval, or multiple posteriors together using ggdist in R. Triggered whenever the user asks to plot or show a posterior, Bayesian result, or credible interval.
user-invocable: true
allowed-tools: Read Write Bash
argument-hint: [description of posterior or variable name]
---

## Posterior Distribution Plotting Rules

Always use **ggdist** (e.g. `stat_halfeye`, `stat_slab`) combined with **ggplot2**.

---

### Layout & Shape

- Wide and short/narrow in height — use `coord_cartesian` or aspect ratio control to enforce this.
- Height carries no meaningful information.
- One plot per figure (whether single or multiple distributions).

---

### X-axis

**Effect posteriors** (differences, contrasts, slopes, interactions — anything where the question is "is this different from zero?"):
- Include zero on the x-axis so the reader can judge against no-effect.
- Always draw a vertical dashed line at x = 0:
  ```r
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40")
  ```
- **Symmetric x-axis:** the axis must extend equally on both sides of zero. Compute the maximum absolute value of the posterior range and set both limits to ±that value:
  ```r
  max_abs <- max(abs(range(draws)))
  coord_cartesian(xlim = c(-max_abs, max_abs))
  ```
  This keeps zero visually centered and prevents the scale from exaggerating or downplaying the direction of the effect.

**Non-effect posteriors** (condition means, intercepts, raw parameters not centred on zero):
- Do **not** force zero onto the axis.
- Pad ~20 % around the posterior range so the distribution has breathing room:
  ```r
  xlim_posterior <- function(draws, pad = 0.20) {
    r <- range(draws); span <- diff(r)
    c(r[1] - pad * span, r[2] + pad * span)
  }
  coord_cartesian(xlim = xlim_posterior(draws))
  ```

---

### Y-axis

- Remove the y-axis line, ticks, and labels entirely — they carry no information:
  ```r
  theme(
    axis.title.y  = element_blank(),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    axis.line.y   = element_blank()
  )
  ```

### X-axis line

- Always keep the x-axis line as **dark gray**:
  ```r
  theme(axis.line.x = element_line(colour = "grey30"))
  ```

---

### Theme

- Clean minimal theme with **no gridlines at all** (neither major nor minor):
  ```r
  theme_minimal(base_size = 13) +
  theme(panel.grid = element_blank(), ...)
  ```

---

### Titles

- **Never** add a plot title, subtitle, or caption (`ggtitle()`, `labs(title = ...)`, `labs(subtitle = ...)`) unless the user explicitly asks for one.
- Only set `labs(x = ...)` for the x-axis label and `labs(fill = NULL)` / `labs(colour = NULL)` for legend cleanup.

---

### Legend

- When a color/fill legend is present, always place it **inside the right side of the panel**:
  ```r
  theme(
    legend.position   = c(1, 0.95),
    legend.justification = c("right", "top"),
    legend.background = element_blank(),
    legend.key        = element_blank()
  )
  ```

---

### Multi-panel figures

- When the figure has **more than one panel** (e.g. via `patchwork` or `facet_*`), always label panels **A, B, C, …** in the top-left corner of each panel.
- With `patchwork`, use:
  ```r
  plot_annotation(tag_levels = "A")
  ```
- With facets, add a custom label manually using `annotate()` or via the strip tag approach.

---

### Credible Intervals — lines only, no fill change

- The CI intervals shown below the distribution (via `stat_pointinterval` or the interval part of `stat_halfeye`) must **vary only in line thickness/opacity — never change the fill color** of the slab.
- Use `fill` solely for the slab shape. The interval lines inherit color from the slab's color aesthetic but do **not** alter the slab fill.

---

### Median point (always applied)

Always add a visible median point on the distribution using `stat_pointinterval`:
```r
stat_pointinterval(
  aes(y = 0),
  point_interval = median_qi,
  .width         = 0.95,
  point_size     = 3,
  position       = position_nudge(y = -0.005)
)
```
This makes the central tendency immediately legible without relying on the shape alone.

---

### Credible Intervals (always applied)

Always display **two nested CIs** using `.width = c(0.80, 0.90)`.

**CI lines only — never affect the slab fill.** Separate the slab from the interval:

- Use `stat_slab()` (or `stat_halfeye()` with `interval_size = 0` / `show_point = FALSE`) for the **slab shape only** — uniform fill, no CI coloring.
- Use `stat_pointinterval()` separately for the **interval lines and point** — this is where CI widths appear, as line thickness differences, not fill changes.

```r
# Slab — uniform fill, no interval
stat_slab(fill = "gray80")   # or mapped fill colour for multi-distribution

# Interval lines + median point — CI widths as line thickness only
stat_pointinterval(
  .width     = c(0.80, 0.90),
  point_size = 3,
  linewidth  = c(2, 1)       # 80% CI thicker, 90% CI thinner
)
```

The slab fill **must never vary** by CI width. The alpha/opacity trick (`aes(alpha = after_stat(.width))`) must **not** be applied to the slab.

---

### Single Distribution (default)

- Use `stat_slab()` for the shape with **uniform light gray fill** (`fill = "gray80"`) — no alpha mapping on the slab.
- Use `stat_pointinterval(.width = c(0.80, 0.90))` separately for the CI lines and median point.
- Only use color if the user explicitly asks for it. If color is requested, follow the **color skill** for palette choices.
- Always add a **thin light dashed vertical line at the median** (thinner and lighter than the zero reference line):
  ```r
  geom_vline(xintercept = median(draws), linetype = "dashed", colour = "grey65", linewidth = 0.4)
  ```
- Annotate the top of that line with `[median = X.XX, pd = XX.XX%]` using `annotate("text", ...)` positioned just inside the top of the plot area, horizontally nudged a few characters to the right of the line.

---

### Multiple Distributions (triggered when user asks to show more than one posterior)

- Plot **all distributions at the same y = 0** so they share a single horizontal axis — never stack them by group on the y-axis.
- Use `stat_slab()` for the shape with **uniform fill per group** (`alpha ≈ 0.50` for overlap visibility) — no CI banding on the slab.
- Use `stat_pointinterval(.width = c(0.80, 0.90))` separately per group for the CI lines and median point.
- Use **different colors per distribution** — follow the **color skill** for palette selection.
- Always include a **legend** identifying each distribution.
- All other rules still apply: no gridlines, no y-axis, dashed zero line, wide/short shape.

---

### Color Dependency

When the user requests color (single distribution) or whenever multiple distributions are plotted, defer to the **color skill** for palette and color choices.

---

## R Code Examples

### Example 1 — Single Posterior

```r
library(ggplot2)
library(ggdist)

set.seed(42)
draws <- rnorm(4000, mean = 0.3, sd = 0.5)
df    <- data.frame(theta = draws)

med_val <- median(draws)
pd_val  <- max(mean(draws > 0), mean(draws < 0)) * 100

ggplot(df, aes(x = theta, y = 0)) +
  # Slab: uniform fill, no CI banding
  stat_slab(fill = "gray80") +
  # CI lines + median point only — does not touch the slab fill
  stat_pointinterval(
    .width     = c(0.80, 0.90),
    point_size = 3,
    linewidth  = c(2, 1)   # 80% CI thicker, 90% thinner
  ) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  geom_vline(xintercept = med_val, linetype = "dashed", colour = "grey65", linewidth = 0.4) +
  annotate(
    "text", x = med_val, y = Inf,
    label  = sprintf("[median = %.2f, pd = %.2f%%]", med_val, pd_val),
    hjust  = -0.05, vjust = 1.4, size = 3.2, colour = "grey40"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid   = element_blank(),
    axis.title.y = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y  = element_blank(),
    axis.line.x  = element_line(colour = "grey30")
  ) +
  labs(x = "Estimate") +
  coord_cartesian(ylim = c(0, 1.3), clip = "off")
```

---

### Example 2 — Multiple Posteriors

All distributions share **y = 0** so they sit on the same horizontal axis and overlap with transparency.

```r
library(ggplot2)
library(ggdist)
library(dplyr)

set.seed(42)
df <- bind_rows(
  data.frame(theta = rnorm(4000,  0.35, 0.40), group = "Group A"),
  data.frame(theta = rnorm(4000, -0.20, 0.60), group = "Group B")
)

# Use color skill for palette; example uses accessible two-color pair:
pal <- c("Group A" = "#4477AA", "Group B" = "#EE6677")

ggplot(df, aes(x = theta, y = 0, fill = group, colour = group)) +
  # Slab: uniform fill per group, alpha for overlap visibility — no CI banding
  stat_slab(alpha = 0.50) +
  # CI lines + median point only
  stat_pointinterval(
    .width     = c(0.80, 0.90),
    point_size = 3,
    linewidth  = c(2, 1)
  ) +
  scale_fill_manual(values = pal, guide = guide_legend(override.aes = list(alpha = 0.7))) +
  scale_colour_manual(values = pal, guide = "none") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.7) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid           = element_blank(),
    axis.title.y         = element_blank(),
    axis.text.y          = element_blank(),
    axis.ticks.y         = element_blank(),
    axis.line.y          = element_blank(),
    axis.line.x          = element_line(colour = "grey30"),
    legend.position      = c(1, 0.95),
    legend.justification = c("right", "top"),
    legend.background    = element_blank(),
    legend.key           = element_blank()
  ) +
  labs(x = "Estimate", fill = NULL) +
  coord_cartesian(ylim = c(0, 1.3))
```
