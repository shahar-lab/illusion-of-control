# Parameter Recovery: eval_only

## Goal
Validate that the hierarchical Stan model (`eval_only.stan`) can reliably recover
subject-level parameters from simulated data.

## Model
`models/eval_only/` — perseveration-trace-only model (2 free parameters per subject),
an ablation of `classic_qval_and_eval` with the RL/Q-value component removed entirely:
- `alpha_per` : perseveration learning rate (bounded [0,1])
- `beta_per`  : inverse temperature for the perseveration trace (unbounded)

Choice on each trial is driven purely by the perseveration trace `E_cards` (how recently/
often an arm was chosen), updated only by *which* arm was chosen — **not** by whether it
was rewarded. `reward` is present in the simulated data and passed into the Stan model's
`data` block, but it is not used anywhere in the likelihood or the update rule, in either
`eval_only.R`'s `sim.block()` or `eval_only.stan`. This looks deliberate (isolating pure
choice-stickiness from outcome-driven learning) but is worth confirming with whoever wrote
it, since it means `reward` is otherwise-dead data carried through the pipeline.

## Simulation setup
- 3-arm bandit; `Nsubjects` / `Narms` / `Ntrials` set at the top of `code/generate_data.R`
- Reward probabilities: 0.50 for all arms (unbiased) — though unused by the model itself
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
- `artifacts/fit.rds`                     — fitted CmdStanMCMC object (not committed to git —
  can exceed GitHub's 100MB push limit at larger scales; regenerate locally via `main.R`)
- `artifacts/recovered_medians.csv`       — posterior median estimates per agent
- `artifacts/population_posteriors.rds`   — posterior draws of the population-level parameters
- `output/param_distributions.pdf/.png`   — simulated parameter distributions
- `output/Diagnostics.pdf`                — trace/rank/pairs plots, Rhat/ESS histograms
- `output/param_recovery.pdf/.png`        — recovery scatter plots
- `output/population_posteriors.pdf/.png` — population-level posterior vs. true value
- `output/recovery_summary.csv`           — Pearson r per parameter

## Results

### First run: 100 subjects, 3 arms, 200 trials, 2000 warmup + 3000 sampling iterations
Runtime: ~45 minutes end-to-end (MCMC sampling alone: ~42 minutes).

- **25 divergent transitions**, all in chain 2 (0/25/0/0 across chains 1-4). No max-treedepth hits.
- **Convergence did not fully succeed**: all 4 group-level parameters had Rhat > 1.01
  and ESS_bulk < 400 — a clear step down from every `classic_qval_and_eval` run at the
  same iteration budget, which converged cleanly (0/8 Rhat > 1.01 in the most recent runs).
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_per | -0.030    |
  | beta_per  |  0.572    |

`alpha_per` recovery essentially failed (~zero correlation with the true generating value).
Combined with the convergence issues, this points to a real identifiability problem
specific to this reduced parameterization — with only `E_cards` and no independent
Q-value signal, `alpha_per` (how fast the trace moves) and `beta_per` (how strongly it
drives choice) are natural candidates to trade off in the posterior. Checked directly:
posterior correlation between `mu_alpha_per` and `mu_beta_per` draws is weak (r ≈ 0.10),
and a spot-check of subject-level `alpha_per_sbj`/`beta_per_sbj` correlations across 5
subjects was inconsistent in both sign and magnitude (-0.40 to +0.35) — so it isn't a
simple, uniform collinearity between the two parameters. The actual cause of the poor
`alpha_per` identifiability (and the divergences) needs more investigation — e.g. a
higher `adapt_delta`, more trials per subject, or examining the pairs plot in
`Diagnostics.pdf` more closely — before trusting `alpha_per` estimates from this model.

### Second run: beta_per's generating sigma raised 0.5 -> 1.2
Same scale (100 subjects, 3 arms, 200 trials, 2000+3000 iterations), with `beta_per`'s
generating `sigma` in `population_params_list` widened from 0.5 to 1.2. Runtime: ~35
minutes end-to-end (MCMC sampling alone: ~29.5 minutes).

- **0 divergent transitions**, 0 max-treedepth hits — a clean resolution of the 25
  divergences seen at sigma=0.5.
- **Full convergence**: 0 of 4 group-level parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_per | 0.114     |
  | beta_per  | 0.684     |

Both convergence and recovery improved with the wider `beta_per` prior — `alpha_per`
recovery went from essentially zero (-0.03) to weakly positive (0.11), and `beta_per`
recovery improved too (0.57 -> 0.68). This is consistent with the earlier divergences/poor
convergence being driven at least partly by `beta_per`'s narrow true population spread
(sigma=0.5) rather than a purely structural identifiability problem — though `alpha_per`
is still recovering weakly even now, so some real difficulty estimating it likely remains.
