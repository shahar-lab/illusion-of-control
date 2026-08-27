# Parameter Recovery: alpha_beta_kappa_delta_3arm (3 arms, no raffle, fixed 50/50 reward)

## Goal
Verify that `alpha_beta_kappa_delta_3arm` — a 3-arm, no-raffle Q-learning +
perseveration model — can recover its four free parameters (`alpha`, `beta`,
`kappa`, `delta`) from synthetic data.

## Model
Hierarchical Rescorla-Wagner Q-learning combined with a decay-based perseveration
trace over a 3-armed bandit with **no raffle**: all arms are offered and choosable
on every trial. Choice is modeled as a categorical softmax over combined value
signals (`categorical_logit_lpmf(ch_card | beta * Q + delta * E)`).

This is the `alpha_beta_3arm` model extended with the perseveration mechanism from
`decay_eval_only` / `qval_and_decay_eval`:
- Q-values update via classic Rescorla-Wagner (only chosen arm)
- E-values (perseveration trace): all arms decay toward 0, chosen arm pulled toward 1

Four free parameters:
- `alpha`: RL learning rate, bounded [0, 1] via inv_logit (hierarchical inv_logit-normal)
- `beta`: RL inverse temperature, unconstrained (hierarchical normal)
- `kappa`: perseveration decay rate, bounded [0, 1] via inv_logit (hierarchical inv_logit-normal)
- `delta`: perseveration weight, unconstrained (hierarchical normal)

## Simulation setup
- n_subjects = 200, n_arms = 3, n_raffle = n_arms (all arms always offered),
  n_trials = 200, n_blocks = 1
- Reward schedule: fixed 50/50 win probability for all arms/trials
- True population generators: mu_alpha = 0, sigma_alpha = 1.25; mu_beta = 3.5,
  sigma_beta = 1.25; mu_kappa = 0, sigma_kappa = 1.25; mu_delta = 0,
  sigma_delta = 1.2

## Pipeline (via main.R)
Identical structure to `alpha_beta_3arm_50_50`, extended for 4 parameters:
1. `01_set_task_parameters.R` — task config
2. `02_generate_random_walk.R` — fixed 50/50 `expvalues` matrix
3. `03_visualize_random_walk.R` — sanity plot
4. `04_set_agent_population_parameters.R` — population generators (alpha, beta, kappa, delta)
5. `05_generate_agents_parameters.R` — per-subject true parameters
6. `06_generate_parameters_visualization.R` — sanity-check simulated parameter distributions
7. `07_set_model.R` — model name config
8. `08_generate_behavior.R` — simulate 200 agents (3-arm, no raffle, Q+E)
9. `09_fit_model.R` — fit hierarchical Stan model (4 chains, 2000 warmup, 2000
   sampling); prints divergence/Rhat/ESS diagnostics inline
10. `10_recovery_visualization.R` — true vs. recovered scatter + population posteriors

## Outputs
- `artifacts/`: simulation_config.RData/.rds, cfg.rds, expvalues.rds,
  model_config.rds, true_parameters.rds, simulated_data.rds, stan_fit.rds,
  stan_draws_sbj.rds, stan_draws_pop.rds, recovery_table.rds, posterior_sds.rds
- `output/`: random_walk.pdf/.png, true_parameters.pdf/.png,
  parameter_recovery_scatter.pdf/.png

## Results

### Pilot run: 2026-08-27, 30 subjects, 4 chains x 300 warmup + 300 sampling

Reduced-scale sanity pass before committing to a full run (per this lab's
`RUN_CONVENTIONS.md`), with `n_subjects` and `iter_warmup`/`iter_sampling`
temporarily lowered in `04_set_agent_population_parameters.R` and
`09_fit_model.R` for this run only, then reverted to the checked-in full-scale
defaults (200 subjects, 4 chains x 2000 warmup + 2000 sampling) afterward — the
committed pipeline still runs at full scale by default.

- **Runtime:** ~2.3 min (137.6s total; ~112.3s mean per chain)
- **Divergent transitions:** 0
- **Max treedepth hits:** 0
- **Rhat / ESS** (all eight group-level parameters):
  - `mu_alpha`: rhat = 1.01, ess_bulk = 318
  - `mu_beta`: rhat = 1.01, ess_bulk = 403
  - `mu_kappa`: rhat = 1.00, ess_bulk = 599
  - `mu_delta`: rhat = 1.02, ess_bulk = 235
  - `sigma_alpha`: rhat = 1.01, ess_bulk = 476
  - `sigma_beta`: rhat = 1.00, ess_bulk = 407
  - `sigma_kappa`: rhat = 1.00, ess_bulk = 408
  - `sigma_delta`: rhat = 1.01, ess_bulk = 348

  Several Rhat values sit just above the 1.01 target and ESS is well below the
  400 full-run target on some parameters — expected at this reduced scale (30
  subjects, 600 total iterations) and not itself a red flag; 0 divergences and
  no max-treedepth hits indicate the sampler geometry itself is fine.

- **Pearson r (subject-level recovery):**
  - alpha: r = 0.97
  - beta: r = 0.88
  - kappa: r = 0.56
  - delta: r = 0.98

### Interpretation: kappa recovery looks structurally weak, not just noisy

Alpha, beta, and delta all recover well even at this reduced scale. **Kappa does
not** — and the failure mode in the recovery scatter (panel G) isn't scattered
noise around the identity line, it's a compressed band: recovered kappa clusters
between ~0.3-0.85 almost regardless of the true value, with low true kappas
(~0.1-0.3) consistently overestimated. That pattern — a narrow recovered range
that doesn't track the true value — is the signature of weak identifiability
rather than "needs more iterations."

