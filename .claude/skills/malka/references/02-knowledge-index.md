# Coding Knowledge Index

Open this file while building a Job Card. Match entries by **What it covers**. Copy each non-em-dash **Path** to `ROUTED READS` and copy the actual **CHECKS** bullets to the Job Card's `CHECKS`. Paths are relative to `${CLAUDE_PLUGIN_ROOT}/coding-knowledge/`.

Constitution files, the covering folder's `context.md` and `rules.md` when present, and its templates are standing reads. An em dash under **CHECKS** means there is nothing to clarify.

## The entry

Each craft file is one heading and one box. The heading is the filename. The box holds three bullets, always in this order, each name on its own line and its value on the next.

```text
### `filename.md`

> - **Path**
> - **What it covers**
> - **CHECKS**
```

- **Heading**
  
  The filename in backticks. Leftover-only entries (no how-to) use the leftover-only label instead.

- **Path**
  
  Copy this path onto the Job Card's `ROUTED READS`. An em dash marks a checks-only entry.

- **What it covers**
  
  The file's subject, and when needed the job that matches it. Match an entry by this line.

- **CHECKS**
  
  Copy these bullets directly onto the Job Card's `CHECKS`, in order. An em dash means none.

Every file under `coding-knowledge/` that is craft is one entry here, and every craft entry is one file.

## 01 · Preprocessing

Always read `01-preprocessing/template-main.md` and `01-preprocessing/template-summary.md`. Preprocessing is the only job-folder whose `output/` contains `reports-collected/`, `reports-raw/`, and `reports-processed/`.

### `01_convert-collected-to-raw.md`

> - **Path**
>   
>   `01-preprocessing/references/01_convert-collected-to-raw.md`
> 
> - **What it covers**
>   
>   Collected-to-raw conversion: which files to write under `data/raw/`, column class and labels, missing data.
> 
> - **CHECKS**
>   
>   - Do we know what files from collected should be pulled to be converted to raw?
>   - Do we know class and domain per column?
>   - Do we know what counts as missing data ?

### `02_convert-raw-to-processed.md`

> - **Path**
>   
>   `01-preprocessing/references/02_convert-raw-to-processed.md`
> 
> - **What it covers**
>   
>   Raw-to-processed conversion: one `source()` per exclusion criterion, append `exclusion.md`, save survivors to `artifacts/` then `data/processed/`.
> 
> - **CHECKS**
>   
>   - Participant-level exclusion criteria and cutoffs
>   - Trial-level exclusion criteria and cutoffs
>   - Calculated columns and formulae

### `how-to-examine.md`

> - **Path**
>   
>   `01-preprocessing/references/how-to-examine.md`
> 
> - **What it covers**
>   
>   Any `examining_` script: five description blocks, report assembly.
> 
> - **CHECKS**
>   
>   —

### `how-to-summarise-exclusions.md`

> - **Path**
>   
>   `01-preprocessing/references/how-to-summarise-exclusions.md`
> 
> - **What it covers**
>   
>   `preprocessing_excerpt` for data treatment: manuscript paragraph from `output/processed/exclusion.md`.
> 
> - **CHECKS**
>   
>   —

### `how-to-summarise-participants.md`

> - **Path**
>   
>   `01-preprocessing/references/how-to-summarise-participants.md`
> 
> - **What it covers**
>   
>   `preprocessing_excerpt` for the analysed sample: manuscript paragraph of final N and demographics.
> 
> - **CHECKS**
>   
>   - Which demographic variables to report (age, sex, group, …)

### `conversion-and-filter-traps.md`

> - **Path**
>   
>   `01-preprocessing/references/conversion-and-filter-traps.md`
> 
> - **What it covers**
>   
>   Read alongside any `converting_` script: type coercion, `%in%` versus chained `!=`, `scale()`/`cut()`, counts to print.
> 
> - **CHECKS**
>   
>   —

### `how-to-build-data-validation.md`

> - **Path**
>   
>   `01-preprocessing/references/how-to-build-data-validation.md`
> 
> - **What it covers**
>   
>   Data-validation HTML per tidy table, class and domain meta-rows.
> 
> - **CHECKS**
>   
>   - raw, processed, or both

### `handling-leaving-window.md`

> - **Path**
>   
>   `01-preprocessing/references/handling-leaving-window.md`
> 
> - **What it covers**
>   
>   `window_status`, one exit per sequence of `left` trials, `window_exit_max`. Route when the study is online, the column is present, or the user mentions leaving the window.
> 
> - **CHECKS**
>   
>   - `window_exit_max` (one exit is one sequence of `left` trials)

### `example-examining-report.md`

> - **Path**
>   
>   `01-preprocessing/assets/example-examining-report.md`
> 
> - **What it covers**
>   
>   Mockup of an `examining_` report.
> 
> - **CHECKS**
>   
>   —

### `example-data-validation.html`

