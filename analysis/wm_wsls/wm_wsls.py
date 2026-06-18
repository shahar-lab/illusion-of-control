"""
Bayesian linear regression: working memory capacity → WSLS reward effect.

WM score  K_j = mean(K_4, K_8),   K_s = set_size × (2×accuracy − 1)
WSLS beta_j = per-subject reward effect from hierarchical logistic regression

Bayesian model:
  beta_j ~ Normal(mu_j, sigma)
  mu_j    = intercept + slope × K_j
  intercept, slope ~ Normal(0, 2)
  sigma   ~ HalfNormal(1)

Scatter plot follows plot-scatter skill conventions:
  - equal-length axes (coord_fixed equivalent: aspect ratio = 1)
  - linear trend line
  - Pearson r annotation (top-right)
  - colorblind-safe palette (Okabe-Ito)
  - points coloured by understood_eq_felt
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
from scipy.stats import gaussian_kde, pearsonr

# ── paths ────────────────────────────────────────────────────────────────────
os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_TASK = "../../data/ioc-all-fixed-pilot/task"
DATA_WM   = "../../data/ioc-all-fixed-pilot/wm"
OUT_PNG   = "wm_wsls.png"

# Okabe-Ito: blue for understood=felt, orange for not
COL_YES = "#0072B2"   # blue
COL_NO  = "#E69F00"   # orange

# ── participant grouping (copied from wsls_three_panels.py) ──────────────────
MISUNDERSTOOD = {"67dae998d8f2cfb8a8e3bf03"}  # reported 44/16/76

FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}

# ── 1. compute WM K scores ───────────────────────────────────────────────────
def load_wm_scores(wm_dir):
    rows = []
    for fname in sorted(os.listdir(wm_dir)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-wm_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        df = pd.read_csv(os.path.join(wm_dir, fname), low_memory=False)
        exp = df[
            (df["trial_name"] == "test_squares") &
            (df["block_type"] == "exp")
        ].copy()
        exp["set_size"] = pd.to_numeric(exp["set_size"], errors="coerce")
        exp["acc_bool"] = exp["accuracy"].astype(str).str.lower() == "true"

        k_vals = []
        for ss in [4, 8]:
            trials = exp[exp["set_size"] == ss]
            if len(trials) == 0:
                continue
            acc = trials["acc_bool"].mean()
            k   = ss * (2 * acc - 1)
            k_vals.append(k)

        rows.append({"pid": pid, "wm_k": float(np.mean(k_vals)) if k_vals else np.nan})

    return pd.DataFrame(rows).set_index("pid")


# ── 2. load task data & build WSLS dataframe ────────────────────────────────
def load_task(data_dir):
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


def make_wsls_df(raw):
    df = raw.copy()
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


# ── 3. WSLS hierarchical model → per-subject beta ───────────────────────────
def fit_wsls(df, n_subjects):
    print(f"\nFitting WSLS model (N={n_subjects}, {len(df)} trials) …")
    with pm.Model() as model:
        alpha_mu    = pm.Normal("alpha_mu",    0, 2)
        beta_mu     = pm.Normal("beta_mu",     0, 2)
        alpha_sigma = pm.HalfNormal("alpha_sigma", 1)
        beta_sigma  = pm.HalfNormal("beta_sigma",  1)

        alpha_z = pm.Normal("alpha_z", 0, 1, shape=n_subjects)
        beta_z  = pm.Normal("beta_z",  0, 1, shape=n_subjects)

        alpha = pm.Deterministic("alpha", alpha_mu + alpha_sigma * alpha_z)
        beta  = pm.Deterministic("beta",  beta_mu  + beta_sigma  * beta_z)

        log_odds = (alpha[df["subj_idx"].values]
                    + beta[df["subj_idx"].values] * df["reward_prev"].values)
        pm.Bernoulli("stay", logit_p=log_odds, observed=df["stay"].values)

        idata = pm.sample(
            draws=1000, tune=1000, chains=4, target_accept=0.9,
            progressbar=True, random_seed=42,
        )
    return idata


# ── 4. Bayesian linear regression: WSLS_beta ~ WM_K ─────────────────────────
def fit_regression(wsls_beta, wm_k):
    print(f"\nFitting WM → WSLS regression (N={len(wsls_beta)}) …")
    # standardize predictors for numerical stability
    wm_k_z = (wm_k - np.mean(wm_k)) / np.std(wm_k)
    with pm.Model() as model:
        intercept = pm.Normal("intercept", 0, 2)
        slope     = pm.Normal("slope",     0, 2)
        sigma     = pm.HalfNormal("sigma", 1)
        mu = intercept + slope * wm_k_z
        pm.Normal("obs", mu=mu, sigma=sigma, observed=wsls_beta)
        idata = pm.sample(
            draws=2000, tune=1000, chains=4, target_accept=0.9,
            progressbar=True, random_seed=42,
        )
    return idata, wm_k_z


# ── 5. scatter plot ──────────────────────────────────────────────────────────
def scatter_plot(wm_k, wsls_beta, colors, idata, wm_k_z):
    fig, ax = plt.subplots(figsize=(5, 5))

    # plot points coloured by understood_eq_felt
    for i in range(len(wm_k)):
        ax.scatter(wm_k[i], wsls_beta[i],
                   color=colors[i], s=40, alpha=0.85, zorder=3)

    # --- Bayesian regression posterior predictive band ---
    slope_draws     = idata.posterior["slope"].values.flatten()
    intercept_draws = idata.posterior["intercept"].values.flatten()
    wm_k_std = np.std(wm_k)
    wm_k_mean = np.mean(wm_k)

    x_grid_z = np.linspace(wm_k_z.min(), wm_k_z.max(), 200)
    x_grid   = x_grid_z * wm_k_std + wm_k_mean

    y_grid = (intercept_draws[:, None]
              + slope_draws[:, None] * x_grid_z[None, :])
    y_lo, y_med, y_hi = np.quantile(y_grid, [0.05, 0.50, 0.95], axis=0)

    ax.fill_between(x_grid, y_lo, y_hi, color="#56B4E9", alpha=0.25, zorder=1)
    ax.plot(x_grid, y_med, color="#0072B2", linewidth=1.5, zorder=2,
            label="Bayesian trend (90% CI)")

    # --- equal-length axes (plot-scatter skill: coord_fixed equivalent) ---
    xmin, xmax = wm_k.min(), wm_k.max()
    ymin, ymax = wsls_beta.min(), wsls_beta.max()
    shared_lo = min(xmin, ymin) - 0.15
    shared_hi = max(xmax, ymax) + 0.15
    ax.set_xlim(shared_lo, shared_hi)
    ax.set_ylim(shared_lo, shared_hi)
    ax.set_aspect("equal")

    # --- identity line (dashed grey, per skill) ---
    ax.axline((shared_lo, shared_lo), slope=1,
              color="grey", linestyle="--", linewidth=0.8, alpha=0.7, zorder=0)

    # --- Pearson r annotation (top-right) ---
    r, p = pearsonr(wm_k, wsls_beta)
    ax.annotate(f"[Pearson r = {r:.2f}]",
                xy=(1.0, 1.0), xycoords="axes fraction",
                xytext=(-8, -8), textcoords="offset points",
                ha="right", va="top", fontsize=8, color="#555555")

    # --- posterior slope annotation ---
    slope_raw_draws = slope_draws / np.std(wm_k)  # back to original units
    slope_med = float(np.median(slope_raw_draws))
    ci90 = np.quantile(slope_raw_draws, [0.05, 0.95])
    pd_val = max(np.mean(slope_raw_draws > 0),
                 np.mean(slope_raw_draws < 0)) * 100
    ax.annotate(f"slope = {slope_med:.2f} [{ci90[0]:.2f}, {ci90[1]:.2f}]\npd = {pd_val:.1f}%",
                xy=(0.03, 0.97), xycoords="axes fraction",
                ha="left", va="top", fontsize=7.5, color="#333333",
                bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="none", alpha=0.7))

    # --- tick marks: 4 ticks per axis ---
    ticks = np.linspace(shared_lo, shared_hi, 4)
    ax.set_xticks(ticks)
    ax.set_yticks(ticks)
    ax.xaxis.set_major_formatter(plt.FormatStrFormatter("%.1f"))
    ax.yaxis.set_major_formatter(plt.FormatStrFormatter("%.1f"))

    # --- legend for understood_eq_felt ---
    from matplotlib.lines import Line2D
    legend_els = [
        Line2D([0], [0], marker="o", color="w", markerfacecolor=COL_YES,
               markersize=7, label="understood = felt (n=13)"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor=COL_NO,
               markersize=7, label="understood ≠ felt (n=5)"),
    ]
    ax.legend(handles=legend_els, fontsize=7.5, loc="lower right",
              framealpha=0.8, edgecolor="none")

    ax.set_xlabel("Working memory capacity (K)", fontsize=10)
    ax.set_ylabel(r"WSLS reward effect ($\beta_j$, log-odds)", fontsize=10)
    ax.tick_params(labelsize=8)
    ax.spines[["top", "right"]].set_visible(False)

    plt.tight_layout()
    plt.savefig(OUT_PNG, dpi=150, bbox_inches="tight")
    print(f"\nSaved → {OUT_PNG}")


# ── main ─────────────────────────────────────────────────────────────────────
def main():
    # 1. WM scores
    print("Computing WM K scores …")
    wm = load_wm_scores(DATA_WM)
    print(wm.sort_index())

    # 2. WSLS per-subject betas
    print("\nLoading task data …")
    raw  = load_task(DATA_TASK)
    wsls_df, pids = make_wsls_df(raw)
    print(f"  Subjects: {len(pids)},  WSLS rows: {len(wsls_df)}")

    idata_wsls = fit_wsls(wsls_df, len(pids))

    # per-subject beta: posterior median
    beta_draws = idata_wsls.posterior["beta"].values  # (chains, draws, N)
    beta_flat  = beta_draws.reshape(-1, len(pids))    # (S, N)
    beta_med   = np.median(beta_flat, axis=0)         # (N,)
    wsls_beta_df = pd.DataFrame({"pid": pids, "wsls_beta": beta_med}).set_index("pid")

    # 3. merge WM + WSLS
    merged = wm.join(wsls_beta_df, how="inner").dropna()
    print(f"\nMerged subjects: {len(merged)}")
    print(merged.sort_index())

    wm_k     = merged["wm_k"].values
    wsls_bet = merged["wsls_beta"].values

    # determine colours
    def is_understood_eq_felt(pid):
        understood = pid not in MISUNDERSTOOD
        felt_ok    = pid not in FELT_DIFFERENT
        return understood and felt_ok

    colors = [COL_YES if is_understood_eq_felt(pid) else COL_NO
              for pid in merged.index]

    # 4. Bayesian regression
    idata_reg, wm_k_z = fit_regression(wsls_bet, wm_k)

    # print regression summary
    print("\n=== Regression posterior summary ===")
    print(az.summary(idata_reg, var_names=["intercept", "slope", "sigma"],
                     hdi_prob=0.90))

    # 5. scatter plot
    scatter_plot(wm_k, wsls_bet, colors, idata_reg, wm_k_z)


if __name__ == "__main__":
    warnings.filterwarnings("ignore", category=FutureWarning)
    warnings.filterwarnings("ignore", category=UserWarning)
    main()
