# Bayesian Regression Workflow

This folder contains the mandatory validation and enforcement workflow for all Bayesian regression analyses in the Shahar Lab.

## How It Works

When you invoke `/shaharlab-bayesian-regression`, follow these three files in order:

### 1. **VALIDATION.md** (Steps 1-3)
**What happens:** You (Claude Code) validate with the user before any code is written.

**In this file, you will:**
- Suggest a specific regression formula
- Confirm or request the user's priors
- Present a 3-step plan
- **Obtain explicit user approval** on ALL THREE before proceeding

**Gate Check:** Do NOT proceed until:
- ✅ Formula is approved
- ✅ Priors are approved
- ✅ Plan is approved

### 2. **EXPERT-INSTRUCTIONS.md** (After User Approval)
**What happens:** You invoke a sub-agent to write the code.

**In this file, you will:**
- Verify you have all approved specifications
- Provide context to the sub-agent with the exact user approvals
- Reference the expert agent instructions
- Verify the sub-agent's output

### 3. **TOPOLOGY-ENFORCEMENT.md** (Reference During Coding)
**What happens:** The sub-agent uses this to ensure compliance.

**This file specifies:**
- "One model, one folder" structure
- Path construction rules (`project_root <- here::here()`, `file.path()`)
- Artifact isolation (artifacts/, output/, code/)
- Script naming conventions
- summary.md documentation structure

---

## Critical Rule

**DO NOT SKIP THE VALIDATION STEP.**

The biggest mistake is reading these files, understanding them, and then proceeding directly to code generation without getting explicit user approval on formula, priors, and plan. This defeats the entire purpose of the workflow.

If you find yourself writing code before the user has approved all three items, you are breaking the gate. Stop and return to VALIDATION.md.

---

## Reference

For sub-agent code patterns, also reference:
- `references/sampling/sampling.md`
- `references/prior_predictive_check/prior_predictive_check.md`
- `references/posterior_predictive_check/posterior_predictive_check.md`
- `references/diagnostics/diagnostics.md`
