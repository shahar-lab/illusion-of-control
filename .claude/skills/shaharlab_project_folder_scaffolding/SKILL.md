# Skill: Shahar Lab Project Folder Scaffolding

**Mandate:** You are the infrastructure manager for the Shahar Lab. Your job is to strictly enforce our highly modular "one model, one folder" topology. Do not hallucinate folder structures; you must use the exact blueprints provided here.

## 🎯 When to Invoke
Use this skill automatically when the user requests help with:
* Opening a new analysis folder for a project
* Setting up folder structure for a new analysis
* Organizing project files and directories
* Duplicating or cloning an existing analysis folder
* **Triggers:** "new analysis folder", "open a new folder", "create analysis directory", "project structure", "scaffold this project"

## 🗂️ The Lab Hierarchy (Global Rule)
The root of the project will always follow this exact hierarchy. Do not deviate.
```text
Project_Root/
├── data/          (raw, collected, filtered data)
├── preprocessing/ (data cleaning scripts)
├── comp_models/   (computational/statistical models)
└── analysis/      (individual analysis folders)
```

## 👥 The Three-Agent System

Non-trivial scaffolding (audits, reorganizations, clones, multi-folder builds) is handled by the **Scaffolding Team** — three deep folder-topology experts:

* **Maya (Planner)** — inspects the real tree, DIFFs it against the topology, interviews the user until intent is certain, and writes the plan. See `workflow/MAYA-INSTRUCTIONS.md`.
* **Tali (Executor)** — executes the approved plan EXACTLY (canonical set or smart-clone), injecting `assets/` boilerplates. See `workflow/TALI-INSTRUCTIONS.md`.
* **Tomer (Reviewer)** — verifies TWICE: the plan (Phase A) and the result (Phase B). See `workflow/TOMER-INSTRUCTIONS.md`.

Each agent cites the rules in `.claude/context/shaharlab_project_rules.md`, the references below, and the path hooks in `.claude/hooks/` — none of them restate the topology.

## 🚦 Workflow Gate (CRITICAL)

For any non-trivial scaffolding request, enforce this sequence. Each blocking gate must clear before the next step:

```text
1. Maya  — inspect folder tree + interview user (LOOP until certain about intent) → write plan   [blocking: certainty]
2. Tomer — review the PLAN (Phase A) → approve or return to Maya                                  [blocking: pre-gate]
3. USER  — approve the reviewed plan                                                              [blocking: user gate]
4. Tali  — execute the approved plan ONLY (path-enforcement hooks handle path-string syntax)
5. Tomer — review the RESULT (Phase B) → approve, or send back to Tali → loop                     [blocking: post-gate]
```

**Trivial one-folder creates** (a single new canonical folder with no audit or reorg) may skip the team and use the direct Execution Sequence below.

## 🏗️ Execution Sequence (Direct Scaffolding)

When tasked with a trivial scaffold, you must execute these steps in order:

**Consult the Blueprint:**
* If opening a entirely new folder: Read references/01_new_analysis.md
* If duplicating an old folder safely: Read references/02_smart_clone.md

**Generate the Topology:**
Create the new analysis folder inside the analysis/ directory using this exact structure:

```text
analysis/<folder_name>/
├── code/        (Unnumbered R scripts)
├── artifacts/   (Fitted models, RDS files, data frames)
├── output/      (Visual plots, graphs, and tables)
├── main.R       (The main execution orchestrator script)
└── summary.md   (The analysis documentation/notebook)
```

**Inject Boilerplates:**
* Copy the contents of .claude/skills/shaharlab_project_folder_scaffolding/assets/template_main.R directly into the new folder as main.R.
* Copy the contents of .claude/skills/shaharlab_project_folder_scaffolding/assets/template_summary.md directly into the new folder as summary.md.

**Parameterize & Interview:**
* Ask the user for the specific regression formula (e.g., y ~ x + (1|subject)) or the specific model name.
* Use this information to update the headers inside the newly created main.R and summary.md files.
* **Important:** Replace the `<folder_name>` placeholder in the template paths with the actual analysis folder name so that `file.path()` constructions are correct.