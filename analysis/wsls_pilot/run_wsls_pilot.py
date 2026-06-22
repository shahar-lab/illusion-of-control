"""
wsls_pilot: Bayesian stay/switch analysis on ioc-all-fixed-pilot (N=18)
For lags 1, 2, 3:
  - Fit group-level logistic: stay ~ alpha + beta * reward_nback
  - Compute per-subject p(stay|reward) and p(switch|reward)
  - Plot: left = posterior of beta, right = boxplots of per-subject proportions
"""

import os, re, warnings
import numpy as np
import pandas as pd
import pymc as pm
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.special import expit
from scipy.stats import gaussian_kde

warnings.filterwarnings("ignore")

os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_DIR  = "../../data/ioc-all-fixed-pilot/task"
os.makedirs("bayesian_draws", exist_ok=True)
os.makedirs("figures",        exist_ok=True)

# ── load data ─────────────────────────────────────────────────────────────────

def load_all(data_dir):
    dfs = []
    for fname in sorted(os.listdir(data_dir)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-all_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        df  = pd.read_csv(os.path.join(data_dir, fname), low_memory=False)
        df["participant"] = pid
        dfs.append(df)
    return pd.concat(dfs, ignore_index=True)

df_raw = load_all(DATA_DIR)
print(f"Loaded {df_raw['participant'].nunique()} subjects")

# ── per-lag analysis ──────────────────────────────────────────────────────────

def prepare_lag(df_raw, lag):
    gb = (
        df_raw[df_raw["task"] == "gambling_choice"]
        .copy()
        .assign(block_number=lambda x: x["block_number"].astype(str))
    )
    gb = gb.sort_values(["participant", "block_number", "trial_number"])

    records = []
    for (pid, blk), grp in gb.groupby(["participant", "block_number"], sort=False):
        if blk == "training":
            continue
        grp = grp.reset_index(drop=True)
        for i in range(lag, len(grp)):
            row    = grp.iloc[i]
            nback  = grp.iloc[i - lag]
            if (str(row["is_choice_valid"]).lower()   != "true" or
                str(nback["is_choice_valid"]).lower() != "true" or
                pd.isna(nback["choice_key"]) or
                pd.isna(nback["reward"]) or
                nback["choice_key"] == row.get("unavailable_key", "")):
                continue
            records.append({
                "participant": pid,
                "stay":        int(row["choice_key"] == nback["choice_key"]),
                "reward_nback": int(float(nback["reward"])),
            })

    return pd.DataFrame(records)

def fit_bayesian(df_lag):
    stay    = df_lag["stay"].values
    reward  = df_lag["reward_nback"].values.astype(float)
    with pm.Model():
        alpha = pm.Normal("alpha", 0, 2)
        beta  = pm.Normal("beta",  0, 2)
        pm.Bernoulli("obs", logit_p=alpha + beta * reward, observed=stay)
        idata = pm.sample(1000, tune=1000, chains=4, progressbar=False,
                          random_seed=42, target_accept=0.9)
    return idata

def subj_props(df_lag):
    rewarded = df_lag[df_lag["reward_nback"] == 1]
    return (
        rewarded
        .groupby("participant")["stay"]
        .mean()
        .reset_index()
        .rename(columns={"stay": "p_stay"})
        .assign(p_switch=lambda x: 1 - x["p_stay"])
    )

# ── plotting ──────────────────────────────────────────────────────────────────

FILL_BETA  = "#c0d7e8"
FILL_STAY  = "#56B4E9"
FILL_SW    = "#E69F00"
GREY       = "#555555"

def beta_panel(ax, beta_draws, lag_label):
    med = float(np.median(beta_draws))
    pd_ = max(np.mean(beta_draws > 0), np.mean(beta_draws < 0)) * 100
    ci  = np.quantile(beta_draws, [0.025, 0.975])
    xs  = np.linspace(beta_draws.min(), beta_draws.max(), 512)
    kde = gaussian_kde(beta_draws)
    ys  = kde(xs); ys /= ys.max()

    ax.fill_between(xs, ys, color=FILL_BETA, linewidth=0)
    CI_Y = -0.08
    ax.plot([ci[0], ci[1]], [CI_Y]*2, color=GREY, lw=1.2, solid_capstyle="round")
    ax.plot(med, CI_Y, "o", color=GREY, ms=5, zorder=5)
    ax.axvline(0,   color="#888888", ls="--", lw=0.8)
    ax.axvline(med, color="#aaaaaa", ls=":",  lw=0.8)
    ax.set_xlim(-0.5, 1.2)
    ax.set_ylim(CI_Y - 0.1, 1.5)
    ax.set_title(lag_label, fontsize=11)
    ax.text(med, 1.12, f"med={med:.2f}\npd={pd_:.1f}%",
            ha="center", va="top", fontsize=8, color=GREY)
    ax.spines[["top","right","left"]].set_visible(False)
    ax.yaxis.set_visible(False)
    ax.tick_params(axis="x", labelsize=8)

def box_panel(ax, props, add_xlabel=False):
    stays   = props["p_stay"].values
    switches = props["p_switch"].values
    bp = ax.boxplot(
        [stays, switches],
        positions=[1, 2],
        widths=0.5,
        patch_artist=True,
        medianprops=dict(color="black", lw=1.5),
        whiskerprops=dict(color=GREY),
        capprops=dict(color=GREY),
        flierprops=dict(marker="o", markersize=4, alpha=0.5, color=GREY),
    )
    bp["boxes"][0].set_facecolor(FILL_STAY)
    bp["boxes"][1].set_facecolor(FILL_SW)

    rng = np.random.default_rng(0)
    for vals, pos in [(stays, 1), (switches, 2)]:
        jitter = rng.uniform(-0.12, 0.12, size=len(vals))
        ax.scatter(pos + jitter, vals, s=18, color="gray", alpha=0.6, zorder=3)

    ax.set_xticks([1, 2])
    ax.set_xticklabels(["p(stay|reward)", "p(switch|reward)"], fontsize=8)
    ax.set_ylim(0, 1)
    ax.set_ylabel("Proportion" if add_xlabel else "", fontsize=9)
    ax.spines[["top","right"]].set_visible(False)
    ax.tick_params(axis="x", labelsize=8)

# ── main loop ─────────────────────────────────────────────────────────────────

lag_results = {}
for lag in [1, 2, 3]:
    print(f"\n=== LAG {lag} ===")
    df_lag = prepare_lag(df_raw, lag)
    print(f"  Observations: {len(df_lag)}")
    print(f"  P(stay|reward):    {df_lag[df_lag.reward_nback==1]['stay'].mean():.3f}")
    print(f"  P(stay|no-reward): {df_lag[df_lag.reward_nback==0]['stay'].mean():.3f}")

    idata = fit_bayesian(df_lag)
    beta_draws = idata.posterior["beta"].values.reshape(-1)
    props      = subj_props(df_lag)
    lag_results[lag] = {"beta_draws": beta_draws, "props": props}
    print(f"  beta median={np.median(beta_draws):.3f}")

# ── figure ─────────────────────────────────────────────────────────────────────

fig, axes = plt.subplots(3, 2, figsize=(10, 10))
fig.subplots_adjust(hspace=0.45, wspace=0.35)

for row, lag in enumerate([1, 2, 3]):
    res = lag_results[lag]
    beta_panel(axes[row, 0], res["beta_draws"], f"{lag}-back")
    box_panel(axes[row, 1], res["props"], add_xlabel=(row == 2))
    if row == 2:
        axes[row, 0].set_xlabel("β (reward effect on log-odds of staying)", fontsize=9)

for i, label in enumerate("ABCDEF"):
    r, c = divmod(i, 2)
    axes[r, c].text(-0.05, 1.05, label, transform=axes[r, c].transAxes,
                    fontsize=12, fontweight="bold", va="top")

fig.suptitle("Stay/switch analysis — ioc-all-fixed-pilot (N=18)", fontsize=12)
fig.savefig("figures/wsls_pilot_all_lags.png", dpi=150, bbox_inches="tight", facecolor="white")
print("\nSaved: figures/wsls_pilot_all_lags.png")
