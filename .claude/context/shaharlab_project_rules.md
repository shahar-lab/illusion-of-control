# Shahar Lab: Global Project Rules & Architectural Philosophy

This file is the global memory bank for the lab's AI architecture. All AI agents, hooks, and skills must adhere to these non-negotiable rules.

## 1. Core Architectural Paradigm: "One Model, One Folder"
Every analytical task—whether an empirical regression (brms) or a synthetic simulation (parameter recovery)—must be housed in its own isolated subfolder within `analysis/`.

## 2. The Three Golden Rules of Operation

### I. The Artifacts Rule
- **No Data Duplication:** Raw or filtered data must NEVER be copied into local analysis folders.
- **Reading:** `main.R` must read clean data directly from the top-level `data/data_filtered/` directory.
- **Writing:** The `artifacts/` folder within an analysis directory is exclusively reserved for generated or derived files (e.g., .rds model fits, MCMC draws, matrices, simulated datasets).
- **Visualization:** The `output/` folder is exclusively reserved for human-facing outputs (plots, figures, and tables).

### II. The Orchestration Rule
- **No Numbered Scripts:** Do not number files in the `code/` directory (e.g., avoid `01_...`). Numbering breaks when intermediate exploratory steps are added.
- **Source of Truth:** `main.R` is the ultimate conductor. Execution order is dictated entirely by reading the `source()` calls in `main.R` from top to bottom.
- **Polyglot Execution:** If a script is R, use `source()`. If Python, use `system("python code/script.py")` or `reticulate::source_python()`.

### III. The Clear Boundaries Rule
- **Mechanistic Models:** All .Stan and mechanistic architecture files must live exclusively in the `comp_models/` directory.
- **Analytical Hub:** All workflows that evaluate, fit, or test models (empirical or simulated) must live in the `analysis/` directory.

## 3. Standard Analysis Folder Structure
Every analysis folder must contain this exact hierarchy:
- `code/` : Short, highly targeted, unnumbered execution scripts.
- `artifacts/` : Derived model objects (machine-readable).
- `output/` : Human-readable figures and tables.
- `main.R` : The top-to-bottom execution orchestrator.
- `summary.md` : Metadata, hypotheses, and model outcomes.

## 4. Path Definition Mandate
**Every `main.R` must define directory paths explicitly at the top of the file** (after libraries are loaded, before any execution). This ensures portability, auditability, and reproducibility.

Required structure:
```r
library(here)

project_root <- here::here()
artifacts_dir <- file.path(project_root, "analysis", "<folder_name>", "artifacts")
output_dir    <- file.path(project_root, "analysis", "<folder_name>", "output")
code_dir      <- file.path(project_root, "analysis", "<folder_name>", "code")
```

**Rules:**
- `project_root` must use `here::here()` to find the repository root dynamically.
- All three directory variables (`artifacts_dir`, `output_dir`, `code_dir`) must be present and correctly reference the analysis folder.
- All `source()` calls must use these variables: `source(file.path(code_dir, "script.R"))` — never hardcode paths.
- The folder name in the paths must match the actual directory name (e.g., if analysis lives in `analysis/anxiety_exam_gender_interaction/`, the paths must say `"anxiety_exam_gender_interaction"`).

**Why:** This contract ensures cloud runners, validation scripts, and future AI agents can locate and archive outputs consistently, and guarantees analyses run identically across machines.

## 5. Visualization Mandate: `/plot-posterior` Skill
All parameter summary plots (posterior distributions, credible intervals, parameter estimates) **must** use the `/plot-posterior` skill from the **shaharlab_plotting** tool capsule. This ensures:
- Consistent, publication-ready visualization across all analyses
- Centralized styling and aesthetic management
- Reproducible plot generation with audit trails

**No raw ggplot code for posteriors.** The skill handles all posterior visualization. See `.claude/skills/shaharlab_plotting/` for implementation details.

## 6. Operational Mandate
AI agents must prioritize brevity and modularity. If a script exceeds 80 lines, the agent must proactively suggest splitting it into smaller, focused modules orchestrated by `main.R`.