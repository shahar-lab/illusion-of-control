"""
Two-panel WSLS overview for all 18 subjects.

Panel 1 — Running WSLS (30-trial window) for every subject, overlaid.
Panel 2 — Scatter: P(stay|win) vs P(stay|lose) per subject.
           Scatter follows plot-scatter skill: equal axes, diagonal reference,
           linear trend, Pearson r top-right, 4 ticks, Okabe-Ito colours.

Colour coding (both panels):
  Blue  #0072B2 — 13 subjects: understood 50/50/50 AND felt_different="no"
  Orange #E69F00 — 5 subjects: misunderstood OR felt odds differed
"""

import os
import re
import warnings
import numpy as np
import pandas as pd
from scipy.stats import pearsonr, linregress
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

warnings.filterwarnings("ignore")
os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_DIR = "../../data/ioc-all-fixed-pilot/task"
OUT_PNG  = "wsls_18_overview.png"
WINDOW   = 30

KEY_TO_ARM = {"arrowleft": 0, "arrowup": 1, "arrowright": 2}

MISUNDERSTOOD  = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}
OMITTED = MISUNDERSTOOD | FELT_DIFFERENT

COL_INC = "#0072B2"   # Okabe-Ito blue  — included (13)
COL_OMT = "#E69F00"   # Okabe-Ito orange — omitted  (5)


