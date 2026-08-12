# Parameter Recovery: decay_rl_decay_h

## Goal
Verify that the four parameters of the decay_rl_decay_h model (decay_rl, decay_h, rho_rl, rho_h) are jointly identifiable and recoverable from simulated choice data.

## Model
A four-parameter hierarchical model with two value systems that each decay toward zero between choices:

- **Q (reward value):** All arms decay by (1 - decay_rl) each trial; the chosen arm is then incremented by rho_rl * reward.
- **H (habit value):** All arms decay by (1 - decay_h) each trial; the chosen arm is then incremented by rho_h regardless of reward.
- **Choice:** logits = Q + H (no separate inverse temperature; scale is absorbed into rho parameters).

Free parameters:
| Parameter | Constraint | Prior (group level) |
|-----------|------------|---------------------|
| decay_rl  | [0, 1]     | inv_logit-normal    |
| decay_h   | [0, 1]     | inv_logit-normal    |
| rho_rl    | > 0        | log-normal          |
| rho_h     | > 0        | log-normal          |

## Simulation setup
- Nsubjects = 200, Narms = 3, Ntrials = 150
- Flat reward probability schedule: expvalues = 0.5 for all arms and trials
- Generating population means (on link scale): decay_rl: mu=0, decay_h: mu=0, rho_rl: mu=0.5, rho_h: mu=0.5 (identity link, unbounded)
- Generating sigma = 0.75 for all parameters

## Pipeline (via main.R)
1. `generate_data.R` — simulate agents, save cfg/df/individual_params/population_params
2. `plot_param_distributions.R` — sanity-check simulated parameter distributions
3. `fit_stan.R` — fit hierarchical Stan model, save fit/recovered_medians/population_posteriors
4. `diagnostics.R` — divergences, Rhat, ESS; save Diagnostics.pdf
5. `plot_recovery.R` — scatter plots of true vs. recovered per parameter
6. `plot_population_posteriors.R` — population posterior vs. true generating value
7. `summary_table.R` — Pearson r table, save recovery_summary.csv

## Outputs
- `artifacts/`: cfg.rds, df.rds, individual_params.csv, population_params.csv, fit.rds, recovered_medians.csv, population_posteriors.rds
- `output/`: param_distributions.pdf/png, Diagnostics.pdf, param_recovery.pdf/png, population_posteriors.pdf/png, recovery_summary.csv

## Results

### Full run (200 subjects, 150 trials, 4 chains x 2000 warmup + 3000 sampling)

**Convergence:** 0 divergent transitions across all 4 chains, 0 max-treedepth hits.
All group-level Rhat = 1.00, all ESS_bulk/ESS_tail in the thousands (min ~2625).
0 parameters with Rhat > 1.01, 0 with ESS_bulk < 400 — clean convergence.

**Recovery (Pearson r, true vs. recovered posterior medians):**

| parameter | pearson_r |
|---|---|
| decay_rl  | 0.488 |
| decay_h   | 0.522 |
| rho_rl    | 0.875 |
| rho_h     | 0.935 |

The increment-scale parameters (`rho_rl`, `rho_h`) recover well. The decay-rate
parameters (`decay_rl`, `decay_h`) recover more weakly — consistent with the
cross-model pattern seen throughout this project's other decaying-trace models:
a decay rate mainly shapes how far back the trace's memory extends, which is a
subtler signal in the choice data than the increment/scale parameters, especially
over a flat (uninformative) 0.5 reward schedule with no true reward-driven
learning signal to sharpen `decay_rl` specifically.

Note: an earlier attempt at this full run was interrupted mid-sampling by a
container restart (1 of 4 chains had finished); the run was restarted from a
fresh data simulation and completed cleanly on the second attempt.
