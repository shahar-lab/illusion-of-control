"""
Per-trial response time overlaid with 30-back WSLS for 13 valid subjects.
WSLS on left y-axis (trial 31–150), RT in ms on right y-axis (trial 1–150).
"""

import os
import re
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

warnings.filterwarnings("ignore")

os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_DIR = "../../data/ioc-all-fixed-pilot/task"

MISUNDERSTOOD  = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}
EXCLUDED = MISUNDERSTOOD | FELT_DIFFERENT

KEY_TO_ARM   = {"arrowleft": 0, "arrowup": 1, "arrowright": 2}
WINDOW       = 30
BLOCK_STARTS = [51, 76, 101, 126]

WSLS_COL  = "#0072B2"   # blue
RT_COL    = "#CC79A7"   # reddish purple
ZERO_COL  = "#888888"
BLOCK_COL = "#cccccc"


def load_subjects(data_dir):
    subjects = []
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
        choices = gb["choice_key"].map(KEY_TO_ARM).values.astype(int)
        rewards = gb["reward"].astype(float).values
        rt      = gb["rt"].astype(float).values
        subjects.append({
            "pid":      pid,
            "excluded": pid in EXCLUDED,
            "choices":  choices,
            "rewards":  rewards,
            "rt":       rt,
        })
    return subjects


def running_wsls(choices, rewards, window=WINDOW):
    T           = len(choices)
    stay        = (choices[1:] == choices[:-1]).astype(float)
    reward_prev = rewards[:-1]
    wsls        = np.full(T - window, np.nan)
    for i in range(window - 1, T - 1):
        idx      = i - (window - 1)
        s        = stay[i - window + 1 : i + 1]
        r        = reward_prev[i - window + 1 : i + 1]
        win_mask = r == 1; lose_mask = r == 0
        if win_mask.sum() > 0 and lose_mask.sum() > 0:
            wsls[idx] = s[win_mask].mean() - s[lose_mask].mean()
    return np.arange(window + 1, T + 1), wsls


def plot_wsls_rt(subjects, mu_rt, rt_half, out_path):
    """
    mu_rt    : global mean RT (ms) — maps to y=0 on right axis
    rt_half  : half-range of right axis in ms, chosen so that
               1 SD of RT looks like 1 SD of WSLS visually
    """
    n     = len(subjects)
    ncols = 5
    nrows = int(np.ceil(n / ncols))

    fig, axes = plt.subplots(nrows, ncols, figsize=(15, nrows * 3.2), sharey=False)
    axes_flat = axes.flatten()

    for i, s in enumerate(subjects):
        ax_l = axes_flat[i]
        ax_r = ax_l.twinx()

        ax_l.axhline(0, color=ZERO_COL, linewidth=0.7, linestyle="--", zorder=1)
        ax_r.axhline(mu_rt, color=ZERO_COL, linewidth=0.7, linestyle="--", zorder=1)
        for bs in BLOCK_STARTS:
            ax_l.axvline(bs, color=BLOCK_COL, linewidth=0.8, zorder=1)

        # RT — right y-axis, trials 31+
        trial_x = np.arange(WINDOW + 1, len(s["rt"]) + 1)
        rt_vals = s["rt"][WINDOW:]
        ax_r.plot(trial_x, rt_vals, color=RT_COL, linewidth=0.7, alpha=0.6, zorder=2)
        ax_r.set_ylim(mu_rt - rt_half, mu_rt + rt_half)
        ax_r.set_ylabel("RT (ms)", fontsize=6, color=RT_COL)
        ax_r.tick_params(axis="y", labelsize=5, labelcolor=RT_COL)

        # WSLS — left y-axis, trials 31+
        ax_l.plot(s["x"], s["wsls"], color=WSLS_COL, linewidth=1.1, alpha=0.9, zorder=3)
        ax_l.set_ylim(-1.05, 1.05)
        ax_l.set_ylabel("WSLS", fontsize=6, color=WSLS_COL)
        ax_l.tick_params(axis="y", labelsize=5, labelcolor=WSLS_COL)

        ax_l.set_title(
            f"P{i+1:02d}  med(WSLS)={s['median_wsls']:.2f}"
            f"  med(RT)={np.nanmedian(s['rt']):.0f} ms",
            fontsize=6, pad=3,
        )
        ax_l.set_xlim(WINDOW + 1, 150)
        ax_l.set_xlabel("Trial", fontsize=6)
        ax_l.tick_params(axis="x", labelsize=5)
        ax_l.spines[["top"]].set_visible(False)
        ax_r.spines[["top"]].set_visible(False)

    legend_elements = [
        Line2D([0], [0], color=WSLS_COL, linewidth=1.1, label="WSLS (left)"),
        Line2D([0], [0], color=RT_COL,   linewidth=0.7, label="RT ms (right)"),
    ]
    axes_flat[0].legend(handles=legend_elements, fontsize=5, loc="upper right")

    for j in range(n, len(axes_flat)):
        axes_flat[j].set_visible(False)

    fig.suptitle(
        "P(stay|win)−P(stay|loss) [blue, left]  ·  Response time [purple, right]  "
        f"(right axis centred at mean RT = {mu_rt:.0f} ms)",
        fontsize=10, y=1.01,
    )
    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved → {out_path}")


def main():
    all_subjects = load_subjects(DATA_DIR)

    valid = [s for s in all_subjects if not s["excluded"]]
    print(f"Valid subjects: {len(valid)}")

    for s in valid:
        s["x"], s["wsls"] = running_wsls(s["choices"], s["rewards"])
        s["median_wsls"]  = float(np.nanmedian(s["wsls"]))

    valid.sort(key=lambda s: s["median_wsls"])

    # ── global scaling: trials 31+ only ──────────────────────────────────────
    all_rt_31   = np.concatenate([s["rt"][WINDOW:] for s in valid])
    all_wsls    = np.concatenate([s["wsls"] for s in valid])
    mu_rt       = np.nanmean(all_rt_31)
    std_rt      = np.nanstd(all_rt_31)
    std_wsls    = np.nanstd(all_wsls[~np.isnan(all_wsls)])
    # right axis half-range: 1 SD of RT maps to 1 SD of WSLS visually
    rt_half     = 1.05 * (std_rt / std_wsls)
    print(f"Global mean RT (trials 31+): {mu_rt:.0f} ms")
    print(f"RT std: {std_rt:.0f} ms  |  WSLS std: {std_wsls:.3f}")
    print(f"Right axis: [{mu_rt - rt_half:.0f}, {mu_rt + rt_half:.0f}] ms")

    plot_wsls_rt(valid, mu_rt=mu_rt, rt_half=rt_half, out_path="running_wsls_rt.png")
    print("Done.")


if __name__ == "__main__":
    main()
