"""
WSLS Bayesian hierarchical logistic regression — three belief subgroups.

Model:  stay ~ Bernoulli(logit⁻¹(alpha[j] + beta[j] * reward_prev))
  alpha[j] ~ Normal(alpha_mu, alpha_sigma)   — random intercept (baseline stay tendency)
  beta[j]  ~ Normal(beta_mu,  beta_sigma)    — random reward slope (WSLS effect)

Three panels:
  1. All 18 participants
  2. 17 who understood instructions correctly (50/50/50)
  3. 14 who felt odds matched instructions (felt_different == "no")
"""

import os
import re
import warnings
import numpy as np
import pandas as pd
import pymc as pm
import arviz as az
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from scipy.stats import gaussian_kde

# ── participant IDs ──────────────────────────────────────────────────────────
MISUNDERSTOOD = {"67dae998d8f2cfb8a8e3bf03"}          # reported 44/16/76

FELT_DIFFERENT = {                                      # felt_different == "yes"
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}

GROUPS = [
    {
        "label":    "All participants",
        "n_total":  18,
        "n_omit":   0,
        "exclude":  set(),
    },
    {
        "label":    "Understood correctly",
        "n_total":  18,
        "n_omit":   1,
        "exclude":  MISUNDERSTOOD,
        "omit_note": "1 excluded (misreported instruction odds)",
    },
    {
        "label":    "Felt = instructed",
        "n_total":  18,
        "n_omit":   4,
        "exclude":  FELT_DIFFERENT,
        "omit_note": "4 excluded (reported felt odds differed)",
    },
]

DATA_DIR  = "../../data/ioc-all-fixed-pilot/task"
OUT_PNG   = "wsls_three_panels.png"

