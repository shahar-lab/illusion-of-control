# Topology Enforcement: Folder Structure and Path Rules

**Reference this during code generation to ensure consistency with Shahar Lab standards.**

---

## One Model, One Folder Principle

Every Bayesian regression analysis lives in its own isolated folder:

```text
analysis/[analysis_name]/
├── code/           ← Unnumbered R scripts
├── artifacts/      ← RDS files, fitted models, posterior draws
├── output/         ← PNG/PDF plots, tables, summaries
├── main.R          ← Master orchestrator script
└── summary.md      ← Lab notebook and analysis documentation
```

**Rule:** Never create nested analysis folders or share scripts between analyses. Each model is self-contained.

---

## Path Construction Rules

### Rule 1: Always use `project_root <- here::here()` in main.R

```r
#### SETUP ####
library(here)
project_root  <- here::here()
code_dir      <- file.path(project_root, "analysis", "<folder_name>", "code")
artifacts_dir <- file.path(project_root, "analysis", "<folder_name>", "artifacts")
output_dir    <- file.path(project_root, "analysis", "<folder_name>", "output")
```

Replace `<folder_name>` with the actual analysis folder name (e.g., `"anxiety_exam_bayesian"`).

### Rule 2: Source scripts with `code_dir` variable

In main.R, ALWAYS use the `code_dir` variable when sourcing scripts:

```r
source(file.path(code_dir, "fit_model.R"))
source(file.path(code_dir, "plot_posterior.R"))
```

Do NOT hardcode `project_root, "code"` directly — use the `code_dir` variable defined at the top.

### Rule 3: Save artifacts with `file.path()`

In any code script, save outputs like this:

```r
saveRDS(model, file.path(artifacts_dir, "model_fit.rds"))
ggsave(file.path(output_dir, "posterior_plot.png"), p, width = 10, height = 6)
```

### Rule 4: Load clean data from the top-level filtered dir

Per the Artifacts Rule, read clean data directly from the top-level
`data/data_filtered/` directory using a rooted path — never a fragile relative
path, and never copy data into the analysis folder.

```r
data_path <- file.path(project_root, "data", "data_filtered", "your_dataset.csv")
df <- read_csv(data_path)
```

Do NOT bundle data inside the analysis folder (e.g.,
`file.path(project_root, "data", "my_data.csv")` under the analysis dir). Data
duplication is forbidden by the Artifacts Rule.

---

## Artifact Isolation Rules

### What goes in `artifacts/`?
- Fitted brms models (`.rds` files from `saveRDS()`)
- Posterior draws and samples (`.rds` from `as_draws_df()`)
- Raw data used for fitting (if not external)
- Any intermediate computational results

### What goes in `output/`?
- Plots (PNG, PDF)
- Tables (CSV, RDS dataframes)
- Summary statistics (text files)
- Diagnostic reports

### What goes in `code/`?
- Unnumbered R scripts (e.g., `fit_model.R`, `plot_posterior.R`)
- Each script 50-80 lines max
- No `rm(list = ls())` in sourced scripts
- No library loading in sourced scripts (loaded in main.R)

---

## main.R Template

Every analysis must follow this structure:

```r
rm(list = ls())

#### SETUP ####
library(tidyverse)
library(brms)
library(posterior)
library(ggdist)
library(bayesplot)

project_root  <- here::here()
code_dir      <- file.path(project_root, "analysis", "<folder_name>", "code")
artifacts_dir <- file.path(project_root, "analysis", "<folder_name>", "artifacts")
output_dir    <- file.path(project_root, "analysis", "<folder_name>", "output")

#### CREATE DATA / LOAD DATA ####
source(file.path(code_dir, "create_data.R"))
# OR
# source(file.path(code_dir, "load_data.R"))

#### FIT MODEL ####
source(file.path(code_dir, "fit_model.R"))

#### POSTERIOR SAMPLING ####
source(file.path(code_dir, "posterior_sample.R"))

#### PLOT RESULTS ####
source(file.path(code_dir, "plot_posterior.R"))
source(file.path(code_dir, "plot_prior_predictive.R"))
```

---

## Script Naming Conventions

Use descriptive, unnumbered names:

✅ **Good:**
- `create_data.R`
- `fit_model.R`
- `posterior_sample.R`
- `plot_posterior_slope.R`
- `plot_prior_predictive.R`
- `diagnostics_trace_plots.R`

❌ **Bad:**
- `01_data.R`, `02_fit.R`, `03_plots.R` (numbered)
- `script.R` (non-descriptive)
- `analysis.R` (too vague)

---

## summary.md Structure

Every analysis must have a `summary.md` documenting:

```markdown
# Analysis Name

## Research Question
[Description of what we're examining]

## Model Specification
- Formula: [exact brms formula]
- Priors: [exact prior specification with distributions and parameters]

## Pipeline Overview
1. [What step 1 does]
2. [What step 2 does]
3. [What step 3 does]

## Outputs
- Artifacts: [list of saved files in artifacts/]
- Figures: [list of saved plots in output/]

## How to Run
Open the project and run the orchestrator — paths resolve via `here::here()`, so no `setwd()` is needed:
\`\`\`r
source("analysis/<folder_name>/main.R")
\`\`\`
```

---

## Enforcement Checklist

Before finalizing code generation, verify:

- [ ] Folder structure matches the template above
- [ ] main.R uses `project_root <- here::here()` and `file.path()`
- [ ] All scripts sourced with `file.path()` paths
- [ ] All artifacts saved to `artifacts_dir`
- [ ] All plots saved to `output_dir`
- [ ] Scripts are unnumbered and focused
- [ ] No `rm(list = ls())` in sourced scripts
- [ ] summary.md documents the analysis with prior spec
- [ ] Scripts follow Shahar Lab style: `|>` pipe, base R, minimal comments

