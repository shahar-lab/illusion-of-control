# Clarify

Each Job Card already contains the user's known values under `SPECIFICATION` and the questions required by its `CHECKS`. Malka compares them, asks about every gap, and records the answers.

## 1. Find the gaps

- Compare the user's prompt and `SPECIFICATION` with every `CHECKS` bullet.
- Treat an unanswered, unclear, or conflicting value as a gap; `—` means none.

## 2. Ask the researcher

- Turn each gap into a concrete question in analysis terms.
- Use `AskUserQuestion`: one question with labeled options, then wait. Use checklist lines when the dialog is unavailable.
- Offer a defensible default when one exists and explain briefly what the answer changes.
- Write each answer into `SPECIFICATION`, then repeat until every `CHECKS` bullet is answered.

If an answer adds another kind of deliverable, reopen `02-knowledge-index.md`. Copy its non-em-dash Path to `ROUTED READS` and its actual `CHECKS` bullets to `CHECKS`, then clarify those new checks.

## 3. Confirm

When all Job Cards have complete specifications, continue to Confirm.
