# Shahar Lab Export Standard for All Figures

## Mandatory Dual-Format Export

Every figure must be saved in BOTH PDF and PNG. No exceptions.

### Defaults (Apply unless user requests otherwise)

- **Width:** 10 inches
- **Height:** 8 inches
- **DPI (PNG only):** 300
- **Background:** white
- **Location:** output_dir/

## Code Template

### Single plot export
```r
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
```

### Multi-panel export (with tagging)
```r
p_final <- (p1 | p2) / p3 +
  plot_annotation(tag_levels = 'A') &
  theme(plot.tag = element_text(face = "bold", size = 14))

plot_name <- "composite_results"

ggsave(
  file.path(output_dir, paste0(plot_name, ".pdf")),
  plot = p_final,
  width = 10, height = 8, bg = "white"
)

ggsave(
  file.path(output_dir, paste0(plot_name, ".png")),
  plot = p_final,
  width = 10, height = 8, dpi = 300, bg = "white"
)
```

## File Naming Convention

- Use descriptive names: `posterior_effect.pdf` not `plot_1.pdf`
- Use snake_case: `scatter_observed_vs_predicted.pdf`
- Both PDF and PNG share the same basename (only extension differs)

## Post-Export Checklist

- [ ] Both .pdf and .png files exist in output_dir/?
- [ ] File sizes are reasonable (not empty, not >10MB)?
- [ ] PNG displays correctly at 300 DPI?
- [ ] PDF is vector-based (can zoom without artifacts)?
- [ ] Multi-panel figure shows panel letters (A, B, C)?
- [ ] All text is readable at manuscript size (10-12pt)?

## When Not to Use These Defaults

- **Width/Height:** Modify only if user explicitly requests "wider" or "smaller"
- **DPI:** Never modify (300 is publication standard)
- **Background:** Never modify (white is lab standard)
- **Format:** Never modify (always PDF + PNG)
