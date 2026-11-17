# Illusion of control: computational modeling

Hierarchical Bayesian RL models (R + Stan via cmdstanr) for the 3-arm illusion-of-control task, parameter recoveries
for them, and fits to pilot data. Layout and conventions: `CLAUDE.md`. Each recovery folder's `summary.md` has the
full design, convergence and tables; this section is the overview.

## Status (2026-11-17): winning model

**`qval_and_decay_eval`, beta_per = N(0, 2)** (`parameter_recoveries/qval_and_decay_eval_param_recovery/`, run
`n200_betaper_sd2`). Q-learning (alpha_rl, beta_rl) plus a perseveration trace E in which every arm decays by
(1 - alpha_per) each trial and the chosen arm gains alpha_per; beta_per weights E in the softmax (> 0 stick, < 0 switch).

| param | r | slope | 90% coverage |
|---|---|---|---|
| alpha_rl  | 0.88 | 0.84 | 0.91 |
| beta_rl   | 0.81 | 0.63 | 0.90 |
| alpha_per | 0.66 | 0.50 | 0.90 |
| beta_per  | 0.96 | 0.91 | 0.95 |

200 subjects, 150 trials, p(win) = 0.5 on all arms, 4 chains x 2000 + 3000, 0 divergences, group Rhat <= 1.006, all
population values inside their 90% intervals. alpha_per is recoverable when perseveration actually moves choices
(push = abs(beta_per * alpha_per) of 0.5-2: r 0.65-0.72) and undefined near 0 (push <= 0.25: r 0.19), which is
expected rather than a model failure.

## What was done (Nov 2026)

### 1. classic_qval: the beta population
The old population (beta = exp(N(-0.25, 0.75)), 66% of agents below 1) left most agents near random choice, so alpha
could not be recovered (r about 0.5). The highbeta population, alpha = plogis(N(0, 1.5)) and beta = exp(N(1, 0.5)),
gives alpha r 0.93 at p = 0.5. All later models use it for the RL part. Details: `parameter_recoveries/classic_qval_comparison.md`.

### 2. Perseveration with one parameter (the PI's kappa model)
`classic_qval_and_perseveration`: kappa added to the logit of the previous choice, kappa = N(0, 0.5).
n200: alpha 0.94, beta 0.91, kappa 0.91. Adding kappa does not hurt alpha or beta. Softmax-by-hand tables and
simulated agents are in `simulations/classic_qval_and_perseveration/`.

### 3. Perseveration with a learning rate: four models, same agents
All four were rerun with the numbered pipeline (`main.R` + `code/01..09`), seeds 1001 / 2002 / 3003 / 4004 (same
agents across models), alpha_per = plogis(N(0, 1.5)) and beta_per widened step by step: N(0, 1.5) -> N(0, 3) -> N(0, 2).
The extra logit on the previous choice is about beta_per * alpha_per, so alpha_per needs a large enough beta_per
to be identifiable; N(0, 2) keeps abs(beta_per) mostly within 4 with a smaller cost to beta_rl than N(0, 3).

r at n200_betaper_sd2:

| model | E for unchosen arms | alpha_rl | beta_rl | alpha_per | beta_per |
|---|---|---|---|---|---|
| **qval_and_decay_eval** | decays | 0.88 | 0.81 | **0.66** | **0.96** |
| classic_qval_and_eval   | frozen | 0.91 | 0.90 | 0.31 | 0.78 |
| decay_eval_only (no RL) | decays | - | - | 0.70 | 0.97 |
| eval_only (no RL)       | frozen | - | - | 0.39 | 0.82 |

The decaying trace is what makes alpha_per recoverable: on identical agents the frozen-trace models stay at
alpha_per r 0.3-0.4 in every push bin, because once every arm has been chosen E saturates near 1 and carries little
information. `decay_eval_only` and `eval_only` were refactored from the old unnumbered scripts; their earlier runs
are kept in `artifacts/legacy_n100/` and `output/legacy_n100/`.

### 4. Other notes
- (beta_per, alpha_per) and (-beta_per, 1 - alpha_per) are not equivalent: the sign of beta_per is the direction
  (stick or switch), alpha_per is the memory length.
- Pilot check: win-stay minus lose-stay has a median of 0.27, consistent with beta_rl around e; 17% of participants
  show no reward effect, and pilot stay rates are lower and more spread out than kappa N(0, 0.5) produces.
- A Shiny model explorer (simulated trials, WSLS regression) is on branch `feature/model-explorer`, not on main.
- `fit.rds` files are gitignored and stay local.

## Next steps
- Fit `qval_and_decay_eval` to the pilot data.
- Optionally a classic_qval_and_perseveration run with kappa SD 1, which matches the pilot spread better.

---

# Legacy template (`stan_modeling/`, `functions/`)


This repository provides a **template** for running computational modeling using Stan in R, focused on **alpha-beta models** with or without spline components.

---

## Features

✅ Fits **alpha-beta reinforcement learning models** using Stan  
✅ Supports optional **spline-based extensions** to capture trial-wise nonlinear effects  
✅ Uses the `cmdstanr` backend for efficient sampling  
✅ Includes built-in **parameter recovery routines** to test model identifiability

---

## Folder Structure

data/ # (Ignored) Empirical or simulated data files
stan_modeling/ # R scripts for fitting and recovery
functions/ # Helper R functions
analysis/ # Analysis scripts


---

## Requirements

- R ≥ 4.1  
- R packages:
  - `cmdstanr`
  - `rstan`
  - `tidyverse`
  - `posterior`
  - `bayesplot`

- Stan installed and configured with `cmdstanr`

---

## How to Use

1️⃣ **Prepare your data**  
Place your dataset (or generate synthetic data) in the `/data/` folder.

2️⃣ **Select your model**  
Choose:
- `/stanmodel_alpha_beta/` → basic alpha-beta model  
- `/stanmodel_alpha_beta_splines/` → spline-augmented model

3️⃣ **Fit the model**  
Run the main R script