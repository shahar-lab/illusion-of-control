# Expert Instructions: Code Generation (Sub-Agent)

**You are HERE:** The user has approved the formula, priors, and 3-step plan. You are now ready to delegate code generation to the sub-agent.

---

## Pre-Delegation Checklist

Verify you have the following from the user (saved in conversation context):

1. ✅ **Approved Formula** — User has confirmed the `brms` formula (e.g., `outcome ~ 1 + predictor`)
2. ✅ **Approved Priors** — User has specified exact prior distributions and parameters
3. ✅ **Approved Plan** — User has agreed to the 3-step workflow
4. ✅ **Data Source** — User has specified: real data file OR synthetic data generation

If ANY of these is missing, do NOT proceed. Return to `workflow/VALIDATION.md` and collect the missing information.

---

## Sub-Agent Delegation

Invoke the expert agent with the following context:

```
You are the Senior Bayesian Statistician for the Shahar Lab.

USER'S APPROVED SPECIFICATIONS:
- Formula: [INSERT USER'S APPROVED FORMULA]
- Priors: [INSERT USER'S APPROVED PRIORS EXACTLY]
- Plan: [INSERT USER'S APPROVED 3-STEP PLAN]
- Data: [REAL FILE PATH OR SYNTHETIC DATA SPEC]

Your task: Write the complete R analysis pipeline following the steps in the plan.

MANDATORY RULES:
1. Define ALL three directory variables in main.R: `project_root <- here::here()`, `code_dir`, `artifacts_dir`, `output_dir` using `file.path()`
2. Use `code_dir` variable (NOT hardcoded paths) when sourcing scripts: `source(file.path(code_dir, "script.R"))`
3. Create unnumbered scripts in code/ folder (e.g., fit_model.R, plot_posterior.R)
4. Save all artifacts to `artifacts_dir` using `file.path()` 
5. Save all plots/tables to `output_dir` using `file.path()`
6. Follow Shahar Lab coding conventions (base R pipe |>, minimal comments, descriptive names)

Read these files for guidance:
- workflow/TOPOLOGY-ENFORCEMENT.md (folder structure and path rules)
- references/sampling/sampling.md (if generating posterior samples)
- references/prior_predictive_check/prior_predictive_check.md (if generating PPC)
- references/posterior_predictive_check/posterior_predictive_check.md (if checking model fit)
- references/diagnostics/diagnostics.md (if diagnostic plots needed)
```

---

## What the Sub-Agent Must Deliver

The sub-agent should generate:

1. **Folder Structure** — analysis/[analysis_name]/ with code/, artifacts/, output/, main.R, summary.md
2. **Scripts** — Unnumbered R files in code/ folder:
   - Data loading or generation script
   - Model fitting script with user's priors
   - Posterior sampling/extraction script
   - Visualization scripts (as specified in the plan)
3. **Documentation** — summary.md with analysis overview, prior spec, and outputs
4. **Artifacts** — Saved models, posterior draws, and plots

---

## Post-Generation Verification

After the sub-agent completes, verify:

- [ ] Analysis folder follows "one model, one folder" topology
- [ ] All scripts use `project_root <- here::here()` and `file.path()` for paths
- [ ] Scripts are unnumbered and focused (50-80 lines max each)
- [ ] Artifacts saved to artifacts/; plots to output/
- [ ] summary.md documents the analysis with prior specification
- [ ] Code follows Shahar Lab style (|> pipe, base R, minimal comments)

If any verification fails, request the sub-agent fix it before finalizing.

---

## Important Notes

- The sub-agent should NOT ask the user for clarification on formula/priors/plan — those are already approved and saved in context.
- The sub-agent MUST follow the topology rules in TOPOLOGY-ENFORCEMENT.md exactly.
- The sub-agent should reference code examples in references/ to ensure consistency with lab conventions.
