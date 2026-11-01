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
* **Sampler:** Stan via cmdstanr, 4 chains; sanity 500 warmup + 500 sampling, full runs 2000 + 3000
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
| `03_plot_param_distributions.R` | dot histograms of true alpha, beta | `03_param_distributions.{pdf,png}` |
| `04_fit_stan.R` | fit; subject medians/SD/90% CI; per-subject alpha-beta posterior correlation | `fit.rds` (gitignored), `recovered_summary.csv`, `posterior_cor.csv`, `population_posteriors.rds` |
| `05_diagnostics.R` | divergences, Rhat, ESS; trace/rank/pairs plots | `diagnostics.csv`, `05_diagnostics.pdf` |
| `06_plot_recovery.R` | true vs posterior median scatter | `06_param_recovery.{pdf,png}` |
| `07_plot_population_posteriors.R` | alpha_pop, beta_pop posteriors (natural scale) vs true values | `07_population_posteriors.{pdf,png}` |
| `08_summary_table.R` | r, bias, slope, coverage, posterior SD, spread ratio, trade-offs | `08_recovery_summary.csv`, `08_population_recovery.csv` |
| `09_write_report.R` | Word narrative + multi-page vector PDF | `09_recovery_report.docx`, `09_recovery_figures.pdf` |

Artifacts go to `artifacts/<run_name>/`, outputs to `output/<run_name>/`.

## 4. Findings / Summary

All runs on the laptop (Windows), 4 chains; sanity 500 + 500, n35 and n200 2000 + 3000.

**Convergence**

| Run | Divergences | Group max Rhat | Group min ESS_bulk | Subject max Rhat | Fit time (min) |
|---|---|---|---|---|---|
| sanity_n20 | 0 | 1.013 (1 group parameter > 1.01) | 377 | 1.008 | 1.1 |
| n35 | 0 | 1.001 | 2787 | 1.002 | 6.6 |
| n200 | 0 | 1.001 | 3227 | 1.002 | 135.9 (in parallel with p50 n200) |

**Subject-level recovery** (true vs posterior median)

| Run | alpha r | alpha slope | alpha 90% cov. | alpha SD ratio | beta r | beta slope | beta 90% cov. | alpha-beta error r |
|---|---|---|---|---|---|---|---|---|
| sanity_n20 | 0.76 | 0.48 | 0.95 | 0.63 | 0.98 | 0.98 | 0.95 | -0.21 |
| n35 | 0.63 | 0.31 | 0.89 | 0.49 | 0.98 | 0.97 | 0.97 | -0.31 |
| n200 | 0.58 | 0.33 | 0.91 | 0.57 | 0.95 | 1.28 | 0.91 | -0.13 |

**Population-level recovery** (natural scale; true alpha_pop = 0.50, beta_pop = 0.78)

| Run | alpha_pop median [90% CI] | beta_pop median [90% CI] |
|---|---|---|
| sanity_n20 | 0.46 [0.31, 0.62] | 1.03 [0.70, 1.49] |
| n35 | 0.54 [0.43, 0.65] | 0.86 [0.63, 1.13] |
| n200 | 0.51 [0.47, 0.56] | 0.74 [0.66, 0.83] |

## 5. Highbeta population (2026-11-01)

The original beta population (exp(N(-0.25, 0.75)), median 0.73, 66% below 1) is close to random choice
(Q is in [0, 1]), and alpha recovered poorly at low beta. New population, suggested by Ido Ben-Artzi:
**mu_alpha = 0, sigma_alpha = 1.5; mu_beta = 1, sigma_beta = 0.5** (beta median 2.7, mean ~3.1, SD ~1.6;
2% below 1). Model, priors, links, seed_params/seed_sim/seed_stan and the 200-draw nesting are unchanged, so
each subject keeps the same underlying z-scores as in sections 1-4. n35 was skipped.

**New random walk.** The original walk (seed_env 2002) had arm 3 best for ~110 of 150 trials. The researcher
picked a more balanced walk, **seed_env = 3021** (five persistent best-arm switches, each arm best on 26-45% of trials,
mean best-vs-second gap 0.21), screened from 5000 seeds of the same generator. Runs on it carry a `_walk3021` suffix.
`sanity_n20_highbeta` still used walk 2002 (population change only).

New figure: `06_alpha_error_vs_beta` (alpha posterior median - true vs true beta, log x, loess), figure 4 in the
report and page 4 of the PDF.

**Convergence**

| Run | Walk | Divergences | Group max Rhat | Group min ESS_bulk | Subject max Rhat | Fit time (min) |
|---|---|---|---|---|---|---|
| sanity_n20_highbeta | 2002 | 0 | 1.013 (2 group parameters > 1.01) | 374 | 1.010 | 0.7 |
| sanity_n20_highbeta_walk3021 | 3021 | 0 | 1.015 (1 group parameter > 1.01) | 396 | 1.004 | 1.9 |
| n200_highbeta_walk3021 | 3021 | 0 | 1.001 | 2810 | 1.002 | 65.7 (in parallel with p50 n200_highbeta) |

**Subject-level recovery**

| Run | alpha r | alpha slope | alpha 90% cov. | alpha SD ratio | beta r | beta slope | beta 90% cov. | alpha-beta error r |
|---|---|---|---|---|---|---|---|---|
| sanity_n20_highbeta | 0.91 | 0.83 | 0.90 | 0.92 | 0.94 | 0.70 | 0.80 | -0.16 |
| sanity_n20_highbeta_walk3021 | 0.97 | 0.95 | 0.95 | 0.98 | 0.93 | 0.72 | 0.85 | -0.28 |
| n200_highbeta_walk3021 | 0.94 | 0.89 | 0.91 | 0.95 | 0.94 | 0.86 | 0.85 | -0.43 |

**Population-level recovery** (natural scale; true alpha_pop = 0.50, beta_pop = exp(1) = 2.72)

| Run | alpha_pop median [90% CI] | beta_pop median [90% CI] |
|---|---|---|
| sanity_n20_highbeta | 0.52 [0.36, 0.70] | 3.12 [2.55, 3.86] |
| sanity_n20_highbeta_walk3021 | 0.49 [0.32, 0.68] | 3.31 [2.71, 4.03] |
| n200_highbeta_walk3021 | 0.50 [0.45, 0.54] | 2.73 [2.55, 2.91] |

**Alpha by true beta** (n200; alpha r, mean alpha error)

| beta | n200 (old population, walk 2002) | n200_highbeta_walk3021 |
|---|---|---|
| < 0.5 | n = 55: r 0.32, error 0.00 | none |
| 0.5-1 | n = 78: r 0.60, error 0.01 | n = 4: r 0.17, error -0.12 |
| 1-2 | n = 42: r 0.68, error 0.04 | n = 50: r 0.91, error -0.04 |
| 2-4 | n = 20: r 0.78, error 0.04 | n = 102: r 0.95, error 0.00 |
| >= 4 | n = 5: r 0.97, error -0.05 | n = 44: r 0.96, error 0.02 |

Alpha recovery still depends on beta within a run, but almost all agents now sit where it is good.
At the low end (beta < ~1.5) alpha is underestimated. Old n200 and n200_highbeta_walk3021 differ in both
population and walk; the sanity pair (walk 2002, population only) shows the population effect alone at N = 20:
alpha r 0.76 -> 0.91, slope 0.48 -> 0.83.
