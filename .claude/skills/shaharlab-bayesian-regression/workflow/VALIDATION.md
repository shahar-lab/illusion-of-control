# Validation Workflow: Formula, Priors, and Plan

**You are HERE:** Steps 1-3 of the skill. Do not skip these. The user must approve all three before you proceed to code generation.

## Step 1: Formula Suggestion

Based on the user's research question, propose a specific `brms` formula.

**Your task:**
1. State the proposed formula clearly (e.g., `exam_score ~ 1 + anxiety`)
2. Explain what it does in plain English
3. Ask: **"Does this formula match your research question, or would you prefer a different structure?"**
4. Wait for user approval or alternative proposal

**Do NOT ask:** "What formula would you like?" — always lead with a concrete suggestion.

**Examples of well-formed proposals:**
- "Simple linear: `outcome ~ 1 + predictor`"
- "With interaction: `outcome ~ 1 + predictor1 + predictor2 + predictor1:predictor2`"
- "Hierarchical: `outcome ~ 1 + predictor + (1|group)`"

---

## Step 2: Prior Specification

**CRITICAL RULE:** You must NEVER invent priors on your own.

**Your task:**
1. Review any priors the user has already specified
2. If the user has provided explicit prior values (mean, SD, distribution), confirm them:
   - "You specified: Intercept ~ Normal(15, 25), Slope ~ Normal(0, 25), Sigma ~ Exponential(0.1). Is this exactly what you want?"
3. If the user has NOT specified priors, suggest specific categories and ask them to choose:
   - "Would you prefer: (a) weakly informative priors, (b) strongly informative priors, or (c) custom values?"
4. **Wait for explicit user approval** of the exact prior specification

**Do NOT proceed** until you have written confirmation of:
- Intercept prior (distribution, mean, SD)
- Slope prior(s) (distribution, mean, SD for each predictor)
- Sigma prior (distribution, scale)

---

## Step 3: Three-Step Plan

Present a concrete 3-step plan for the analysis. This should include:
1. **What we will do first** (e.g., "Fit the Bayesian regression model with your specified priors")
2. **What we will do second** (e.g., "Extract posterior samples and create diagnostic plots")
3. **What we will do third** (e.g., "Generate visualizations: posterior slope distribution and prior predictive check")

**Your task:**
1. Write out the 3-step plan in bullet format
2. Ask: **"Does this plan sound correct to you? Any changes or additions?"**
3. Wait for user approval

---

## Gate Check (Before Proceeding)

Before you move to code generation, verify:

- [ ] Formula is approved by user
- [ ] All prior specifications are approved by user
- [ ] 3-step plan is approved by user

If ANY of these is missing or uncertain, DO NOT proceed. Ask clarifying questions until all three are confirmed.

Once all three checkmarks are satisfied, proceed to: `workflow/EXPERT-INSTRUCTIONS.md`