> - **Path**
>   
>   `01-preprocessing/assets/example-data-validation.html`
> 
> - **What it covers**
>   
>   Mockup of a data-validation HTML.
> 
> - **CHECKS**
>   
>   —

A figure of a cutoff takes the matching `visualization/` plot-type entry.

## 02 · Analysis

Route by path, not by where the job lands. A `simulation/` or `preprocessing/` job that needs a figure or a brms fit takes these same entries.

**Regression**

### `01_sampling_and_priors.md`

> - **Path**
>   
>   `regression/01_sampling_and_priors.md`
> 
> - **What it covers**
>   
>   `brm()` workflow: load by `data_path`, approved priors, sampling, save the `.rds`.
> 
> - **CHECKS**
>   
>   - Formula and RE structure
>   - Family
>   - Priors (offer weakly informative)
>   - Sampling (offer 4 / 2000 / half warmup)

### `02_diagnostics.md`

> - **Path**
>   
>   `regression/02_diagnostics.md`
> 
> - **What it covers**
>   
>   Post-fit diagnostics: ess/rhat table, trankplot, pairs plot, reported without interpretation.
> 
> - **CHECKS**
>   
>   —

**Visualization**

### `plot-posterior.md`

> - **Path**
>   
>   `visualization/plot-types/plot-posterior.md`
> 
> - **What it covers**
>   
>   Posterior / credible interval / effect estimate. ggdist: wide-and-short canvas, three x-axis cases, 0.90 CI.
> 
> - **CHECKS**
>   
>   - Which parameters or effects
>   - Effect vs bounded vs other
>   - Single figure or composite

### `plot-scatter.md`

> - **Path**
>   
>   `visualization/plot-types/plot-scatter.md`
> 
> - **What it covers**
>   
>   Scatter, x vs y, correlation, parameter recovery. ggplot2: square panel, shared limits, diagonal, Pearson, mandatory color.
> 
> - **CHECKS**
>   
>   - x and y columns
>   - Same-scale or different
>   - Colour mapping
>   - Trend-line band or line alone
>   - Single figure or composite

### `plot-dot-histogram.md`

> - **Path**
>   
>   `visualization/plot-types/plot-dot-histogram.md`
> 
> - **What it covers**
>   
>   Dot histogram, distribution of one variable. ggdist `geom_dots()`: full-range x-axis, rebuilt count y-axis.
> 
> - **CHECKS**
>   
>   - Which column
>   - Theoretical range or none
>   - Grouping or none
>   - Single figure or composite

### `plot-posterior.png`

> - **Path**
>   
>   `visualization/plot-types/plot-posterior.png`
> 
> - **What it covers**
>   
>   Rendered reference for the posterior plot.
> 
> - **CHECKS**
>   
>   —

### `PANEL_TAGGING_STANDARD.md`

> - **Path**
>   
>   `visualization/standards/PANEL_TAGGING_STANDARD.md`
> 
> - **What it covers**
>   
>   Two or more panels: patchwork assembly and A/B/C tags.
> 
> - **CHECKS**
>   
>   —

### `EXPORT_STANDARD.md`

> - **Path**
>   
>   `visualization/standards/EXPORT_STANDARD.md`
> 
> - **What it covers**
>   
>   Every figure: dual PDF+PNG export, canvas, naming.
> 
> - **CHECKS**
>   
>   —

### `COLOR_STANDARD.md`

> - **Path**
>   
>   `visualization/standards/COLOR_STANDARD.md`
> 
> - **What it covers**
>   
>   When the plot uses color: which palettes.
> 
> - **CHECKS**
>   
>   —

**Descriptives**

### `how-to-report-descriptives.md`

> - **Path**
>   
>   `descriptives/how-to-report-descriptives.md`
> 
> - **What it covers**
>   
>   Participant counts, demographics, or questionnaire distributions: sample tables and per-measure distributions.
> 
> - **CHECKS**
>   
>   - Which variables
>   - Grouping
>   - Which measures get a distribution figure
>   - Each named measure exists as a scored column in `data/processed/`

**Cloning**

A new job-folder takes structure from `FOLDER`. A repair reads that covering folder's `context.md`.

### `smart_clone.md`

> - **Path**
>   
>   `02-analysis/smart_clone.md`
> 
> - **What it covers**
>   
>   Duplicating an `analysis/` or `simulation/` job-folder: what to copy, what to wipe, which paths to re-point.
> 
> - **CHECKS**
>   
>   - Source job-folder
>   - What changes in the clone

**Model comparison**

### Model comparison / `loo`

> - **Path**
>   
>   —
> 
> - **What it covers**
>   
>   Model comparison / `loo` — leftover-only; no how-to.
> 
> - **CHECKS**
>   
>   - Which fitted objects
>   - Which metric (`loo` or another)
>   - Where the PDF goes

## 03 · Models

### `how-to-write-a-model-definition.md`

