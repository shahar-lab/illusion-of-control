"""
Running WSLS effect for the 13 subjects who understood correctly and felt
the odds matched (understood 50/50/50 AND felt_different == "no").

At each trial t (31 to T), look back at the 30 most recent consecutive
trial pairs and compute:
    WSLS(t) = P(stay | reward_prev=1) - P(stay | reward_prev=0)

stay at trial t is defined as: choice(t) == choice(t-1), crossing block
boundaries included.  Panels are sorted by subject median WSLS effect.
"""

import os
import re
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

warnings.filterwarnings("ignore")

os.chdir(os.path.dirname(os.path.abspath(__file__)))

DATA_DIR = "../../data/ioc-all-fixed-pilot/task"
OUT_PNG  = "running_wsls.png"
WINDOW   = 30

KEY_TO_ARM = {"arrowleft": 0, "arrowup": 1, "arrowright": 2}

MISUNDERSTOOD  = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}

LINE_COL = "#0072B2"   # Okabe-Ito blue
ZERO_COL = "#888888"
BLOCK_COL = "#cccccc"


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
        if pid in MISUNDERSTOOD or pid in FELT_DIFFERENT:
            continue
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
        subjects.append({"pid": pid, "choices": choices, "rewards": rewards})
    return subjects


# ── running WSLS ─────────────────────────────────────────────────────────────
def running_wsls(choices, rewards, window=WINDOW):
    T = len(choices)
    # stay[i] and reward_prev[i] defined for i = 1 ... T-1
    stay        = (choices[1:] == choices[:-1]).astype(float)
    reward_prev = rewards[:-1]

    # evaluation points: window to T-1 (0-based in the pairs array)
    # corresponds to trial numbers window+1 to T (1-based)
    n_points = T - window
    wsls = np.full(n_points, np.nan)
    for i in range(window - 1, T - 1):
        idx = i - (window - 1)
        s = stay[i - window + 1 : i + 1]
        r = reward_prev[i - window + 1 : i + 1]
        win_mask  = r == 1
        lose_mask = r == 0
        if win_mask.sum() > 0 and lose_mask.sum() > 0:
            wsls[idx] = s[win_mask].mean() - s[lose_mask].mean()

    x = np.arange(window + 1, T + 1)   # trial numbers (1-based)
    return x, wsls


# ── plot ─────────────────────────────────────────────────────────────────────
def main():
    subjects = load_subjects(DATA_DIR)
    print(f"Loaded {len(subjects)} subjects")

    # compute running WSLS for each subject
    for s in subjects:
        s["x"], s["wsls"] = running_wsls(s["choices"], s["rewards"])
        s["median_wsls"] = float(np.nanmedian(s["wsls"]))

    # sort panels by median WSLS (ascending)
    subjects = sorted(subjects, key=lambda s: s["median_wsls"])

    n      = len(subjects)
    ncols  = 5
    nrows  = int(np.ceil(n / ncols))    # 3 rows
    fig, axes = plt.subplots(nrows, ncols,
                             figsize=(15, nrows * 3),
                             sharey=False)
    axes_flat = axes.flatten()

    # block start trials visible within x range (31-150): 51, 76, 101, 126
    block_starts = [51, 76, 101, 126]

    for i, s in enumerate(subjects):
        ax = axes_flat[i]
        ax.axhline(0, color=ZERO_COL, linewidth=0.8, linestyle="--", zorder=1)
        for bs in block_starts:
            ax.axvline(bs, color=BLOCK_COL, linewidth=0.8, zorder=1)

        ax.plot(s["x"], s["wsls"],
                color=LINE_COL, linewidth=1.0, alpha=0.85, zorder=2)

        ax.set_title(f"P{i+1:02d}  (med={s['median_wsls']:.2f})",
                     fontsize=8, pad=3)
        ax.set_xlim(WINDOW + 1, 150)
        ax.set_ylim(-1.05, 1.05)
        ax.set_xlabel("Trial", fontsize=7)
        ax.set_ylabel("P(stay|win) − P(stay|lose)", fontsize=7)
        ax.tick_params(labelsize=6)
        ax.spines[["top", "right"]].set_visible(False)

    # hide unused panels
    for j in range(n, len(axes_flat)):
        axes_flat[j].set_visible(False)

    fig.suptitle(
        "P(stay | win) − P(stay | loss)  as to 30 previous trials",
        fontsize=10, y=1.01
    )
    plt.tight_layout()
    plt.savefig(OUT_PNG, dpi=150, bbox_inches="tight")
    print(f"Saved → {OUT_PNG}")


if __name__ == "__main__":
    main()
