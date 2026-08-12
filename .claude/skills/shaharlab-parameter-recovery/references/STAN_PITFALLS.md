# Stan/R Pitfalls in Parameter Recovery Models

Three bugs below were each hit for real while building models in this lab, and each one
was expensive to diagnose *after* a long run had already failed. All three are cheap to
avoid if you know to look for them before you hit "run." Check every new `.stan` file and
its companion `sim.block()` R file against this list before running anything.

## 1. Never persist a per-trial array for every posterior draw

**The bug:** declaring something like

```stan
transformed parameters {
  vector[Ndata] log_lik;   // <-- one value per trial, saved every draw
  ...
}
generated quantities {
  array[Ndata, Narms] real Q_trial;  // <-- one row per trial, saved every draw
  array[Ndata, Narms] real E_trial;
  ...
}
```

Anything declared in `transformed parameters` or `generated quantities` gets written to
the output CSV **for every single post-warmup draw, on every chain.** At a realistic
scale — say 100 subjects × 200 trials = 20,000 trials, 4 chains × 5,000 draws — a
per-trial array like this multiplies out to billions of stored values. This produced
3.3GB *per chain* (13GB total) in one real run and OOM-killed the R process outright
(confirmed via `dmesg`) partway through post-processing, after the expensive MCMC
sampling had already completed. Nothing downstream even read these values — they'd been
added for exploratory/diagnostic purposes and never removed.

**The fix:** compute the likelihood as a local, unsaved accumulator inside an anonymous
block in the `model` block, and don't declare per-trial arrays in `generated quantities`
at all unless something genuinely needs to read them later (nothing has, so far, across
five models built this way):

```stan
model {
  ... priors ...

  {
    vector[Narms] Q_cards;
    vector[Narms] E_cards;
    vector[Narms] logits;
    real total_log_lik = 0;   // local scalar, never written to output

    for (t in 1:Ndata) {
      ...
      logits = ...;
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);
      ...
    }

    target += total_log_lik;
  }
}
```

Only keep genuinely small things in `transformed parameters`/`generated quantities`:
`Nsubjects`-length vectors (e.g. `alpha_rl_sbj`), and scalar population-level quantities
(e.g. `alpha_rl_pop = inv_logit(mu_alpha_rl)`). Both are cheap even at 200 subjects.

**How to check:** grep the `.stan` file for `[Ndata` inside `transformed parameters` or
`generated quantities`. If you find one, ask whether anything actually reads it — if not,
delete it or move the computation into an unsaved local block as above.

## 2. Don't redeclare a name from `transformed parameters` inside `generated quantities`

**The bug:** if `transformed parameters` declares `Q_cards`/`E_cards` (or any other name),
and a later local block in `generated quantities` tries to declare a fresh local variable
with the *same name* to recompute something (e.g. per-trial trajectories for plotting),
Stan's compiler rejects it outright with a duplicate-identifier error — the name is
already in scope from `transformed parameters`, and Stan doesn't allow shadowing here.

**The fix:** if you genuinely need a local recomputation in `generated quantities`, give
it a distinct name (this lab's convention is a `_gq` suffix: `Q_cards_gq`, `E_cards_gq`).
But first ask whether you need the recomputation at all — per pitfall #1, saving
per-trial trajectories from `generated quantities` is usually the wrong move anyway, so
the right fix is often to delete the block entirely rather than rename it.

**How to check:** run `stanc --o=/tmp/test.hpp path/to/model.stan` before ever calling
`cmdstan_model()` on it from R. This project's `references/ENVIRONMENT_BOOTSTRAP.md`
covers getting a working `stanc` binary. A clean `stanc` compile catches this instantly;
finding it via `cmdstan_model()`'s longer compile path wastes more time.

## 3. Use `tibble()`, not `data.frame()`, for per-trial list-columns in `sim.block()`

**The bug:** every `sim.block()` function stores each trial's Q/E-value vectors (length
`Narms`) as one cell holding the whole vector, so downstream code can inspect the
trajectory later. The natural-looking way to do this is:

```r
dfnew = data.frame(
  ...,
  Q_cards = list(Q_cards),   # Q_cards is a numeric vector of length Narms
  ...
)
```

This looks like it should create a list-column (one cell containing the vector), but
base R's `data.frame()` does **not** treat `list(vector)` this way — it silently unpacks
the vector into that many *rows*, recycling every other column to match, and invents a
garbage column name deparsed from the vector's own values (something like
`c.0.5..0.5..0.5.`). Across a whole simulated dataset, this explodes a fixed number of
per-trial rows into a fixed number × `Narms`, with thousands of uniquely-named junk
columns (one dataset ballooned to 3.76GB and ~20,000 columns from what should have been a
few-MB, 15-column tibble).

**The fix:** use `tibble()` instead of `data.frame()` for any row that has a list-column
in it — `tibble()` treats `list(vector)` correctly as a single list-column cell:

```r
dfnew = tibble(
  ...,
  Q_cards = list(Q_cards),   # now a proper length-1 list-column cell
  ...
)
```

**How to check:** after `generate_data.R` runs, check the row count and column count of
`df.rds` are what you expect (`Nsubjects * Ntrials` rows, a small fixed number of
columns — see `PIPELINE_CONTRACTS.md` for the expected column list), and spot-check that
a list-column entry (e.g. `df$Q_cards[[5]]`) is a plain numeric vector of length `Narms`,
not something else. Don't just trust that `sim.block()` "looks right" — actually inspect
the output once, the first time you write a new `sim.block()`.
