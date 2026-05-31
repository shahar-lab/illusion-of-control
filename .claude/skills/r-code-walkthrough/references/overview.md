
## Goal

Give the user a concise mental map of the entire selected excerpt so they know what to expect before going statement by statement.

## Rules

1. **No code** — Do not print, quote, or fence any code. Explanation only.
2. **No headings** 
3. **Length** — A few sentences (typically 2–3). Cover the full excerpt, not just the first lines.
4. **Be technical and specific** — Use precise terms, not vague phrases like "processes data" or "does some analysis."
5. **Include where relevant:**
   - **Packages** loaded or used (e.g., dplyr, ggplot2, brms)
   - **Input objects** and their format (e.g., tibble, matrix, file path)
   - **Output objects** and their format
   - **Data frame dimensions** when inferable (e.g., `df [20 × 50] → [1000 × 2]`)
   - **Transformations** by name (filter, pivot, group, summarise, fit model, plot)
   - **Variable and column names** from the code
6. **Input → output flow** — Describe what goes in and what comes out across the excerpt.
7. **End with exactly:** **"Any questions about this overview, or can we start a code walkthrough?"
8. **Stop the message** — Do not add statements, code blocks, or walkthrough content after this question.


## Examples

**Example 1 — data wrangling**

> Loads tidyverse and readr. Reads `patients.csv` into a tibble `df` [842 × 12], filters to rows where `diagnosis == "ADHD"`, groups by `year` and `sex`, then summarises to count rows and mean age per group. Output is a summary tibble `rates` with one row per year–sex combination [14 × 3].
>
> Any questions about this overview, or can we start a code walkthrough?

*(Message ends here. Wait for user.)*

**Example 2 — short excerpt**

> Converts `dates` (character vector, length 120) to Date objects with `lubridate::ymd()`, then filters `df` [120 × 6] to rows on or after 2020-01-01, leaving roughly 80 rows depending on the date range in the data.
>
> Any questions about this overview, or can we start a code walkthrough?

*(Message ends here. Wait for user.)*
