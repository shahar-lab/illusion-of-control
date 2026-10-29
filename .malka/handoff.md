# Handoff: classic_qval recoveries (random walk vs p = 0.5)

Branch: `feature/add-classic-qval-recoveries`. Steps 1–3 done. Step 4 (full runs) is meant to run in a
Claude Code **cloud** session, started by the researcher from their phone; Step 5 can follow there or locally.

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
- Plan mode: show the plan for each step and wait for approval. On the phone keep plans short.

## Done
1. `models/classic_qval/classic_qval.stan` + `.R` (commit 2171da7). Old `ab_3arm.stan` (f04f728) was not reused
   as code: it saved per-trial log_lik (OOM pitfall) and had beta on identity scale.
2. Both recovery folders with main.R, code/01–09, summary.md (commit b02b102). They differ only in
   01_generate_data.R's schedule block and main.R's environment lines.
3. Sanity run `sanity_n20` (20 subjects, 4 x 500+500), both folders, main.R end to end on Windows; outputs committed.
   - 03's `dot_panel` rewritten to bin and stack dots itself: ggdist 3.3.3's `ggplot_build()` of `geom_dots` has no
     `bin` column (y = 0). 03 no longer depends on ggdist; 07 still uses `stat_slab`.
   - 05 needs the `gridExtra` package (bayesplot pairs plot). Not loaded in main.R; it only has to be installed.
   - 0 divergences, 0 treedepth hits, no "log odds is inf" warnings. Group min ESS_bulk 257 (p50) / 377 (randomwalk),
     expected at 500 draws/chain. Reruns reproduced every number exactly.
   - Sanity numbers (not conclusions): alpha r = 0.76 / slope 0.48 (randomwalk) vs r = 0.62 / slope 0.18 (p50);
     beta r >= 0.95 in both.

## Step 4 in the cloud: full runs
Goal: n35 and n200, 4 chains, 2000 + 2000, both folders; report divergences, Rhat, ESS, then Step 5.

1. **Environment.** Check `Rscript -e 'library(cmdstanr); cmdstan_version()'`. If R/CmdStan are missing, follow
   `.claude/skills/shaharlab-parameter-recovery/references/ENVIRONMENT_BOOTSTRAP.md` (apt + git-clone path).
   Packages: here dplyr readr tibble tidyr cmdstanr posterior ggplot2 patchwork bayesplot ggdist officer flextable
   **gridExtra**. Use released versions (CRAN/apt or a release tag), not dev builds: an earlier cloud attempt broke on
   dev stanc and dev cmdstanr vs an old data.table, and stan-dev r-universe serves a dev bayesplot (x.y.z.9000).
   officer/flextable (09) have never been installed in the cloud; if apt lacks them, install from CRAN or git tags.
2. **Smoke test first** (a few minutes): run p50 at sanity_n20 as committed, then `git diff --stat` on
   `parameter_recoveries/classic_qval_p50_param_recovery/{artifacts,output}/sanity_n20`. Simulated data
   (`individual_params.csv`, `df.rds`) should be identical. Stan draws may differ slightly across platforms/compilers.
   Then `git checkout -- <those folders>` to keep the committed Windows outputs. This proves 01–09 work in the container.
3. **Settings.** In each folder's `main.R` edit only the run block:
   `run_name <- "n35"; Nsubjects <- 35; iter_warmup <- 2000; iter_sampling <- 2000` (then `"n200"`, `200`).
4. **Order:** p50 n35, randomwalk n35, p50 n200, randomwalk n200. Run each from the repo root as
   `nohup Rscript parameter_recoveries/<folder>/main.R > /tmp/<folder>_<run>.log 2>&1 &` and wait for completion
   notifications rather than polling.
5. **Commit and push after every finished run.** A cloud session can end or time out, and each run writes only to its
   own `<run_name>` folders, so finished runs are safe once pushed. `fit.rds` is gitignored; also check its size.
6. **Runtime is unknown.** Laptop sanity timings were noisy (same seeded fit: 17.7 then 5.4 min; 2 then 35.8 min).
   Each run records `artifacts/<run_name>/runtime_min.rds`; report it.
7. **Convergence targets** (RUN_CONVENTIONS.md): 0 divergences, group Rhat <= 1.01, group ESS_bulk >= 400. If missed,
   diagnose before rerunning. If "log odds is inf" stops being sporadic, a tighter init (e.g. `init = 0.5`) is the
   candidate fix — ask the researcher first.

## Step 5
Append results per run to each `summary.md` (section 4); write `parameter_recoveries/classic_qval_comparison.md`:
is alpha recoverable with p = 0.5 vs random walk, and N=35 vs N=200 (sample size vs structural).

## Open items (not done, ask before acting)
- Plot `.rds` files in `artifacts/<run>/` (03/06/07 `_plot.rds`, read by 09) are 5–7 MB each, about 40 MB per run,
  because ggplot objects serialize their environments. Fine under GitHub's limit but adds up; candidates are
  gitignoring them or slimming what 09 needs.
- Cosmetic: 07 has no legend for true (blue dotted) vs median (grey dashed); 06 ticks fall at odd values;
  docx tables show raw column names; docx/PDF figure order is 03, 07, 06.
- `.claude/context/*.md` referenced by CLAUDE.md do not exist in this repo; malka's constitution and R rules were used.

## Local Windows environment (only relevant when working on the researcher's laptop)
- R 4.6.1 at `C:\Program Files\R\R-4.6.1` (not on PATH; call `Rscript.exe` by full path). Rtools 4.5 at `C:\rtools45`.
- Packages in `C:\Users\alonk\R\win-library\4.6` via user env var `R_LIBS_USER` (the Claude desktop app redirects
  AppData writes into its sandbox, so the default `%LOCALAPPDATA%\R` library is invisible to RStudio).
- cmdstanr 0.9.0, CmdStan 2.40.0 in `C:\Users\alonk\.cmdstan\cmdstan-2.40.0`. Spaces in the repo path are fine.
- Smart App Control is off and Defender has a folder exclusion for `models/` — both were needed for the compiled
  model `.exe` to run (SAC blocked it; Defender flagged it as `Trojan:Win32/Bearfoos.A!ml`, a false positive).
