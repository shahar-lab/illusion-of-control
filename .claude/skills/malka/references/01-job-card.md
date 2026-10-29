# The Job Card

A Job Card holds everything needed to specify and execute one job in one job-folder. Malka creates it from the user's request; Malka or a Code Writer later executes it.

## 1. Structure Legend

Write one tight block per job.

```text
Job Card
JOB
<one-line deliverable>
FOLDER
<path> (new | existing | repair)
ROUTED READS
- <path from 02-knowledge-index.md>
CHECKS
- <check copied from 02-knowledge-index.md>
SPECIFICATION
- <approved value>
```

- **Job Card**

  Use this title as the first line.

- **`JOB`**

  State what the job produces in the user's words.

- **`FOLDER`**

  Name the only job-folder this job writes into and mark it `(new)`, `(existing)`, or `(repair)`.

- **`ROUTED READS`**

  Copy the Path from every matching entry in `02-knowledge-index.md`.

- **`CHECKS`**

  Copy the matching entry's `CHECKS` bullets exactly. Use `—` when every matching entry has `CHECKS: —`.

- **`SPECIFICATION`**

  Start with values already supplied by the user. Clarify adds the answers to `CHECKS`; Confirm approves the completed specification.

## 2. Build the card

1. Split the request by job-folder: one job-folder is one Job Card.
2. Walk every entry in `02-knowledge-index.md`. Match by **What it covers**.
3. Copy each matching non-em-dash **Path** to `ROUTED READS` and each matching **CHECKS** bullet to `CHECKS`.
4. Write all values already present in the request under `SPECIFICATION`, including any dependency on another job's output.

## 3. Example

```text
Job Card
JOB
Fit a stay-by-reward regression and plot posterior means
FOLDER
analysis/stay_reward/ (new)
ROUTED READS
- regression/01_sampling_and_priors.md
- regression/02_diagnostics.md
- visualization/plot-types/plot-posterior.md
- visualization/standards/EXPORT_STANDARD.md
CHECKS
- Formula and RE structure
- Family
- Priors (offer weakly informative)
- Sampling (offer 4 / 2000 / half warmup)
- Which parameters or effects
- Effect vs bounded vs other
- Single figure or composite
SPECIFICATION
- Formula: stay ~ reward + (1 | id)
- Data: data/processed/trials.csv
```
