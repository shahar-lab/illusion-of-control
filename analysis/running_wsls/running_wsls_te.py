"""
Running WSLS + Transfer Entropy (Ω) for 13 valid subjects
(understood 50/50/50 AND felt_different == "no").

State  S  : previous coin outcome — win=1, loss=0
Action A  : arm chosen — left=0, up=1, right=2
Next st S': current coin outcome — win=1, loss=0

P_actor[s, a] = P(win | prev_outcome=s, arm=a), init 0.5
P_spec[s]     = P(win | prev_outcome=s),         init 0.5
Ω             = leaky integrator of instantaneous TE, init 0

inst_causality (standard): P_actor(S'_obs | A, S) − P_spec(S'_obs | S)
  — sign flips on loss trials (observing 0 means we use the "loss" column)

inst_causality (always-win, approach 3): P_actor(win | A, S) − P_spec(win | S)
  — always the win column; subjects attend to arm's win probability regardless
    of the actual outcome (illusion of control: "I expect to win")

Three α approaches:
  A1  fixed α = 0.537 for all subjects
      (group posterior median from our RL fit: sigmoid(median(mu_alpha)))
  A2  per-subject α (posterior median from draws_m1.nc, M1 RL model)
  A3  per-subject α same as A2, but inst_causality uses always-win formula

All three:
  • same α for P_actor, P_spec, and Ω updates
  • no block-boundary resets
  • trial 1 skipped (no previous outcome)
  • Ω plotted from trial 31 onward (matching the WSLS 30-trial rolling window)
"""

import os
import re
import warnings
import numpy as np
import pandas as pd
import arviz as az
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

warnings.filterwarnings("ignore")

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# ── paths ─────────────────────────────────────────────────────────────────────
DATA_DIR   = "../../data/ioc-all-fixed-pilot/task"
DRAWS_PATH = "../param_recovery/draws_m1.nc"

# ── exclusions (same as running_wsls.py) ─────────────────────────────────────
MISUNDERSTOOD  = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {
    "677009b08130c3028f6a8a6d",
    "68598a1d4cebd213b2abb1d9",
    "69b7e04340b00585acbb91ac",
    "6a0092581cd317f1ff1765a2",
}
EXCLUDED = MISUNDERSTOOD | FELT_DIFFERENT

KEY_TO_ARM = {"arrowleft": 0, "arrowup": 1, "arrowright": 2}
WINDOW     = 30

# approach 1: fixed group-level α
ALPHA_GROUP = 0.537


# ── colours ──────────────────────────────────────────────────────────────────
WSLS_COL  = "#0072B2"   # Okabe-Ito blue
OMG_COL   = "#D55E00"   # Okabe-Ito vermillion
ZERO_COL  = "#888888"
BLOCK_COL = "#cccccc"
BLOCK_STARTS = [51, 76, 101, 126]


# ── data loading ──────────────────────────────────────────────────────────────
def load_subjects(data_dir):
    """Load all valid subjects in sorted order (matches draws_m1.nc indexing)."""
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
        subjects.append({
            "pid":         pid,
            "excluded":    pid in EXCLUDED,
            "choices":     choices,
            "rewards":     rewards,
        })
    return subjects


def load_per_subject_alpha(draws_path, n_all):
    """
    Read draws_m1.nc and return median α for each of the n_all subjects
    in the same sorted order as load_subjects().
    """
    idata  = az.from_netcdf(draws_path)
    alpha  = idata.posterior["alpha_sbj"].values   # (chains, draws, subjects)
    flat   = alpha.reshape(-1, alpha.shape[-1])    # (total_draws, subjects)
    return np.median(flat, axis=0)                 # shape (n_all,)


# ── running WSLS ──────────────────────────────────────────────────────────────
def running_wsls(choices, rewards, window=WINDOW):
    """30-trial rolling WSLS: P(stay|win) − P(stay|loss)."""
    T           = len(choices)
    stay        = (choices[1:] == choices[:-1]).astype(float)
    reward_prev = rewards[:-1]
    n_points    = T - window
    wsls        = np.full(n_points, np.nan)
    for i in range(window - 1, T - 1):
        idx       = i - (window - 1)
        s         = stay[i - window + 1 : i + 1]
        r         = reward_prev[i - window + 1 : i + 1]
        win_mask  = r == 1
        lose_mask = r == 0
        if win_mask.sum() > 0 and lose_mask.sum() > 0:
            wsls[idx] = s[win_mask].mean() - s[lose_mask].mean()
    x = np.arange(window + 1, T + 1)
    return x, wsls


