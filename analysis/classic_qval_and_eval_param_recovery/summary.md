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
- 3-arm bandit; `Nsubjects` / `Ntrials` set at the top of `code/generate_data.R`
- Reward probabilities: 0.50 for all arms (unbiased)
- True parameters sampled from priors defined in `population_params_list` in `generate_data.R`,
  matching the Stan model's parameterization

## Pipeline (via main.R)
1. `generate_data.R`             — simulate agents, save `cfg.rds` + `df.rds` + `population_params.csv` + `individual_params.csv`
2. `plot_param_distributions.R`  — dotplots of simulated per-agent parameter distributions
3. `fit_stan.R`                  — fit Stan model with cmdstanr; save `fit.rds`, `recovered_medians.csv`
   (subject-level posterior medians), `population_posteriors.rds` (population-level posterior draws)
4. `diagnostics.R`               — check divergences, Rhat, ESS; save `Diagnostics.pdf` (trace/rank/pairs plots, Rhat/ESS histograms)
5. `plot_recovery.R`             — 2x2 scatter grid (true vs. recovered medians), save `param_recovery.pdf/png`
6. `plot_population_posteriors.R`— population-level posterior vs. true generating value, save `population_posteriors.pdf/png`
7. `summary_table.R`             — Pearson r table, save `recovery_summary.csv`

## Outputs
- `artifacts/cfg.rds`                  — simulation config (Nsubjects, Narms, Ntrials, expvalues)
- `artifacts/df.rds`                   — simulated trial-level data
- `artifacts/population_params.csv`    — population-level distribution parameters (mu/sigma per parameter)
- `artifacts/individual_params.csv`    — generating parameter values per agent
- `artifacts/fit.rds`                  — fitted CmdStanMCMC object (not committed to git —
  can exceed GitHub's 100MB push limit at larger scales; regenerate locally via `main.R`)
- `artifacts/recovered_medians.csv`    — posterior median estimates per agent
- `artifacts/population_posteriors.rds`— posterior draws of the population-level parameters
- `output/param_distributions.pdf/.png`— simulated parameter distributions
- `output/Diagnostics.pdf`             — trace/rank/pairs plots, Rhat/ESS histograms
- `output/param_recovery.pdf/.png`     — recovery scatter plots
- `output/population_posteriors.pdf/.png` — population-level posterior vs. true value
- `output/recovery_summary.csv`        — Pearson r per parameter

## Results

### Sanity run (reduced scale)
Ran end-to-end with reduced settings to sanity-check the pipeline before a full-scale run:
`Nagents = 50` (vs. 200 in the documented setup) and `iter_warmup = iter_sampling = 100`
(vs. 1000). These reductions are temporary, in `code/generate_data.R` and `code/fit_stan.R`.

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Group-level Rhat/ESS not fully converged at this reduced iteration count (expected):
  4 of 8 group-level parameters had Rhat > 1.01, all had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior mean):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.727     |
  | alpha_per | 0.205     |
  | beta_rl   | 0.966     |
  | beta_per  | 0.472     |

`alpha_per` recovers poorly at this reduced scale/iteration count — worth watching once
run at full scale (200 agents, 1000/1000 iterations) to see whether it's a sampling-budget
artifact or a genuine identifiability issue with the perseveration learning rate.

### Full warmup/sampling budget, reduced agent count
Ran with the documented iteration budget restored (`iter_warmup = iter_sampling = 1000`)
but `Nagents` still at 50 (not the documented 200) to keep runtime manageable. Runtime:
~15.5 minutes end-to-end (4 chains, 2000 total iterations each).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Group-level convergence improved over the reduced sanity run: 4 of 8 parameters still
  had Rhat > 1.01, but only 3 of 8 had ESS_bulk < 400 (vs. all 8 previously).
- Parameter recovery (Pearson r, true vs. posterior mean; note: a new random draw of true
  parameters each run, since the pipeline doesn't set a seed, so these r values aren't
  directly comparable trial-to-trial):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.595     |
  | alpha_per | 0.300     |
  | beta_rl   | 0.940     |
  | beta_per  | 0.529     |

