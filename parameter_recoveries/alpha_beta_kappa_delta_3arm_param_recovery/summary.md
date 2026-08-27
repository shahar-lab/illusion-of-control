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

<!-- Append a new ### subsection here for every run. Don't overwrite previous Results. -->
