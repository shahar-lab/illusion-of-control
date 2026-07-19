# Parameter Recovery: <model_name>

## Goal
Validate that the hierarchical Stan model (`<model_name>.stan`) can reliably recover
subject-level parameters from simulated data.

## Model
`models/<model_name>/` — <one or two sentences describing the model's mechanism, e.g.
"Q-learning + perseveration trace"> (<N> free parameters per subject):
- `<param1>` : <what it is, bounds, e.g. "RL learning rate (bounded [0,1])">
- `<param2>` : ...
<!-- one bullet per free parameter -->

<If this model is a variant/ablation of another model in this repo, say so explicitly
and note exactly what's different — this has repeatedly been the most useful comparison
point when interpreting recovery results across models.>

## Simulation setup
- <N>-arm bandit; `Nsubjects` / `Narms` / `Ntrials` set at the top of `code/generate_data.R`
- Reward probabilities: <e.g. "0.50 for all arms (unbiased)">
- True parameters sampled from priors defined in `population_params_list` in `generate_data.R`

## Pipeline (via main.R)
1. `generate_data.R`             — simulate agents, save `cfg.rds` + `df.rds` + `population_params.csv` + `individual_params.csv`
2. `plot_param_distributions.R`  — dotplots of simulated per-agent parameter distributions
3. `fit_stan.R`                  — fit Stan model with cmdstanr; save `fit.rds`,
   `recovered_medians.csv` (subject-level posterior medians), `population_posteriors.rds`
   (population-level posterior draws)
4. `diagnostics.R`               — check divergences, Rhat, ESS; save `Diagnostics.pdf`
   (trace/rank/pairs plots, Rhat/ESS histograms)
5. `plot_recovery.R`             — scatter grid (true vs. recovered medians), save `param_recovery.pdf/png`
6. `plot_population_posteriors.R`— population-level posterior vs. true generating value, save `population_posteriors.pdf/png`
7. `summary_table.R`             — Pearson r table, save `recovery_summary.csv`

## Outputs
- `artifacts/cfg.rds`                     — simulation config (Nsubjects, Narms, Ntrials, expvalues)
- `artifacts/df.rds`                      — simulated trial-level data
- `artifacts/population_params.csv`       — population-level distribution parameters (mu/sigma per parameter)
- `artifacts/individual_params.csv`       — generating parameter values per agent
- `artifacts/fit.rds`                     — fitted CmdStanMCMC object <(gitignored if close to 100MB — regenerate locally via main.R) OR (committed directly, small enough)>
- `artifacts/recovered_medians.csv`       — posterior median estimates per agent
- `artifacts/population_posteriors.rds`   — posterior draws of the population-level parameters
- `output/param_distributions.pdf/.png`   — simulated parameter distributions
- `output/Diagnostics.pdf`                — trace/rank/pairs plots, Rhat/ESS histograms
- `output/param_recovery.pdf/.png`        — recovery scatter plots
- `output/population_posteriors.pdf/.png` — population-level posterior vs. true value
- `output/recovery_summary.csv`           — Pearson r per parameter

## Results

### <Run description, e.g. "First run: 100 subjects, 3 arms, 200 trials, 2000 warmup + 3000 sampling iterations">
<Any settings changed from a previous run / from defaults, and why.>
Runtime: ~<X> minutes end-to-end (MCMC sampling alone: ~<Y> minutes).

- <N> divergent transitions, <N> max-treedepth hits across all 4 chains.
- <Convergence summary>: <N> of <total> group-level parameters had Rhat > 1.01, <N> had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | <param1>  | <r>       |
  | <param2>  | <r>       |

<Interpretation: which parameters recovered well/poorly, and — if there's a comparable
result from another model in this repo — how this compares and what that suggests.>

<!-- Append a new ### subsection here for every subsequent run at different settings.
     Don't overwrite previous Results — the run history is the point of this file. -->
