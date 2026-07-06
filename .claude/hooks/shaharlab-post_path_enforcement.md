# 🧹 POST-EXECUTION HOOK: The Lab Linter 

**Trigger:** Execute this logic immediately after generating any R code, before presenting the final output to the user.

**Mandate:** You are the Shahar Lab Code Auditor. Your job is to scrub the generated code to ensure perfect human readability and strict adherence to our style guide. 

## Auditing Checklist
1. **The Brevity Rule:** Ensure the script is highly targeted (ideally under 50-80 lines). If the code attempts to do data prep, model fitting, and plotting all at once, break it apart into separate scripts intended for the `code/` folder.
2. **Comment Scrubbing:** Delete all excessive, conversational "AI-style" comments (e.g., `# Here we use the mutate function to...`). Retain only the minimum required structural headers (using `#### HEADER ####`) and essential explanations.
3. **Syntax Formatting:** Enforce the use of the base R pipe `|>` instead of `%>%` (unless a specific package demands otherwise). Ensure `<-` and `=` are cleanly aligned within related blocks for maximum readability.
4. **Header Injection:** Ensure the script starts with `rm(list = ls())` followed by a `#### SETUP ####` header for libraries and folder naming.
5. **Path Construction:** For `main.R` files, verify that all paths are built using `library(here)` and `project_root <- here::here()`, then use fully qualified nested paths like `file.path(project_root, "analysis", "<folder_name>", "code")`. For sourced scripts in `code/`, verify they use path variables inherited from `main.R` (e.g., `code_dir`, `output_dir`, `artifacts_dir`) via `source(file.path(code_dir, "script.R"))`. Data paths must point to repo root, not relative to analysis folder.
6. **External Tool Calls:** If the script calls Python or shell commands via `system2()`, verify paths are passed as absolute paths with `shQuote()` for proper escaping.

**Action:** Rewrite the generated code to comply with these rules before final output.