# Drilldown

Use this reference during the **statement walkthrough** when the user replies **"drilldown"** on a statement.

You are an expert consultant helping them review and understand that statement so they can verify it is correct.

A "statement" is a complete logical unit that can span multiple physical lines.

## What to Do

1. **Print the statement** — Show exactly what statement you're explaining (it may span multiple lines)
2. **Explain what it does** — In just a few words, what is the outcome?
3. **Include specifics:**
   - What it generates or produces (e.g., "creates a new column named X")
   - Numbers, counts, sizes (e.g., "removes 47 rows", "creates 5 groups")
   - Expected outputs/results (e.g., "will have 156 rows")
   - Variable names, column names
   - Labels or values it creates

4. **Help them decide** — Is this statement doing what they expect? Is it correct?
5. **Be concise** — No unnecessary words
6. **Return to the step** — When finished, ask **"ok or drilldown?"** again on the same statement. Only move to the next statement after the user replies **"ok"**.

## Example Drilldown

**Statement:**
```r
df <- df |> filter(reward > 0) |> mutate(group = case_when(choice == 1 ~ "A", choice == 2 ~ "B"))
```

**Drilldown response:**
```
This filters to keep only rows where reward is positive, then creates a new column "group" 
that assigns "A" for choice==1 and "B" for choice==2. 

Expected: Removes any rows with reward ≤ 0. Your df will have fewer rows after this.
The new "group" column will have only values "A" or "B".
```

## Key Points

- **Specific** — Include numbers, names, expected counts
- **Verifiable** — User should be able to check this when they run the code
- **Brief** — Get to the point, no extra explanation
- **Accurate** — Get the details right (counts, names, logic)
