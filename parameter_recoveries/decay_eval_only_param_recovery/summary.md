# Parameter Recovery: decay_eval_only

## Goal
Validate that the hierarchical Stan model (`decay_eval_only.stan`) can reliably recover
subject-level parameters from simulated data.

## Model
`models/decay_eval_only/` — a decayed variant of `eval_only` (2 free parameters per subject):
- `alpha_per` : perseveration learning rate / decay rate (bounded [0,1])
- `beta_per`  : inverse temperature for the perseveration trace (unbounded)

Like `eval_only`, choice is driven purely by a perseveration trace `E_cards`, and `reward`
is present in the simulated data / Stan `data` block but not used anywhere in the
likelihood or update rule. The difference from `eval_only` is what happens to *unchosen*
arms: in `eval_only` they stay frozen at their last value; here every arm decays toward 0
each trial (`E_cards *= (1 - alpha_per)`), with the chosen arm additionally pulled toward 1
(`E_cards[chosen] += alpha_per`). The chosen-arm update is algebraically identical between
the two models — only the unchosen-arm behavior differs.

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
- `artifacts/fit.rds`                     — fitted CmdStanMCMC object
- `artifacts/recovered_medians.csv`       — posterior median estimates per agent
- `artifacts/population_posteriors.rds`   — posterior draws of the population-level parameters
- `output/param_distributions.pdf/.png`   — simulated parameter distributions
- `output/Diagnostics.pdf`                — trace/rank/pairs plots, Rhat/ESS histograms
- `output/param_recovery.pdf/.png`        — recovery scatter plots
- `output/population_posteriors.pdf/.png` — population-level posterior vs. true value
- `output/recovery_summary.csv`           — Pearson r per parameter

## Results

### First run: 20 subjects, 3 arms, 200 trials, 500 warmup + 500 sampling iterations
Runtime: ~4 minutes end-to-end (MCMC sampling alone: ~2.3 minutes).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Near-full convergence: 2 of 4 group-level parameters had Rhat of exactly 1.01
  (borderline, not clearly problematic), 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_per | 0.806     |
  | beta_per  | 0.963     |

Both parameters recover strongly, even at this much smaller scale (20 subjects, 500/500
iterations) than typically needed elsewhere. Notably, `alpha_per` recovers far better here
than in the non-decayed `eval_only` model, where it was consistently the weakest parameter
across every run (r = -0.03 to 0.32 depending on `beta_per`'s prior width, always at 100
subjects / 2000+3000 iterations). This suggests the frozen-unchosen-arm parameterization in
`eval_only` genuinely limits `alpha_per`'s identifiability, and that having unchosen arms
decay back toward baseline provides much more informative trial-to-trial variation for
pinning down the perseveration learning rate. Worth confirming at a larger scale (matching
the 100-subject / 2000+3000-iteration runs used elsewhere) before drawing a firm conclusion.

### Second run: scaled to 100 subjects, 2000 warmup + 3000 sampling iterations
Matches the scale used for `eval_only_param_recovery`'s full runs, to directly compare
`alpha_per` recovery between the frozen (`eval_only`) and decayed (`decay_eval_only`)
unchosen-arm parameterizations. Runtime: ~28 minutes end-to-end (MCMC sampling alone:
~26.6 minutes) — notably faster than other 100-subject/2000+3000 runs in this repo, likely
because this model has only 2 free parameters and 3 arms (vs. 4 parameters / up to 8 arms
elsewhere).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full convergence: 0 of 4 group-level parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_per | 0.571     |
  | beta_per  | 0.959     |

Confirms the hypothesis from the first run, directionally: `alpha_per` recovery (0.571) is
still clearly better here than in *any* `eval_only` run at the same 100-subject /
2000+3000-iteration scale (r range -0.03 to 0.32 across all of them, regardless of arm
count or `beta_per`'s prior width). `alpha_per`'s recovery did drop from the smaller-scale
run (0.806 -> 0.571 here), so this shouldn't be over-read as guaranteed to hold at every
scale/prior setting, but the qualitative conclusion stands: decaying unchosen arms back
toward baseline gives the perseveration learning rate substantially more identifiability
than freezing them.

## Refactor to the numbered pipeline and beta_per N(0, 2) (2026-11-12/13, branch `recovery/eval_betaper_sd2_t400`)

### Where the earlier runs are
The runs above used the old unnumbered scripts (`generate_data.R`, `fit_stan.R`, ...), which wrote straight into
`artifacts/` and `output/`; those scripts are in git history before commit `ed69c19`. The last run's files (100
subjects, 3 arms, 200 trials) were moved unchanged to `artifacts/legacy_n100/` and `output/legacy_n100/`.

### New pipeline and design
`main.R` holds all run settings and sources `code/01_*.R` ... `code/09_*.R`, the same scripts as the other recoveries
(`qval_and_decay_eval`, `classic_qval_and_perseveration_p50`). Each run writes to `artifacts/<run_name>/` and
`output/<run_name>/`, with seeds 1001 / 2002 / 3003 / 4004.
- Population: alpha_per = plogis(N(0, 1.5)), beta_per = N(0, 2) (was plogis(N(0, 0.75)) and N(0, 1.2)).
  The perseveration push on the previous choice is about beta_per * alpha_per; alpha_per needs a push of about 0.5-2
  to be identifiable (see `qval_and_decay_eval_param_recovery/summary.md`). N(0, 2) keeps abs(beta_per) mostly within 4.
- Environment: 3 arms, 150 trials, p(win) = 0.5 for every arm (as in the pilot task).
- Stan priors aligned with the sibling models: `sigma_*` half-N(0, 2) -> half-N(0, 3).

### n200_betaper_sd2 (200 subjects, 4 x 2000 + 3000)
Runtime 194 min (in parallel with the qval_and_decay_eval fit). 0 divergences, 0 treedepth hits, group Rhat <= 1.003,
group ESS_bulk >= 695. Both population values inside the 90% intervals (alpha_per_pop 0.46, true 0.5; beta_per_pop
0.02, true 0).

| param | r (legacy_n100) | r | slope | bias | 90% coverage |
|---|---|---|---|---|---|
| alpha_per | 0.57 | 0.70 | 0.64 | -0.05 | 0.94 |
| beta_per  | 0.96 | 0.97 | 0.93 | 0.01 | 0.98 |

alpha_per r by push size abs(beta_per * alpha_per):

| push | <= 0.25 | 0.25-0.5 | 0.5-1 | 1-2 | > 2 |
|---|---|---|---|---|---|
| r (n) | 0.07 (61) | 0.27 (36) | 0.81 (43) | 0.91 (44) | 0.70 (16) |

By abs(beta_per): alpha_per r 0.26 below 0.5, 0.76 for 0.5-1, 0.90-0.94 above 1. Same pattern as qval_and_decay_eval:
alpha_per is recoverable for agents whose perseveration actually moves choices, and undefined for those near 0.
Bin numbers come from a scratchpad script (not in repo).
