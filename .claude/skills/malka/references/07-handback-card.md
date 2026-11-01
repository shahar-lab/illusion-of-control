# Handback

Malka checks each completed job against its Job Card, then gives the user one Handback Card per job.

## 1. Check the job

- Read the Job Card and every file created or changed in `FOLDER`.
- Verify that the files implement `SPECIFICATION`, follow `ROUTED READS`, and stay inside `FOLDER`.
- For preprocessing, analysis, and simulation, verify that `main.R` sources scripts in order and `summary.md` records the approved specification.
- For models, verify the generating `.R` and fitting `.stan` pair.
- Correct any mismatch supported by the Job Card. Tag a missing user decision as `BLOCKED`.

## 2. Handback Card

Use this Structure Legend for each job.

```text
Handback Card
JOB
<JOB>
STATUS
<READY | BLOCKED>
FILES
- <path> — <purpose>
RUN
<entry point>
CHECK
- <output — what to inspect>
TAGS
- <tag | None>
```

- **Handback Card**

  Use this title as the first line.

- **`JOB`**

  Copy `JOB` from the Job Card.

- **`STATUS`**

  Write `READY` when the files match the Job Card. Write `BLOCKED` when a user decision is required.

- **`FILES`**

  Name every created or changed file and its purpose.

- **`RUN`**

  Name the entry point, usually `main.R`, and state that the code was written but not run.

- **`CHECK`**

  Name each output and what the user should inspect: validation and exclusions for preprocessing, convergence diagnostics for Bayesian models, and convergence, correlation, bias, and precision for recovery studies.

- **`TAGS`**

  Include every applicable tag. Write `None` when none apply.

## 3. Tags

- `BLOCKED[<missing decision>]: <question in analysis terms>`
- `ASSUMED[<unspecified detail>]: <default and file>`
- `ADDED READS[<path>]: <reason>`

## 4. Close

Offer a code walkthrough and invite the user to bring back errors, diagnostics, or results.
