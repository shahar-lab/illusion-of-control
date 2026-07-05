import glob
import re
from pathlib import Path

import numpy as np
import pandas as pd
import stan
import arviz as az

REPO       = Path(__file__).resolve().parents[2]
DATA_DIR   = REPO / "data" / "ioc-all-fixed-pilot" / "task"
MODEL_FILE = REPO / "models" / "ab_3arm" / "ab_3arm.stan"
OUT_DIR    = REPO / "analysis" / "param_estimation" / "bayesian_draws_ab"
OUT_DIR.mkdir(parents=True, exist_ok=True)

KEY_TO_CARD = {"arrowleft": 1, "arrowup": 2, "arrowright": 3}

MISUNDERSTOOD = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d", "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac", "6a0092581cd317f1ff1765a2",
}

#### LOAD DATA ####
files = sorted(glob.glob(str(DATA_DIR / "ioc-all_*_SESSION*.csv")))
df_list = []
for f in files:
    m = re.search(r"ioc-all_([a-f0-9]{24})_SESSION", f)
    pid = m.group(1)
    d = pd.read_csv(f)
    d["participant"] = pid
    df_list.append(d)

df = pd.concat(df_list, ignore_index=True)

df = df[
    (df["task"] == "gambling_choice")
    & (df["block_number"] != "training")
    & (df["is_choice_valid"] == True)
].copy()

df["block_number"] = df["block_number"].astype(int)
df["trial_number"] = df["trial_number"].astype(int)
df["reward"] = df["reward"].astype(float)
df["choice"] = df["choice_key"].map(KEY_TO_CARD).astype(int)

df = df.sort_values(["participant", "block_number", "trial_number"]).reset_index(drop=True)

participants = sorted(df["participant"].unique())
pid_to_idx = {p: i + 1 for i, p in enumerate(participants)}
df["subject_trial"] = df["participant"].map(pid_to_idx)

df["first_trial"] = (
    df.groupby("participant").cumcount() == 0
).astype(int)

Nsubjects = len(participants)
Ndata = len(df)

print("Total trials:", Ndata)
print("Subjects:    ", Nsubjects)

participant_map = pd.DataFrame({
    "participant": participants,
    "participant_idx": [pid_to_idx[p] for p in participants],
    "understood_eq_felt": [
        (p not in MISUNDERSTOOD) and (p not in FELT_DIFFERENT) for p in participants
    ],
})
participant_map.to_csv(OUT_DIR / "participant_map.csv", index=False)

stan_data = {
    "Ndata":        int(Ndata),
    "Nsubjects":    int(Nsubjects),
    "subject_trial": df["subject_trial"].tolist(),
    "choice":       df["choice"].tolist(),
    "reward":       df["reward"].tolist(),
    "first_trial":  df["first_trial"].tolist(),
}

#### FIT MODEL ####
model_code = MODEL_FILE.read_text()

posterior = stan.build(model_code, data=stan_data, random_seed=1)
fit = posterior.sample(num_chains=4, num_samples=1000, num_warmup=1000)

idata = az.from_pystan(posterior=fit)
idata.to_netcdf(str(REPO / "analysis" / "param_estimation" / "draws_ab.nc"))

#### SAVE GROUP DRAWS ####
draws_group = pd.DataFrame({
    "alpha_pop": fit["alpha_pop"].reshape(-1),
    "beta_pop":  fit["beta_pop"].reshape(-1),
})
draws_group.to_csv(OUT_DIR / "posterior_draws_group.csv", index=False)

#### SAVE SUBJECT DRAWS ####
sbj_param_map = {
    "alpha": fit["alpha_sbj"],
    "beta":  fit["beta_sbj"],
}

rows = []
for pname, arr in sbj_param_map.items():
    for s in range(Nsubjects):
        draws_s = arr[s, :].reshape(-1)
        med  = float(np.median(draws_s))
        lo90 = float(np.quantile(draws_s, 0.05))
        hi90 = float(np.quantile(draws_s, 0.95))
        pid = participants[s]
        rows.append({
            "participant": pid,
            "understood_eq_felt": (pid not in MISUNDERSTOOD) and (pid not in FELT_DIFFERENT),
            "param": f"{pname}_ab",
            "median": med,
            "lo90": lo90,
            "hi90": hi90,
        })

draws_subject = pd.DataFrame(rows)
draws_subject.to_csv(OUT_DIR / "posterior_draws_subject.csv", index=False)

#### SAVE TRIAL-LEVEL Q MEDIANS ####
# fit["Q_trial"] shape: (num_chains, num_samples, Ndata, 3)
Q_draws = fit["Q_trial"].reshape(-1, Ndata, 3)   # (total_samples, Ndata, 3)
Q_median = np.median(Q_draws, axis=0)             # (Ndata, 3)

q_trial_df = df[["participant", "block_number", "trial_number", "choice", "reward"]].copy()
q_trial_df["Q1"] = Q_median[:, 0]
q_trial_df["Q2"] = Q_median[:, 1]
q_trial_df["Q3"] = Q_median[:, 2]
q_trial_df.to_csv(OUT_DIR / "q_trial_median.csv", index=False)

print("Saved group draws    ->", OUT_DIR / "posterior_draws_group.csv")
print("Saved subject draws  ->", OUT_DIR / "posterior_draws_subject.csv")
print("Saved Q trial median ->", OUT_DIR / "q_trial_median.csv")

print(az.summary(idata, var_names=["alpha_pop", "beta_pop"]))
