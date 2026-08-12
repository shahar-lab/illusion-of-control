# Pipeline Contracts

Every parameter-recovery analysis in this lab follows the same shape. This document
specifies what each file must do; `assets/template_*` gives you starting-point code to
copy and adapt. Consistency here matters more than any individual choice — it's what lets
scripts be read and modified quickly across models built by different people/sessions.

## Folder layout

```text
models/<model_name>/
├── <model_name>.stan      # the Stan model
└── <model_name>.R         # defines sim.block(subject, parameters, cfg)

analysis/<model_name>_param_recovery/
├── code/
│   ├── generate_data.R
│   ├── plot_param_distributions.R
│   ├── fit_stan.R
│   ├── diagnostics.R
│   ├── plot_recovery.R
│   ├── plot_population_posteriors.R
│   └── summary_table.R
├── artifacts/              # .gitkeep, then generated .rds/.csv (machine-readable)
├── output/                 # .gitkeep, then generated .pdf/.png/.csv (human-readable)
├── main.R
└── summary.md
```

This mirrors `.claude/context/shaharlab_project_rules.md`'s "one model, one folder"
topology exactly — read that file too if you haven't.

## `main.R`

```r
rm(list = ls())

#### SETUP ####

library(here)
library(dplyr)
library(readr)
library(tibble)
library(tidyr)
library(cmdstanr)
library(posterior)
library(ggplot2)
library(patchwork)
library(bayesplot)
library(ggdist)

project_root  <- here::here()
code_dir      <- file.path(project_root, "analysis", "<model_name>_param_recovery", "code")
artifacts_dir <- file.path(project_root, "analysis", "<model_name>_param_recovery", "artifacts")
output_dir    <- file.path(project_root, "analysis", "<model_name>_param_recovery", "output")

source(file.path(project_root, "models", "<model_name>", "<model_name>.R"))


#### EXECUTE PIPELINE ####

source(file.path(code_dir, "generate_data.R"))
source(file.path(code_dir, "plot_param_distributions.R"))
source(file.path(code_dir, "fit_stan.R"))
source(file.path(code_dir, "diagnostics.R"))
source(file.path(code_dir, "plot_recovery.R"))
source(file.path(code_dir, "plot_population_posteriors.R"))
source(file.path(code_dir, "summary_table.R"))
```

All libraries load here — sourced scripts never call `library()` (per this repo's
`.claude/CLAUDE.md`). `plot_param_distributions.R` runs *before* `fit_stan.R` deliberately:
it only needs the simulated data, and running it first means you can sanity-check the
simulated parameter distributions before committing to a possibly-long Stan fit.

## `generate_data.R`

Responsibilities, in order:
1. Set `Nsubjects`, `Narms`, `Ntrials` at the top (see `RUN_CONVENTIONS.md` for what
   values to use).
2. Build `expvalues`, an `Narms x Ntrials` reward-probability matrix (a plain
   `matrix(rep(0.5, Narms * Ntrials), nrow = Narms)` gives an unbiased bandit — vary this
   only if the research question needs a biased schedule).
3. Bundle simulation config into `cfg <- list(Nsubjects=, Narms=, Ntrials=, expvalues=)`
   and save it (`cfg.rds`) — `fit_stan.R` and the plotting scripts read `Narms`/`Nsubjects`
   back out of the data itself, but `cfg.rds` is still useful for reference and consumed
   directly by `plot_param_distributions.R`.
4. Define `population_params_list`, a named list of `list(mu=, sigma=, link=)` — one
   entry per free parameter, e.g.:
   ```r
   population_params_list <- list(
     alpha_rl  = list(mu = 0,     sigma = 0.75, link = "inv_logit"),
     alpha_per = list(mu = 0,     sigma = 0.75, link = "inv_logit"),
     beta_rl   = list(mu = -0.25, sigma = 0.75, link = "exp"),
     beta_per  = list(mu = 0,     sigma = 1.2,  link = "identity")
   )
   population_params <- bind_rows(population_params_list, .id = "param")
   ```
   Link functions used so far: `inv_logit` (via `plogis()`) for [0,1]-bounded rates,
   `exp` for >0 inverse temperatures (log-normal), `identity` for unbounded parameters.
5. Sample `individual_params`, one row per subject, applying the link function to each
   `rnorm(Nsubjects, mu, sigma)` draw.
6. Loop `sim.block(subject = i, parameters = <named vector for subject i>, cfg = cfg)`
   over `1:Nsubjects`, `bind_rows()` the results into `df`.
7. Write `cfg.rds`, `df.rds`, `population_params.csv`, `individual_params.csv` to
   `artifacts_dir`.

`sim.block()` (in `models/<model_name>/<model_name>.R`) takes `(subject, parameters, cfg)`
and returns one tibble of trial-level rows for that subject — see
`assets/template_sim_block.R`. **Use `tibble()`, not `data.frame()`**, for the per-trial
row construction if any column is a per-trial vector (Q-values, E-values, choice
probabilities) — see `STAN_PITFALLS.md` pitfall #3.

## `fit_stan.R`

Responsibilities, in order:
1. Read `df.rds`.
2. Build `stan_data`. **`Narms` must come from the data** (`max(df$ch_card)`), never
   hardcoded — this is what lets the exact same `fit_stan.R` work unchanged if someone
   later reruns `generate_data.R` with a different `Narms`.
3. `cmdstan_model()` + `model$sample(chains = 4, parallel_chains = 4, iter_warmup = ,
   iter_sampling = , refresh = 200)`.
