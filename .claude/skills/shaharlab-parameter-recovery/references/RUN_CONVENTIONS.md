# Run Conventions

## Scale: sanity run first, full run second

Every model built in this lab hit at least one bug (a Stan compile error, a data-corruption
bug, or an OOM crash) that would have been caught in seconds at small scale but cost
30+ minutes to hours to discover at full scale. **Always run a small sanity pass before
committing to a full-scale run**, especially for a brand-new model:

- **Sanity run**: 10-50 subjects, `iter_warmup = iter_sampling = 100-500`. Takes seconds
  to a few minutes. Goal is just "does this compile, run, and produce sane-looking
  output" — not to draw any conclusions from the recovery numbers themselves.
- **Full run**: 100-200 subjects, 200 trials, `iter_warmup = 2000, iter_sampling = 3000`,
  4 chains. This is the convention that emerged across every model in this lab; match it
  unless the user asks for something else, so results are comparable across models.
  Expect **30 minutes to 2.5+ hours** depending on `Nsubjects`/`Narms`/model complexity —
  run in the background and check back rather than blocking.

Rough scaling intuition from real runs: doubling `Nsubjects` (holding trials/arms/iterations
fixed) roughly doubles wall-clock time. More `Narms` also slows sampling per iteration
(bigger softmax/categorical_logit_lpmf every trial) even at fixed `Ndata`.

## Convergence targets

After every run, `diagnostics.R` prints these — check them before treating a run's
recovery numbers as meaningful:

- **0 divergent transitions.** Any nonzero count means the posterior geometry is being
  explored badly somewhere; don't just accept a few divergences as noise. If they cluster
  in one chain, that's worth noting even if the total looks small.
- **Rhat ≤ 1.01** on all group-level parameters (`mu_*`, `sigma_*`).
- **ESS_bulk ≥ 400** on all group-level parameters.

If a run fails these targets, don't reflexively rerun with more iterations — first check
whether it's actually an OOM/crash (see `STAN_PITFALLS.md`) or whether a specific
parameter's prior is too narrow/wide for the data to constrain it (this lab has seen
convergence improve substantially just from widening a too-tight generating `sigma`).

## `.gitignore` rules

Add these for every new model, before the first commit:

```gitignore
# cmdstanr compiled model binary (no file extension, same name as the .stan file)
models/<model_name>/<model_name>

# fit.rds — see threshold note below
analysis/<model_name>_param_recovery/artifacts/fit.rds
```

The compiled binary rule is needed for *every* model — `cmdstan_model()` compiles a
binary right next to the `.stan` file, and it's easy to `git add` it by accident the
first time.

`fit.rds` size scales with `Nsubjects x Ntrials x total posterior draws`. As a rough
threshold: if it's within shouting distance of 100MB (GitHub's push size limit), gitignore
it and note in `summary.md` that it "regenerates locally via `main.R`." Smaller ones
(observed range: ~1MB at a 20-subject sanity scale up to ~150MB at 200 subjects/5000
total draws) are fine to commit directly when comfortably under the limit — don't
gitignore reflexively, since a committed `fit.rds` is occasionally useful to have in git
history for later comparison. If in doubt, check the actual file size after the first
full run and decide then.

## Compiling before running

If you changed a `.stan` file, compile-check it directly before running the full
pipeline — this is much faster than discovering a compile error after `generate_data.R`
has already finished:

```bash
stanc --o=/tmp/test.hpp path/to/model.stan   # exit code 0 = compiles clean
rm -f /tmp/test.hpp
```

(`stanc` lives at `<cmdstan_path>/bin/stanc` — see `ENVIRONMENT_BOOTSTRAP.md` if you don't
know where that is.)
