# shaharlab_plotting: Structural Rules & Defaults

This file consolidates all mandatory rules that govern how plots are created and exported.

## Plot Defaults by Type

### Posterior Plots
- **Default fill:** gray80 (uniform, no banding)
- **Default color:** None (unless user requests or multiple posteriors)
- **Panel tags:** None (single posterior = single panel)
- **Theme:** theme_minimal(base_size = 13) + no gridlines
- **Export:** PDF + PNG (see EXPORT_STANDARD.md)

### Scatter Plots
- **Default point color:** #4477AA (Okabe-Ito primary blue)
- **Default line color:** #EE6677 (Okabe-Ito rose)
- **Panel tags:** None
- **Axes:** coord_equal() with shared limits (see instructions)
- **Export:** PDF + PNG (see EXPORT_STANDARD.md)

### Multi-Panel Composites
- **Assembly:** patchwork only (never gridExtra or cowplot)
- **Panel tags:** MANDATORY (plot_annotation(tag_levels = 'A'))
- **Tag style:** MANDATORY bold 14pt (see PANEL_TAGGING_STANDARD.md)
- **Export:** PDF + PNG (see EXPORT_STANDARD.md)

## Canvas & Export Defaults

- **Width:** 10 inches (default, override only if user requests)
- **Height:** 8 inches (default, override only if user requests)
- **DPI (PNG only):** 300 (never modify)
- **Background:** white (never modify)
- **Format:** ALWAYS PDF + PNG (mandatory)

## Mandatory Rules (Never Override)

1. **Dual export is non-negotiable** — always PDF + PNG
2. **Panel tagging is mandatory** — if 2+ panels exist
3. **Colorblind-safe palettes only** — use COLOR_STANDARD.md
4. **output_dir is mandatory** — all files must save there
5. **Theme is mandatory** — theme_minimal(base_size = 13)
6. **No gridlines** — panel.grid = element_blank()

## When to Read Other Files

| Need | Read |
|------|------|
| Posterior plot structure | `references/plot-posterior/instructions.md` |
| Scatter plot structure | `references/plot-scatter/instructions.md` |
| Color palette rules | `references/COLOR_STANDARD.md` |
| Panel tagging rules | `references/PANEL_TAGGING_STANDARD.md` |
| Export width/height/dpi | `references/EXPORT_STANDARD.md` |
| Calling contract | `ASSUMPTIONS.md` |
