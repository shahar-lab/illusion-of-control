---
name: r-code-walkthrough
description: >-
  Walks the user through selected R code statement by statement so they can
  learn or verify what each statement does. Use when the user asks for a code
  walkthrough, help understanding R code, step-by-step verification, help me
  understand this code, or invokes /r-code-walkthrough on a selected code excerpt.
compatibility: None
---

## References

| Stage | Reference | Purpose |
|-------|-----------|-------|
| Overview | [overview.md](references/overview.md) | Opening summary — first message only, no code |
| What is a statement | [what_is_a_statement.md](references/what_is_a_statement.md) | How to divide code into statements (internal, Step C) |
| Describe a statement | [describe_statement.md](references/describe_statement.md) | Code block first, then one/two-sentence explanation (Step D) |
| Drilldown | [drilldown.md](references/drilldown.md) | Deeper detail on request |
| Novel function | [explain_novel_function.md](references/explain_novel_function.md) | Explain an unfamiliar function |


# R Code Walkthrough

Your job is to follow these steps:

Step A:
1. Learn the code silently, no output from your side to the user at this point. 

Step B:
2. Print the title "overview"
3. Under the title, print to the user an "overview" following the guidelines in references/overview.md 
4. ask the user "Any questions about this overview, or can we start a code walkthrough?"
5. STOP. Wait. dont print anything else. wait for the user reply.
6. If the user allows you to move on go to Step C. If the useres ask questions try explaining, and keep asking after each explnation "Any more questions about this overview, or can we start a code walkthrough?"

Step C:
7. silently, just internally for your learning, divide the selected code into statements. Use references/what_is_a_statement.md to understand what are your statements. 

Step D:
8. Print "statement X out of X".
9. Print the code statement using md or codebox so it will be clear that this is code.
10. provide one/two sentences explaining the statement. Use "references/describe_statement.md" to know how.
11. ask "OK or drilldown?" 
12. STOP. Wait for the user reply.
13. if the user says "ok" move to Step D item 7 again with the next statement. 
14. if the user says "ok" but all statements were read, say "Done!"
15. if the user says "drilldown" then use "references/drilldown.md" to help the user understand the code.
