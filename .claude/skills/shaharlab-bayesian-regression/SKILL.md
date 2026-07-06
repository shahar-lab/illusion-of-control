# Skill: Bayesian Regression Analysis (brms)

**🛑 MANDATORY WORKFLOW — Do not skip steps.**

## When to Invoke
Use this skill automatically when the user requests help with:
* Bayesian regression modeling using `brms`
* Setting up MCMC sampling or defining priors
* Running posterior predictive checks (PPCs) or diagnostics
* Organizing Bayesian analysis workflows
* **Triggers:** "brms", "bayesian regression", "bayesian model", "mcmc fitting", "fit brms"

## Workflow Gate (CRITICAL)

You MUST NOT write code until:
1. ✅ User has approved the regression **formula**
2. ✅ User has approved the **priors**
3. ✅ User has approved the **3-step plan**

## Step 1: Validation Workflow
Read and follow: `workflow/VALIDATION.md`

This file contains the exact sequence for:
- Suggesting a specific formula based on the user's research question
- Suggesting informative priors based on domain knowledge
- Presenting a 3-step plan
- Waiting for user approval on ALL THREE before proceeding

## Step 2: Sub-Agent Code Generation (After User Approval)
Once the user has approved formula, priors, and plan:
1. Read: `workflow/EXPERT-INSTRUCTIONS.md`
2. Invoke the sub-agent with the user's approved specifications
3. Reference the examples in `references/` as needed

## Step 3: Topology Enforcement
Read: `workflow/TOPOLOGY-ENFORCEMENT.md`

Ensure the sub-agent follows:
- "One model, one folder" structure
- Proper pathing with `project_root <- here::here()`
- Artifact isolation (artifacts/, output/, code/)

## 🗂️ Analysis Folder Structure
Every isolated model must follow this exact structure:

```text
analysis/[analysis_name]/
├── code/        (Unnumbered, highly targeted R scripts)
├── artifacts/   (Fitted models, RDS files, MCMC draws)
├── output/      (Visual plots, graphs, and tables)
├── main.R       (Master execution orchestrator)
└── summary.md   (Analysis documentation and lab notebook)
```