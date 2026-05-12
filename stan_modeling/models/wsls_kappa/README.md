# WSLS Model with Perseveration (wsls_kappa)

This is a model template for the Illusion-of-Control task with Win-Stay/Lose-Shift behavior driven by perseveration bias.

## Task Description

- **3 machines (arms)**: Each trial one machine is randomly unavailable
- **Softmax choice**: Agent selects from 2 available machines with softmax policy
- **Rescorla-Wagner learning**: Q-values updated via prediction error
- **Perseveration bias**: Extra log-odds added to previously chosen arm (kappa)

## Parameters

- `alpha`: Learning rate (transformed as logit, typical range 0.1–0.9)
- `beta`: Inverse temperature / softmax temperature (typical range 1–10)
- `kappa`: Perseveration bias / "stickiness" to previous choice (typical range 0–2)

## Files

- **wsls_kappa.r**: R simulation function for the task (implements `sim.block()`)
- **wsls_kappa_parameters.R**: Prior specification and artificial parameter ranges
- **wsls_kappa.stan**: Stan model for hierarchical parameter inference
- **simulate_wsls.py**: Standalone Python script for exploratory parameter sweep analysis

## Usage

### R: Parameter Recovery

Use with the standard `stan_modeling/` workflow:

```r
path = set_workingmodel()  # Select this model via GUI
cfg = list(
  Nsubjects        = 100,
  Nblocks          = 4,
  Ntrials_perblock = 150,  # Match Python script
  Narms            = 3,
  scarcity         = 0.5   # Reward probability
)
```

### Python: Exploratory Analysis

```bash
cd stan_modeling/models/wsls_kappa/
python simulate_wsls.py
```

Generates:
- `wsls_by_scarcity.csv`: WSLS effect across reward scarcity levels
- `wsls_by_scarcity.png`: Parameter sweep visualization

## References

- Rescorla-Wagner: Rescorla & Wagner (1972)
- Softmax with perseveration: Lau & Glimcher (2005), Wilson & Collins (2019)
