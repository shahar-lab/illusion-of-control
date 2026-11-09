# Parameter Recovery: classic_qval_and_perseveration (p = 0.5)

## Goal
The PI's request (2026-11-02): before adding a perseveration learning rate, start with one perseveration parameter,
check by hand what its values do in the softmax, look at simulated agents in the dataframe, then test whether the
hierarchical model recovers it.

## Model
`models/classic_qval_and_perseveration/` (3 free parameters per subject):
- `alpha` : RL learning rate, `inv_logit` (bounded [0, 1])
- `beta`  : inverse temperature for Q-values, `exp` (> 0)
- `kappa` : added to the logit of the previous trial's choice, identity (unbounded; > 0 repeat, < 0 switch)

`logits = beta * Q_cards; logits[prev_card] += kappa`. No bonus on a subject's first trial. Only the chosen arm's Q
updates (`Q += alpha * (reward - Q)`), as in `classic_qval`. kappa is `qval_and_decay_eval`'s perseveration with a
one-trial memory (beta_per with alpha_per fixed at 1).

Stan priors as in the sibling models: mu ~ N(0, 3), sigma ~ half-N(0, 3), raw ~ N(0, 1).

## Softmax by hand
`simulations/classic_qval_and_perseveration/simulate.R` (run from the repo root) writes:
- `data/softmax_table.csv`: p(repeat) for beta {1, e, 5} x Q difference {-0.2, 0, 0.2} x kappa {-1 ... 1}.
- `data/two_agents.csv`: two agents (alpha 0.5, beta e, kappa +0.5 / -0.5) trial by trial, with Q1-Q3 and p1-p3.
- `data/stay_by_agent.csv` and `figs/stay_rate_by_kappa.png`: 200 agents from the recovery population.
  Stay rate rises with kappa (cor 0.62; mean stay 0.32 in the lowest kappa bin, 0.62 in the highest).
`data/` is gitignored; rerun the script to regenerate it.

## Simulation setup
- 3 arms, 150 trials, p(win) = 0.5 for every arm on every trial.
- Population: alpha = plogis(N(0, 1.5)), beta = exp(N(1, 0.5)) (the classic_qval highbeta population), kappa = N(0, 0.5)
  (the PI's choice).
- Seeds 1001 / 2002 / 3003 / 4004, the same as classic_qval, so alpha and beta equal classic_qval's agents.

## Pipeline (via main.R)
`main.R` holds all run settings and the `population_params` / `error_pairs` tables, then sources `code/01_*.R` ...
`code/09_*.R`. Each run writes to `artifacts/<run_name>/` and `output/<run_name>/`. `fit.rds` is gitignored (109 MB
at n200). The same generic scripts are used by `qval_and_decay_eval_param_recovery` and
`classic_qval_and_eval_param_recovery`.

## Results

### sanity_n20 (20 subjects, 4 x 500 + 500)
0 divergences, group Rhat <= 1.008, group ESS_bulk >= 374 (one parameter below 400, expected at 500 draws).
r: alpha 0.95, beta 0.85, kappa 0.93 (kappa slope 0.64). kappa_pop -0.21, true 0, not covered (the 20 drawn kappas
have mean -0.13).

### n200 (200 subjects, 4 x 2000 + 3000)
Runtime 556 min (run in parallel with two other n200 fits on 14 cores). 0 divergences, 0 treedepth hits, group Rhat
<= 1.002, group ESS_bulk >= 2343.

| param | r | slope | bias | 90% coverage | SD ratio |
|---|---|---|---|---|---|
| alpha | 0.94 | 0.87 | -0.01 | 0.93 | 0.93 |
| beta  | 0.91 | 0.77 | -0.13 | 0.93 | 0.85 |
| kappa | 0.91 | 0.79 | -0.01 | 0.90 | 0.87 |

Population: alpha_pop 0.50 (true 0.50), beta_pop 2.69 (true 2.72), kappa_pop -0.06 (true 0); all inside the 90%
intervals. Trade-offs (error cor / mean posterior cor): alpha-beta -0.44 / -0.53, alpha-kappa -0.01 / -0.02,
beta-kappa -0.13 / -0.21.

Adding kappa does not hurt alpha or beta (classic_qval p50 n200_highbeta: alpha r 0.93). kappa at SD 0.5 recovers well,
with some shrinkage toward the mean (slope 0.79).

## Comparison with the pilot (2026-11-02, scratchpad scripts, not in repo)
Per-person stay rates in the pilot (35 participants, ~150 trials, mean reward 0.5) are wider than this population
produces: 10% / 50% / 90% quantiles 0.18 / 0.37 / 0.60 in the pilot vs 0.29 / 0.44 / 0.67 with kappa N(0, 0.5).
kappa SD around 1 matches the pilot spread better, and the lower pilot median hints at a negative mean kappa.
Win-stay minus lose-stay in the pilot (median 0.27) matches beta ~ e (0.26) rather than beta ~ 1 (0.10), but 17% of
participants show no reward effect. Candidate next runs: kappa SD 1.0, and a fit of this model to the pilot.