4. `fit$save_object(file.path(artifacts_dir, "fit.rds"))`.
5. **Immediately after saving `fit.rds`**, compute and save two more things so that no
   downstream script ever needs to reload the (often 50-150MB+) fit object:
   - `recovered_medians.csv` — subject-level posterior **medians** (not means — this lab
     switched from mean to median partway through and every model since has used median):
     ```r
     recovered_medians <- tibble(
       subject   = 1:Nsubjects,
       alpha_rl  = fit$summary(paste0("alpha_rl_sbj[",  1:Nsubjects, "]"))$median,
       ...  # one column per free parameter
     )
     write_csv(recovered_medians, file.path(artifacts_dir, "recovered_medians.csv"))
     ```
   - `population_posteriors.rds` — posterior draws of the population-level (`_pop`)
     generated quantities:
     ```r
     population_posteriors <- fit$draws(
       variables = c("alpha_rl_pop", "alpha_per_pop", ...),  # one per free parameter
       format    = "df"
     )
     write_rds(population_posteriors, file.path(artifacts_dir, "population_posteriors.rds"))
     ```

## `diagnostics.R`

1. `fit$diagnostic_summary()` → print divergent transitions and max-treedepth hits per
   chain and in total.
2. `fit$summary(variables = group_vars, "rhat", "ess_bulk", "ess_tail")` on the
   group-level parameters (`mu_*`, `sigma_*`) → print the table, then count and print how
   many have `rhat > 1.01` and how many have `ess_bulk < 400`. These two counts are what
   you check against `RUN_CONVENTIONS.md`'s targets after every run.
3. Save `Diagnostics.pdf` with: `bayesplot::mcmc_trace()`, `mcmc_rank_overlay()`,
   `mcmc_pairs(np = nuts_params(fit))` on the group-level draws, plus ESS/Rhat histograms
   computed across group-level *and* subject-level parameters (not transformed
   quantities/log_lik — those aren't saved per pitfall #1 anyway, so this is usually moot,
   but if a model ever does save one, exclude it explicitly: it'll have `NA` Rhat/ESS and
   otherwise pollute the histogram).

## `plot_recovery.R`

Read `individual_params.csv` (true values) and `recovered_medians.csv` (recovered
values). For each free parameter, build a scatter panel: `geom_point()` +
`geom_smooth(method="lm", se=FALSE)` + `geom_abline(slope=1, intercept=0, linetype="dashed")`
+ a `[Pearson r = %.2f]` text annotation, shared/equal axis limits via `coord_equal()`.
Combine panels with `patchwork` (`(p1 | p2) / (p3 | p4)` for a 2x2 grid of 4 parameters,
`(p1 | p2)` for 2 parameters). Save both `param_recovery.pdf` and `.png`
(`width=10, height=8` for 4 panels, `height=5` for 2).

## `plot_param_distributions.R`

Read `individual_params.csv`. One `geom_dotplot()` panel per parameter showing the raw
simulated distribution (this is a sanity check on the simulation itself, run *before*
fitting). Combine with `patchwork`, tag panels `plot_annotation(tag_levels = "A")`.

## `plot_population_posteriors.R`

Read `population_posteriors.rds` and `population_params.csv`. For each parameter, plot
the population-level posterior (`ggdist::stat_slab()` + `stat_pointinterval()`) against
the true generating value (`geom_vline()`, transformed through the same link function
used in `generate_data.R` — e.g. `plogis(population_params$mu[...])` for an `inv_logit`
parameter). See the note in `SKILL.md` about this deviating from the `/plot-posterior`
skill mandate — check whether that skill can express this "posterior + true-value
reference line, multi-panel" layout before defaulting to the raw-ggdist pattern in
`assets/template_plot_population_posteriors.R`.

## `summary_table.R`

Read `individual_params.csv` and `recovered_medians.csv`. Compute `cor(true, recovered)`
per parameter, save as `recovery_summary.csv`. This is the single most-referenced output
when comparing models or reporting results — keep it exactly this simple (parameter,
pearson_r), don't expand it without a specific reason.

## `summary.md` contract

**Every analysis folder needs one. This was missed on nearly every new model added in
this lab and had to be retrofitted after the fact — don't repeat that.** Use this
structure (see `assets/template_summary.md`):

```markdown
# Parameter Recovery: <model_name>

## Goal
## Model
   <what the model is, its free parameters, what makes it different from siblings>
## Simulation setup
## Pipeline (via main.R)
## Outputs
## Results
### <run description, e.g. "First run: 100 subjects, ...">
   - runtime
   - divergences / Rhat / ESS counts
   - Pearson r table
   - any interpretation, especially cross-model comparisons if relevant
```

Append a new `### ...` subsection under Results for every subsequent run at different
settings — don't overwrite previous results, and don't skip writing one just because "the
numbers will change next time anyway." The history of what was tried and what happened is
the actual point of this file.

## Scaffolding a new model

To add a brand-new model:
1. Write `models/<model_name>/<model_name>.stan` and `<model_name>.R` — read
   `STAN_PITFALLS.md` first.
2. Copy every file from `assets/template_*` into
   `analysis/<model_name>_param_recovery/{code,main.R}`, replacing every
   `<model_name>` placeholder and adjusting the parameter list to match the model's
   actual free parameters (the templates are written for a 4-parameter model like
   `classic_qval_and_eval`; a 2-parameter model like `eval_only` drops `alpha_rl`/`beta_rl`
   throughout — see the real per-model code in this repo for both variants if in doubt).
3. Create `artifacts/.gitkeep` and `output/.gitkeep` (empty directories don't survive
   in git otherwise).
4. Add the `.gitignore` entries from `RUN_CONVENTIONS.md`.
5. Write `summary.md` from the template, filling in Goal/Model/Simulation setup before
   the first run (Results gets filled in after).