# ── TE / Ω estimation ─────────────────────────────────────────────────────────
def compute_omega(choices, rewards, alpha, always_win=False):
    """
    Compute trial-by-trial Ω for a single subject.

    Parameters
    ----------
    choices    : int array, length T
    rewards    : float array {0,1}, length T
    alpha      : scalar learning rate (same for actor, spectator, Ω)
    always_win : if True, use inst_causality = P_actor(win|A,S) − P_spec(win|S)
                 every trial (approach 3); otherwise use the observed-outcome
                 column (approaches 1 & 2).

    Returns
    -------
    omega_trace : float array, length T (nan for trial 0)
    """
    N_STATES = 2
    N_ARMS   = 3

    P_actor = np.full((N_STATES, N_ARMS), 0.5)  # P(win | prev_outcome, arm)
    P_spec  = np.full(N_STATES, 0.5)            # P(win | prev_outcome)
    omega   = 0.0

    T           = len(choices)
    omega_trace = np.full(T, np.nan)

    for t in range(1, T):
        s       = int(rewards[t - 1])   # previous outcome (0 or 1)
        a       = int(choices[t])       # current arm
        s_prime = int(rewards[t])       # current outcome (0 or 1)

        # ── instantaneous causality ───────────────────────────────────────────
        if always_win:
            # always look at the "win" column regardless of actual s_prime
            inst = P_actor[s, a] - P_spec[s]
        else:
            # standard: use the probability of the OBSERVED next state
            if s_prime == 1:
                inst = P_actor[s, a] - P_spec[s]
            else:
                inst = (1.0 - P_actor[s, a]) - (1.0 - P_spec[s])
                # = P_spec[s] - P_actor[s, a]  (sign flips for loss trials)

        # ── update Ω (leaky integrator) ───────────────────────────────────────
        omega = omega + alpha * (inst - omega)
        omega_trace[t] = omega

        # ── update probability models (Rescorla-Wagner, actual outcomes) ──────
        delta_actor = float(s_prime) - P_actor[s, a]
        delta_spec  = float(s_prime) - P_spec[s]
        P_actor[s, a] = np.clip(P_actor[s, a] + alpha * delta_actor, 1e-6, 1 - 1e-6)
        P_spec[s]     = np.clip(P_spec[s]     + alpha * delta_spec,  1e-6, 1 - 1e-6)

    return omega_trace


