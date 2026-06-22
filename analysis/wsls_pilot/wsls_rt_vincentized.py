"""
Vincentized WSLS effect as a function of RT quantile.

For each subject:
  1. Compute 10 RT quantile boundaries from their own RT distribution
  2. Assign each trial to a quantile bin based on the CURRENT trial's RT
  3. Compute WSLS effect = p(stay|reward=1) - p(stay|reward=0) within each bin

Then average across subjects (Vincent averaging).
Plot: WSLS effect (y) vs RT quantile midpoint (x), with SE across subjects.
"""

import os, re, warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

warnings.filterwarnings("ignore")
os.chdir(os.path.dirname(os.path.abspath(__file__)))
os.makedirs("figures", exist_ok=True)

DATA_DIR   = "../../data/ioc-all-fixed-pilot/task"
N_QUANTILES = 10

# ── style (plot-colors + plot-posterior rules) ────────────────────────────────
GREY30 = "#4d4d4d"
GREY40 = "#666666"
OI_BLUE = "#0072B2"   # Okabe-Ito blue for the effect line

# ── load data ─────────────────────────────────────────────────────────────────
dfs = []
for fname in sorted(os.listdir(DATA_DIR)):
    m = re.match(r"ioc-all_([a-f0-9]{24})_SESSION", fname)
    if not m: continue
    df = pd.read_csv(os.path.join(DATA_DIR, fname), low_memory=False)
    df["participant"] = m.group(1)
    dfs.append(df)

df_raw = pd.concat(dfs, ignore_index=True)
print(f"Loaded {df_raw['participant'].nunique()} subjects")

# ── build lag-1 stay/switch dataset ──────────────────────────────────────────
LAG = 1

def prepare(df_raw, lag):
    gb = (
        df_raw[df_raw["task"] == "gambling_choice"]
        .copy()
        .assign(block_number=lambda x: x["block_number"].astype(str))
        .sort_values(["participant", "block_number", "trial_number"])
    )

    records = []
    for (pid, blk), grp in gb.groupby(["participant", "block_number"], sort=False):
        if blk == "training": continue
        grp = grp.reset_index(drop=True)
        for i in range(lag, len(grp)):
            row   = grp.iloc[i]
            nback = grp.iloc[i - lag]
            if (str(row["is_choice_valid"]).lower()  != "true" or
                str(nback["is_choice_valid"]).lower() != "true" or
                pd.isna(nback["choice_key"]) or pd.isna(nback["reward"]) or
                pd.isna(row["rt"]) or row["rt"] <= 0):
                continue
            records.append({
                "participant":  pid,
                "stay":         int(row["choice_key"] == nback["choice_key"]),
                "reward_nback": int(float(nback["reward"])),
                "rt":           float(row["rt"]),
            })
    return pd.DataFrame(records)

df = prepare(df_raw, LAG)
print(f"Total trials: {len(df)}  |  Subjects: {df.participant.nunique()}")

# ── vincentizing ──────────────────────────────────────────────────────────────
# For each subject: assign RT quantile, compute WSLS effect per bin

quantile_edges = np.linspace(0, 1, N_QUANTILES + 1)
bin_labels     = np.arange(1, N_QUANTILES + 1)

subject_effects = []   # (N_QUANTILES,) per subject
subject_rt_mids = []   # median RT per bin per subject

for pid, grp in df.groupby("participant"):
    # quantile boundaries from this subject's RT distribution
    boundaries = np.quantile(grp["rt"], quantile_edges)
    grp = grp.copy()
    grp["rt_bin"] = pd.cut(grp["rt"], bins=boundaries, labels=bin_labels,
                           include_lowest=True)

    effects = []
    rt_mids = []
    for b in bin_labels:
        trials = grp[grp["rt_bin"] == b]
        if len(trials) < 5:           # skip near-empty bins
            effects.append(np.nan)
            rt_mids.append(np.nan)
            continue
        p_stay_rew   = trials[trials.reward_nback == 1]["stay"].mean() if (trials.reward_nback==1).any() else np.nan
        p_stay_norew = trials[trials.reward_nback == 0]["stay"].mean() if (trials.reward_nback==0).any() else np.nan
        effects.append(p_stay_rew - p_stay_norew if not (np.isnan(p_stay_rew) or np.isnan(p_stay_norew)) else np.nan)
        rt_mids.append(trials["rt"].median())

    subject_effects.append(effects)
    subject_rt_mids.append(rt_mids)

effects_arr = np.array(subject_effects, dtype=float)  # (N_subjects, N_quantiles)
rt_mids_arr = np.array(subject_rt_mids, dtype=float)

# Vincent average: mean effect per quantile across subjects
mean_effect = np.nanmean(effects_arr, axis=0)
se_effect   = np.nanstd(effects_arr,  axis=0) / np.sqrt(np.sum(~np.isnan(effects_arr), axis=0))
mean_rt     = np.nanmean(rt_mids_arr, axis=0)   # average median RT per bin

print("\nVincentized WSLS effect by RT quantile:")
for i, (rt, eff, se) in enumerate(zip(mean_rt, mean_effect, se_effect)):
    print(f"  Q{i+1:02d}: RT={rt:.0f} ms  effect={eff:.3f} ± {se:.3f}")

# ── plot ──────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(7, 3.5))
fig.patch.set_facecolor("white")
fig.subplots_adjust(left=0.12, right=0.97, top=0.88, bottom=0.18)

x = mean_rt   # x axis: average median RT (ms) per bin

ax.fill_between(x, mean_effect - se_effect, mean_effect + se_effect,
                color=OI_BLUE, alpha=0.18, linewidth=0)
ax.plot(x, mean_effect, color=OI_BLUE, lw=2.0, zorder=3)
ax.scatter(x, mean_effect, color=OI_BLUE, s=40, zorder=4, edgecolors="white", linewidths=0.6)

ax.axhline(0, color=GREY40, ls="--", lw=0.9)

ax.set_xlabel("RT (ms) — quantile midpoint", fontsize=11)
ax.set_ylabel("WSLS effect\np(stay|reward) − p(stay|no reward)", fontsize=10)

ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.spines["bottom"].set_color(GREY30)
ax.spines["left"].set_color(GREY30)
ax.tick_params(labelsize=9)

# quantile tick labels on top x-axis
ax2 = ax.twiny()
ax2.set_xlim(ax.get_xlim())
ax2.set_xticks(x)
ax2.set_xticklabels([f"Q{i}" for i in bin_labels], fontsize=7.5)
ax2.spines["top"].set_color(GREY30)
ax2.spines["right"].set_visible(False)
ax2.spines["left"].set_visible(False)
ax2.spines["bottom"].set_visible(False)
ax2.tick_params(length=2, labelsize=7.5)

out = "figures/wsls_effect_by_rt_quantile.png"
fig.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
print(f"\nSaved: {out}")
