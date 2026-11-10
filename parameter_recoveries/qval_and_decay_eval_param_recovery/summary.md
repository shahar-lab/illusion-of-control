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

### Second run: widened priors, Nsubjects 100->200, beta_per sigma 1.2->0.75
Pushed directly by the PI (with Nitzan), referring to this model as "RL+H." Changes:
`Nsubjects` 100->200; generating `sigma` for `alpha_rl`/`alpha_per` 0.75->0.85 (wider true
spread); generating `sigma` for `beta_per` 1.2->0.75 (narrower); and in
`qval_and_decay_eval.stan`, `mu_beta_rl`'s prior widened `normal(0,1.5)`->`normal(0,3)`,
and all four `sigma_*` priors widened `normal(0,2)`->`normal(0,3)`. No structural changes.
`Ntrials`/`Narms`/`iter_warmup`/`iter_sampling` unchanged (200/3/2000/3000). Runtime:
~2h40m end-to-end (MCMC sampling alone: ~2h29m — Ndata doubled to 40,000 trials with
Nsubjects at 200, so this took considerably longer than the first run).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full convergence: 0 of 8 group-level parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.567     |
  | alpha_per | 0.515     |
  | beta_rl   | 0.964     |
  | beta_per  | 0.918     |

Recovery held up well despite the wider priors and (going by the `eval_only` precedent)
the potentially-riskier narrower `beta_per` sigma: all four parameters recovered about as
strongly as in the first run, with 0 divergences and full convergence at double the
subject count. `alpha_per` (0.515) again lands well above `classic_qval_and_eval`'s best
comparable result (0.321), reinforcing that the decaying-perseveration parameterization's
identifiability advantage is not just a small-sample artifact of the first run.

## Refactor to the numbered pipeline and highbeta population (2026-11-02, branch `recovery/rl_per_high_beta`)