# ── load & preprocess ────────────────────────────────────────────────────────
def load_all(data_dir):
    records = []
    for fname in sorted(os.listdir(data_dir)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-all_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        df = pd.read_csv(os.path.join(data_dir, fname), low_memory=False)
        gb = df[
            (df["task"] == "gambling_choice") &
            (df["block_number"].astype(str) != "training")
        ].copy()
        gb["participant"] = pid
        gb["reward"]           = pd.to_numeric(gb["reward"],           errors="coerce")
        gb["trial_number"]     = pd.to_numeric(gb["trial_number"],     errors="coerce")
        gb["is_choice_valid"]  = gb["is_choice_valid"].astype(str).str.lower() == "true"
        records.append(gb)
    return pd.concat(records, ignore_index=True)


def make_wsls_df(raw, exclude_ids):
    df = raw[~raw["participant"].isin(exclude_ids)].copy()
    df = df.sort_values(["participant", "block_number", "trial_number"])
    df["choice_prev"]   = df.groupby(["participant", "block_number"])["choice_key"].shift(1)
    df["reward_prev"]   = df.groupby(["participant", "block_number"])["reward"].shift(1)
    df["is_valid_prev"] = df.groupby(["participant", "block_number"])["is_choice_valid"].shift(1)
    df = df[
        (df["trial_number"] > 1) &
        (df["is_choice_valid"] == True) &
        (df["is_valid_prev"]   == True) &
        df["choice_prev"].notna() &
        df["reward_prev"].notna()
    ].copy()
    df["stay"]        = (df["choice_key"] == df["choice_prev"]).astype(int)
    df["reward_prev"] = df["reward_prev"].astype(int)
    pids = sorted(df["participant"].unique())
    pid_map = {p: i for i, p in enumerate(pids)}
    df["subj_idx"] = df["participant"].map(pid_map)
    return df, pids


# ── Bayesian fit ─────────────────────────────────────────────────────────────
def fit_model(df, n_subjects, group_label):
    print(f"\n=== Fitting: {group_label} (N={n_subjects}, {len(df)} trials) ===")
    with pm.Model() as model:
        alpha_mu    = pm.Normal("alpha_mu",    0, 2)
        beta_mu     = pm.Normal("beta_mu",     0, 2)
        alpha_sigma = pm.HalfNormal("alpha_sigma", 1)
        beta_sigma  = pm.HalfNormal("beta_sigma",  1)

        alpha_z = pm.Normal("alpha_z", 0, 1, shape=n_subjects)
        beta_z  = pm.Normal("beta_z",  0, 1, shape=n_subjects)

        alpha = pm.Deterministic("alpha", alpha_mu + alpha_sigma * alpha_z)
        beta  = pm.Deterministic("beta",  beta_mu  + beta_sigma  * beta_z)

        log_odds = alpha[df["subj_idx"].values] + beta[df["subj_idx"].values] * df["reward_prev"].values
        pm.Bernoulli("stay", logit_p=log_odds, observed=df["stay"].values)

        idata = pm.sample(
            draws=1000, tune=1000, chains=4, target_accept=0.9,
            progressbar=True, random_seed=42,
            nuts_sampler="nutpie" if False else "pymc",
        )
    return idata


# ── plot helpers ─────────────────────────────────────────────────────────────
GREY_FILL  = "#c8c8c8"
GREY_LINE  = "#404040"
GREY_MED   = "#888888"
ZERO_COL   = "#666666"


def posterior_panel(ax, draws, group_info, n_in_sample):
    med  = float(np.median(draws))
    pd_  = max(np.mean(draws > 0), np.mean(draws < 0)) * 100
    ci80 = np.quantile(draws, [0.10, 0.90])
    ci90 = np.quantile(draws, [0.05, 0.95])

    kde  = gaussian_kde(draws, bw_method="scott")
    xs   = np.linspace(draws.min(), draws.max(), 512)
    ys   = kde(xs)
    ys   = ys / ys.max()

    ax.fill_between(xs, ys, color=GREY_FILL, linewidth=0)

    CI_Y = -0.07
    # 90 % CI (thin)
    ax.plot([ci90[0], ci90[1]], [CI_Y, CI_Y], color=GREY_LINE, linewidth=1.0, solid_capstyle="round")
    # 80 % CI (thick)
    ax.plot([ci80[0], ci80[1]], [CI_Y, CI_Y], color=GREY_LINE, linewidth=2.5, solid_capstyle="round")
    # median dot
    ax.plot(med, CI_Y, "o", color=GREY_LINE, markersize=5, zorder=5)

    ax.axvline(0,   color=ZERO_COL,  linestyle="--", linewidth=0.8, alpha=0.8)
    ax.axvline(med, color=GREY_MED,  linestyle="--", linewidth=0.5, alpha=0.7)

    ax.text(med, 1.22,
            f"median = {med:.2f}\npd = {pd_:.1f}%",
            ha="center", va="top", fontsize=8, color="#555555")

    max_abs = max(abs(draws.min()), abs(draws.max())) * 1.05
    ax.set_xlim(-max_abs, max_abs)
    ax.set_ylim(CI_Y - 0.12, 1.45)

    # title with sample info
    n_omit = group_info["n_omit"]
    if n_omit == 0:
        subtitle = f"N = {n_in_sample}"
    else:
        subtitle = f"N = {n_in_sample}  ({n_omit} omitted)"
    ax.set_title(f"{group_info['label']}\n{subtitle}", fontsize=10, pad=6)

    ax.set_xlabel(r"$\beta_{\mu}$  (reward effect on log-odds of staying)", fontsize=9)
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.yaxis.set_visible(False)
    ax.spines["bottom"].set_color("#888888")
    ax.tick_params(axis="x", labelsize=8)


# ── main ─────────────────────────────────────────────────────────────────────
def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    print("Loading data …")
    raw = load_all(DATA_DIR)
    print(f"  Total gambling rows loaded: {len(raw)}")

    idatas = []
    wsls_dfs = []
    for g in GROUPS:
        df, pids = make_wsls_df(raw, g["exclude"])
        wsls_dfs.append(df)
        idata = fit_model(df, len(pids), g["label"])
        idatas.append(idata)

    # ── figure ───────────────────────────────────────────────────────────────
    fig, axes = plt.subplots(1, 3, figsize=(13, 4))
    fig.suptitle("WSLS: reward effect on staying (hierarchical Bayesian logistic regression)",
                 fontsize=11, y=1.02)

    for ax, idata, g, wdf in zip(axes, idatas, GROUPS, wsls_dfs):
        beta_mu_draws = idata.posterior["beta_mu"].values.flatten()
        n_in = len(wdf["participant"].unique())
        posterior_panel(ax, beta_mu_draws, g, n_in)

    plt.tight_layout()
    plt.savefig(OUT_PNG, dpi=150, bbox_inches="tight")
    print(f"\nSaved → {OUT_PNG}")


if __name__ == "__main__":
    warnings.filterwarnings("ignore", category=FutureWarning)
    main()
