import glob
import re
from pathlib import Path

import numpy as np
import pandas as pd
import stan
import arviz as az

REPO       = Path(__file__).resolve().parents[2]
DATA_DIR   = REPO / "data" / "ioc-all-fixed-pilot" / "task"
MODEL_FILE = REPO / "models" / "dr_3arm" / "dr_3arm.stan"
OUT_DIR    = REPO / "analysis" / "param_estimation" / "bayesian_draws_dr"
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
df["choice"] = df["choice_key"].map(KEY_TO_CARD).astype(int)

df = df.sort_values(["participant", "block_number", "trial_number"]).reset_index(drop=True)

participants = sorted(df["participant"].unique())
pid_to_idx = {p: i + 1 for i, p in enumerate(participants)}
df["subject_trial"] = df["participant"].map(pid_to_idx)

df["first_trial_in_block"] = (
    df.groupby(["participant", "block_number"]).cumcount() == 0
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
    "Ndata":               int(Ndata),
    "Nsubjects":           int(Nsubjects),
    "subject_trial":       df["subject_trial"].tolist(),
    "choice":              df["choice"].tolist(),
    "first_trial_in_block": df["first_trial_in_block"].tolist(),
}

#### FIT MODEL ####
model_code = MODEL_FILE.read_text()

posterior = stan.build(model_code, data=stan_data, random_seed=1)
fit = posterior.sample(num_chains=4, num_samples=1000, num_warmup=1000)

idata = az.from_pystan(posterior=fit)
idata.to_netcdf(str(REPO / "analysis" / "param_estimation" / "draws_dr.nc"))

#### SAVE GROUP DRAWS ####
draws_group = pd.DataFrame({
    "delta_pop": fit["delta_pop"].reshape(-1),
    "rho_pop":   fit["rho_pop"].reshape(-1),
})
draws_group.to_csv(OUT_DIR / "posterior_draws_group.csv", index=False)

#### SAVE SUBJECT DRAWS ####
sbj_param_map = {
    "delta": fit["delta_sbj"],
    "rho":   fit["rho_sbj"],
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
            "param": f"{pname}_dr",
            "median": med,
            "lo90": lo90,
            "hi90": hi90,
        })

draws_subject = pd.DataFrame(rows)
draws_subject.to_csv(OUT_DIR / "posterior_draws_subject.csv", index=False)

#### SAVE TRIAL-LEVEL E MEDIANS ####
# fit["E_trial"] shape: (num_chains, num_samples, Ndata, 3)
E_draws = fit["E_trial"].reshape(-1, Ndata, 3)   # (total_samples, Ndata, 3)
E_median = np.median(E_draws, axis=0)             # (Ndata, 3)

e_trial_df = df[["participant", "block_number", "trial_number", "choice"]].copy()
e_trial_df["E1"] = E_median[:, 0]
e_trial_df["E2"] = E_median[:, 1]
e_trial_df["E3"] = E_median[:, 2]
e_trial_df.to_csv(OUT_DIR / "e_trial_median.csv", index=False)

print("Saved group draws    ->", OUT_DIR / "posterior_draws_group.csv")
print("Saved subject draws  ->", OUT_DIR / "posterior_draws_subject.csv")
print("Saved E trial median ->", OUT_DIR / "e_trial_median.csv")

print(az.summary(idata, var_names=["delta_pop", "rho_pop"]))
