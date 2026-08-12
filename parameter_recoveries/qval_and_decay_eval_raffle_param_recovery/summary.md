# Parameter Recovery: qval_and_decay_eval_raffle

## Goal
Validate that the hierarchical Stan model (`qval_and_decay_eval_raffle.stan`) can reliably
recover subject-level parameters from simulated data.

## Raffle variant
Identical to `qval_and_decay_eval_param_recovery` except each trial offers only a random
subset of `Nraffle` arms out of `Narms` (here `Narms = 4`, `Nraffle = 2`). The choice softmax
and the Stan likelihood are restricted to the offered arms each trial; `Q_cards`/`E_cards`
learning and decay still run over the full arm set.

## Model
`models/qval_and_decay_eval_raffle/` — combines `classic_qval_and_eval`'s reward-driven Q-value
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
- 4-arm bandit, 2 arms raffled per trial; `Nsubjects = 100`, `Narms = 4`, `Nraffle = 2`, `Ntrials = 150`
- Reward probabilities: Gaussian random walk per arm (SD = 0.05), clamped to [0, 1]; all arms start from `runif(4, 0, 1)`
- True parameters sampled from:
  - `alpha_rl`  ~ inv_logit(Normal(0, 0.85))
  - `alpha_per` ~ inv_logit(Normal(0, 0.85))
  - `beta_rl`   ~ exp(Normal(−0.25, 0.75))
  - `beta_per`  ~ Normal(0, 0.75)
- Sampling: 4 chains, `iter_warmup = 2000`, `iter_sampling = 3000`

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
- `artifacts/cfg.rds`                     — simulation config (Nsubjects, Narms, Nraffle, Ntrials, expvalues)
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

Full-scale run (100 subjects, 150 trials, 4 chains × 3000 draws after 2000 warmup).
Convergence diagnostics in `output/Diagnostics.pdf`.

### Pearson r — true vs. recovered posterior medians

| Parameter  | Pearson r | Quality    |
|------------|-----------|------------|
| `alpha_rl` | 0.303     | Poor       |
| `alpha_per`| 0.439     | Moderate   |
| `beta_rl`  | 0.899     | Good       |
| `beta_per` | 0.946     | Excellent  |

### Interpretation

- `beta_rl` and `beta_per` recover well (r > 0.89), as expected for inverse-temperature parameters that strongly constrain the choice distribution.
- `alpha_rl` (r = 0.30) and `alpha_per` (r = 0.44) are only weakly recovered. This is common for learning-rate parameters in short sequences (150 trials); the two alpha parameters may also trade off against each other. The raffle design (only 2 of 4 arms visible per trial) further reduces the information available per trial to constrain individual rates.
- Recovery quality is acceptable for group-level inference but should be considered when interpreting individual differences in `alpha_rl` / `alpha_per`.
