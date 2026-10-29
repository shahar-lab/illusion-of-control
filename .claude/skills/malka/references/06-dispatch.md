# Dispatch Multiple Jobs

The approved Job Cards are stored in `.malka/current_job.md`. Dispatch one Code Writer per Job Card. Independent jobs can run together; a job that needs another job's output waits for that job.

## 1. Complete the Job Cards

Read `dispatch-job-card.md`. For each ready job, copy `JOB`, `FOLDER`, `ROUTED READS`, and `SPECIFICATION`; drop `CHECKS`; add `PROJECT STATE` and `RETURN`.

## 2. Deploy

- Dispatch independent Job Cards in parallel.
- Tell each Code Writer to follow `${CLAUDE_PLUGIN_ROOT}/skills/malka/references/05-executing-job.md`.
- Dispatch a dependent Job Card after the job producing its input returns clean.

## 3. Handle returns

- **clean** — carry the changed paths to Handback.
- **`ASSUMED`** — keep the deliverable and carry every tag to Handback.
- **`ADDED READS`** — keep the deliverable, carry every tag to Handback, and add those reads to affected later jobs.
- **`BLOCKED`** — resolve the cause below and redispatch only that job.

## 4. Resolve `BLOCKED`

- Missing reserved value → ask the user, update `SPECIFICATION`, and redispatch.
- Write needed outside `FOLDER` → split the work into separate Job Cards, then Clarify and Confirm.
- `FOLDER` contradicts the work → correct the Job Card's folder and redispatch.
- More than one fit in one job → split it into one Job Card per fit.
- Missing input from another job → wait for the producing job, then redispatch.
- Failed or empty return → redispatch once; after a second failure, report what is on disk.
