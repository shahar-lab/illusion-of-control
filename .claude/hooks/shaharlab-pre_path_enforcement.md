# 🛑 PRE-EXECUTION HOOK: Strict Path Enforcement

**Trigger:** Execute this logic immediately before generating any R script, Python script, or file structure modification.

**Mandate:** You must strictly adhere to the Shahar Lab's portable pathing topology. All paths must be built dynamically from the project root using `here::here()`.

## Global Pathing Rules

**Path Construction (in main.R):**
Always use `here::here()` to find the repository root dynamically (where `project.Rproj` lives). Use this pattern:
```r
library(here)
project_root  <- here::here()
artifacts_dir <- file.path(project_root, "analysis", "<folder_name>", "artifacts")
output_dir    <- file.path(project_root, "analysis", "<folder_name>", "output")
code_dir      <- file.path(project_root, "analysis", "<folder_name>", "code")
```

Replace `<folder_name>` with the actual folder name (e.g., `"anxiety_exam_bayesian"`).

This ensures portability: scripts work identically from any working directory (local, cloud runners, different machines) and data paths always resolve correctly to the repo root.

**Important:** Always use `here::here()`, never `getwd()`. Always include the full nested path from repo root to the analysis folder. This is the contract that ensures cloud runners and validation scripts can locate outputs consistently.

**In Code Scripts (sourced from main.R):**
* **Data Loading:** Use `data_path` variable passed from `main.R`
* **Data Saving (Artifacts):** Save to `artifacts_dir` using `file.path(artifacts_dir, "filename.rds")`
* **Plot Saving (Output):** Save to `output_dir` using `file.path(output_dir, "plot.png")`
* **Script Placement:** Write short, unnumbered scripts for the `code/` folder that inherit all paths from parent `main.R`

**System Calls to External Tools (Python, shell):**
* Use `shQuote()` to escape paths with spaces
* Pass absolute paths to external processes: `system2("python", args = c(script_path, shQuote(data_path), shQuote(output_dir)))`