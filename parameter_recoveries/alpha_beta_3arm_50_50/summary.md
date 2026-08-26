# Parameter Recovery: alpha_beta_3arm (3 arms, no raffle, fixed 50/50 reward)

## Goal
Verify that `alpha_beta_3arm` — a 3-arm, no-raffle variant of `alpha_beta` — can
recover its two free parameters (`alpha`, `beta`) from synthetic data, and compare
recovery quality to the 2-arm/raffle version (`alpha_beta_raffle_50_50`).

## Model
Hierarchical Rescorla-Wagner Q-learning model over an n-armed bandit with **no
raffle**: all `n_arms` cards are offered and choosable on every trial (unlike
`alpha_beta`, which always offers exactly 2 of `n_arms`). Choice is modeled as a
categorical softmax over Q-values for all arms (`categorical_logit_lpmf(ch_card |
beta * Q)`), rather than `alpha_beta`'s binary logistic decision on a left/right
Q-difference — `alpha_beta`'s likelihood is hardcoded for exactly 2 offered arms and
cannot express a 3-way (or n-way) choice, so this is a new model rather than a
reconfigured `alpha_beta`. Only the chosen card's Q-value updates via a standard
delta rule; Q-values reset to 0.5 at the start of each block.

Two free parameters (same link functions as `alpha_beta`):
- `alpha`: learning rate, bounded [0, 1] via inv_logit transform (hierarchical
  inv_logit-normal)
- `beta`: inverse temperature, unconstrained (`mu_beta + sigma_beta * raw`, no
  exp transform)

The Stan likelihood is computed in a local, unsaved accumulator inside the `model`
block (per this lab's `STAN_PITFALLS.md` #1) — the repo's older `ab_3arm.stan`
(since removed) used the same categorical-choice structure but persisted a
`vector[Ndata] log_lik_trial` in `transformed parameters`, which gets written to
the output CSV for every posterior draw and risks the OOM failure mode that pitfall
describes at full scale. This model avoids that by keeping the log-likelihood
accumulation local to the `model` block.

## Simulation setup
- n_subjects = 200, n_arms = 3, n_raffle = n_arms (all arms always offered),
  n_trials = 200, n_blocks = 1
- Reward schedule: fixed 50/50 win probability for all arms/trials (same as
  `alpha_beta_raffle_50_50` — `expvalues` is a constant 0.5 matrix)
- True population generators: mu_alpha = 0, sigma_alpha = 1.25; mu_beta = 3.5,
  sigma_beta = 1.25 (identical to `alpha_beta_raffle_50_50`, for a like-for-like
  comparison across arm count / raffle structure)

## Pipeline (via main.R)
Copied from `alpha_beta_raffle_50_50` with `n_arms = 3`, `n_raffle = n_arms`, and
steps 08/09 rewritten for the no-offered-arms data shape (no `card_left`/
`card_right`/`ch_key`/`selected_offer`/`offered_arms` — just `ch_card`, `reward`,
`first_trial_in_block`, with `n_arms` derived from the data per this lab's
convention rather than hardcoded):
1. `01_set_task_parameters.R` — task config
2. `02_generate_random_walk.R` — fixed 50/50 `expvalues` matrix
3. `03_visualize_random_walk.R` — sanity plot
4. `04_set_agent_population_parameters.R` — population generators
5. `05_generate_agents_parameters.R` — per-subject true parameters
6. `06_generate_parameters_visualization.R` — sanity-check simulated parameter distributions
7. `07_set_model.R` — model name config
8. `08_generate_behavior.R` — simulate 200 agents (3-arm, no raffle)
9. `09_fit_model.R` — fit hierarchical Stan model (4 chains, 2000 warmup, 2000
   sampling); also saves `sigma_alpha`/`sigma_beta` draws and prints divergence/
   Rhat/ESS diagnostics inline (this pipeline has no separate `diagnostics.R` step)
10. `10_recovery_visualization.R` — true vs. recovered scatter + population posteriors

## Outputs
- `artifacts/`: simulation_config.RData/.rds, cfg.rds, expvalues.rds,
  model_config.rds, true_parameters.rds, simulated_data.rds, stan_fit.rds,
  stan_draws_sbj.rds, stan_draws_pop.rds, recovery_table.rds, posterior_sds.rds
- `output/`: random_walk.pdf/.png, true_parameters.pdf/.png,
  parameter_recovery_scatter.pdf/.png

## Results (run 2026-08-26)

Before the full run, a small sanity pass (20 subjects, 50 trials, 2 chains x
150+150) confirmed the simulated data had the expected shape (1000 rows, `ch_card`
in 1:3) and the model compiled/sampled/converged with 0 divergences before
committing to the full-scale run.

- **Runtime:** ~36 min (2161.8s total; ~2131.8s mean per chain) — noticeably
  slower than `alpha_beta_raffle_50_50`'s ~11 min at the same iteration count,
  since the categorical softmax over 3 arms is more expensive per iteration than
  the 2-arm bernoulli_logit likelihood
- **Divergent transitions:** 0
- **Max treedepth hits:** 0
- **Rhat / ESS** (all four group-level parameters, unlike the 2-arm run where
  sigma_alpha/sigma_beta weren't saved):
  - `mu_alpha`: rhat = 1.00, ess_bulk = 1042, ess_tail = 2278
  - `mu_beta`: rhat = 1.00, ess_bulk = 2001, ess_tail = 2834
  - `sigma_alpha`: rhat = 1.00, ess_bulk = 2064, ess_tail = 3720
  - `sigma_beta`: rhat = 1.00, ess_bulk = 2612, ess_tail = 4354
- **Pearson r (subject-level recovery):**
  - alpha: r = 0.92
  - beta: r = 0.89
- **Population posteriors:** both `mu_alpha` and `mu_beta` posteriors tightly
  bracket their true generating values (0 and 3.5 respectively).

### Comparison to alpha_beta_raffle_50_50 (2-arm, same population parameters)
- alpha recovery is identical (r = 0.92 in both).
- beta recovery is *better* with 3 arms and no raffle (r = 0.89 vs. r = 0.82):
  every trial reveals a 3-way relative preference instead of a single left/right
  comparison, which more strongly constrains the inverse-temperature parameter per
  trial. The 2-arm run's visible hierarchical shrinkage on beta (recovered values
  pulled toward the population mean) is less pronounced here.
- Convergence is clean and comparable in both (0 divergences, Rhat = 1.00), though
  this run costs ~3x the wall-clock time for the same iteration count.
