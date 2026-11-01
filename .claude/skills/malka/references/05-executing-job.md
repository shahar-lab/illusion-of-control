# Executing a Job

Malka and the Code Writer use this file to execute one approved Job Card consistently.

## Read

- Read the Job Card, every file under `coding-knowledge/00-constitution/`, and `coding-knowledge/01-coding-rules/coding-rules-R.md`.
- Resolve every `ROUTED READS` path under `${CLAUDE_PLUGIN_ROOT}/coding-knowledge/` and read it.
- Read the covering folder's `context.md` and `rules.md` when present, its templates, and any project files needed to understand the existing work.

## Prepare

- Write only inside the Job Card's `FOLDER`.
- Create or verify the standard job-folder structure.
- Start preprocessing `main.R` from `template-main.md`; for a parameter-recovery job under `simulation/`, write `main.R` from the example in `parameter_recovery/context.md`; use the covering folder's `template_main.R` for other analysis and simulation jobs; use the generating `.R` and fitting `.stan` templates for models.

## Write and check

- Implement the complete `SPECIFICATION` using the routed guidance.
- Check every changed file against the Job Card and everything read.
- Where `main.R` applies, ensure it sources scripts in order and uses the standard path and setup blocks.

## Write `summary.md`

- Start preprocessing from `template-summary.md`; start a parameter-recovery job from `parameter_recovery/template_summary.md`; start other analysis and simulation jobs from that covering folder's `template_summary.md`.
- Record the approved model, hypotheses, variables, filters, and settings that apply.
- Keep the findings placeholder until the user runs the code.
- A `models/` job ends with its model files.

## Handle gaps

- Return `BLOCKED` with a question in analysis terms when a reserved research value is missing.
- For another missing detail, use a defensible default and mark it in the file with `ASSUMED[...]`.
- Report any guidance opened beyond `ROUTED READS` as `ADDED READS[...]`.

## Finish

- When Malka executes directly, continue to Handback.
- When a Code Writer executes, return the changed paths and every `ASSUMED` or `ADDED READS` tag, or return `BLOCKED` and the question.
