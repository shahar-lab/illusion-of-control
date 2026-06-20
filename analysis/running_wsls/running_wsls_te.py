"""
Running WSLS + Transfer Entropy (Ω) for 13 valid subjects
(understood 50/50/50 AND felt_different == "no").

State  S  : previous coin outcome — win=1, loss=0
Action A  : arm chosen — left=0, up=1, right=2
Next st S': current coin outcome — win=1, loss=0

P_actor[s, a] = P(win | prev_outcome=s, arm=a), init 0.5
P_spec[s]     = P(win | prev_outcome=s),         init 0.5
Ω             = leaky integrator of instantaneous TE, init 0

Two approaches, both plotted on the same 13 panels:

  Approach 1 — Personalized paper parameters, standard TE
    Per-subject z-score from RL-fit α distribution (13 valid subjects),
    mapped onto Uncontrollable-Group paper parameters (Ligneul et al. 2022):
      α_SAS'_i = α_SS'_i = clip(0.47 + z_i × 0.23, ε, 1−ε)
      α_Ω_i               = clip(0.41 + z_i × 0.18, ε, 1−ε)
    inst_causality (standard): P_actor(S'_obs | A, S) − P_spec(S'_obs | S)
      — sign flips on loss trials

  Approach 2 — RL α, always-win TE
    All three rates = per-subject median RL α (posterior from draws_m1.nc).
    inst_causality (always-win): P_actor(win | A, S) − P_spec(win | S)
      — always the win column; captures illusion-of-control framing
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

KEY_TO_ARM   = {"arrowleft": 0, "arrowup": 1, "arrowright": 2}
WINDOW       = 30
EPS          = 1e-6

# ── paper parameters (Ligneul 2022, Uncontrollable Group) ────────────────────
PAPER_MU_SAS  = 0.47
PAPER_SD_SAS  = 0.23
PAPER_MU_OM   = 0.41
PAPER_SD_OM   = 0.18

# ── colours (Okabe-Ito palette) ───────────────────────────────────────────────
WSLS_COL  = "#0072B2"   # blue
P1_COL    = "#D55E00"   # vermillion  — personalized paper α, standard TE
P2_COL    = "#009E73"   # bluish-green — RL α, always-win TE
ZERO_COL  = "#888888"
BLOCK_COL = "#cccccc"
BLOCK_STARTS = [51, 76, 101, 126]


# ── data loading ──────────────────────────────────────────────────────────────
def load_subjects(data_dir):
    """Load all subjects in sorted order (matches draws_m1.nc indexing)."""
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
            "pid":      pid,
            "excluded": pid in EXCLUDED,
            "choices":  choices,
            "rewards":  rewards,
        })
    return subjects


def load_per_subject_alpha(draws_path, n_all):
    """Return median α for each of n_all subjects from draws_m1.nc."""
    idata = az.from_netcdf(draws_path)
    alpha = idata.posterior["alpha_sbj"].values   # (chains, draws, subjects)
    flat  = alpha.reshape(-1, alpha.shape[-1])    # (total_draws, subjects)
    return np.median(flat, axis=0)                # shape (n_all,)


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
def compute_omega(choices, rewards, alpha_sas, alpha_ss, alpha_omega,
                  always_win=False):
    """
    Compute trial-by-trial Ω for a single subject.

    Parameters
    ----------
    choices     : int array, length T
    rewards     : float array {0,1}, length T
    alpha_sas   : learning rate for P_actor (SAS' model)
    alpha_ss    : learning rate for P_spec  (SS'  model)
    alpha_omega : learning rate for Ω leaky integrator
    always_win  : if True, inst = P_actor(win|A,S) − P_spec(win|S) every trial

    Returns
    -------
    omega_trace : float array, length T (nan for trial 0)
    """
    N_STATES = 2
    N_ARMS   = 3

    P_actor = np.full((N_STATES, N_ARMS), 0.5)   # P(win | prev_outcome, arm)
    P_spec  = np.full(N_STATES, 0.5)             # P(win | prev_outcome)
    omega   = 0.0

    T           = len(choices)
    omega_trace = np.full(T, np.nan)

    for t in range(1, T):
        s       = int(rewards[t - 1])   # previous outcome (0 or 1)
        a       = int(choices[t])       # current arm
        s_prime = int(rewards[t])       # current outcome (0 or 1)

        # ── instantaneous causality ───────────────────────────────────────────
        if always_win:
            inst = P_actor[s, a] - P_spec[s]
        else:
            if s_prime == 1:
                inst = P_actor[s, a] - P_spec[s]
            else:
                inst = (1.0 - P_actor[s, a]) - (1.0 - P_spec[s])

        # ── leaky-integrator Ω update ─────────────────────────────────────────
        omega = omega + alpha_omega * (inst - omega)
        omega_trace[t] = omega

        # ── Rescorla-Wagner probability updates ───────────────────────────────
        delta_actor   = float(s_prime) - P_actor[s, a]
        delta_spec    = float(s_prime) - P_spec[s]
        P_actor[s, a] = np.clip(P_actor[s, a] + alpha_sas * delta_actor, EPS, 1 - EPS)
        P_spec[s]     = np.clip(P_spec[s]     + alpha_ss  * delta_spec,  EPS, 1 - EPS)

    return omega_trace


# ── plotting ──────────────────────────────────────────────────────────────────
def plot_combined(subjects, out_path):
    """
    3×5 grid (13 panels), each showing WSLS + two Ω traces, sorted by median WSLS.
    """
    n     = len(subjects)
    ncols = 5
    nrows = int(np.ceil(n / ncols))

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
        ax_left.axhline(0,  color=ZERO_COL, linewidth=0.7, linestyle="--", zorder=1)
        ax_right.axhline(0, color=ZERO_COL, linewidth=0.7, linestyle="--", zorder=1)
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

        # ── Ω — personalized paper α, standard TE (vermillion) ───────────────
        ax_right.plot(
            s["x"], s["omega_p1"],
            color=P1_COL, linewidth=1.0, alpha=0.85, zorder=2,
            label="Ω paper",
        )

        # ── Ω — RL α, always-win TE (bluish-green) ───────────────────────────
        ax_right.plot(
            s["x"], s["omega_p2"],
            color=P2_COL, linewidth=1.0, alpha=0.85, zorder=2,
            label="Ω win",
        )

        ax_right.set_ylabel("Ω", fontsize=6)
        ax_right.tick_params(axis="y", labelsize=5)

        # ── panel title ──────────────────────────────────────────────────────
        ax_left.set_title(
            f"P{i+1:02d}  med(WSLS)={s['median_wsls']:.2f}"
            f"  α_RL={s['alpha_rl']:.2f}"
            f"  α_SAS={s['alpha_sas']:.2f} α_Ω={s['alpha_om']:.2f}",
            fontsize=6, pad=3,
        )
        ax_left.set_xlim(WINDOW + 1, 150)
        ax_left.set_xlabel("Trial", fontsize=6)
        ax_left.tick_params(axis="x", labelsize=5)
        ax_left.spines[["top"]].set_visible(False)
        ax_right.spines[["top"]].set_visible(False)

    # legend in first panel
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], color=WSLS_COL, linewidth=1.1, label="WSLS (left)"),
        Line2D([0], [0], color=P1_COL,   linewidth=1.0, label="Ω paper α (right)"),
        Line2D([0], [0], color=P2_COL,   linewidth=1.0, label="Ω always-win (right)"),
    ]
    axes_flat[0].legend(handles=legend_elements, fontsize=5, loc="upper left")

    for j in range(n, len(axes_flat)):
        axes_flat[j].set_visible(False)

    fig.suptitle(
        "P(stay|win)−P(stay|loss) [blue, left]  ·  "
        "Ω paper-α [vermillion, right]  ·  "
        "Ω always-win [green, right]",
        fontsize=10, y=1.01,
    )
    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved → {out_path}")


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    # load all subjects (preserve index ordering for draws_m1.nc)
    all_subjects = load_subjects(DATA_DIR)
    n_all        = len(all_subjects)
    print(f"Total subjects loaded: {n_all}")

    alpha_per_subj = load_per_subject_alpha(DRAWS_PATH, n_all)
    print(f"Per-subject α (M1 posterior medians): {np.round(alpha_per_subj, 3)}")

    # attach RL alphas and filter to valid subjects
    valid = []
    for i, s in enumerate(all_subjects):
        s["alpha_rl"] = float(alpha_per_subj[i])
        if not s["excluded"]:
            valid.append(s)
    print(f"Valid subjects: {len(valid)}")

    # ── z-score personalisation across the 13 valid subjects ─────────────────
    alpha_rl_valid = np.array([s["alpha_rl"] for s in valid])
    mean_rl = alpha_rl_valid.mean()
    std_rl  = alpha_rl_valid.std(ddof=1)
    print(f"RL α across valid subjects — mean={mean_rl:.3f}, std={std_rl:.3f}")

    for s in valid:
        z_i = (s["alpha_rl"] - mean_rl) / std_rl
        s["alpha_sas"] = float(np.clip(PAPER_MU_SAS + z_i * PAPER_SD_SAS, EPS, 1 - EPS))
        s["alpha_ss"]  = float(np.clip(PAPER_MU_SAS + z_i * PAPER_SD_SAS, EPS, 1 - EPS))
        s["alpha_om"]  = float(np.clip(PAPER_MU_OM  + z_i * PAPER_SD_OM,  EPS, 1 - EPS))

    # ── compute WSLS and both Ω traces ────────────────────────────────────────
    for s in valid:
        choices = s["choices"]
        rewards = s["rewards"]

        s["x"], s["wsls"] = running_wsls(choices, rewards)
        s["median_wsls"]  = float(np.nanmedian(s["wsls"]))

        # Approach 1: personalized paper alphas, standard TE
        omega_p1 = compute_omega(
            choices, rewards,
            s["alpha_sas"], s["alpha_ss"], s["alpha_om"],
            always_win=False,
        )
        # Approach 2: RL alpha for all rates, always-win TE
        omega_p2 = compute_omega(
            choices, rewards,
            s["alpha_rl"], s["alpha_rl"], s["alpha_rl"],
            always_win=True,
        )

        idx = s["x"] - 1   # 0-based indices matching 1-based trial numbers
        s["omega_p1"] = omega_p1[idx]
        s["omega_p2"] = omega_p2[idx]

    # sort by median WSLS ascending
    valid.sort(key=lambda s: s["median_wsls"])

    # ── produce single combined figure ────────────────────────────────────────
    plot_combined(valid, out_path="running_wsls_te.png")

    print("Done.")


if __name__ == "__main__":
    main()
