# Describe a Statement

Use this reference during **Step D** — each time you present one statement in the walkthrough.

## Goal

Show the user one statement at a time so they can learn or verify it at their own pace.

## Mandatory Order

Every statement message must follow this **exact order**. Do not reorder or skip steps.

1. **Statement X out of M** — label only
2. **Code block** — print the exact statement in a fenced R code block (or clear code formatting)
3. **Brief explanation** — one or two sentences below the code block
4. **OK or drilldown?** — prompt on its own line

**The code block must come before the explanation.** Never describe what code does without first showing the code.

## Rules

1. **One statement per message** — Present only the current statement, not the whole excerpt.
2. **No section headings** — Do not write "Line-by-line Walkthrough", "Step-by-step", or similar.
3. **Exact code** — Copy the statement verbatim. Do not paraphrase code as prose (e.g., do not write "Lines 1–4 filter to…" instead of showing the code).
4. **One or two sentences** — Brief, plain language after the code block.
5. **Use names from the code** — Reference actual variables, columns, functions, and values.
6. **Wait** — Do not send the next statement until the user replies.
   - **"ok"** → next statement in a new message (Step D item 6 again)
   - **"drilldown"** → follow [drilldown.md](drilldown.md), then ask **"OK or drilldown?"** again on the same statement

## Template

```
Statement X out of M

```r
<exact statement>
```

<One or two sentences explaining what this statement does.>

OK or drilldown?
```

## Examples

**Statement 1 of 4**

```r
library(tidyverse)
```

Loads tidyverse (dplyr, ggplot2, readr, tidyr, purrr, tibble).

OK or drilldown?

---

**Statement 2 of 4**

```r
filter(
  adhd.visit.profession %in% relevant_professions,
  tre.occurrence.number == 1
)
```

Keeps rows where profession is in `relevant_professions` and episode number is 1.

OK or drilldown?

---

**Statement 3 of 4**

```r
df <- df |> filter(diagnosis == "ADHD")
```

Keeps only rows where the `diagnosis` column equals `"ADHD"`.

OK or drilldown?

## Anti-Pattern

**Wrong** — no code block, code paraphrased as prose:

```
Statement 1 of 5
Filter to rows where the profession is in relevant_professions and
it's the first episode (tre.occurrence.number == 1).
OK or drilldown?
```

**Correct** — code block first, then explanation:

```
Statement 1 of 5

```r
filter(
  adhd.visit.profession %in% relevant_professions,
  tre.occurrence.number == 1
)
```

Keeps rows in `relevant_professions` with first treatment episode only.

OK or drilldown?
```
