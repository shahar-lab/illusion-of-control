# Blueprint: New Analysis Folder

When the user asks to open a completely new analysis folder, you must follow these strict rules:

1. **Location:** Always build it inside the root `analysis/` directory.
2. **Naming Convention:** Prompt the user for a name if they didn't provide one. Use `snake_case` for the folder name (e.g., `analysis/model_y_by_x_and_z/`).
   * **Warning:** Avoid special characters, spaces, and formula notation (`~`, `+`, `|`) in folder names. These break path construction and shell commands.
3. **Trigger:** Create the folder tree (`code/`, `artifacts/`, `output/`), then immediately execute the Boilerplate Injection step defined in your `SKILL.md` orchestrator.