# ── data ─────────────────────────────────────────────────────────────────────
def load_subjects(data_dir):
    subjects = []
    for fname in sorted(os.listdir(data_dir)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-all_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        df = pd.read_csv(os.path.join(data_dir, fname), low_memory=False)
        gb = (
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
        choices = gb["choice_key"].map(KEY_TO_ARM).values.astype(int)
        rewards = gb["reward"].astype(float).values

        stay        = (choices[1:] == choices[:-1]).astype(float)
        reward_prev = rewards[:-1]

        # running WSLS
        T = len(choices)
        n_pts = T - WINDOW
        wsls = np.full(n_pts, np.nan)
        for i in range(WINDOW - 1, T - 1):
            s = stay[i - WINDOW + 1 : i + 1]
            r = reward_prev[i - WINDOW + 1 : i + 1]
            wm, lm = r == 1, r == 0
            if wm.sum() > 0 and lm.sum() > 0:
                wsls[i - (WINDOW - 1)] = s[wm].mean() - s[lm].mean()
        x = np.arange(WINDOW + 1, T + 1)

        # overall P(stay|win) and P(stay|lose)
        p_win  = float(stay[reward_prev == 1].mean()) if (reward_prev == 1).sum() > 0 else np.nan
        p_lose = float(stay[reward_prev == 0].mean()) if (reward_prev == 0).sum() > 0 else np.nan

        subjects.append({
            "pid":     pid,
            "omitted": pid in OMITTED,
            "x":       x,
            "wsls":    wsls,
            "p_win":   p_win,
            "p_lose":  p_lose,
        })
    return subjects


# ── figure ───────────────────────────────────────────────────────────────────
def main():
    subjects = load_subjects(DATA_DIR)
    print(f"Loaded {len(subjects)} subjects")

    included = [s for s in subjects if not s["omitted"]]
    omitted  = [s for s in subjects if s["omitted"]]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    # ── Panel 1: running WSLS ─────────────────────────────────────────────────
    block_starts = [51, 76, 101, 126]
    for bs in block_starts:
        ax1.axvline(bs, color="#dddddd", linewidth=0.8, zorder=1)
    ax1.axhline(0, color="#888888", linewidth=0.8, linestyle="--", zorder=2)

    for s in omitted:
        ax1.plot(s["x"], s["wsls"], color=COL_OMT,
                 linewidth=0.8, alpha=0.45, zorder=3)
    for s in included:
        ax1.plot(s["x"], s["wsls"], color=COL_INC,
                 linewidth=0.8, alpha=0.45, zorder=3)

    # group mean lines
    def group_mean(grp):
        max_x = max(len(s["wsls"]) for s in grp)
        mat   = np.full((len(grp), max_x), np.nan)
        for j, s in enumerate(grp):
            mat[j, :len(s["wsls"])] = s["wsls"]
        return np.nanmean(mat, axis=0)

    x_inc = np.arange(WINDOW + 1, 151)
    ax1.plot(x_inc, group_mean(included), color=COL_INC,
             linewidth=2.0, zorder=4, label=f"Included (n={len(included)})")
    # omitted group mean (some may be shorter)
    x_omt = np.arange(WINDOW + 1, 151)
    ax1.plot(x_omt, group_mean(omitted), color=COL_OMT,
             linewidth=2.0, zorder=4, label=f"Omitted (n={len(omitted)})")

    ax1.set_xlim(WINDOW + 1, 150)
    ax1.set_ylim(-1.05, 1.05)
    ax1.set_xlabel("Trial", fontsize=10)
    ax1.set_ylabel("P(stay | win) − P(stay | loss)", fontsize=10)
    ax1.set_title("Running WSLS effect  (30-trial window)", fontsize=10, pad=6)
    ax1.legend(fontsize=8, framealpha=0.8, edgecolor="none")
    ax1.spines[["top", "right"]].set_visible(False)
    ax1.tick_params(labelsize=8)

    # ── Panel 2: scatter P(stay|win) vs P(stay|lose) ──────────────────────────
    p_win  = np.array([s["p_win"]  for s in subjects])
    p_lose = np.array([s["p_lose"] for s in subjects])
    colors = [COL_OMT if s["omitted"] else COL_INC for s in subjects]

    # equal axes on [0,1]
    shared_lo, shared_hi = 0.0, 1.0
    shared_limits = [shared_lo, shared_hi]
    axis_breaks = np.linspace(shared_lo, shared_hi, 4)

    # diagonal reference line (y = x)
    ax2.plot([shared_lo, shared_hi], [shared_lo, shared_hi],
             linestyle="--", color="grey", linewidth=0.9, zorder=1)

    # linear trend (all 18)
    mask = ~(np.isnan(p_win) | np.isnan(p_lose))
    slope, intercept, *_ = linregress(p_win[mask], p_lose[mask])
    x_fit = np.array([shared_lo, shared_hi])
    ax2.plot(x_fit, intercept + slope * x_fit,
             color="#EE6677", linewidth=1.2, zorder=2)

    # points
    for i in range(len(subjects)):
        ax2.scatter(p_win[i], p_lose[i],
                    color=colors[i], s=50, alpha=0.85, zorder=3)

    # Pearson r annotation (top-right, per skill)
    r, _ = pearsonr(p_win[mask], p_lose[mask])
    ax2.annotate(f"[Pearson r = {r:.2f}]",
                 xy=(1.0, 1.0), xycoords="axes fraction",
                 xytext=(-6, -6), textcoords="offset points",
                 ha="right", va="top", fontsize=8, color="#555555")

    ax2.set_xlim(shared_limits)
    ax2.set_ylim(shared_limits)
    ax2.set_aspect("equal")
    ax2.set_xticks(axis_breaks)
    ax2.set_yticks(axis_breaks)
    ax2.xaxis.set_major_formatter(plt.FormatStrFormatter("%.2f"))
    ax2.yaxis.set_major_formatter(plt.FormatStrFormatter("%.2f"))
    ax2.set_xlabel("P(stay | win)", fontsize=10)
    ax2.set_ylabel("P(stay | loss)", fontsize=10)
    ax2.set_title("Per-subject stay rates", fontsize=10, pad=6)
    ax2.spines[["top", "right"]].set_visible(False)
    ax2.tick_params(labelsize=8)

    legend_els = [
        Line2D([0], [0], marker="o", color="w", markerfacecolor=COL_INC,
               markersize=7, label=f"Included (n={len(included)})"),
        Line2D([0], [0], marker="o", color="w", markerfacecolor=COL_OMT,
               markersize=7, label=f"Omitted (n={len(omitted)})"),
    ]
    ax2.legend(handles=legend_els, fontsize=8, loc="upper left",
               framealpha=0.8, edgecolor="none")

    plt.tight_layout()
    plt.savefig(OUT_PNG, dpi=150, bbox_inches="tight")
    print(f"Saved → {OUT_PNG}")


if __name__ == "__main__":
    main()
