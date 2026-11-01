# classic_qval recovery: p = 0.5 vs random walk, n35 vs n200, and three beta populations

Folders: `classic_qval_p50_param_recovery/` and `classic_qval_randomwalk_param_recovery/`.
Same seeds, same true parameters (n35 nested in n200), 3 arms, 150 trials, 4 chains x 2000 + 3000.
Only the reward schedule differs: p(win) = 0.5 for every arm vs a Gaussian random walk (SD 0.05).
All four runs: 0 divergences, group Rhat <= 1.003, group ESS_bulk >= 1497. Full tables are in each `summary.md`.

## Subject-level recovery

| Environment | N | alpha r | alpha slope | alpha 90% cov. | beta r | beta slope | beta 90% cov. | alpha-beta error r |
|---|---|---|---|---|---|---|---|---|
| p50 | 35 | 0.51 | 0.13 | 0.83 | 0.94 | 1.06 | 0.91 | -0.45 |
| p50 | 200 | 0.49 | 0.24 | 0.88 | 0.95 | 0.93 | 0.93 | -0.38 |
| randomwalk | 35 | 0.63 | 0.31 | 0.89 | 0.98 | 0.97 | 0.97 | -0.31 |
| randomwalk | 200 | 0.58 | 0.33 | 0.91 | 0.95 | 1.28 | 0.91 | -0.13 |

## Population-level recovery (natural scale; true alpha_pop = 0.50, beta_pop = 0.78)

| Environment | N | alpha_pop median [90% CI] | beta_pop median [90% CI] |
|---|---|---|---|
| p50 | 35 | 0.55 [0.39, 0.66] | 0.68 [0.41, 1.05] |
| p50 | 200 | 0.54 [0.49, 0.59] | 0.69 [0.59, 0.80] |
| randomwalk | 35 | 0.54 [0.43, 0.65] | 0.86 [0.63, 1.13] |
| randomwalk | 200 | 0.51 [0.47, 0.56] | 0.74 [0.66, 0.83] |

## What the numbers show

* **Environment.** At both sample sizes, subject-level alpha is recovered better under the random walk than under
  p = 0.5: r 0.63 vs 0.51 (n35) and 0.58 vs 0.49 (n200), with steeper slopes (0.31-0.33 vs 0.13-0.24).
  The alpha-beta error correlation is also weaker under the random walk.
* **Sample size.** Going from 35 to 200 subjects narrows the population-level intervals (alpha_pop CI width
  0.27 -> 0.10 for p50, 0.22 -> 0.09 for randomwalk) but does not raise subject-level alpha r in either
  environment. The limit on subject-level alpha comes from the per-subject data (150 trials), not from N.
* **beta** is recovered with r >= 0.94 in every run. The randomwalk n200 beta slope of 1.28 (SD ratio 1.35)
  means posterior medians are more spread out than the true values in that run.
* The 90% intervals cover the true population values in all four runs.

# Beta population: old vs highbeta vs unbounded (added 2026-11-02)

The old population (beta = exp(N(-0.25, 0.75)), median 0.73, 66% of agents below 1) puts most agents close to
random choice, because Q is in [0, 1]. Two alternatives, following Ido Ben-Artzi's suggestion, all at N = 200,
4 chains x 2000 + 3000, same seed_params / seed_sim / seed_stan (each agent keeps the same underlying z-scores):

| Population | Model | alpha | beta | beta median | beta < 1 | beta < 0 |
|---|---|---|---|---|---|---|
| old | `classic_qval` | plogis(N(0, 0.85)) | exp(N(-0.25, 0.75)) | 0.73 | 66% | 0% |
| highbeta | `classic_qval` | plogis(N(0, 1.5)) | exp(N(1, 0.5)) | 2.61 | 2% | 0% |
| unbounded | `classic_qval_unbounded_beta` (identity link) | plogis(N(0, 1.5)) | N(3, 1.5) | 2.88 | 10.5% | 2% |

**Random walk changed too.** The old randomwalk runs used walk seed 2002 (arm 3 best for ~110 of 150 trials).
The highbeta and unbounded randomwalk runs use seed 3021, which the researcher picked as more balanced (five
best-arm switches). For randomwalk, old vs new therefore changes both population and walk. The population effect
alone, at N = 20 on walk 2002: alpha r 0.76 -> 0.91, slope 0.48 -> 0.83 (`sanity_n20` vs `sanity_n20_highbeta`).
p50 is unaffected (no walk).

## Convergence (n200)

| Environment | Population | Run | Divergences | Group max Rhat | Group min ESS_bulk | Fit (min) |
|---|---|---|---|---|---|---|
| p50 | old | n200 | 0 | 1.001 | 2646 | 148.5 |
| p50 | highbeta | n200_highbeta | 0 | 1.003 | 1928 | 74.6 |
| p50 | unbounded | n200 | 0 | 1.002 | 1498 | 75.8 |
| randomwalk | old | n200 (walk 2002) | 0 | 1.001 | 3227 | 135.9 |
| randomwalk | highbeta | n200_highbeta_walk3021 | 0 | 1.001 | 2810 | 65.7 |
| randomwalk | unbounded | n200_walk3021 | 0 | 1.002 | 1447 | 72.6 |

All pairs ran two at a time. Warmup-only "log odds is inf" messages stayed sporadic (3-5 per run).

## Subject-level recovery (n200)

