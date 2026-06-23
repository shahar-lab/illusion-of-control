"""
wsls_pilot: Bayesian stay/switch analysis on ioc-all-fixed-pilot (N=18)
For lags 1, 2, 3:
  - Fit group-level logistic: stay ~ alpha + beta * reward_nback  (PyMC)
  - Compute per-subject p(stay|reward) and p(switch|reward) proportions
  - Plot: left = posterior of beta, right = boxplots (Okabe-Ito colors)
Styled per plot-posterior and plot-colors skills.
"""

import os, re, warnings
import numpy as np
import pandas as pd
import pymc as pm
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.stats import gaussian_kde

warnings.filterwarnings("ignore")

os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_DIR = "../../data/ioc-all-fixed-pilot/task"
os.makedirs("bayesian_draws", exist_ok=True)
os.makedirs("figures",        exist_ok=True)

# ── style constants (plot-posterior + plot-colors skills) ─────────────────────
GREY30  = "#4d4d4d"   # x-axis line
GREY40  = "#666666"   # zero ref line + annotations
GREY65  = "#a6a6a6"   # median line
GREY80  = "#cccccc"   # slab fill (single posterior)
CI80_LW = 3.0
CI90_LW = 1.5
BASE_FS = 20

# Okabe-Ito — p(stay|reward) = sky blue, p(switch|reward) = orange
OI_BLUE   = "#56B4E9"
OI_ORANGE = "#E69F00"

# ── data loading ──────────────────────────────────────────────────────────────

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

# ── per-lag preparation ───────────────────────────────────────────────────────

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
            row   = grp.iloc[i]
            nback = grp.iloc[i - lag]
            if (str(row["is_choice_valid"]).lower()   != "true" or
                str(nback["is_choice_valid"]).lower() != "true" or
                pd.isna(nback["choice_key"]) or
                pd.isna(nback["reward"]) or
                nback["choice_key"] == row.get("unavailable_key", "")):
                continue
            records.append({
                "participant":  pid,
                "stay":         int(row["choice_key"] == nback["choice_key"]),
                "reward_nback": int(float(nback["reward"])),
            })
    return pd.DataFrame(records)

def fit_bayesian(df_lag):
    stay   = df_lag["stay"].values
    reward = df_lag["reward_nback"].values.astype(float)
    with pm.Model():
        alpha = pm.Normal("alpha", 0, 2)
        beta  = pm.Normal("beta",  0, 2)
        pm.Bernoulli("obs", logit_p=alpha + beta * reward, observed=stay)
        idata = pm.sample(1000, tune=1000, chains=4, progressbar=False,
                          random_seed=42, target_accept=0.9)
    return idata.posterior["beta"].values.reshape(-1)

def subj_props(df_lag):
    """Per-subject p(stay|reward=1) and p(stay|reward=0)."""
    return (
        df_lag
        .groupby(["participant", "reward_nback"])["stay"]
        .mean()
        .reset_index()
        .rename(columns={"stay": "p_stay", "reward_nback": "reward"})
    )

# ── panel helpers ─────────────────────────────────────────────────────────────

def beta_panel(ax, beta_draws, lag_label, add_xlabel=False):
    """Beta posterior — x starts at 0, y-axis visible as reference."""
    med  = float(np.median(beta_draws))
    pd_  = max(np.mean(beta_draws > 0), np.mean(beta_draws < 0)) * 100
    ci90 = np.quantile(beta_draws, [0.05, 0.95])

    xs  = np.linspace(beta_draws.min(), beta_draws.max(), 600)
    kde = gaussian_kde(beta_draws, bw_method=0.15)
    ys  = kde(xs); ys /= ys.max()
    ax.fill_between(xs, ys, color=GREY80, linewidth=0)

    CI_Y = -0.09
    ax.plot([ci90[0], ci90[1]], [CI_Y]*2, color=GREY30, lw=CI90_LW, solid_capstyle="round", zorder=3)
    ax.plot(med, CI_Y, "o", color=GREY30, ms=5, zorder=5)

    ax.axvline(med, color=GREY65, ls="--", lw=0.5)
    ax.text(med, 1.05, f"[median = {med:.2f}, pd = {pd_:.1f}%]",
            ha="left", va="bottom", fontsize=7.5, color=GREY40,
            transform=ax.get_xaxis_transform())

    x_max = beta_draws.max() * 1.10
    ax.set_xlim(0, x_max)
    ax.set_ylim(CI_Y - 0.08, 1.35)
    ax.set_title(lag_label, fontsize=BASE_FS, pad=4)
    if add_xlabel:
        ax.set_xlabel("β  (reward effect on log-odds of staying)", fontsize=BASE_FS - 1)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(GREY30)
    ax.spines["bottom"].set_color(GREY30)
    ax.yaxis.set_visible(False)
    ax.tick_params(axis="x", labelsize=BASE_FS - 2)

