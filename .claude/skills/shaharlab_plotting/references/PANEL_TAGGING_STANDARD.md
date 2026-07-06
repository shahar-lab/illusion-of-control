# Panel Tagging Standard for Multi-Panel Figures

## When to Apply Panel Tags

**Rule:** If and ONLY if a figure has 2 or more panels.

### Examples
- 2 scatter plots side-by-side → ADD TAGS (A, B)
- 3-panel composite (top row + bottom row) → ADD TAGS (A, B, C)
- Single posterior plot → NO TAGS
- Single scatter plot → NO TAGS

## How to Apply Panel Tags

Use patchwork's `plot_annotation(tag_levels = 'A')`:

```r
p_final <- (p1 | p2) / p3 +
  plot_annotation(tag_levels = 'A') &
  theme(plot.tag = element_text(face = "bold", size = 14))
```

### Mandatory Style

- **Tag letters:** A, B, C, ... (uppercase, sequential)
- **Font weight:** bold
- **Font size:** 14pt
- **Position:** automatically top-left of each panel (patchwork default)

## Verification

After creating a multi-panel figure:
- [ ] Panel letters (A, B, C) are visible?
- [ ] Letters are bold?
- [ ] Letters are clearly sized (not tiny)?
- [ ] Letter position is top-left of each panel?

## When to NOT Use Auto-Tagging

If you are using `facet_wrap()` or `facet_grid()`, you may:
- Use patchwork's `tag_levels = 'A'` if you combine faceted plots with other plots
- Or manually annotate facet strips with custom labels

For simple faceted plots with no patchwork assembly, tagging is optional but recommended.

## Common Error: Forgetting to Apply Tags

**Wrong:**
```r
p_final <- p1 | p2  # Two panels but no tags!
ggsave(...)
```

**Right:**
```r
p_final <- p1 | p2 +
  plot_annotation(tag_levels = 'A') &
  theme(plot.tag = element_text(face = "bold", size = 14))
ggsave(...)
```

## Example: Tags on Complex Layout

```r
# 4-panel figure: 2x2 grid
layout <- (p1 | p2) / (p3 | p4) +
  plot_annotation(tag_levels = 'A') &
  theme(plot.tag = element_text(face = "bold", size = 14))

# Output: Panel A (top-left), Panel B (top-right), Panel C (bottom-left), Panel D (bottom-right)
```