`beta_rl` recovers strongly and consistently across runs. `alpha_per` remains the weakest
across both the reduced and full-iteration runs — at 50 agents this looks more like a
genuine identifiability limitation than a sampling-budget artifact, but this should be
re-checked once run with the full 200 agents.

### Merged with upstream refactor, same parameters (Nagents=50, 1000/1000 iterations)
Merged in a refactor from `analysis/classic-model-recovery` (renamed `sim_data`/`true_params`
to `df`/`population_params`+`individual_params`, dropped the custom `init_fn`/`adapt_delta`
from `fit_stan.R`) and updated `fit_stan.R`/`plot_recovery.R`/`summary_table.R` to read the
renamed artifact files, which the refactor commit hadn't updated. Re-ran with the same
parameters as the previous run (`Nagents = 50`, `iter_warmup = iter_sampling = 1000`).
Runtime: ~14 minutes end-to-end.

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full group-level convergence: 0 of 8 parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior mean; new random draw of true
  parameters each run, so not directly comparable trial-to-trial):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.528     |
  | alpha_per | 0.511     |
  | beta_rl   | 0.919     |
  | beta_per  | 0.786     |

Best `alpha_per` recovery so far (0.511 vs. 0.20-0.30 in earlier runs) alongside the
cleanest convergence diagnostics yet — consistent with dropping the custom `init_fn` in
`fit_stan.R` having helped, though this should be confirmed by running the model multiple
times rather than from a single run.

### PI additions: diagnostics/distribution/population-posterior plots, medians moved to fit_stan.R
The PI added `plot_param_distributions.R`, expanded `diagnostics.R` to save a full
`Diagnostics.pdf` (bayesplot trace/rank/pairs plots, Rhat/ESS histograms), and added
`plot_population_posteriors.R` (ggdist half-eye plots of population-level posteriors vs.
true value). Also refactored `generate_data.R` around a `cfg` list/`cfg.rds` artifact and
renamed `Nagents` to `Nsubjects`.

Per follow-up request, `fit_stan.R` now saves `recovered_medians.csv` (subject-level
posterior **medians**, not means) and `population_posteriors.rds` (population-level
posterior draws) directly after fitting, so `plot_recovery.R`, `plot_population_posteriors.R`,
and `summary_table.R` no longer need to reload `fit.rds` themselves.

### Full-scale run: 100 subjects, 200 trials, 2000 warmup + 3000 sampling iterations
First attempt at this scale **OOM-crashed** (killed by the kernel, confirmed via `dmesg`)
right after all 4 chains finished sampling, before `fit.rds` could even be saved. Root cause:
`classic_qval_and_eval.stan` persisted `log_lik` (as a `transformed parameters` vector) and
`Q_trial`/`E_trial` (in `generated quantities`) — full `Ndata`-length arrays saved for
*every* posterior draw. At `Ndata = 100 x 200 = 20000` and 5000 draws x 4 chains, each
chain's output CSV was 3.3GB (13.2GB total), more than the container's 15GB RAM.

Fixed by moving the per-trial simulation loop into the `model` block so `log_lik` is
accumulated as a local scalar instead of being saved as an `Ndata`-length vector per draw,
and dropping `Q_trial`/`E_trial` entirely (nothing downstream read them). Same priors and
parameter estimates, ~100x less output per draw. Rerun succeeded: `fit.rds` came out to 73MB
(vs. an extrapolated multi-GB size without the fix).

Runtime: ~27 minutes end-to-end (MCMC sampling alone: ~24.3 minutes).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Strong convergence: 1 of 8 group-level parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.439     |
  | alpha_per | 0.177     |
  | beta_rl   | 0.832     |
  | beta_per  | 0.521     |

`alpha_per` recovery is weakest here despite the much larger sample size and iteration
budget — combined with its consistently weak recovery across every run so far (reduced and
full scale alike), this now looks more like a structural identifiability limitation of the
model/parameterization for `alpha_per` than a sampling-budget issue. Worth a closer look
(e.g. simulation-based calibration, or checking whether `alpha_per` trades off against
`beta_per` in the posterior) before relying on this parameter in downstream analyses.

