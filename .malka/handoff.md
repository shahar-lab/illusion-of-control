# Handoff: classic_qval recoveries (random walk vs p = 0.5)

Branch: `feature/add-classic-qval-recoveries`. Steps 1–2 done; Steps 3–5 to run locally.

## Decisions made with the researcher
- Names use `classic_qval`, never `ab`. `analysis/param_estimation/fit_ab_3arm.R` is out of scope (to be rewritten separately).
- Repo layout `parameter_recoveries/` (not malka's `simulation/`), plus a Word report (officer/flextable) and a multi-page vector PDF.
- Scripts and outputs numbered `NN_` (malka convention), chosen by the researcher.
- Priors match sibling models: mu ~ N(0, 3), sigma ~ half-N(0, 3), raw ~ N(0, 1).
- Recovery criterion: report numbers only, no verdict thresholds.
- Seeds kept on purpose (researcher asked; lab default is no seeds unless asked — PI may remove).
  seed_params 1001, seed_env 2002, seed_sim 3003, seed_stan 4004, identical in both folders;
  200 true-parameter draws, first Nsubjects kept, so N=35 is nested in N=200.
- Runs live in subfolders: `artifacts/<run_name>/`, `output/<run_name>/` with run_name sanity_n20 | n35 | n200.
- Plan mode: show the plan for each step and wait for approval.

## Done
1. `models/classic_qval/classic_qval.stan` + `.R` (commit 2171da7). Old `ab_3arm.stan` (f04f728) was not reused
   as code: it saved per-trial log_lik (OOM pitfall) and had beta on identity scale. stanc compiles clean;
   sim.block returns 150 x 12 with length-3 Q_cards list-cells.
2. Both recovery folders with main.R, code/01–09, summary.md (commit b02b102). They differ only in
   01_generate_data.R's schedule block and main.R's environment lines.
   Smoke test (5 subjects, 100+100 iter, cloud) passed for 01, 02, 04, 05, 06, 08.
   NOT yet run: 03 (ggdist geom_dots), 07 (ggdist stat_slab), 09 (docx + PDF).

## Notes
- Cloud CmdStan issues (dev stanc, dev cmdstanr vs old data.table) were container-only; use released versions locally.
- Early warmup showed sporadic "categorical_logit_lpmf: log odds is inf" (exp(beta) overflow at extreme inits).
  Confirm it stays sporadic at scale; if not, consider tighter init (e.g. init = 0.5) — ask first.
- `.claude/context/*.md` referenced by CLAUDE.md do not exist in this repo; malka's constitution and R rules were used.

## Next
3. Sanity: sanity_n20, Nsubjects 20, 500+500, both folders; inspect all figures and the docx; fix bugs.
4. Full: n35 and n200, 4 chains, 2000+2000, both folders; divergences, Rhat, ESS.
5. Results into each summary.md (append per run); write `parameter_recoveries/classic_qval_comparison.md`:
   is alpha recoverable with p = 0.5 vs random walk, and N=35 vs N=200 (sample size vs structural).
   Check fit.rds sizes; gitignore already covers `artifacts/*/fit.rds`.
