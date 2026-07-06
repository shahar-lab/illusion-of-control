# Shahar Lab Plot Type Selection & Routing Guide

Use this guide to identify which plot type the user requested and where to find the implementation rules.

## Decision Tree

When a user asks for a plot, identify keywords:

| User Says | Plot Type | Read | Notes |
|-----------|-----------|------|-------|
| "posterior" / "credible interval" / "effect estimate" / "Bayesian estimate" | Posterior | `plot-posterior/instructions.md` | Use ggdist + ggplot2 |
| "scatter" / "x-y" / "correlation" / "parameter recovery" / "observed vs predicted" | Scatter | `plot-scatter/instructions.md` | Use ggplot2 with equal axes |
| "multiple panels" / "composite" / "combine plots" | Multi-panel | `EXPORT_STANDARD.md` + `PANEL_TAGGING_STANDARD.md` | Use patchwork + tagging |
| "colors" / "palette" / "colorblind-safe" | Color rules | `COLOR_STANDARD.md` | Applies to any plot type |

## Plot Type Reference Table

| Plot Type | Color | Panel Tagging | Export | Example |
|-----------|-------|---|---|---|
| Posterior (single) | Optional | None | PDF+PNG | See `plot-posterior/example.R` |
| Posterior (multi) | Required | If >1 panel | PDF+PNG | See `plot-posterior/example.R` |
| Scatter | Required* | None | PDF+PNG | See `plot-scatter/example.R` |
| Multi-panel composite | N/A | Required if >1 | PDF+PNG | See `EXPORT_STANDARD.md` |

*Scatter always requires color per COLOR_STANDARD.md unless user explicitly requests monochrome.

## What Each Standard Applies To

| Standard | Applies to | Contains |
|----------|-----------|----------|
| `CONFIG.md` | All plots | Canvas dimensions, fonts, DPI, mandatory rules |
| `EXPORT_STANDARD.md` | All plots | Dual export (PDF+PNG), file naming, defaults |
| `PANEL_TAGGING_STANDARD.md` | Multi-panel figures only | When & how to tag panels A, B, C |
| `COLOR_STANDARD.md` | Plots with color | Palettes, colorblind safety, when required |
| `plot-posterior/instructions.md` | Posterior/credible interval plots | Layout, axes, theme, slab+interval |
| `plot-scatter/instructions.md` | Scatter/x-y plots | Equal axes, shared limits, trend line, Pearson r |

## Future Plot Types (Placeholder)

As the lab expands its plotting toolkit, new plot types will be added. Check the `.claude/skills/shaharlab_plotting/references/` directory for updates.

Current roadmap (future additions):
- Heatmaps / correlation matrices
- Forest plots / coefficient plots
- Time series / trajectory plots
- Model diagnostics / posterior predictive checks