> - **Path**
>   
>   `03-models/references/how-to-write-a-model-definition.md`
> 
> - **What it covers**
>   
>   Generating `.R` and fitting `.stan` as one pair.
> 
> - **CHECKS**
>   
>   - Parameters, what each does, and the scale each is on
>   - Task structure
>   - New definition or structural variant
>   - The three generating/fitting agreements if a recovery will use the pair

A definition a recovery study will generate from and fit back also matches `parameter_recovery/context.md` and `04-simulations/references/how-to-build-a-recovery-pipeline.md`.

## Parameter recovery

Always read `parameter_recovery/context.md` and `parameter_recovery/template_summary.md`. A parameter-recovery job-folder lives under `simulation/`. Write `main.R` from the example in `context.md`, not from `04-simulations/template_main.R`.

### `context.md`

> - **Path**
>   
>   `parameter_recovery/context.md`
> 
> - **What it covers**
>   
>   Parameter-recovery job-folder under `simulation/`: four-stage `main.R` (true parameters, generated data, recovered parameters, Word-and-PDF evaluation).
> 
> - **CHECKS**
>   
>   - Which `models/` definition generates and which is fitted
>   - Population location and scale per parameter (set in `main.R`)
>   - `n_subjects`, `n_trials`, `n_sessions`
>   - Sampler (Stan, brms, or other)
>   - Logistic transform onto the unit interval, or none

## 04 · Simulations

Parameter-recovery job-folders take their covering files from `parameter_recovery/` (standing reads above). The files below remain routed craft for recovery studies. Other simulation studies (model simulation, model comparison) still take covering files from this folder.

### `how-to-build-a-recovery-pipeline.md`

> - **Path**
>   
>   `04-simulations/references/how-to-build-a-recovery-pipeline.md`
> 
> - **What it covers**
>   
>   Model-family mapping and generating-versus-fitting agreements. Stage headers for a recovery job follow `parameter_recovery/context.md`, not this file's three-stage outline.
> 
> - **CHECKS**
>   
>   - Environment (trials, blocks, task constants)
>   - Population (n agents, location and scale per parameter)
>   - Which `models/` definition generates and which is fitted
>   - Sampler

### `how-to-read-recovery.md`

> - **Path**
>   
>   `04-simulations/references/how-to-read-recovery.md`
> 
> - **What it covers**
>   
>   Six recovery checks in order.
> 
> - **CHECKS**
>   
>   - Success criterion: correlation
>   - Success criterion: bias
>   - Success criterion: precision
>   - Offer conventional defaults

### `example_main.R`

> - **Path**
>   
>   `04-simulations/assets/example_main.R`
> 
> - **What it covers**
>   
>   Older three-stage recovery `main.R` skeleton. Do not inject; write `main.R` from the example in `parameter_recovery/context.md`.
> 
> - **CHECKS**
>   
>   —

A first recovery study matches `parameter_recovery/context.md`, both `04-simulations` reference entries, and the `visualization/` entries its true-parameter and individual-recovery figures call for. A study that fits brms also matches `regression/01_sampling_and_priors.md`. Do not treat `example_main.R` as the study's `main.R` — that skeleton is the older three-stage outline; write `main.R` from the example in `parameter_recovery/context.md`.

## Common jobs

Standing reads are the same in every job. Copy these extra paths onto the Job Card's `ROUTED READS`; copy the matching `CHECKS` bullets from the catalog above.

| Job                                                  | Extra paths                                                                                                                                                                                 |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| First preprocessing, study online                    | both numbered conversion files, `how-to-examine.md`, `how-to-summarise-exclusions.md`, `how-to-summarise-participants.md`, `how-to-build-data-validation.md`, `conversion-and-filter-traps.md`, `handling-leaving-window.md`, `example-examining-report.md`, `example-data-validation.html` |
| Revising exclusions, study in person                 | `02_convert-raw-to-processed.md`, `conversion-and-filter-traps.md`, `how-to-summarise-exclusions.md`, `how-to-summarise-participants.md`                                                       |
| New brms folder with a posterior plot                | both regression files, `plot-posterior.md`, `plot-posterior.png`, `EXPORT_STANDARD.md`, `COLOR_STANDARD.md` if colour                                                                       |
| Revising a two-panel scatter                         | `plot-scatter.md`, `COLOR_STANDARD.md`, `EXPORT_STANDARD.md`, `PANEL_TAGGING_STANDARD.md`                                                                                                   |
| First parameter-recovery, model already in `models/` | `parameter_recovery/context.md`, both `04-simulations` references, `plot-dot-histogram.md`, `plot-scatter.md`, `COLOR_STANDARD.md`, `EXPORT_STANDARD.md`, `PANEL_TAGGING_STANDARD.md` |
| Writing the `models/` pair a recovery needs          | `how-to-write-a-model-definition.md`, `how-to-build-a-recovery-pipeline.md`                                                                                                                 |