### Where the earlier runs are
All runs above were made with the old unnumbered scripts (`generate_data.R`, `fit_stan.R`, ...), which wrote
straight into `artifacts/` and `output/`. Those scripts are in git history (last at commit `fe700b1` on main).
Only the last run's files survived on disk; they were moved, not deleted, to `artifacts/legacy_n200/` and
`output/legacy_n200/` (200 subjects, 3 arms, 200 trials, the PI's widened-prior run).

### New pipeline
`main.R` now holds all run settings and sources `code/01_*.R` ... `code/09_*.R`, the same scripts as
`classic_qval_and_perseveration_p50_param_recovery`. They are driven by the `population_params` table in
`main.R`. Each run writes to `artifacts/<run_name>/` and `output/<run_name>/`, with fixed seeds
(1001 / 2002 / 3003 / 4004, the same as classic_qval, so alpha_rl and beta_rl equal classic_qval's alpha and beta).
New outputs: bias, OLS slope, 90% coverage, SD ratio, pairwise trade-offs (`08_tradeoffs.csv`), and an error figure:
alpha_rl error vs true beta_rl and alpha_per error vs |true beta_per|. Word report and multi-page PDF from 09.

### Design changes
- Population: alpha_rl = plogis(N(0, 1.5)), beta_rl = exp(N(1, 0.5)), alpha_per = plogis(N(0, 1.5)), beta_per = N(0, 1.5).
- Environment: 3 arms, 150 trials, p(win) = 0.5 for every arm (the same as classic_qval p50).

### sanity_n20_highbeta (20 subjects, 4 x 500 + 500)
0 divergences, group Rhat <= 1.010, group ESS_bulk >= 469. r: alpha_rl 0.95, beta_rl 0.80, alpha_per 0.26,
beta_per 0.95. alpha_per is uninformative for agents with |beta_per| < 0.5 (90% intervals about 0.01 to 0.7); for
|beta_per| >= 1 (9 agents) alpha_per r = 0.71. alpha_per_pop 0.29 (true 0.5, not covered), pulled down by those agents.

### n200_highbeta (200 subjects, 4 x 2000 + 3000)
Runtime 736 min (run in parallel with two other n200 fits on 14 cores). 0 divergences, 0 treedepth hits, group Rhat
<= 1.009, group ESS_bulk >= 1018.

| param | r | slope | bias | 90% coverage |
|---|---|---|---|---|
| alpha_rl  | 0.91 | 0.84 | 0.01 | 0.89 |
| beta_rl   | 0.86 | 0.69 | -0.15 | 0.86 |
| alpha_per | 0.59 | 0.42 | 0.00 | 0.90 |
| beta_per  | 0.93 | 0.86 | -0.01 | 0.91 |

Population: all four true values inside the 90% intervals (alpha_per_pop 0.49, true 0.5; beta_per_pop 0.08, true 0).
Trade-offs: alpha_rl / beta_rl error cor -0.51; beta_rl / beta_per -0.22; the rest |cor| <= 0.15.

Recovery by bin (r, 90% coverage):

| abs(beta_per) | n | alpha_per r | alpha_per cov | beta_per r |
|---|---|---|---|---|
| <= 0.5  | 64 | 0.14 | 0.89 | 0.71 |
| 0.5-1   | 42 | 0.65 | 0.93 | 0.88 |
| 1-2     | 53 | 0.76 | 0.83 | 0.89 |
| > 2     | 41 | 0.93 | 0.98 | 0.98 |

alpha_rl by beta_rl: r 0.46 for beta_rl <= 1 (4 agents), 0.89-0.96 above. The highbeta population fixes alpha_rl
(old runs 0.52-0.57). alpha_per is recoverable once abs(beta_per) > 0.5; below that, perseveration does not affect
choices and its learning rate is not defined by the data. Bin numbers come from a scratchpad script (not in repo).

## Wider beta_per: N(0, 1.5) -> N(0, 3) (2026-11-10)

### Why
The perseveration push on the previous choice is about beta_per * alpha_per (E of the last choice minus the mean E
of the other arms is about alpha_per). With N(0, 1.5) its median absolute size was 0.42, already on the scale of the
well-recovered kappa N(0, 0.5) (0.34), but alpha_per recovered only where the push was > 0.5. N(0, 3) doubles the push
(median about 0.84, close to the pilot-like kappa SD of about 1). Everything else as n200_highbeta. Model unchanged.
The same rescaling does not work for `classic_qval_and_eval`: its frozen E saturates near 1 for every tried arm, so
the push there is about 0.02 whatever beta_per is.

### sanity_n20_betaper_sd3 (20 subjects, 4 x 500 + 500)
0 divergences, group Rhat <= 1.009 (ESS_bulk >= 222, expected at 500 draws). r: alpha_rl 0.86, beta_rl 0.89,
alpha_per 0.57 (0.26 in sanity_n20_highbeta), beta_per 0.98.

### n200_betaper_sd3 (200 subjects, 4 x 2000 + 3000)
0 divergences, 0 treedepth hits, group Rhat <= 1.003, group ESS_bulk >= 907. All four population values inside the
90% intervals.

| param | r (highbeta) | r (betaper_sd3) | slope (sd3) | 90% coverage (sd3) |
|---|---|---|---|---|
| alpha_rl  | 0.91 | 0.86 | 0.75 | 0.93 |
| beta_rl   | 0.86 | 0.77 | 0.55 | 0.88 |
| alpha_per | 0.59 | 0.71 | 0.57 | 0.89 |
| beta_per  | 0.93 | 0.97 | 0.94 | 0.90 |

alpha_per r by push size abs(beta_per * alpha_per):

| push | <= 0.25 | 0.25-0.5 | 0.5-1 | 1-2 | > 2 |
|---|---|---|---|---|---|
| highbeta (n) | 0.21 (81) | 0.26 (43) | 0.65 (34) | 0.80 (33) | 0.50 (9) |
| betaper_sd3 (n) | 0.14 (55) | 0.54 (26) | 0.75 (43) | 0.88 (34) | 0.56 (42) |

RL recovery by abs(beta_per) in betaper_sd3:

| abs(beta_per) | <= 1 | 1-2 | 2-4 | > 4 |
|---|---|---|---|---|
| beta_rl r | 0.83 | 0.90 | 0.81 | 0.75 |
| alpha_rl r | 0.93 | 0.91 | 0.90 | 0.67 |

The wider beta_per buys alpha_per (0.59 -> 0.71) and beta_per (0.93 -> 0.97), and costs the RL part (beta_rl
0.86 -> 0.77, alpha_rl 0.91 -> 0.86). The cost comes from the strongest perseverators: with abs(beta_per) > 4, choices
are mostly driven by choice history and alpha_rl falls to 0.67. alpha_per recovers best at a push of 0.5-2. Above 2 r drops
again, because a push that large needs alpha_per near 1, where E is the last choice only and alpha_per has little
range left. Bin numbers come from a scratchpad script (not in repo).
