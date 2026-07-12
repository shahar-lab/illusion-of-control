# shaharlab_plotting Skill — Calling Contract

This file defines the explicit assumptions the plotting skill makes about its calling environment. When writing a script that uses this skill, you MUST satisfy all assumptions listed below.

**What is this file?** This file defines the execution environment contract. It describes what the calling code must provide (paths, libraries, data) before plotting code runs. It does NOT describe plotting rules; see the standards (CONFIG.md, EXPORT_STANDARD.md, COLOR_STANDARD.md) for those.

---

## Mandatory Assumptions

### 1. Directory Paths (Non-Negotiable)

The parent script (`main.R`) **must** define these variables before calling any plotting code:

```r
project_root <- here::here()
output_dir   <- file.path(project_root, "analysis", "<folder_name>", "output")
artifacts_dir <- file.path(project_root, "analysis", "<folder_name>", "artifacts")
code_dir     <- file.path(project_root, "analysis", "<folder_name>", "code")
```

**Why:** All `ggsave()` calls in the plotting code assume `output_dir` is already defined. The skill does not create directories, manage paths, or infer folder structure. See `shaharlab_project_rules.md` for the "one analysis, one folder" topology.

**Responsibility:** The **shaharlab_project_folder_scaffolding** skill creates these folders. The parent `main.R` must define these paths. The plotting skill uses them.

---

### 2. Required Libraries (Non-Negotiable)

The parent script **must** load these libraries before sourcing any plotting code:

```r
library(ggplot2)      # Required for all plots
library(ggdist)       # Required for posterior plots
library(patchwork)    # Required for multi-panel assembly
library(tidyverse)    # Required for data manipulation before plotting
```

**Why:** The plotting skill references these packages without loading them. Attempting to use `stat_slab()` or `+` operators without these libraries will fail silently or with cryptic errors.

**Note:** Always load all four libraries in the parent script (`main.R`), even if some are not used in a particular analysis. This ensures consistency and prevents downstream errors when plots are added or modified. Unused libraries do not break anything.

---

### 3. Data or Draws in Scope (Non-Negotiable)

All data, MCMC draws, or simulated values must be available in the **parent environment** before plotting code is called.

**Examples:**

- **Posterior plot:** The vector `draws` (or `df$param_draws`) must exist and be numeric.
- **Scatter plot:** The vectors `x` and `y` (or dataframe columns) must exist, have equal length, and be complete.
- **Multi-panel:** All individual plots (`p1`, `p2`, `p3`, ...) must be assigned before patchwork assembly.

**Why:** Plotting code is never the data-generation step. It assumes data is ready. Mixing data prep and plotting violates the lab's modular principle.

---

### 4. Sourced Plotting Code (Conditional)

If plotting code is written in a separate `code/` file and sourced from `main.R`:

- Do **not** include `rm(list = ls())` in the sourced file.
- Do **not** reload libraries in the sourced file.
- Assume `output_dir`, libraries, and data inherit from the parent environment.
- Use functional headers (e.g., `#### PLOT POSTERIORS ####`, `#### EXPORT FIGURES ####`).

See `shaharlab-coding-rules.md` section "Sourced scripts (code/*.R)" for details.

---

## Before Using This Skill: Required Knowledge

An AI agent using this skill **must**:

- Understand when to invoke `plot-posterior`, `plot-scatter`, and when to apply color rules (see SKILL.md routing).
- Verify the analysis folder follows the "one model, one folder" structure with `code/`, `artifacts/`, `output/`, and `main.R`.
- Verify the parent `main.R` has defined `output_dir`, `artifacts_dir`, and `code_dir` before sourcing any plotting script (these must already exist in scope; do not create them).
- Confirm the parent `main.R` loads `ggplot2`, `ggdist`, `patchwork`, and `tidyverse` before sourcing any plotting script (do not reload them in sourced scripts).
- Refer to `shaharlab_project_rules.md` section 4 if folder path definitions are unclear.

