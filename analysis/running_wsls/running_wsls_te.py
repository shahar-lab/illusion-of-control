"""
Running WSLS + Transfer Entropy for 13 valid subjects
(understood 50/50/50 AND felt_different == "no").

State  S  : previous coin outcome — win=1, loss=0
Action A  : arm chosen — left=0, up=1, right=2
Next st S': current coin outcome — win=1, loss=0

P_actor[s, a] = P(win | prev_outcome=s, arm=a), init 0.5
P_spec[s]     = P(win | prev_outcome=s),         init 0.5
Ω             = leaky integrator of instantaneous TE, init 0
ω             = 1 / (1 + exp(−β_Ω × (Ω − thresh_Ω)))   [Ligneul 2022 eq.]

Personalisation (Ligneul 2022, Uncontrollable Group):
  z_α_i  = (α_RL_i − mean(α_RL)) / std(α_RL)  across 13 valid subjects
  z_β_i  = (β_RL_i − mean(β_RL)) / std(β_RL)  across 13 valid subjects

  α_SAS'_i = α_SS'_i = clip(0.47 + z_α_i × 0.23, ε, 1−ε)
  α_Ω_i               = clip(0.41 + z_α_i × 0.18, ε, 1−ε)
  β_Ω_i               = clip(96.22 + z_β_i × 164.28, ε, ∞)
  thresh_Ω            = 0.23 (paper mean, same for all subjects)

Standard TE: inst_causality sign flips on loss trials.
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
from matplotlib.lines import Line2D

warnings.filterwarnings("ignore")

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# ── paths ─────────────────────────────────────────────────────────────────────
DATA_DIR   = "../../data/ioc-all-fixed-pilot/task"
DRAWS_PATH = "../param_recovery/draws_m1.nc"

# ── exclusions ────────────────────────────────────────────────────────────────
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
EPS        = 1e-6

# ── paper parameters (Ligneul 2022, Uncontrollable Group) ────────────────────
PAPER_MU_SAS   = 0.47;  PAPER_SD_SAS   = 0.23
PAPER_MU_OM    = 0.41;  PAPER_SD_OM    = 0.18
PAPER_MU_BETA  = 96.22; PAPER_SD_BETA  = 164.28
THRESH_OM      = 0.23   # paper mean, same for all subjects

# ── colours (Okabe-Ito palette) ───────────────────────────────────────────────
WSLS_COL  = "#0072B2"   # blue
OM_COL    = "#D55E00"   # vermillion
ZERO_COL  = "#888888"
BLOCK_COL = "#cccccc"
BLOCK_STARTS = [51, 76, 101, 126]


# ── data loading ──────────────────────────────────────────────────────────────
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
        subjects.append({
            "pid":      pid,
            "excluded": pid in EXCLUDED,
            "choices":  choices,
            "rewards":  rewards,
        })
    return subjects


def load_rl_params(draws_path, n_all):
    """Return per-subject posterior medians for α and β."""
    idata = az.from_netcdf(draws_path)
    def median_param(name):
        vals = idata.posterior[name].values          # (chains, draws, subjects)
        return np.median(vals.reshape(-1, n_all), axis=0)
    return median_param("alpha_sbj"), median_param("beta_sbj")


# ── running WSLS ──────────────────────────────────────────────────────────────
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


# ── TE estimation ─────────────────────────────────────────────────────────────
def compute_omega(choices, rewards, alpha_sas, alpha_ss, alpha_omega):
    """
    Return Ω trace (leaky-integrated instantaneous TE), length T, nan at t=0.

    Realization-matrix formulation:
      P_actor[s, a, s'] = P(S'=s' | prev=s, arm=a)   shape (2, 3, 2)
      P_spec[s, s']     = P(S'=s' | prev=s)           shape (2, 2)
    Each entry is the probability that a particular next-state occurred.
    The Rescorla-Wagner target is always 1.0 for the realized s' and the
    complementary entry is kept as 1 − P (normalisation), so no sign flip
    is needed in the inst calculation.
    """
    # realization matrices: P[..., s'] = prob that next state s' occurs
    P_actor = np.full((2, 3, 2), 0.5)   # P(S'=s' | prev=s, arm=a)
    P_spec  = np.full((2, 2),    0.5)   # P(S'=s' | prev=s)
    omega   = 0.0
    T           = len(choices)
    omega_trace = np.full(T, np.nan)

    for t in range(1, T):
        s       = int(rewards[t - 1])   # previous outcome
        a       = int(choices[t])       # current arm
        s_prime = int(rewards[t])       # realized next state

        # inst = p_actor(realized s' | a, s) − p_spec(realized s' | s)
        inst = P_actor[s, a, s_prime] - P_spec[s, s_prime]

        omega = omega + alpha_omega * (inst - omega)
        omega_trace[t] = omega

        # Rescorla-Wagner: target = 1.0 (the realized state happened)
        P_actor[s, a, s_prime] = np.clip(
            P_actor[s, a, s_prime] + alpha_sas * (1.0 - P_actor[s, a, s_prime]),
            EPS, 1 - EPS,
        )
        P_actor[s, a, 1 - s_prime] = 1.0 - P_actor[s, a, s_prime]   # normalise

        P_spec[s, s_prime] = np.clip(
            P_spec[s, s_prime] + alpha_ss * (1.0 - P_spec[s, s_prime]),
            EPS, 1 - EPS,
        )
        P_spec[s, 1 - s_prime] = 1.0 - P_spec[s, s_prime]

    return omega_trace


def omega_to_small(omega_trace, beta_om, thresh=THRESH_OM):
    """Apply sigmoid: ω = 1 / (1 + exp(−β_Ω × (Ω − thresh)))."""
    return 1.0 / (1.0 + np.exp(-beta_om * (omega_trace - thresh)))


CAPTION = (
    r"$\Omega(t) = \Omega(t{-}1) + \alpha_\Omega\,[p_{SAS'}(S'|A,S) - p_{SS'}(S'|S) - \Omega(t{-}1)]$, "
    r"where $p_{SAS'}$ and $p_{SS'}$ are Rescorla–Wagner estimates updated by $\alpha_{SAS'}$ "
    r"and $\alpha_{SS'}$, respectively; all learning rates personalised by mapping each subject's "
    r"RL-fit $\alpha$ z-score onto Uncontrollable Group distributions (Ligneul et al., 2022)."
)


# ── plotting ──────────────────────────────────────────────────────────────────
def plot_wsls_omega(subjects, omega_lim, out_path):
    """
    3×5 grid (13 panels): WSLS on left y-axis, Ω on right y-axis.
    omega_lim : shared y-limit for all right axes (global max |Ω| across subjects).
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
        ax_r.axhline(0, color=ZERO_COL, linewidth=0.7, linestyle="--", zorder=1)
        for bs in BLOCK_STARTS:
            ax_l.axvline(bs, color=BLOCK_COL, linewidth=0.8, zorder=1)

        # WSLS — left y-axis
        ax_l.plot(s["x"], s["wsls"], color=WSLS_COL, linewidth=1.1, alpha=0.9, zorder=3)
        ax_l.set_ylim(-1.05, 1.05)
        ax_l.set_ylabel("WSLS", fontsize=6, color=WSLS_COL)
        ax_l.tick_params(axis="y", labelsize=5, labelcolor=WSLS_COL)

        # Ω — right y-axis, fixed global scale
        ax_r.plot(s["x"], s["big_omega"], color=OM_COL, linewidth=1.0, alpha=0.85, zorder=2)
        ax_r.set_ylim(-omega_lim, omega_lim)
        ax_r.set_ylabel("Ω", fontsize=6, color=OM_COL)
        ax_r.tick_params(axis="y", labelsize=5, labelcolor=OM_COL)

        ax_l.set_title(
            f"P{i+1:02d}  med(WSLS)={s['median_wsls']:.2f}"
            f"  α_SAS={s['alpha_sas']:.2f}  α_Ω={s['alpha_om']:.2f}",
            fontsize=6, pad=3,
        )
        ax_l.set_xlim(WINDOW + 1, 150)
        ax_l.set_xlabel("Trial", fontsize=6)
        ax_l.tick_params(axis="x", labelsize=5)
        ax_l.spines[["top"]].set_visible(False)
        ax_r.spines[["top"]].set_visible(False)

    legend_elements = [
        Line2D([0], [0], color=WSLS_COL, linewidth=1.1, label="WSLS"),
        Line2D([0], [0], color=OM_COL,   linewidth=1.0, label="Ω"),
    ]
    axes_flat[0].legend(handles=legend_elements, fontsize=5, loc="upper left")

    for j in range(n, len(axes_flat)):
        axes_flat[j].set_visible(False)

    fig.suptitle(
        "P(stay|win)−P(stay|loss) [blue, left]  ·  Ω [vermillion, right]  —  personalised paper parameters",
        fontsize=10, y=1.01,
    )
    fig.text(0.5, -0.01, CAPTION, ha="center", va="top", fontsize=6.5, style="italic",
             wrap=True, transform=fig.transFigure)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved → {out_path}")


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    all_subjects = load_subjects(DATA_DIR)
    n_all        = len(all_subjects)
    print(f"Total subjects loaded: {n_all}")

    alpha_all, beta_all = load_rl_params(DRAWS_PATH, n_all)
    print(f"RL α medians: {np.round(alpha_all, 3)}")
    print(f"RL β medians: {np.round(beta_all, 3)}")

    valid = []
    for i, s in enumerate(all_subjects):
        s["alpha_rl"] = float(alpha_all[i])
        s["beta_rl"]  = float(beta_all[i])
        if not s["excluded"]:
            valid.append(s)
    print(f"Valid subjects: {len(valid)}")

    # ── z-score personalisation ───────────────────────────────────────────────
    alpha_v = np.array([s["alpha_rl"] for s in valid])
    beta_v  = np.array([s["beta_rl"]  for s in valid])

    z_alpha = (alpha_v - alpha_v.mean()) / alpha_v.std(ddof=1)
    z_beta  = (beta_v  - beta_v.mean())  / beta_v.std(ddof=1)

    print(f"RL α valid — mean={alpha_v.mean():.3f}, std={alpha_v.std(ddof=1):.3f}")
    print(f"RL β valid — mean={beta_v.mean():.3f},  std={beta_v.std(ddof=1):.3f}")

    for idx, s in enumerate(valid):
        s["alpha_sas"] = float(np.clip(PAPER_MU_SAS  + z_alpha[idx] * PAPER_SD_SAS,  EPS, 1 - EPS))
        s["alpha_ss"]  = float(np.clip(PAPER_MU_SAS  + z_alpha[idx] * PAPER_SD_SAS,  EPS, 1 - EPS))
        s["alpha_om"]  = float(np.clip(PAPER_MU_OM   + z_alpha[idx] * PAPER_SD_OM,   EPS, 1 - EPS))
        s["beta_om"]   = float(np.clip(PAPER_MU_BETA + z_beta[idx]  * PAPER_SD_BETA, EPS, np.inf))

    # ── compute WSLS + Ω per subject ─────────────────────────────────────────
    for s in valid:
        s["x"], s["wsls"] = running_wsls(s["choices"], s["rewards"])
        s["median_wsls"]  = float(np.nanmedian(s["wsls"]))

        omega_trace = compute_omega(
            s["choices"], s["rewards"],
            s["alpha_sas"], s["alpha_ss"], s["alpha_om"],
        )
        trial_idx      = s["x"] - 1   # 0-based indices for 1-based trial numbers
        s["big_omega"] = omega_trace[trial_idx]

    # global Ω limit: max |Ω| across all subjects (makes all right axes comparable)
    omega_lim = max(np.nanmax(np.abs(s["big_omega"])) for s in valid) * 1.05
    print(f"Global Ω limit: ±{omega_lim:.4f}")

    # sort by median WSLS ascending
    valid.sort(key=lambda s: s["median_wsls"])

    plot_wsls_omega(valid, omega_lim=omega_lim, out_path="running_wsls_te_paper.png")
    print("Done.")


if __name__ == "__main__":
    main()
