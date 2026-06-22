"""
Two-panel figure (style matches wm_wsls.png):
  Left  — scatter P(stay|win) vs P(stay|lose) per subject (all 18)
           Blue  #0072B2 = understood=felt (n=13)
           Orange #E69F00 = understood≠felt (n=5)
  Right — β_mu posterior from hierarchical WSLS on the 13 included subjects
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
from matplotlib.lines import Line2D
from scipy.stats import linregress, gaussian_kde

warnings.filterwarnings("ignore")
os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_DIR = "../../data/ioc-all-fixed-pilot/task"
OUT_PNG  = "wsls_scatter_posterior.png"
DRAWS_NC = "wsls_13_draws.nc"

MISUNDERSTOOD  = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}
OMITTED = MISUNDERSTOOD | FELT_DIFFERENT

COL_INC   = "#0072B2"   # Okabe-Ito blue   — understood = felt
COL_OMT   = "#E69F00"   # Okabe-Ito orange — understood ≠ felt
COL_TREND = "#EE6677"   # Paul Tol rose
GREY_LINE = "#404040"
ZERO_COL  = "#666666"
GREY_MED  = "#888888"


# ── data ──────────────────────────────────────────────────────────────────────
def load_raw(data_dir):
    records = []
    for fname in sorted(os.listdir(data_dir)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-all_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        df  = pd.read_csv(os.path.join(data_dir, fname), low_memory=False)
        gb  = (
            df[
                (df["task"] == "gambling_choice") &
                (df["block_number"].astype(str) != "training") &
                (df["is_choice_valid"].astype(str).str.lower() == "true")
            ]
            .copy()
            .assign(block_number=lambda x: x["block_number"].astype(int))
            .sort_values(["block_number", "trial_number"])
            .reset_index(drop=True)
        )
        gb["reward"]          = pd.to_numeric(gb["reward"], errors="coerce")
        gb["trial_number"]    = pd.to_numeric(gb["trial_number"], errors="coerce")
        gb["is_choice_valid"] = gb["is_choice_valid"].astype(str).str.lower() == "true"
        records.append({"pid": pid, "df": gb})
    return records


def per_subject_stay_rates(records):
    rows = []
    for rec in records:
        gb = rec["df"].copy()
        gb["choice_prev"] = gb.groupby("block_number")["choice_key"].shift(1)
        gb["reward_prev"] = gb.groupby("block_number")["reward"].shift(1)
        gb["valid_prev"]  = gb.groupby("block_number")["is_choice_valid"].shift(1)
        sub = gb[
            (gb["trial_number"] > 1) &
            gb["is_choice_valid"] &
            gb["valid_prev"].fillna(False) &
            gb["choice_prev"].notna() &
            gb["reward_prev"].notna()
        ].copy()
        sub["stay"]        = (sub["choice_key"] == sub["choice_prev"]).astype(int)
        sub["reward_prev"] = sub["reward_prev"].astype(int)
        p_win  = float(sub.loc[sub["reward_prev"] == 1, "stay"].mean()) \
                 if (sub["reward_prev"] == 1).sum() > 0 else np.nan
        p_lose = float(sub.loc[sub["reward_prev"] == 0, "stay"].mean()) \
                 if (sub["reward_prev"] == 0).sum() > 0 else np.nan
        rows.append({"pid": rec["pid"], "p_win": p_win, "p_lose": p_lose,
                     "omitted": rec["pid"] in OMITTED})
    return pd.DataFrame(rows).dropna(subset=["p_win", "p_lose"])


def make_wsls_df(records):
    frames = []
    for rec in records:
        gb = rec["df"].copy()
        gb["participant"] = rec["pid"]
        frames.append(gb)
    raw = pd.concat(frames, ignore_index=True)
    raw = raw.sort_values(["participant", "block_number", "trial_number"])
    raw["choice_prev"]   = raw.groupby(["participant","block_number"])["choice_key"].shift(1)
    raw["reward_prev"]   = raw.groupby(["participant","block_number"])["reward"].shift(1)
    raw["is_valid_prev"] = raw.groupby(["participant","block_number"])["is_choice_valid"].shift(1)
    raw = raw[
        (raw["trial_number"] > 1) &
        raw["is_choice_valid"] &
        raw["is_valid_prev"].fillna(False) &
        raw["choice_prev"].notna() &
        raw["reward_prev"].notna()
    ].copy()
    raw["stay"]        = (raw["choice_key"] == raw["choice_prev"]).astype(int)
    raw["reward_prev"] = raw["reward_prev"].astype(int)
    pids    = sorted(raw["participant"].unique())
    pid_map = {p: i for i, p in enumerate(pids)}
    raw["subj_idx"] = raw["participant"].map(pid_map)
    return raw, pids


def fit_wsls(df, n_subjects):
    print(f"Fitting WSLS (N={n_subjects}, {len(df)} trials) …")
    with pm.Model():
        alpha_mu    = pm.Normal("alpha_mu",    0, 2)
        beta_mu     = pm.Normal("beta_mu",     0, 2)
        alpha_sigma = pm.HalfNormal("alpha_sigma", 1)
        beta_sigma  = pm.HalfNormal("beta_sigma",  1)
        alpha_z = pm.Normal("alpha_z", 0, 1, shape=n_subjects)
        beta_z  = pm.Normal("beta_z",  0, 1, shape=n_subjects)
        pm.Deterministic("alpha", alpha_mu + alpha_sigma * alpha_z)
        pm.Deterministic("beta",  beta_mu  + beta_sigma  * beta_z)
        log_odds = (
            (alpha_mu + alpha_sigma * alpha_z)[df["subj_idx"].values]
            + (beta_mu + beta_sigma * beta_z)[df["subj_idx"].values]
            * df["reward_prev"].values
        )
        pm.Bernoulli("stay", logit_p=log_odds, observed=df["stay"].values)
        idata = pm.sample(draws=1000, tune=1000, chains=4,
                          target_accept=0.9, progressbar=True, random_seed=42)
    return idata


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    all_records = load_raw(DATA_DIR)

    # scatter data
    sdf    = per_subject_stay_rates(all_records)
    p_win  = sdf["p_win"].values
    p_lose = sdf["p_lose"].values
    colors = [COL_OMT if row["omitted"] else COL_INC
              for _, row in sdf.iterrows()]
    assert len(p_win) == len(p_lose)

    # WSLS posterior on 13 included subjects
    incl = [r for r in all_records if r["pid"] not in OMITTED]
    wsls_df, pids = make_wsls_df(incl)

    if os.path.exists(DRAWS_NC):
        print("Loading saved WSLS draws …")
        idata = az.from_netcdf(DRAWS_NC)
    else:
        idata = fit_wsls(wsls_df, len(pids))
        az.to_netcdf(idata, DRAWS_NC)

    beta_mu_draws = idata.posterior["beta_mu"].values.flatten()

    # ── figure ────────────────────────────────────────────────────────────────
    fig, (ax_sc, ax_post) = plt.subplots(1, 2, figsize=(10, 4.5))

    # ── left: scatter ─────────────────────────────────────────────────────────
    # axes switched: x = P(stay|lose), y = P(stay|win)
    shared_lo = 0.0
    shared_hi = max(p_win.max(), p_lose.max()) * 1.08

    # diagonal reference line (y = x)
    ax_sc.plot([shared_lo, shared_hi], [shared_lo, shared_hi],
               linestyle="--", color=GREY_LINE, linewidth=0.9, alpha=0.6, zorder=1)

    # OLS trend line
    slope, intercept, *_ = linregress(p_lose, p_win)
    x_fit = np.array([shared_lo, shared_hi])
    ax_sc.plot(x_fit, intercept + slope * x_fit,
               color=COL_TREND, linewidth=1.2, zorder=2)

    for i in range(len(sdf)):
        ax_sc.scatter(p_lose[i], p_win[i],
                      color=colors[i], s=50, alpha=0.85, zorder=3)

    ax_sc.set_xlim(shared_lo, shared_hi)
    ax_sc.set_ylim(shared_lo, shared_hi)

    legend_els = [
        Line2D([0],[0], marker="o", color="w", markerfacecolor=COL_INC,
               markersize=7, label="understood = felt  (n=13)"),
        Line2D([0],[0], marker="o", color="w", markerfacecolor=COL_OMT,
               markersize=7, label="understood ≠ felt  (n=5)"),
    ]
    ax_sc.legend(handles=legend_els, fontsize=7.5, loc="upper left",
                 framealpha=0.8, edgecolor="none")

    ax_sc.set_xlabel("P(stay | loss)", fontsize=10)
    ax_sc.set_ylabel("P(stay | win)", fontsize=10)
    ax_sc.tick_params(labelsize=8)
    ax_sc.spines[["top", "right"]].set_visible(False)

    # ── right: posterior ──────────────────────────────────────────────────────
    med  = float(np.median(beta_mu_draws))
    pd_  = max(np.mean(beta_mu_draws > 0), np.mean(beta_mu_draws < 0)) * 100
    ci90 = np.quantile(beta_mu_draws, [0.05, 0.95])

    kde  = gaussian_kde(beta_mu_draws, bw_method="scott")
    xs   = np.linspace(beta_mu_draws.min() * 1.15, beta_mu_draws.max() * 1.15, 512)
    ys   = kde(xs); ys = ys / ys.max()

    ax_post.fill_between(xs, ys, color="#c8c8c8", linewidth=0)
    ax_post.axvline(0,   color=ZERO_COL, linestyle="--", linewidth=0.9, alpha=0.8)
    ax_post.axvline(med, color=GREY_MED, linestyle="--", linewidth=0.5, alpha=0.7)

    CI_Y = -0.08
    ax_post.plot([ci90[0], ci90[1]], [CI_Y, CI_Y],
                 color=GREY_LINE, linewidth=1.0, solid_capstyle="round")
    ax_post.plot(med, CI_Y, "o", color=GREY_LINE, markersize=5, zorder=5)

    ax_post.text(med, 1.22,
                 f"median = {med:.2f}\npd = {pd_:.1f}%",
                 ha="center", va="top", fontsize=8, color="#555555")

    max_abs = max(abs(beta_mu_draws.min()), abs(beta_mu_draws.max())) * 1.1
    ax_post.set_xlim(-max_abs, max_abs)
    ax_post.set_ylim(CI_Y - 0.15, 1.5)

    ax_post.set_xlabel(r"$\beta_{\mu}$  (reward effect on log-odds of staying)",
                       fontsize=10)
    ax_post.set_title("WSLS reward effect\nFelt = instructed  (N = 13, 5 omitted)",
                      fontsize=10, pad=6)
    ax_post.spines[["top", "right", "left"]].set_visible(False)
    ax_post.yaxis.set_visible(False)
    ax_post.spines["bottom"].set_color("#888888")
    ax_post.tick_params(axis="x", labelsize=8)

    plt.tight_layout()
    plt.savefig(OUT_PNG, dpi=150, bbox_inches="tight")
    print(f"Saved → {OUT_PNG}")


if __name__ == "__main__":
    main()