def box_panel(ax, props, add_xlabel=False):
    """Boxplots of p(stay|reward=0) and p(stay|reward=1) per subject.
    Colors: Okabe-Ito orange (no reward) and sky blue (reward)."""
    no_rew    = props[props["reward"] == 0]["p_stay"].values
    rew       = props[props["reward"] == 1]["p_stay"].values
    data_vals = [no_rew, rew]
    positions = [1, 1.6]
    colors    = [OI_ORANGE, OI_BLUE]
    labels    = ["p(stay | no reward)", "p(stay | reward)"]

    bp = ax.boxplot(
        data_vals,
        positions=positions,
        widths=0.45,
        patch_artist=True,
        medianprops=dict(color="black", lw=1.8),
        whiskerprops=dict(color=GREY40, lw=1.0),
        capprops=dict(color=GREY40, lw=1.0),
        flierprops=dict(marker="o", markersize=3.5, alpha=0.4, color=GREY40),
        boxprops=dict(linewidth=0),
    )
    for patch, col in zip(bp["boxes"], colors):
        patch.set_facecolor(col)
        patch.set_alpha(0.75)

    rng = np.random.default_rng(0)
    for vals, pos, col in zip(data_vals, positions, colors):
        jitter = rng.uniform(-0.13, 0.13, size=len(vals))
        ax.scatter(pos + jitter, vals, s=22, color=col, alpha=0.85,
                   edgecolors="white", linewidths=0.4, zorder=3)

    ax.set_xticks(positions)
    ax.set_xticklabels(labels, fontsize=BASE_FS - 2)
    ax.set_xlim(0.6, 2.0)
    ax.set_ylim(0, 1.05)
    ax.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
    ax.set_yticklabels(["0", ".25", ".50", ".75", "1"], fontsize=BASE_FS - 3)
    if add_xlabel:
        ax.set_xlabel("Condition", fontsize=BASE_FS - 1)
    ax.set_ylabel("Proportion", fontsize=BASE_FS - 1)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["bottom"].set_color(GREY30)
    ax.spines["left"].set_color(GREY30)
    ax.tick_params(axis="both", labelsize=BASE_FS - 2)
    ax.set_facecolor("white")

# ── run lags ──────────────────────────────────────────────────────────────────

lag_results = {}
for lag in [1, 2, 3]:
    print(f"\n=== LAG {lag} ===")
    df_lag = prepare_lag(df_raw, lag)
    print(f"  Obs: {len(df_lag)}  |  P(stay|reward): {df_lag[df_lag.reward_nback==1]['stay'].mean():.3f}")
    beta_draws = fit_bayesian(df_lag)
    props      = subj_props(df_lag)
    lag_results[lag] = {"beta_draws": beta_draws, "props": props}
    print(f"  β median = {np.median(beta_draws):.3f}")

# ── figure — vertical layout: 3 lag rows × 2 columns (beta | boxplot) ─────────
fig, axes = plt.subplots(3, 2, figsize=(10, 9))
fig.patch.set_facecolor("white")
fig.subplots_adjust(hspace=0.55, wspace=0.40, left=0.09, right=0.97, top=0.95, bottom=0.09)

panel_labels = "ABCDEF"
for row, lag in enumerate([1, 2, 3]):
    add_xl = (row == 2)
    beta_panel(axes[row, 0], lag_results[lag]["beta_draws"], f"{lag}-back", add_xlabel=add_xl)
    box_panel(axes[row, 1],  lag_results[lag]["props"],                     add_xlabel=add_xl)

for i, ax in enumerate(axes.flat):
    ax.text(-0.08, 1.15, panel_labels[i], transform=ax.transAxes,
            fontsize=BASE_FS + 2, fontweight="bold", va="top")

fig.savefig("figures/wsls_pilot_all_lags.png", dpi=150,
            bbox_inches="tight", facecolor="white")
print("\nSaved: figures/wsls_pilot_all_lags.png")
