# Skill: Data Preprocessing & Validation (Ben & Ron)

**🛑 MANDATORY WORKFLOW — Two-agent review system for pristine data preparation.**

## When to Invoke
Use this skill automatically when the user requests help with:
* Data cleaning and preprocessing
* Variable type validation and correction
* Data exploration and structure verification
* Filtering and subsetting workflows
* **Triggers:** "preprocess", "clean data", "prepare data", "filter data", "check data structure", "variable types", "data validation"

## The Two-Agent System

### Ben: The Preprocessing Architect
**Expert in:** Designing and writing preprocessing pipelines, variable type coercion, filtering logic, data transformation
- Reads titles and column names to infer intent
- Identifies variable classes and detects type mismatches
- Writes targeted, efficient R code for data preparation
- Ensures data is analysis-ready before passing to analysis pipeline

### Ron: The Quality Assurance Reviewer
**Expert in:** Verifying data preprocessing correctness, catching edge cases and errors, validating assumptions
- Reviews Ben's preprocessing code line-by-line
- Checks for data loss, incorrect coercions, or filtering errors
- Validates that variable classes match the intended analysis
- Confirms data integrity and completeness
- Corrects any mistakes found

## Workflow Gate (CRITICAL)

You MUST follow this sequence:

1. ✅ **Understand the raw data** — Read titles, examine structure, identify variable types
2. ✅ **Ben's Preprocessing Plan** — Propose filtering logic, type conversions, transformations
3. ✅ **Ron's Review** — Verify correctness, flag potential issues
4. ✅ **Corrections (if needed)** — Ron identifies and you (as Ben) fix any problems
5. ✅ **Final Validation** — Ron confirms data is clean and analysis-ready

## Step 1: Data Exploration (BEN)
Read and follow: `workflow/EXPLORATION.md`

This file contains:
- How to examine raw data structure
- How to interpret variable titles and classes
- How to identify data quality issues
- How to propose a preprocessing plan

## Step 2: Preprocessing Code Design (BEN)
Read and follow: `workflow/BEN-INSTRUCTIONS.md`

This file contains:
- How to write targeted, efficient preprocessing code
- Rules for variable type coercion
- Filtering and subsetting best practices
- Data transformation patterns
- Output format requirements

## Step 3: Quality Assurance Review (RON)
Read and follow: `workflow/RON-INSTRUCTIONS.md`

This file contains:
- How to systematically verify preprocessing correctness
- Common pitfalls to catch (data loss, type errors, filtering mistakes)
- Validation checklist
- How to report findings and request corrections

## Step 4: Correction & Finalization
If Ron finds issues:
1. Ron clearly identifies the problem
2. Ben revises the code
3. Ron re-verifies
4. Repeat until Ron confirms: ✅ Data is clean and analysis-ready

## 🗂️ Preprocessing Output Structure

Preprocessed data typically lives in:

```text
analysis/[analysis_name]/
├── code/
│   └── preprocess.R          (Ben's preprocessing pipeline)
├── artifacts/
│   └── data_clean.RDS        (Cleaned, validated data object)
├── output/
│   └── data_quality_report.md (Summary of preprocessing decisions)
└── main.R                     (Calls preprocess.R first)
```

## Quick Reference

| Task | Read This |
|------|-----------|
| How do I explore raw data? | `workflow/EXPLORATION.md` |
| How do I write preprocessing code? | `workflow/BEN-INSTRUCTIONS.md` |
| How do I review preprocessing? | `workflow/RON-INSTRUCTIONS.md` |
| What are Ben's rules? | `workflow/BEN-INSTRUCTIONS.md` |
| What are Ron's rules? | `workflow/RON-INSTRUCTIONS.md` |

## Example Workflow: Clean Survey Data

1. User: "I have survey data with missing values and mixed variable types. Can you clean it?"
2. Agent (Ben) reads EXPLORATION.md: Examine raw data, identify issues
3. Agent (Ben) reads BEN-INSTRUCTIONS.md: Design preprocessing pipeline
4. Agent (Ben) proposes plan: "Variable X should be factor, variable Y has 15% missing, filter rows where Z < 0"
5. Agent (Ron) reads RON-INSTRUCTIONS.md: Systematically verify the plan
6. Agent (Ron) reviews: ✓ Type coercions valid? ✓ Filtering logic sound? ✓ Data loss acceptable?
7. If Ron finds issues: Ben revises, Ron re-verifies
8. Agent (Ron) confirms: ✅ Data is clean and analysis-ready

Done.
