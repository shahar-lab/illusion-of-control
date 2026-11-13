# Analysis Notebook: decay_eval_only, no pooling (ioc-per-baseline)

**Model:** `models/decay_eval_only_nopool/` — choice ~ categorical_logit(beta_per * E); after each choice
E = (1 - alpha_per) * E, then E[chosen] += alpha_per. Each participant is estimated independently.
**Date Created:** 2026-11-13

## 1. Hypotheses
* Estimate each participant's choice perseveration (beta_per) and trace learning rate (alpha_per) in the
  no-reward baseline of the ioc-all machine game, where choices cannot be driven by outcomes.
* This is the primary per-participant analysis. With 4 participants a hierarchical model has almost no
  information about the population spread, so `../decay_eval_only_per_baseline/` (hierarchical) is kept
  as a comparison only.

## 2. Variables
* **Outcome:** `choice` (1 = left / green, 2 = up / blue, 3 = right / red), every trial.
* **Parameters:** `alpha_per` in [0, 1] (logit scale), `beta_per` unbounded (> 0 repeat recent choices,
  < 0 avoid them). Push = |beta_per * alpha_per|, the pull toward the last choice.
* **Data:** `data/collected/ioc-per-baseline/` (Pavlovia `Shahar_Lab/ioc-per-baseline`, 4 Prolific
  participants, 2026-11-10). `reward` is null in this task; the model ignores it.
* **Trials:** `gambling_choice`, non-training, valid choices only: 4 x 150 minus 1 timeout = 599. All
  three machines were available on every trial.
* **Priors:** logit(alpha_per) ~ N(0, 1.5), beta_per ~ N(0, 5).
* **Sampling:** 4 chains, 2000 warmup + 3000 sampling, seed 4004.

ASSUMED[data route]: read from `data/collected/` inside `01_prep_data.R`; there is no `preprocessing/`
job in this repo yet (approved by the researcher).
ASSUMED[priors]: logit(alpha_per) ~ N(0, 1.5) is the population the recoveries validated; beta_per ~ N(0, 5)
is wider than that population's N(0, 2) so a strong alternator is not forced toward 0 (chosen while
the researcher was away).
ASSUMED[model]: `decay_eval_only_nopool` is a new structural variant (no pooling) of `decay_eval_only`;
its `.R` simulator is the parent's, unchanged.

## 3. Findings / Summary
Convergence: 0 divergences, 0 treedepth hits, E-BFMI >= 0.99, Rhat 1.00 and ESS_bulk >= 9491 for all
8 parameters (`output/03_diagnostic.pdf`).

| participant | p(stay) | alpha_per median [90% CI] | beta_per median [90% CI] | push median |
|---|---|---|---|---|
| P1 | 0.82 | 0.92 [0.80, 0.98] | 2.40 [2.03, 2.79] | 2.18 |
| P2 | 0.00 | 0.43 [0.35, 0.52] | -15.68 [-19.65, -12.31] | 6.63 |
| P3 | 0.63 | 0.75 [0.53, 0.94] | 1.53 [1.18, 1.95] | 1.14 |
| P4 | 0.20 | 0.03 [0.02, 0.06] | 3.89 [2.72, 5.58] | 0.13 |

* P1 and P3 are perseverators: beta_per > 0 with a fast trace (alpha_per near 1, the last choice counts
  most). Their push (1.1-2.2) lies where the n200 recoveries recover alpha_per well (r 0.8-0.9).
* P2 never repeats and cycles through the machines (the unchosen-for-longest arm on 96.5% of trials).
  beta_per is strongly negative; its size sits in the prior's tail, so the sign is clear but the
  magnitude depends on the N(0, 5) prior.
* P4 avoids the left machine (6.7% of choices) and alternates between the other two (p(stay) 0.20, 2-back
  return 0.57). The model reads this as a long-run preference (alpha_per 0.03, beta_per > 0) and cannot
  also express the short-term alternation; push 0.13 is in the range where alpha_per was not recoverable.
* The hierarchical fit gives the same picture (largest change: P3 alpha_per 0.89 vs 0.75).
* Posterior plots follow the lab posterior standard: `output/05_subject_posteriors.{pdf,png}`.
