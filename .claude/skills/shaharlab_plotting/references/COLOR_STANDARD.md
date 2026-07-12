# Shahar Lab Color Standard for Plotting

Use this file to choose colors for scatter plots, multiple posteriors, and any other plot that requires color.

## Structural Rule: When Color is Required

| Plot Type | Color Required | Default Palette |
|-----------|---|---|
| Single posterior (no user request) | No | gray80 |
| Single posterior (user requests color) | Yes | See "Single Color" below |
| Multiple posteriors | Yes | Okabe-Ito or Paul Tol |
| Scatter plot | Yes | Okabe-Ito (point + line) |
| Multi-panel composite | No (colors inherited from panels) | — |

## Okabe-Ito Palette (Primary Choice for Categorical Data)

The de-facto standard for colorblind accessibility. Use for up to 8 groups:

```r
okabe_ito <- c(
  "#E69F00",  # orange
  "#56B4E9",  # sky blue
  "#009E73",  # bluish green
  "#F0E442",  # yellow
  "#0072B2",  # blue
  "#D55E00",  # vermillion
  "#CC79A7",  # reddish purple
  "#000000"   # black
)

# Apply in ggplot2:
scale_colour_manual(values = okabe_ito)
scale_fill_manual(values = okabe_ito)
```

## Paul Tol Palettes (Alternative for Categorical & Diverging Data)

### Bright (up to 7 categories)
```r
tol_bright <- c("#4477AA", "#EE6677", "#228833", "#CCBB44",
                "#66CCEE", "#AA3377", "#BBBBBB")
```

### Muted (up to 10 categories)
```r
tol_muted <- c("#332288", "#117733", "#44AA99", "#88CCEE",
               "#DDCC77", "#CC6677", "#AA4499", "#882255",
               "#999933", "#44BB99")
```

## Viridis Palette (For Continuous/Sequential Data)

Use for continuous color scales (e.g., heatmaps, gradients):

```r
scale_colour_viridis_c()              # continuous
scale_fill_viridis_c(option = "mako") # continuous, alternative
scale_colour_viridis_d()              # discrete groups
```

## Quick Reference: 2-Color Pairs (Scatter Plots & Comparisons)

For scatter plots, use point + line colors from these pairs:

| Use Case | Point Color | Line Color |
|----------|---|---|
| Default | `#4477AA` (blue) | `#EE6677` (rose) |
| Emphasis | `#0072B2` (dark blue) | `#E69F00` (orange) |
| Neutral | `#56B4E9` (sky) | `#D55E00` (vermillion) |

### Code Template for Scatter
```r
ggplot(plot_df, aes(x = x, y = y)) +
  geom_point(colour = "#4477AA", alpha = 0.75, size = 2) +
  geom_smooth(method = "lm", se = FALSE, colour = "#EE6677", linewidth = 0.8) +
  ...
```

## What to Avoid

| Avoid | Why |
|---|---|
| Pure red/green pairs | Red-green colorblindness (~8% of males) |
| `rainbow()` or `heat.colors()` | Not perceptually uniform |
| Pure hues: `#FF0000`, `#00FF00`, `#0000FF` | Inaccessible |
| High-saturation yellow on white | Poor contrast |

## Rules for Multi-Distribution Posteriors

When plotting multiple posteriors:
- Each distribution gets a unique color from your chosen palette
- Slab alpha = 0.50 (to show overlap)
- Use `scale_fill_manual()` and `scale_colour_manual()`
- Always include a legend

Example:
```r
pal <- c("Group A" = "#4477AA", "Group B" = "#EE6677")

ggplot(df, aes(x = theta, y = 0, fill = group, colour = group)) +
  stat_slab(alpha = 0.50) +
  stat_pointinterval(.width = c(0.80, 0.90), point_size = 3, linewidth = c(2, 1)) +
  scale_fill_manual(values = pal, guide = guide_legend(override.aes = list(alpha = 0.7))) +
  scale_colour_manual(values = pal, guide = "none") +
  ...
```

## Verification Checklist

Before submitting a plot:
- [ ] Is color used only when required?
- [ ] Are all colors from one of the approved palettes?
- [ ] Can the plot be read by colorblind viewers (deuteranopia simulator test)?
- [ ] Is there sufficient contrast between colors and background?
