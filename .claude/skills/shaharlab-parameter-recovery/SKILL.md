---
name: shaharlab-parameter-recovery
description: Write, scaffold, and run hierarchical Stan parameter-recovery pipelines (simulate synthetic subjects from a Stan model, refit it, and check whether the true parameters come back out) in this lab's analysis/<model>_param_recovery layout. Use this whenever the user asks to set up, build, write, or run a parameter recovery for a Stan/cmdstanr model, check whether a model's parameters are identifiable/recoverable, add a new computational model and validate it, or debug a Stan model that's failing to compile, producing huge/corrupted simulated data, or OOM-crashing during sampling — even if they just say "run the recovery" or name a model folder without spelling out "parameter recovery" explicitly.
---
# Skill: Stan Parameter Recovery Pipeline

**Mandate:** Write, scaffold, and run hierarchical Stan parameter-recovery analyses
correctly the first time. This skill exists because the same three bugs and the same
missing deliverable (`summary.md`) were hit repeatedly across several models built in
this lab before this skill existed — follow it to not repeat them.

## When to Invoke
Use this skill automatically when the user requests help with:
* Building a new parameter-recovery analysis for a Stan model (simulate → fit → check recovery)
* Writing `generate_data.R` / `fit_stan.R` / `diagnostics.R` / plotting scripts for a recovery pipeline
* Running or re-running an existing `*_param_recovery` analysis
* Debugging a Stan model that's OOM-crashing, failing to compile, or silently producing bloated data
* **Triggers:** "parameter recovery", "recover parameters", "check if X is recoverable", "run the recovery pipeline", "new model recovery analysis", "simulate and refit"

## Step 0: Is R/cmdstanr available?
Try running any existing `main.R` or `Rscript -e 'library(cmdstanr)'`. If R isn't
installed or cmdstanr can't find CmdStan, **stop and read** `references/ENVIRONMENT_BOOTSTRAP.md`
before doing anything else. Do not attempt to install cmdstanr/CmdStan by improvising —
the reference documents a specific working path for restricted-network containers.

## Step 1: New model, or running an existing one?

**New model** (no `models/<name>/` or `analysis/<name>_param_recovery/` yet):
1. Read `references/STAN_PITFALLS.md` **before writing a single line of Stan or R
   simulation code.** These are three real bugs (one silent data-corruption bug, one
   compile error, one OOM-crasher) that were each hit and fixed the hard way. Writing
   the model correctly the first time is much cheaper than debugging it at full scale.
2. Read `references/PIPELINE_CONTRACTS.md` for the exact per-script contract every
   analysis in this lab follows.
3. Copy the templates in `assets/` into the new `models/<name>/` and
   `analysis/<name>_param_recovery/` folders (see `references/PIPELINE_CONTRACTS.md`
   §"Scaffolding a new model" for exactly what to substitute).
4. Continue to Step 2.

**Existing model** (folders already exist, just need to (re)run it):
1. Skip to Step 2.

## Step 2: Before running

Read `references/RUN_CONVENTIONS.md` for:
* What scale to run at (sanity run vs. full run) and expected wall-clock time
* Convergence targets to check in `diagnostics.R`'s output
* `.gitignore` rules for `fit.rds` and the compiled model binary — every new model in
  this lab has forgotten these on the first commit

## Step 3: Run it

```r
Rscript analysis/<name>_param_recovery/main.R
```

Run in the background for anything at full scale (30 min–2+ hours depending on
`Nsubjects`/`Ntrials`/iterations). Watch the log for the divergence/Rhat/ESS summary
`diagnostics.R` prints, and for the Pearson-r table `summary_table.R` prints at the end.

## Step 4: After running

1. Check convergence against `references/RUN_CONVENTIONS.md`'s targets. If it fails them,
   don't just rerun — diagnose first (see `references/STAN_PITFALLS.md` if it's an OOM
   crash; otherwise check `Diagnostics.pdf`'s pairs plot for problem parameters).
2. **Write or update `summary.md`** in the analysis folder (Goal / Model / Simulation
   setup / Pipeline / Outputs / Results). This is a required deliverable, not optional —
   see `references/PIPELINE_CONTRACTS.md` §"summary.md contract". Every model built
   before this skill existed shipped without one and had to have it added after the fact.
3. Commit artifacts/output alongside the code (per this repo's `.gitignore` rules from
   Step 2), not just the code.

## Note on posterior plots

`.claude/context/shaharlab_project_rules.md` mandates that all posterior/credible-interval
plots go through the `/plot-posterior` skill, with no raw ggplot/ggdist code. Every
`plot_population_posteriors.R` built in this lab so far has used raw `ggdist::stat_slab`/
`stat_pointinterval` code directly instead (see `assets/template_plot_population_posteriors.R`),
because the multi-panel "posterior vs. true generating value" layout needed here is more
specific than a single posterior plot. Treat the template as the pattern actually in
production use across every model in this repo, but check whether `/plot-posterior` can
now express this layout before copying the raw-ggdist pattern into a new model — don't
perpetuate the deviation by default if the skill has since grown to cover it.

## Quick Reference

| Task | Read This |
|------|-----------|
| Writing a new Stan model / R simulation from scratch | `references/STAN_PITFALLS.md` (first!), then `references/PIPELINE_CONTRACTS.md` |
| What does each pipeline script need to do? | `references/PIPELINE_CONTRACTS.md` |
| R/cmdstanr not installed, or network-restricted container | `references/ENVIRONMENT_BOOTSTRAP.md` |
| What scale to run at, convergence targets, gitignore rules | `references/RUN_CONVENTIONS.md` |
| Starting-point code for a new model | `assets/` |

## Example Workflow: Add recovery for a brand-new model

1. User: "I added `models/foo/foo.stan` and `foo.R`, set up parameter recovery for it and run it."
2. Read `references/STAN_PITFALLS.md` — check the new `.stan` file doesn't declare a
   saved per-trial `log_lik`/`Q_trial`-style array, and doesn't redeclare a
   transformed-parameters variable name inside a `generated quantities` block.
3. Read `references/PIPELINE_CONTRACTS.md`, copy `assets/template_*.R` into
   `analysis/foo_param_recovery/code/`, substitute the model name and parameter list.
4. Read `references/RUN_CONVENTIONS.md`, add the `.gitignore` entries, run a small
   sanity pass first (e.g. 20 subjects, 500+500 iterations) to catch bugs cheaply.
5. Once the sanity run is clean, rerun at full scale per the same reference.
6. Check convergence, write `summary.md`, commit code + artifacts + output together.

Done.