# ── plotting ──────────────────────────────────────────────────────────────────
def plot_approach(subjects, approach_label, out_path):
    """
    Draw a 3×5 grid (13 panels) of WSLS + Ω, sorted by median WSLS.
    Each panel has a shared x-axis; WSLS on the left y-axis, Ω on the right.
    """
    n      = len(subjects)
    ncols  = 5
    nrows  = int(np.ceil(n / ncols))

    fig, axes = plt.subplots(
        nrows, ncols,
        figsize=(15, nrows * 3.2),
        sharey=False,
    )
    axes_flat = axes.flatten()

    for i, s in enumerate(subjects):
        ax_left  = axes_flat[i]
        ax_right = ax_left.twinx()

        # reference lines + block markers
        for ax in (ax_left, ax_right):
            ax.axhline(0, color=ZERO_COL, linewidth=0.7, linestyle="--", zorder=1)
        for bs in BLOCK_STARTS:
            ax_left.axvline(bs, color=BLOCK_COL, linewidth=0.8, zorder=1)

        # ── WSLS (left axis) ─────────────────────────────────────────────────
        ax_left.plot(
            s["x"], s["wsls"],
            color=WSLS_COL, linewidth=1.1, alpha=0.9, zorder=3,
            label="WSLS",
        )
        ax_left.set_ylim(-1.05, 1.05)
        ax_left.set_ylabel("WSLS", fontsize=6, color=WSLS_COL)
        ax_left.tick_params(axis="y", labelsize=5, labelcolor=WSLS_COL)

        # ── Ω (right axis) ───────────────────────────────────────────────────
        x_te  = s["x"]                         # same x as WSLS (trial 31..T)
        omega = s["omega_plot"]                 # Ω values for those same trials
        ax_right.plot(
            x_te, omega,
            color=OMG_COL, linewidth=1.0, alpha=0.85, zorder=2,
            label="Ω",
        )
        ax_right.set_ylabel("Ω", fontsize=6, color=OMG_COL)
        ax_right.tick_params(axis="y", labelsize=5, labelcolor=OMG_COL)

        # ── panel title ──────────────────────────────────────────────────────
        alpha_str = f"α={s['alpha_used']:.2f}" if s.get("alpha_used") is not None else ""
        ax_left.set_title(
            f"P{i+1:02d}  med(WSLS)={s['median_wsls']:.2f}  {alpha_str}",
            fontsize=7, pad=3,
        )
        ax_left.set_xlim(WINDOW + 1, 150)
        ax_left.set_xlabel("Trial", fontsize=6)
        ax_left.tick_params(axis="x", labelsize=5)
        ax_left.spines[["top"]].set_visible(False)
        ax_right.spines[["top"]].set_visible(False)

    for j in range(n, len(axes_flat)):
        axes_flat[j].set_visible(False)

    fig.suptitle(
        f"P(stay|win)−P(stay|loss) [blue, left]  vs  Ω [orange, right]  —  {approach_label}",
        fontsize=10, y=1.01,
    )
    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved → {out_path}")


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    # load all 18 subjects (including excluded ones, to preserve index ordering)
    all_subjects = load_subjects(DATA_DIR)
    n_all        = len(all_subjects)
    print(f"Total subjects loaded: {n_all}")

    # per-subject α from RL model fit (all 18, then we select valid ones)
    alpha_per_subj = load_per_subject_alpha(DRAWS_PATH, n_all)
    print(f"Per-subject α (M1 posterior medians): {np.round(alpha_per_subj, 3)}")

    # attach alphas and exclude
    valid = []
    for i, s in enumerate(all_subjects):
        s["alpha_rl"] = float(alpha_per_subj[i])
        if not s["excluded"]:
            valid.append(s)

    print(f"Valid subjects: {len(valid)}")

    # ── compute WSLS + Ω for each approach ────────────────────────────────────
    for s in valid:
        choices = s["choices"]
        rewards = s["rewards"]

        # rolling WSLS
        s["x"], s["wsls"] = running_wsls(choices, rewards)
        s["median_wsls"]  = float(np.nanmedian(s["wsls"]))

        # Ω traces (full length T)
        omega_a1 = compute_omega(choices, rewards, ALPHA_GROUP, always_win=False)
        omega_a2 = compute_omega(choices, rewards, s["alpha_rl"], always_win=False)
        omega_a3 = compute_omega(choices, rewards, s["alpha_rl"], always_win=True)

        # slice Ω to match the WSLS x-range (trials 31..T, 1-based)
        # s["x"] contains 1-based trial numbers starting at WINDOW+1=31
        # omega_trace index t corresponds to 1-based trial t+1
        # so for 1-based trial n, index = n-1
        idx = s["x"] - 1   # 0-based indices into the omega arrays
        s["omega_a1"] = omega_a1[idx]
        s["omega_a2"] = omega_a2[idx]
        s["omega_a3"] = omega_a3[idx]

    # sort by median WSLS (ascending) — same order as running_wsls.py
    valid.sort(key=lambda s: s["median_wsls"])

    # ── Approach 1: fixed group α ─────────────────────────────────────────────
    for s in valid:
        s["omega_plot"] = s["omega_a1"]
        s["alpha_used"] = ALPHA_GROUP
    plot_approach(
        valid,
        approach_label=f"A1: fixed group α = {ALPHA_GROUP:.3f}  (RL posterior median)",
        out_path="running_wsls_te_a1.png",
    )

    # ── Approach 2: per-subject α, standard TE ───────────────────────────────
    for s in valid:
        s["omega_plot"] = s["omega_a2"]
        s["alpha_used"] = s["alpha_rl"]
    plot_approach(
        valid,
        approach_label="A2: per-subject α (RL fit)  ·  standard TE",
        out_path="running_wsls_te_a2.png",
    )

    # ── Approach 3: per-subject α, always-win TE ─────────────────────────────
    for s in valid:
        s["omega_plot"] = s["omega_a3"]
        s["alpha_used"] = s["alpha_rl"]
    plot_approach(
        valid,
        approach_label="A3: per-subject α (RL fit)  ·  always-win TE  (inst = P_actor(win|A,S)−P_spec(win|S))",
        out_path="running_wsls_te_a3.png",
    )

    print("Done.")


if __name__ == "__main__":
    main()
