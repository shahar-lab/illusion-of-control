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
