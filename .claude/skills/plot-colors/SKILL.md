---
name: ggplot-color
description: Rules for color use in ggplot2 plots. Always prefer colorblind-safe palettes; avoid strong pure hues like red and green. Apply whenever writing or reviewing R ggplot code that uses color.
user-invocable: false
---

## Color Rules for ggplot2

Always use **colorblind-safe palettes**. Never use strong pure hues (pure red `#FF0000`, pure green `#00FF00`, pure blue `#0000FF`, etc.) or any palette that relies on red/green contrast to convey meaning.

---

### Preferred Palettes (in priority order)

#### 1. Okabe-Ito — first choice for categorical data (up to 8 groups)

The de-facto standard for colorblind accessibility. Use `scale_colour_manual` / `scale_fill_manual` with these hex values:

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
scale_colour_manual(values = okabe_ito)
scale_fill_manual(values = okabe_ito)
```

Or use the built-in shortcut (requires `ggplot2 >= 3.3`):
```r
scale_colour_discrete(type = okabe_ito)
scale_fill_discrete(type = okabe_ito)
```

#### 2. Paul Tol's palettes — alternative for categorical and diverging data

```r
# Bright (up to 7 categories)
tol_bright <- c("#4477AA", "#EE6677", "#228833", "#CCBB44",
                "#66CCEE", "#AA3377", "#BBBBBB")

# Muted (up to 10 categories)
tol_muted <- c("#332288", "#117733", "#44AA99", "#88CCEE",
               "#DDCC77", "#CC6677", "#AA4499", "#882255",
               "#999933", "#44BB99")
```

#### 3. Viridis — for continuous/sequential data

Always prefer `viridis` or `mako` over rainbow or heat palettes:
```r
scale_colour_viridis_c()          # continuous
scale_fill_viridis_c(option = "mako")
scale_colour_viridis_d()          # discrete
```

#### 4. ColorBrewer — acceptable for small categorical sets

Stick to the **qualitative** palettes: `"Set2"`, `"Dark2"`, `"Paired"`.
Avoid `"Set1"` (contains strong red and green side by side).
```r
scale_colour_brewer(palette = "Dark2")
scale_fill_brewer(palette = "Set2")
```

---

### What to Avoid

| Avoid | Why |
|---|---|
| `scale_colour_manual(values = c("red", "green", ...))` | Red–green confusion is the most common colorblindness |
| `rainbow()` / `heat.colors()` / `terrain.colors()` | Not perceptually uniform; fail for colorblind viewers |
| Pure hues: `#FF0000`, `#00FF00`, `#0000FF` | Perceptually extreme; inaccessible |
| Red/green pairs to encode meaning | Invisible to deuteranopia (~8 % of males) |
| High-saturation yellow-on-white | Poor luminance contrast |

---

### Quick Reference — 2-color pairs

When only two groups are needed, use one of these accessible pairs:

| Context | Color 1 | Color 2 |
|---|---|---|
| Default | `#4477AA` (blue) | `#EE6677` (rose) |
| Emphasis | `#0072B2` (blue) | `#E69F00` (orange) |
| Neutral | `#56B4E9` (sky) | `#D55E00` (vermillion) |

---

### Applying these rules in code

```r
library(ggplot2)

# Example: 3-group bar chart using Okabe-Ito
okabe_ito <- c("#E69F00", "#56B4E9", "#009E73")

ggplot(data, aes(x = x, y = y, fill = group)) +
  geom_col() +
  scale_fill_manual(values = okabe_ito) +
  theme_minimal()

# Example: continuous heatmap — use viridis
ggplot(data, aes(x = x, y = y, fill = value)) +
  geom_tile() +
  scale_fill_viridis_c(option = "viridis") +
  theme_minimal()
```
