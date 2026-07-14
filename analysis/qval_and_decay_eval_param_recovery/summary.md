# Parameter Recovery: qval_and_decay_eval

## Goal
Validate that the hierarchical Stan model (`qval_and_decay_eval.stan`) can reliably
recover subject-level parameters from simulated data.

## Model
`models/qval_and_decay_eval/` — combines `classic_qval_and_eval`'s reward-driven Q-value
update with `decay_eval_only`'s decaying perseveration trace (4 free parameters per subject):
- `alpha_rl`  : RL learning rate for the Q-value update (bounded [0,1])
- `alpha_per` : perseveration learning rate / decay rate (bounded [0,1])
- `beta_rl`   : inverse temperature for Q-values (log-normal, > 0)
- `beta_per`  : inverse temperature for the perseveration trace (unbounded)

`Q_cards` updates the classic way — only the chosen arm, driven by reward prediction
error (`PE_rl = reward - Q_cards[chosen]`). `E_cards` updates the decayed way — every arm
decays toward 0 each trial (`E_cards *= (1 - alpha_per)`), with the chosen arm additionally
pulled toward 1. Unlike `eval_only`/`decay_eval_only`, `reward` is actually used here (via
the Q-value term), not just carried through unused.

## Simulation setup
- 3-arm bandit; `Nsubjects` / `Narms` / `Ntrials` set at the top of `code/generate_data.R`
- Reward probabilities: 0.50 for all arms (unbiased)
- True parameters sampled from priors defined in `population_params_list` in `generate_data.R`

## Pipeline (via main.R)
1. `generate_data.R`             — simulate agents, save `cfg.rds` + `df.rds` + `population_params.csv` + `individual_params.csv`
2. `plot_param_distributions.R`  — dotplots of simulated per-agent parameter distributions
3. `fit_stan.R`                  — fit Stan model with cmdstanr; save `fit.rds`,
   `recovered_medians.csv` (subject-level posterior medians), `population_posteriors.rds`
   (population-level posterior draws)
4. `diagnostics.R`               — check divergences, Rhat, ESS; save `Diagnostics.pdf`
   (trace/rank/pairs plots, Rhat/ESS histograms)
5. `plot_recovery.R`             — 2x2 scatter grid (true vs. recovered medians), save `param_recovery.pdf/png`
6. `plot_population_posteriors.R`— population-level posterior vs. true generating value, save `population_posteriors.pdf/png`
7. `summary_table.R`             — Pearson r table, save `recovery_summary.csv`

## Outputs
- `artifacts/cfg.rds`                     — simulation config (Nsubjects, Narms, Ntrials, expvalues)
- `artifacts/df.rds`                      — simulated trial-level data
- `artifacts/population_params.csv`       — population-level distribution parameters (mu/sigma per parameter)
- `artifacts/individual_params.csv`       — generating parameter values per agent
- `artifacts/fit.rds`                     — fitted CmdStanMCMC object (not committed to git —
  close to GitHub's 100MB push limit at full-scale iteration counts; regenerate locally via `main.R`)
- `artifacts/recovered_medians.csv`       — posterior median estimates per agent
- `artifacts/population_posteriors.rds`   — posterior draws of the population-level parameters
- `output/param_distributions.pdf/.png`   — simulated parameter distributions
- `output/Diagnostics.pdf`                — trace/rank/pairs plots, Rhat/ESS histograms
- `output/param_recovery.pdf/.png`        — recovery scatter plots
- `output/population_posteriors.pdf/.png` — population-level posterior vs. true value
- `output/recovery_summary.csv`           — Pearson r per parameter

## Results

### First run: 100 subjects, 3 arms, 200 trials, 2000 warmup + 3000 sampling iterations
Bumped `Nsubjects` from the checked-in default of 20 to 100 to match the full-scale
convention used elsewhere in this repo (`iter_warmup`/`iter_sampling` were already at
2000/3000). Runtime: ~40 minutes end-to-end (MCMC sampling alone: ~35.9 minutes).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full convergence: 0 of 8 group-level parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.518     |
  | alpha_per | 0.537     |
  | beta_rl   | 0.910     |
  | beta_per  | 0.952     |

`alpha_per` recovers notably better here (0.537) than in `classic_qval_and_eval`'s best
comparable run (0.321, at 8 arms / `beta_per` sigma=1.2). This is consistent with the
`eval_only` vs. `decay_eval_only` comparison, where switching from a frozen to a decaying
unchosen-arm update produced the same kind of improvement — and it now holds up in the
full Q-value + perseveration model too, not just the perseveration-only ablation. Across
this whole line of models, the decaying perseveration-trace parameterization consistently
gives `alpha_per` (and, by extension, the model as a whole) better identifiability than
letting unchosen arms sit frozen.
