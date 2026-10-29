# Confirm

Confirm is the last interview beat. You write a plain-English **Summary Card**, show it, and wait. Nothing is built until the user says yes. This is the only approval in the system, so every value that will appear in the code appears here too. Not silent: present the card, then halt until yes.

Work through the steps below in order.

## 1. Structure of the Summary Card

Machinery stays off the Summary Card — file paths as slot names, `CHECKS`, `ROUTED READS`, and AI-to-AI brief language live on the Job Cards the user never sees. Folder names in backticks are fine: the user needs to know where the work lands.

```text
Summary Card

📋 Summary: [short name]

[plain-English body: every job, every value, any overwrite, any wait]

- [ ] Confirm & Execute
- [ ] Revise
```

- **`Summary Card`**

  The name. First line of every copy.

- **📋 Summary**

  A short title for this request.

- **Body**

  One paragraph per Job Card, or a short run of paragraphs when several jobs belong together. Include every folder, formula, cutoff, family, prior, sampling setting, plot type, and recovery criterion that will appear in the code. When a job rebuilds a `data/` stage that existing folders read, name those folders. When one job waits for another, say what it waits for.

- **`- [ ] Confirm & Execute` / `- [ ] Revise`**

  The same two-item checklist on every card, so the terminal UI picks it up. Present the card, then halt until yes. Treat an ambiguous reply as a no and ask again.

## 2. Examples

### Example 1: One analysis

```
Summary Card

📋 Summary: Bayesian Model

For `analysis/go_nogo_rt/`, we will run a Bayesian regression using formula
`rt ~ condition + (1|subject)`, with weakly informative priors — normal(0, 1) on the
effects, package defaults elsewhere — sampled over 4 chains of 2000 iterations, half
of them warmup. It produces the model fit, the convergence diagnostics, and a
posterior plot.

- [ ] Confirm & Execute
- [ ] Revise
```

### Example 2: Two jobs — clean, then fit

```
Summary Card

📋 Summary: Preprocessing and stay-by-reward

Two jobs. `preprocessing/` drops participants with fewer than 50 valid trials, then drops
trials where RT is under 200 ms or over 3000 ms, writes `data/processed/`, and reports
the exclusion counts. Then `analysis/stay_by_reward/` fits
`stay_ch ~ reward_oneback + (reward_oneback | subject)`, bernoulli, weakly informative
priors — normal(0, 1) on the effects — 4 chains of 2000 iterations, half warmup, and a
posterior plot of the fixed effects.

This rewrites `data/processed/`, so `analysis/go_nogo_rt/` will need rerunning against
the new file. `analysis/stay_by_reward/` waits until preprocessing is done.

- [ ] Confirm & Execute
- [ ] Revise
```

### Example 3: Visualization

```
Summary Card

📋 Summary: Plots

Inside `analysis/value_learning/`, we will generate a side-by-side scatter plot and
histogram panel following lab themes.

- [ ] Confirm & Execute
- [ ] Revise
```

## 3. When the user wants changes

**Revise** is a return into the interview, not a new request.

- Jobs, folders, or dependencies are wrong → rebuild the affected Job Cards, then Clarify and Confirm again.
- A leftover value is wrong or still missing → go back to Clarify. Update that Job Card's `SPECIFICATION`, then Confirm again.
- Wording on the Summary Card is the only issue → edit the card and present it again.

On **Confirm & Execute**, write the approved Job Cards to `.malka/current_job.md`. Then go to Step 2.
