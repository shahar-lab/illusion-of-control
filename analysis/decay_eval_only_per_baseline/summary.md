# Analysis Notebook: decay_eval_only, hierarchical (ioc-per-baseline)

**Model:** `models/decay_eval_only/` — choice ~ categorical_logit(beta_per * E); after each choice
E = (1 - alpha_per) * E, then E[chosen] += alpha_per. Subject parameters drawn from population
distributions: alpha_per = inv_logit(mu + sigma * raw), beta_per = mu + sigma * raw.
**Date Created:** 2026-11-13

## 1. Hypotheses
* Estimate each participant's choice perseveration (beta_per) and trace learning rate (alpha_per) in the
  no-reward baseline, with partial pooling across participants.
* With 4 participants the population SDs rest mostly on their priors, so this fit is the comparison;
  the primary per-participant analysis is `../decay_eval_only_per_baseline_nopool/`.

## 2. Variables
* **Outcome:** `choice` (1 = left / green, 2 = up / blue, 3 = right / red), every trial.
* **Parameters:** subject `alpha_per`, `beta_per`; population `alpha_per_pop`, `beta_per_pop`.
* **Data:** `data/collected/ioc-per-baseline/` (4 Prolific participants, 2026-11-10); 599 valid
  main-task trials (training and 1 timeout dropped). `reward` is null; the model ignores it.
* **Priors:** the model's own: mu ~ N(0, 3), sigma ~ half-N(0, 3), raw ~ N(0, 1).
* **Sampling:** 4 chains, 2000 warmup + 3000 sampling, seed 4004 (as the n200_betaper_sd2 recoveries).

ASSUMED[data route]: read from `data/collected/` inside `01_prep_data.R`; there is no `preprocessing/`
job in this repo yet (approved by the researcher).

## 3. Findings / Summary
Convergence: 0 divergences, 0 treedepth hits, E-BFMI >= 0.88, Rhat <= 1.002, population ESS_bulk >= 4467
(`output/03_diagnostic.pdf`).

| participant | p(stay) | alpha_per median [90% CI] | beta_per median [90% CI] | push median |
|---|---|---|---|---|
| P1 | 0.82 | 0.99 [0.87, 1.00] | 2.37 [2.00, 2.75] | 2.29 |
| P2 | 0.00 | 0.40 [0.31, 0.50] | -17.51 [-23.13, -13.19] | 6.93 |
| P3 | 0.63 | 0.89 [0.58, 1.00] | 1.43 [1.10, 1.86] | 1.22 |
| P4 | 0.20 | 0.03 [0.01, 0.05] | 4.28 [2.92, 7.85] | 0.10 |

* Same picture as the no-pooling fit; see its `summary.md` for the per-participant reading.
* Population posteriors (`output/05_population_posteriors.*`) are wide, as expected from 4 participants
  with one strong alternator among three perseverators; they should not be read as a population estimate.
