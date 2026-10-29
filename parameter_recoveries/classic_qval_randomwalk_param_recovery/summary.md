# Recovery Notebook: classic_qval, randomwalk environment

**Generative model:** `models/classic_qval/` (`classic_qval.R`, `sim.block()`)
**Fitted model:** `models/classic_qval/classic_qval.stan`
**Job-folder:** `parameter_recoveries/classic_qval_randomwalk_param_recovery/`
**Sibling folder:** `parameter_recoveries/classic_qval_p50_param_recovery/` (same seeds, same true parameters)
**Date Created:** 2026-10-29

## Goal

Check whether the plain 2-parameter RL model (alpha, beta; no perseveration) is recoverable
in this environment, at the real sample size (N = 35) and at a larger N (200) to separate
sample-size limits from structural identifiability. Compared directly with the sibling folder
in `parameter_recoveries/classic_qval_comparison.md`.

## 1. Design (set in `main.R`)

* **Environment:** 3 arms, all offered every trial. p(win) per arm follows a Gaussian random walk (SD 0.05, clamped to [0, 1], start U(0, 1)); one walk (seed_env) shared by all subjects.
* **n_subjects:** 20 (sanity), 35, 200 (`run_name` = `sanity_n20`, `n35`, `n200`)
* **n_trials:** 150; **n_sessions:** 1
* **Population location:** mu_alpha = 0, mu_beta = -0.25
* **Population scale:** sigma_alpha = 0.85, sigma_beta = 0.75
* **Transforms:** alpha = plogis(N(mu_alpha, sigma_alpha)); beta = exp(N(mu_beta, sigma_beta))
* **Sampler:** Stan via cmdstanr, 4 chains; sanity 500 warmup + 500 sampling, full runs 2000 + 2000
* **Priors (fitted model):** mu ~ N(0, 3), sigma ~ half-N(0, 3), raw ~ N(0, 1), non-centred
* **Seeds:** seed_params = 1001 (true parameters: 200 draws, first n_subjects kept, so runs are nested),
  seed_env = 2002 (reward schedule), seed_sim = 3003 (choices/rewards), seed_stan = 4004 (MCMC).
  Identical in both sibling folders.

## 2. Model

Q initialised at 0.5 for every arm at each subject's first trial; delta-rule update of the chosen
arm only (Q[ch] += alpha * (reward - Q[ch])); choice by softmax over all 3 arms
(`categorical_logit(beta * Q)`). The likelihood is accumulated locally in the `model` block; only
subject-length vectors and population scalars are saved.

## 3. Pipeline (via `main.R`)

| Script | Does | Writes |
|---|---|---|
| `01_generate_data.R` | reward schedule, true parameters, simulated choices | `cfg.rds`, `df.rds`, `population_params.csv`, `individual_params.csv` |
| `02_plot_reward_schedule.R` | p(win) per arm over trials | `02_reward_schedule.{pdf,png}` |
| `03_plot_param_distributions.R` | dot histograms of true alpha, beta + generating density | `03_param_distributions.{pdf,png}` |
| `04_fit_stan.R` | fit; subject medians/SD/90% CI; per-subject alpha-beta posterior correlation | `fit.rds` (gitignored), `recovered_summary.csv`, `posterior_cor.csv`, `population_posteriors.rds` |
| `05_diagnostics.R` | divergences, Rhat, ESS; trace/rank/pairs plots | `diagnostics.csv`, `05_diagnostics.pdf` |
| `06_plot_recovery.R` | true vs posterior median scatter | `06_param_recovery.{pdf,png}` |
| `07_plot_population_posteriors.R` | mu, sigma posteriors vs true values | `07_population_posteriors.{pdf,png}` |
| `08_summary_table.R` | r, bias, slope, coverage, posterior SD, spread ratio, trade-offs | `08_recovery_summary.csv`, `08_population_recovery.csv` |
| `09_write_report.R` | Word narrative + multi-page vector PDF | `09_recovery_report.docx`, `09_recovery_figures.pdf` |

Artifacts go to `artifacts/<run_name>/`, outputs to `output/<run_name>/`.

## 4. Findings / Summary

(Filled in after the runs.)
