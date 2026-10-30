# classic_qval recovery: p = 0.5 vs random walk, n35 vs n200

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