---

## Sanity Checks (Before Running Your Script)

Use this checklist to verify you've satisfied the contract:

- [ ] Is `output_dir` defined in `main.R` before any plotting code runs?
- [ ] Are all required libraries loaded (`ggplot2`, `ggdist`, `patchwork`, `tidyverse`)?
- [ ] Do all data/draws exist in the parent environment before plotting code is sourced?
- [ ] If using a sourced plotting script in `code/`, does it inherit paths and libraries without reloading?
- [ ] Do all `ggsave()` calls use `file.path(output_dir, ...)` to save plots?
- [ ] Are both `.pdf` and `.png` versions being saved (not just one)?

If any box is unchecked, fix it before running.

---

## Example: The Right Way to Call This Skill

```r
#### SETUP ####
library(here)
library(ggplot2)
library(ggdist)
library(patchwork)
library(tidyverse)

project_root <- here::here()
output_dir   <- file.path(project_root, "analysis", "anxiety_exam", "output")
artifacts_dir <- file.path(project_root, "analysis", "anxiety_exam", "artifacts")
code_dir     <- file.path(project_root, "analysis", "anxiety_exam", "code")

#### LOAD DATA ####
draws <- readRDS(file.path(artifacts_dir, "posterior_draws.rds"))

#### PLOT POSTERIORS ####
source(file.path(code_dir, "plot_posteriors.R"))
```

The sourced file `plot_posteriors.R` can now:
- Use `stat_slab()` and `stat_pointinterval()` (ggdist loaded).
- Reference `draws` (in scope from parent).
- Call `ggsave(file.path(output_dir, "..."), ...)` (output_dir defined).

---

## Example: An Incorrect Way (Avoid This)

```r
# ❌ BAD: Plotting script tries to define paths itself
source(file.path(code_dir, "plot_posteriors.R"))
```

Inside `plot_posteriors.R`:
```r
# ❌ This will fail or create files in the wrong place
output_dir <- "output/"  # Wrong: hardcoded, not portable
ggsave("posterior.png", plot = p)  # Wrong: no path, no format control
```

---

## Notes for AI Agents (Claude, etc.)

- **Before writing plotting code**, verify this ASSUMPTIONS.md is satisfied by the calling context.
- **Never invent folder creation** — assume the folder structure exists (created by `shaharlab_project_folder_scaffolding`).
- **Never reload libraries** in sourced scripts.
- **Always use `file.path(output_dir, ...)`** in `ggsave()` calls — do not concatenate strings.
- **Always save both .pdf and .png** unless the user explicitly requests otherwise.
- If the user's `main.R` does not define `output_dir`, tell them to read `shaharlab_project_rules.md` section 4, don't invent a path yourself.

---

## Post-Execution Verification Checklist (After Your Script Runs)

After your plotting script completes, run these checks before declaring the task complete:

- [ ] Do both `.pdf` and `.png` files exist in `output_dir/`?
- [ ] Open the PNG in a viewer—does the plot display correctly with no artifacts or errors?
- [ ] For posterior plots: Are the credible interval lines visible? Is the slab shape clear? Do you see the median point and reference lines?
- [ ] For scatter plots: Does the diagonal reference line (x = y) appear? Is the Pearson r annotation visible in the top-right corner? Are both the trend line and data points displayed?
- [ ] For multi-panel figures: Are all panels labeled with letters (A, B, C, ...)? Is the tagging bold and appropriately sized?
- [ ] Check file sizes—are they reasonable (not empty, not bloated)? Both PDF and PNG should be similar in "informativeness" despite format differences.
- [ ] If the plot looks wrong, systematically check: (1) Did the R script run without errors? (2) Are the data/draws actually in scope? (3) Are all required libraries loaded before the script was sourced? (4) Was `output_dir` defined before the plot command executed?

If any check fails, fix the R script and re-run before reporting success.
