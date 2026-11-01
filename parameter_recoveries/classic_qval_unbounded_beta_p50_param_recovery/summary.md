# Recovery Notebook: classic_qval_unbounded_beta, p50 environment

**Generative model:** `models/classic_qval_unbounded_beta/` (`classic_qval_unbounded_beta.R`, `sim.block()`)
**Fitted model:** `models/classic_qval_unbounded_beta/classic_qval_unbounded_beta.stan`
**Job-folder:** `parameter_recoveries/classic_qval_unbounded_beta_p50_param_recovery/`
**Sibling folder:** `parameter_recoveries/classic_qval_unbounded_beta_randomwalk_param_recovery/` (same seeds, same true parameters)
**Date Created:** 2026-11-01

## Goal

Same as `classic_qval_p50_param_recovery`, but with beta on an identity link (no exp), as suggested by
Ido Ben-Artzi, so a population beta of 0 (random choice) and negative betas are reachable. Generating population
on the natural scale: alpha = plogis(N(0, 1.5)), beta = N(3, 1.5). Compared with the old and highbeta populations of
`classic_qval` in `parameter_recoveries/classic_qval_comparison.md`.

## 1. Design (set in `main.R`)

* **Environment:** 3 arms, all offered every trial. p(win) = 0.5 for every arm on every trial (the real experiment design).
* **n_subjects:** 200 only (`run_name` = `n200`); no sanity or n35 runs, by the researcher's choice
* **n_trials:** 150; **n_sessions:** 1
* **Population location:** mu_alpha = 0, mu_beta = 3
* **Population scale:** sigma_alpha = 1.5, sigma_beta = 1.5
* **Transforms:** alpha = plogis(N(mu_alpha, sigma_alpha)); beta = N(mu_beta, sigma_beta) (identity; 2% of the 200 draws are < 0, 10.5% < 1)
* **Sampler:** Stan via cmdstanr, 4 chains, 2000 warmup + 3000 sampling
* **Priors (fitted model):** mu ~ N(0, 3), sigma ~ half-N(0, 3), raw ~ N(0, 1), non-centred (as classic_qval)
* **Seeds:** seed_params = 1001, seed_env = 2002 (unused by p50), seed_sim = 3003, seed_stan = 4004;
  200 true-parameter draws (same z-scores as the classic_qval folders).

## 2. Model

As `classic_qval` (Q initialised at 0.5, delta-rule update of the chosen arm only, softmax
`categorical_logit(beta * Q)` over all 3 arms), except beta_sbj = mu_beta + sigma_beta * beta_raw with no
link, and beta_pop = mu_beta.

## 3. Pipeline (via `main.R`)

Identical to `classic_qval_p50_param_recovery` (01-09, including `06_alpha_error_vs_beta`), with the
link-dependent parts changed for beta: 01 draws beta with `rnorm` (link "identity"); 06's alpha-error plot uses a
linear x axis (beta can be <= 0); 07 and 08 take the true beta_pop as mu_beta; 09's design text and captions
describe the identity link.

Artifacts go to `artifacts/<run_name>/`, outputs to `output/<run_name>/`.

## 4. Findings / Summary

Laptop (Windows), 4 chains x 2000 + 3000. `fit.rds` (73 MB) is gitignored and kept locally.

**Convergence**

| Run | Divergences | Group max Rhat | Group min ESS_bulk | Subject max Rhat | Fit time (min) |
|---|---|---|---|---|---|
| n200 | 0 | 1.002 | 1498 | 1.002 | 75.8 (in parallel with randomwalk n200_walk3021) |

**Subject-level recovery** (true vs posterior median)

| Run | alpha r | alpha slope | alpha 90% cov. | alpha SD ratio | beta r | beta slope | beta 90% cov. | alpha-beta error r |
|---|---|---|---|---|---|---|---|---|
| n200 | 0.88 | 0.85 | 0.90 | 0.96 | 0.86 | 0.78 | 0.91 | -0.55 |

**Population-level recovery** (natural scale; true alpha_pop = 0.50, beta_pop = 3.00)

| Run | alpha_pop median [90% CI] | beta_pop median [90% CI] |
|---|---|---|
| n200 | 0.50 [0.45, 0.55] | 3.06 [2.85, 3.28] |

**Alpha by true beta**

| beta | n | alpha r | mean alpha error |
|---|---|---|---|
| < 0 | 4 | 0.56 | -0.14 |
| 0-0.5 | 7 | -0.56 | -0.16 |
| 0.5-1 | 10 | 0.68 | -0.21 |
| 1-2 | 29 | 0.93 | -0.03 |
| 2-4 | 101 | 0.92 | 0.00 |
| >= 4 | 49 | 0.97 | 0.04 |

For beta >= 1 (179 agents) alpha recovers about as well as in the classic_qval highbeta run. The 21 agents with
beta < 1 (they do not exist in the highbeta population) have alpha underestimated by about 0.15-0.2 and r that is
noisy and low (bins of 4-10 agents). They pull the overall alpha r down relative to highbeta.
