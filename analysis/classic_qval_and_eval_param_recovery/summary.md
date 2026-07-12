# Parameter Recovery: classic_qval_and_eval

## Goal
Validate that the hierarchical Stan model (`classic_qval_and_eval.stan`) can reliably
recover subject-level parameters from simulated data.

## Model
`models/classic_qval_and_eval/` — Q-learning + perseveration trace (4 free parameters per subject):
- `alpha_rl`  : RL learning rate (bounded [0,1])
- `alpha_per` : perseveration learning rate (bounded [0,1])
- `beta_rl`   : inverse temperature for Q-values (log-normal, > 0)
- `beta_per`  : inverse temperature for perseveration trace (unbounded)

## Simulation setup
- 200 artificial agents, 3-arm bandit, 150 trials each
- Reward probabilities: 0.50 for all arms (unbiased)
- True parameters sampled from broad priors matching the Stan model's parameterization

## Pipeline (via main.R)
1. `generate_data.R`  — simulate agents, save `sim_data.rds` + `true_params.csv`
2. `fit_stan.R`       — fit Stan model with cmdstanr, save `fit.rds`
3. `diagnostics.R`    — check divergences, Rhat, ESS
4. `plot_recovery.R`  — 2x2 scatter grid (true vs. recovered), save `param_recovery.pdf/png`
5. `summary_table.R`  — Pearson r table, save `recovery_summary.csv`

## Outputs
- `artifacts/sim_data.rds`          — simulated trial-level data
- `artifacts/true_params.csv`       — generating parameter values per agent
- `artifacts/fit.rds`               — fitted CmdStanMCMC object
- `artifacts/recovered_means.csv`   — posterior mean estimates per agent
- `output/param_recovery.pdf/.png`  — recovery scatter plots
- `output/recovery_summary.csv`     — Pearson r per parameter

## Results
*(to be filled after running)*
