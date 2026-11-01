# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Lab-wide role and orchestration instructions live in `.claude/CLAUDE.md`; this file covers what is specific to this repo.

## What this is

R + Stan (cmdstanr) computational modeling for the "illusion of control" / uncontrollable-learning task: participants repeatedly choose among 3 arms (cards) and get binary rewards. Work is hierarchical Bayesian RL models, parameter recoveries for them, and fits/plots on pilot data. There is no build, lint or test suite: the "tests" are parameter recoveries.

## Running things

- R scripts are run from the **repo root** (`project.Rproj`); recovery pipelines resolve paths with `here::here()`:
  `Rscript parameter_recoveries/<model>_param_recovery/main.R`
- Long runs (full recoveries take 30 min to 2.5+ h): run in the background, e.g. `nohup Rscript ... > log 2>&1 &`, and wait for completion rather than polling.
- Compile-check an edited `.stan` file before a full run: `<cmdstan_path>/bin/stanc --o=<tmp>.hpp models/<model>/<model>.stan`.
- Exception: scripts in `analysis/param_estimation/` use paths relative to their own folder (`../../data/...`) and `rstan`, so run them with that folder as the working directory.

## Architecture

**One model, one folder.** `models/<model_name>/` holds `<model_name>.stan` (hierarchical fit) and `<model_name>.R` (defines `sim.block(subject, parameters, cfg)`, the trial-by-trial simulator that must implement the same choice/update rule as the Stan model). Compiled binaries land next to the `.stan` file and must be gitignored per model.

**Parameter recoveries** live in `parameter_recoveries/<model>[_<env>]_param_recovery/`:
- `main.R` loads all libraries, sets run settings (`run_name`, `Nsubjects`, iterations, seeds), the environment and the generating population, then sources the model's `.R` and `code/NN_*.R` in order. Sourced scripts inherit everything from `main.R` and never call `library()`.
- Each `code/NN_*.R` starts with a `# reads: ... · writes: ...` header; steps communicate only through files in `artifacts/`.
- Outputs are split per run: `artifacts/<run_name>/` (intermediate: `df.rds`, `fit.rds`, summaries) and `output/<run_name>/` (figures, report). Run names: `sanity_n20`, `n35`, `n200`.
- Sibling folders for the same model (e.g. `classic_qval_randomwalk` vs `classic_qval_p50`) differ only in `main.R`'s environment block and `01_generate_data.R`'s reward schedule; keep everything else identical.
- `summary.md` in each folder records design and results.
- Scaffold new ones with the `shaharlab-parameter-recovery` skill (templates in `.claude/skills/shaharlab-parameter-recovery/assets/`).

**Recovery conventions** (from the skill's `references/RUN_CONVENTIONS.md`):
- Sanity run first (10–50 subjects, 100–500 iterations), then the full run (4 chains, 2000 warmup).
- Convergence targets: 0 divergences, group-level Rhat ≤ 1.01, ESS_bulk ≥ 400.
- Never save per-trial `log_lik` in recovery models (OOM); see `STAN_PITFALLS.md`.
- Priors match sibling models: `mu ~ N(0, 3)`, `sigma ~ half-N(0, 3)`, `raw ~ N(0, 1)`; alpha via `inv_logit`, beta via `exp`.
- `fit.rds` near GitHub's 100 MB limit is gitignored.

**Other folders**
- `data/`: gitignored raw PsychoPy CSVs (`ioc-all_<prolific_id>_SESSION_*.csv`). The current pilot is `data/ioc-all-fixed-pilot/{task,wm}`.
- `analysis/`: empirical analyses of pilot data (model fits, WSLS regressions, plots), one subfolder per question.
- `simulations/`: exploratory model simulations with `figs/`.
- `functions/` + `stan_modeling/`: an older workflow built around `my_starter.R`/`set_workingmodel()`. Legacy; new work uses the `models/` + `parameter_recoveries/` layout.
- `archive/`: retired code, do not extend.
- `.malka/`: `current_job.md` and `handoff.md` hold the state of in-progress work (decisions made with the researcher, next steps). Read `handoff.md` before continuing a multi-session task.

## Naming and style

- Model names describe the mechanism (`classic_qval`, `qval_and_decay_eval`, ...). Use `classic_qval`, never `ab`, for the alpha/beta Q-learning model.
- R style (also enforced for Cursor via `.cursor/rules/r-coding-standards.mdc`):
  - Readable tidyverse code with the base pipe `|>`.
  - `#### SECTION ####` headers, minimal comments.
  - No `set.seed()`, `tryCatch()` or `stop()` unless there's a task-specific reason. The classic_qval recoveries keep seeds because the researcher asked for them.
- Analysis scripts are normally unnumbered. Recovery `code/` scripts are numbered `NN_` by the researcher's choice.
- The researcher works in plan mode: show the plan for each step and wait for approval.
