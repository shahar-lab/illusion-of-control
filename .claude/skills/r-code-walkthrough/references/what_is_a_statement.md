# What Is a Statement

Use this reference **silently** during Step C — before the walkthrough begins. Divide the selected code into statements internally; do not show this breakdown to the user yet.

## Definition

A **statement** is one complete logical unit of code. It may span multiple physical lines when those lines belong together (e.g., a piped chain, a function call with arguments on several lines, or a multi-line `if` block).

## How to Split

- **Keep lines together** when they form one coherent operation (e.g., a `%>%` or `|>` chain, a multi-line function call, a braced block).
- **Split into separate statements** when lines do independent things (e.g., a `library()` call followed by a separate assignment).

## Examples

**One statement** — piped chain:

```r
df <- df |> filter(reward > 0) |> mutate(group = case_when(choice == 1 ~ "A", choice == 2 ~ "B"))
```

**One statement** — multi-line function call:

```r
filter(
  adhd.visit.profession %in% relevant_professions,
  tre.occurrence.number == 1
)
```

**Two statements** — independent operations:

```r
library(tidyverse)
df <- read_csv("patients.csv")
```

**Two statements** — load then transform:

```r
library(dplyr)
rates <- df |> group_by(year) |> summarise(n = n())
```

## Count

After dividing, you should have a numbered list of statements (1 … M). Use M in **"statement X out of M"** during the walkthrough.
