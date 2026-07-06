# Blueprint: Smart Clone (Duplicating an Analysis)

When tasked with duplicating an existing analysis folder (e.g., to tweak a model or add a covariate), you MUST follow these safety protocols to prevent data bloat:

1. **Copy the Code & Docs:** Copy the `code/` folder, the `main.R`, and the `summary.md` files from the old folder to the new destination.
2. **WIPE THE ARTIFACTS (CRITICAL):** Do NOT copy the contents of the `artifacts/` or `output/` folders. The new analysis must have these folders, but they MUST be completely empty. We absolutely cannot have old `.rds` model fits contaminating the new model's directory.
3. **Re-point the Paths (CRITICAL):** Open the cloned `main.R` and update the `code_dir`, `artifacts_dir`, and `output_dir` variables so the `analysis/<old_folder_name>/` segment is replaced with the NEW folder name. A cloned script otherwise keeps reading from and writing to the SOURCE folder, contaminating it. Per project_rules.md §4, the folder name in the paths must match the actual directory name.
4. **Update Context:** Open the new `main.R` and `summary.md` and explicitly ask the user what the new regression formula or model name should be so you can update the headers.