| Environment | Population | alpha r | alpha slope | alpha bias | alpha 90% cov. | beta r | beta slope | beta bias | beta 90% cov. | alpha-beta error r |
|---|---|---|---|---|---|---|---|---|---|---|
| p50 | old | 0.49 | 0.24 | 0.042 | 0.88 | 0.95 | 0.93 | -0.11 | 0.93 | -0.38 |
| p50 | highbeta | 0.93 | 0.90 | 0.000 | 0.90 | 0.91 | 0.77 | -0.13 | 0.92 | -0.48 |
| p50 | unbounded | 0.88 | 0.85 | -0.012 | 0.90 | 0.86 | 0.78 | -0.03 | 0.91 | -0.55 |
| randomwalk | old | 0.58 | 0.33 | 0.012 | 0.91 | 0.95 | 1.28 | -0.00 | 0.91 | -0.13 |
| randomwalk | highbeta | 0.94 | 0.89 | -0.006 | 0.91 | 0.94 | 0.86 | -0.09 | 0.85 | -0.43 |
| randomwalk | unbounded | 0.90 | 0.87 | -0.014 | 0.89 | 0.90 | 0.77 | -0.06 | 0.86 | -0.57 |

## Population-level recovery (n200, natural scale)

| Environment | Population | true alpha_pop | alpha_pop median [90% CI] | true beta_pop | beta_pop median [90% CI] |
|---|---|---|---|---|---|
| p50 | old | 0.50 | 0.54 [0.49, 0.59] | 0.78 | 0.69 [0.59, 0.80] |
| p50 | highbeta | 0.50 | 0.51 [0.46, 0.56] | 2.72 | 2.70 [2.50, 2.91] |
| p50 | unbounded | 0.50 | 0.50 [0.45, 0.55] | 3.00 | 3.06 [2.85, 3.28] |
| randomwalk | old | 0.50 | 0.51 [0.47, 0.56] | 0.78 | 0.74 [0.66, 0.83] |
| randomwalk | highbeta | 0.50 | 0.50 [0.45, 0.54] | 2.72 | 2.73 [2.55, 2.91] |
| randomwalk | unbounded | 0.50 | 0.49 [0.44, 0.54] | 3.00 | 3.01 [2.82, 3.20] |

## Alpha error vs true beta (n200; alpha r / mean alpha error per beta bin, n in brackets)

| beta | p50 old | p50 highbeta | p50 unbounded | randomwalk old | randomwalk highbeta | randomwalk unbounded |
|---|---|---|---|---|---|---|
| < 0 | | | (4) 0.56 / -0.14 | | | (4) 0.98 / -0.01 |
| 0-0.5 | (55) 0.18 / 0.01 | | (7) -0.56 / -0.16 | (55) 0.32 / 0.00 | | (7) 0.32 / -0.16 |
| 0.5-1 | (78) 0.44 / 0.05 | (4) 0.96 / -0.16 | (10) 0.68 / -0.21 | (78) 0.60 / 0.01 | (4) 0.17 / -0.12 | (10) 0.44 / -0.23 |
| 1-2 | (42) 0.72 / 0.07 | (50) 0.94 / -0.06 | (29) 0.93 / -0.03 | (42) 0.68 / 0.04 | (50) 0.91 / -0.04 | (29) 0.95 / -0.04 |
| 2-4 | (20) 0.71 / 0.07 | (102) 0.93 / 0.02 | (101) 0.92 / 0.00 | (20) 0.78 / 0.04 | (102) 0.95 / 0.00 | (101) 0.95 / 0.01 |
| >= 4 | (5) 0.98 / -0.02 | (44) 0.96 / 0.04 | (49) 0.97 / 0.04 | (5) 0.97 / -0.05 | (44) 0.96 / 0.02 | (49) 0.96 / 0.03 |

Bins with fewer than ~10 agents are noisy. Figure: `output/<run>/06_alpha_error_vs_beta.png` in each folder.

## What the numbers show

* **Beta is what limited alpha.** With the old population, subject-level alpha r was 0.49-0.58 and slope 0.24-0.33;
  with either new population it is 0.88-0.94 and 0.85-0.90, in both environments. The SD ratio of alpha medians
  rises from 0.48-0.57 to 0.95-0.97, so the shrinkage toward the mean that flattened the old slopes is mostly gone.
* **The pattern within a run is the same everywhere.** Alpha recovery depends on the agent's beta: below beta ~1
  r is low and alpha is underestimated by ~0.15-0.2 in the new runs. Above beta ~1-2, r is >= 0.91 in every bin. The new
  populations simply move almost all agents into the good region.
* **p = 0.5 vs random walk.** With the old population the random walk recovered alpha clearly better (r 0.58 vs
  0.49). With the new populations the two environments are close (0.93 vs 0.94 highbeta, 0.88 vs 0.90 unbounded).
  So the p = 0.5 design is not by itself the obstacle once beta is in a realistic range.
* **Unbounded vs highbeta.** Convergence is equally clean (0 divergences, Rhat <= 1.002), and the identity link
  recovers the population beta well (3.06 and 3.01 vs true 3.00). Subject-level alpha r is a bit lower (0.88-0.90 vs
  0.93-0.94). That difference comes from the population, not the link: N(3, 1.5) has 10.5% of agents below beta = 1
  vs 2% for highbeta, and within beta >= 1 the two are the same. The alpha-beta error correlation is more negative
  under unbounded (-0.55 / -0.57 vs -0.43 / -0.48).
* **beta** is slightly compressed in all new runs (slope 0.77-0.86, mean bias -0.03 to -0.13), and 90% coverage of
  subject beta is 0.85-0.86 in the randomwalk runs (0.91-0.92 in p50).
* The 90% intervals cover the true population values in all six n200 runs.