### 8-arm bandit: same scale (100 subjects, 200 trials, 2000+3000 iterations), Narms=3->8
Same settings as the previous full-scale run, with `Narms` raised from 3 to 8 in
`generate_data.R` (all downstream code — `sim.block()`, the Stan model, `fit_stan.R`'s
data-driven `Narms_fit <- max(df$ch_card)` — is generic to `Narms`, so no other changes
were needed). Verified directly on the simulated data before fitting: `Q_cards`/`E_cards`/
`prob_cards` list-columns are length-8 vectors per trial, `ch_card` spans 1-8, and
`cfg$Narms == 8`.

Runtime: ~87 minutes end-to-end (MCMC sampling alone: ~85 minutes — heavier per-iteration
cost than the 3-arm run, from the larger softmax/categorical_logit_lpmf over 8 categories
each trial). `fit.rds` came out to 74MB, consistent with the trimmed model.

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full group-level convergence: 0 of 8 parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.570     |
  | alpha_per | 0.214     |
  | beta_rl   | 0.921     |
  | beta_per  | 0.807     |

Consistent with the 3-arm run: `alpha_per` is again the weakest-recovering parameter by a
wide margin, further supporting a structural identifiability issue rather than a
data-scale or arm-count artifact.

### 8-arm bandit rerun: beta_per's generating sigma lowered 0.75 -> 0.5
Same settings as the previous 8-arm run (100 subjects, 200 trials, 2000+3000 iterations),
with `beta_per`'s generating `sigma` in `population_params_list` (`generate_data.R`) lowered
from 0.75 to 0.5, narrowing the true population spread of the perseveration inverse-temperature.

Runtime: ~2h9m end-to-end (MCMC sampling alone: ~2h04m — slower than the first 8-arm run,
likely reflecting scheduling variability in this shared container rather than the model change).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full group-level convergence: 0 of 8 parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.619     |
  | alpha_per | 0.203     |
  | beta_rl   | 0.962     |
  | beta_per  | 0.543     |

`alpha_per` again the weakest by far, consistent across every run regardless of arm count
or `beta_per`'s prior width. `beta_per` recovery dropped noticeably (0.543 vs. 0.807 in the
first 8-arm run) — expected, since narrowing the generating sigma shrinks the true
between-subject spread in `beta_per`, leaving less signal for the true-vs-recovered
correlation to pick up against posterior estimation noise.

### 8-arm bandit, beta_per's generating sigma raised 0.5 -> 1.2
Same scale as the last two 8-arm runs (100 subjects, 200 trials, 2000+3000 iterations),
with `beta_per`'s generating `sigma` widened from 0.5 to 1.2 (same change applied in
parallel to `eval_only_param_recovery`, run back-to-back in this same session). Runtime:
~95 minutes end-to-end (MCMC sampling alone: ~95.3 minutes).

- 0 divergent transitions, 0 max-treedepth hits across all 4 chains.
- Full group-level convergence: 0 of 8 parameters had Rhat > 1.01, 0 had ESS_bulk < 400.
- Parameter recovery (Pearson r, true vs. posterior median):

  | parameter | pearson_r |
  |-----------|-----------|
  | alpha_rl  | 0.548     |
  | alpha_per | 0.321     |
  | beta_rl   | 0.969     |
  | beta_per  | 0.774     |

`beta_per` recovery bounced back up with the wider prior (0.774, vs. 0.543 at sigma=0.5,
back in the 0.79-0.81 range seen at sigma=0.75), consistent with the `eval_only` model's
same pattern — narrower `beta_per` priors leave less true between-subject signal to
recover. `alpha_per` improved too (0.321, its best result yet) but remains the weakest
parameter in every run regardless of arm count or `beta_per`'s prior width, still pointing
to some genuine identifiability difficulty specific to `alpha_per` in this model.