The likely mechanism: `kappa` (perseveration trace decay rate) and `delta`
(perseveration trace weight) both act only through the combined term
`delta * E`, where `E`'s steady-state scale itself depends on `kappa`. Different
`(kappa, delta)` pairs can produce a similar `delta * E` trajectory — e.g. a
smaller `kappa` with a larger `delta` can mimic a larger `kappa` with a smaller
`delta` — which is a classic soft non-identifiability between a rate and a scale
parameter multiplying the same latent signal. `delta` recovers cleanly (r=0.98)
because its scale is well pinned down by the choice data in aggregate, while
`kappa` — which only shows up multiplicatively inside that same term — is much
less constrained per subject.

I checked this directly: within-subject posterior correlation between `kappa_sbj`
and `delta_sbj` for the first 5 subjects (from this pilot's saved
`stan_draws_sbj.rds`) came back mixed — 0.62, 0.64, 0.32, -0.03, 0.10 — not the
uniform strong trade-off the multiplicative-nonidentifiability story would
predict. So that specific mechanism isn't confirmed by this quick check (only
600 total draws per subject at pilot scale, and only 5 subjects inspected), and
should be treated as an untested hypothesis, not a diagnosis.

**Before running at full scale**, it's worth investigating further rather than
just scaling up: rerun the `kappa_sbj`/`delta_sbj` pairs check with more
subjects and full-scale draws, and consider whether kappa is identifiable at all
under a fixed-50/50, no-raffle reward schedule (constant reward means `E`'s
influence on behavior is never validated against feedback, which could leave
`kappa` underconstrained regardless of any kappa/delta trade-off). Widening/
narrowing priors is unlikely to fix a structural non-identifiability — the
`RUN_CONVENTIONS.md` guidance to "check whether a specific parameter's prior is
too narrow/wide" applies more to convergence problems than to this shape of
recovery failure, so don't reach for that first without more diagnosis.

### Full run: 2026-08-27, 200 subjects, 4 chains x 2000 warmup + 2000 sampling

- **Runtime:** ~52 min (3132.6s total; ~3109.2s mean per chain) — about 1.4x
  `alpha_beta_3arm_50_50`'s ~36 min at the same subject/trial/iteration count,
  consistent with tracking two latent states (Q and E) per arm per trial instead
  of one
- **Divergent transitions:** 0
- **Max treedepth hits:** 0
- **Rhat / ESS** (all eight group-level parameters — clean at full scale, unlike
  the pilot where several sat just above target):
  - `mu_alpha`: rhat = 1.01, ess_bulk = 816
  - `mu_beta`: rhat = 1.00, ess_bulk = 2017
  - `mu_kappa`: rhat = 1.00, ess_bulk = 2125
  - `mu_delta`: rhat = 1.00, ess_bulk = 993
  - `sigma_alpha`: rhat = 1.00, ess_bulk = 1485
  - `sigma_beta`: rhat = 1.00, ess_bulk = 2007
  - `sigma_kappa`: rhat = 1.00, ess_bulk = 1544
  - `sigma_delta`: rhat = 1.01, ess_bulk = 1527
- **Pearson r (subject-level recovery):**
  - alpha: r = 0.89
  - beta: r = 0.85
  - kappa: r = 0.58
  - delta: r = 0.95

### Kappa identifiability: confirmed and diagnosed (not a pilot-scale artifact)

Kappa's r barely moved between pilot (0.56, n=30) and full scale (0.58, n=200),
and the full-scale recovery scatter shows the identical compressed-band pattern
— convergence itself is clean (0 divergences, Rhat ≤ 1.01 on every group
parameter), so this is a real feature of the model/design, not insufficient
sampling.

The pilot's "kappa/delta trade off pairwise" hypothesis did **not** hold up at
full scale either: mean within-subject `cor(kappa_sbj, delta_sbj)` across all 200
subjects is ~0 (mean 0.056, median 0.12), with correlations of both signs and
high subject-to-subject variance (SD 0.40) — not the systematic trade-off that
story predicts.

The actual mechanism, checked directly against this run's saved draws: **kappa's
identifiability depends on the magnitude of that subject's delta**, not on a
trade-off with it.
- `cor(kappa posterior SD, |true delta|) = -0.75` — subjects with larger |delta|
  get much tighter (more identified) kappa posteriors.
- Splitting subjects into terciles by |true delta|, kappa's recovery Pearson r
  rises monotonically: **r = 0.23** (lowest |delta| tercile, mean |delta| = 0.25)
  → **r = 0.59** (mid, mean |delta| = 0.79) → **r = 0.84** (highest, mean |delta|
  = 1.77).

This makes sense from the likelihood structure: `kappa` only enters choice
through `delta * E`. When a subject's `delta` is near 0, the perseveration trace
has almost no effect on their choices regardless of `kappa`'s true value, so
there's essentially no signal in the data to pin `kappa` down — the pooled
r=0.58 is an average over subjects who are individually well-identified (high
|delta|) and subjects who are nearly unidentified (low |delta|), not uniform
weak identifiability. Subjects with `delta` near the population mean (0) are
structurally the hardest to estimate `kappa` for, no matter how much data or how
many iterations are added.

**Implication:** more iterations/subjects won't fix this — it's a property of
the design, not the sampler. If `kappa` needs to be well-identified for subjects
with weak perseveration (small |delta|) specifically, the task itself needs to
change (e.g. a reward schedule where perseveration and reward-tracking make
different predictions, so choices are informative about the decay trace even
when its overall weight is small) rather than the model or priors.
