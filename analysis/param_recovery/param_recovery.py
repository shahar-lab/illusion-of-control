"""
Parameter recovery: two hierarchical Bayesian RL models on ioc-all-fixed-pilot (N=18)

Model 1 (M1): alpha, beta, kappa, delta  — full RL + perseveration with decay
Model 2 (M2): kappa, delta               — perseveration only

Perseveration trace E (per arm, 3-arm free-choice bandit):
  - Reset to [0, 0, 0] at start of each block
  - On arm switch: E[old] = 0, E[new] = 1
  - On arm stay:   E[chosen] *= delta
  Analytical form: at decision time t,
    E[a] = delta^(run_after[t-1] - 1)  if a == choices[t-1] and same block as t-1
           0                            otherwise
  where run_after[t-1] is the consecutive-same-arm run length ending at t-1
  within its block.

Q-values (Rescorla-Wagner):
  - Initialized at 0.5 once, persist across all blocks (no per-block reset)

Key mapping: arrowleft=green=0, arrowup=blue=1, arrowright=red=2

Output: param_recovery.png  (12 panels: 6 group + 6 subject-level)
  Row 1 (group): population-mean posterior for delta-M1, delta-M2,
                 kappa-M1, kappa-M2, alpha-M1, beta-M1
  Row 2 (subj) : per-subject median + 90% CI for same 6 quantities
"""

import os
import re
import warnings

import numpy as np
import pandas as pd
import pymc as pm
import pytensor
import pytensor.tensor as pt
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.stats import gaussian_kde
from scipy.special import expit as sigmoid

warnings.filterwarnings("ignore", category=FutureWarning)

# ── constants ────────────────────────────────────────────────────────────────
DATA_DIR   = "../../data/ioc-all-fixed-pilot/task"
N_ARMS     = 3
KEY_TO_ARM = {"arrowleft": 0, "arrowup": 1, "arrowright": 2}
GREY_LINE  = "#404040"


# ── data loading ─────────────────────────────────────────────────────────────

def load_subjects(data_dir):
    records = []
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
        blocks  = gb["block_number"].values
        T       = len(choices)

        # run_after[t] = within-block consecutive run length ending at trial t
        run_after = np.ones(T, dtype=int)
        for t in range(1, T):
            if blocks[t] == blocks[t - 1] and choices[t] == choices[t - 1]:
                run_after[t] = run_after[t - 1] + 1

        # At decision time t:
        #   E[a] = delta^persev_exp[t]  if a == choices[t-1] and same block
        #        = 0                    at block start (prev_arm_oh row is all zeros)
        persev_exp  = np.zeros(T, dtype=float)
        prev_arm_oh = np.zeros((T, N_ARMS), dtype=float)
        for t in range(1, T):
            if blocks[t] == blocks[t - 1]:
                persev_exp[t]               = float(run_after[t - 1] - 1)
                prev_arm_oh[t, choices[t - 1]] = 1.0
        persev_exp = np.clip(persev_exp, 0, 50)   # numerical safety

        choices_oh = np.zeros((T, N_ARMS), dtype=float)
        choices_oh[np.arange(T), choices] = 1.0

        records.append({
            "pid":         pid,
            "T":           T,
            "choices":     choices,
            "rewards":     rewards,
            "choices_oh":  choices_oh,   # (T, 3)
            "persev_exp":  persev_exp,   # (T,)
            "prev_arm_oh": prev_arm_oh,  # (T, 3)
        })

    print(f"Loaded {len(records)} subjects, {records[0]['T']} trials each")
    return records


def make_tensors(subjects):
    """Stack per-subject arrays → pytensor constants shaped (T, N, ...).
    Pads shorter subjects to T_max with dummy zeros; a valid_mask (T,N)
    ensures padded trials contribute 0 to the log-likelihood.
    """
    T_max = max(s["T"] for s in subjects)
    N     = len(subjects)

    def pad_TN3(key):
        arr = np.zeros((T_max, N, N_ARMS), dtype=float)
        for j, s in enumerate(subjects):
            arr[:s["T"], j, :] = s[key]
        return arr

    def pad_TN(key):
        arr = np.zeros((T_max, N), dtype=float)
        for j, s in enumerate(subjects):
            arr[:s["T"], j] = s[key]
        return arr

    valid = np.zeros((T_max, N), dtype=float)
    for j, s in enumerate(subjects):
        valid[:s["T"], j] = 1.0

    return dict(
        T=T_max, N=N,
        choices_oh_pt  = pt.constant(pad_TN3("choices_oh")),    # (T,N,3)
        rewards_pt     = pt.constant(pad_TN("rewards")),         # (T,N)
        persev_exp_pt  = pt.constant(pad_TN("persev_exp")),      # (T,N)
        prev_arm_oh_pt = pt.constant(pad_TN3("prev_arm_oh")),    # (T,N,3)
        valid_pt       = pt.constant(valid),                     # (T,N)
    )


# ── vectorised Q scan ────────────────────────────────────────────────────────

def compute_Q_before(tensors, alpha_N):
    """One scan over T for all N subjects simultaneously.
    alpha_N : pytensor (N,)  → returns Q_before : pytensor (T, N, 3)
    """
    N = tensors["N"]
    Q0 = pt.ones((N, N_ARMS)) * 0.5   # (N, 3)

    def step(cho_oh_t, rew_t, Q, alpha):
        pe = rew_t[:, None] - Q                           # (N, 3)
        return Q + alpha[:, None] * pe * cho_oh_t         # (N, 3)

    Q_after, _ = pytensor.scan(
        fn=step,
        sequences=[tensors["choices_oh_pt"], tensors["rewards_pt"]],
        outputs_info=[Q0],
        non_sequences=[alpha_N],
    )
    # Q_after[t] is Q after update at t; decision at t uses Q_after[t-1]
    return pt.concatenate([Q0[None, :, :], Q_after[:-1, :, :]], axis=0)   # (T,N,3)


# ── shared helpers ────────────────────────────────────────────────────────────

def persev_matrix_pt(delta_N, tensors):
    """delta_N: (N,) → (T, N, 3) perseveration contribution"""
    d_eff = delta_N[None, :] ** tensors["persev_exp_pt"]    # (T, N)
    return d_eff[:, :, None] * tensors["prev_arm_oh_pt"]    # (T, N, 3)


def categorical_loglik(logits, choices_oh_pt, valid_pt):
    """logits: (T, N, 3)  →  scalar total log-likelihood (padded trials masked)"""
    chosen = pt.sum(logits * choices_oh_pt, axis=2)          # (T, N)
    log_Z  = pt.logsumexp(logits, axis=2)                    # (T, N)
    return pt.sum((chosen - log_Z) * valid_pt)


# ── model builders ────────────────────────────────────────────────────────────

def build_model_1(tensors):
    N = tensors["N"]
    with pm.Model() as model:
        mu_a = pm.Normal("mu_alpha", 0.0, 3.0)
        mu_b = pm.Normal("mu_beta",  0.0, 3.0)
        mu_k = pm.Normal("mu_kappa", 0.0, 2.0)
        mu_d = pm.Normal("mu_delta", 0.0, 3.0)

        sig_a = pm.HalfNormal("sigma_alpha", 1.0)
        sig_b = pm.HalfNormal("sigma_beta",  1.0)
        sig_k = pm.HalfNormal("sigma_kappa", 1.0)
        sig_d = pm.HalfNormal("sigma_delta", 1.0)

        z_a = pm.Normal("z_alpha", 0.0, 1.0, shape=N)
        z_b = pm.Normal("z_beta",  0.0, 1.0, shape=N)
        z_k = pm.Normal("z_kappa", 0.0, 1.0, shape=N)
        z_d = pm.Normal("z_delta", 0.0, 1.0, shape=N)

        alpha = pm.Deterministic("alpha_sbj", pt.sigmoid(mu_a + sig_a * z_a))   # (N,) ∈(0,1)
        beta  = pm.Deterministic("beta_sbj",  mu_b + sig_b * z_b)               # (N,) ∈ ℝ
        kappa = pm.Deterministic("kappa_sbj", mu_k + sig_k * z_k)               # (N,) ∈ ℝ
        delta = pm.Deterministic("delta_sbj", pt.sigmoid(mu_d + sig_d * z_d))   # (N,) ∈(0,1)

        Q      = compute_Q_before(tensors, alpha)                                # (T,N,3)
        P      = persev_matrix_pt(delta, tensors)                               # (T,N,3)
        logits = beta[None, :, None] * Q + kappa[None, :, None] * P

        pm.Potential("ll", categorical_loglik(logits, tensors["choices_oh_pt"], tensors["valid_pt"]))
    return model


def build_model_2(tensors):
    N = tensors["N"]
    with pm.Model() as model:
        mu_k = pm.Normal("mu_kappa", 0.0, 2.0)
        mu_d = pm.Normal("mu_delta", 0.0, 3.0)
        sig_k = pm.HalfNormal("sigma_kappa", 1.0)
        sig_d = pm.HalfNormal("sigma_delta", 1.0)

        z_k = pm.Normal("z_kappa", 0.0, 1.0, shape=N)
        z_d = pm.Normal("z_delta", 0.0, 1.0, shape=N)

        kappa = pm.Deterministic("kappa_sbj", mu_k + sig_k * z_k)
        delta = pm.Deterministic("delta_sbj", pt.sigmoid(mu_d + sig_d * z_d))

        P      = persev_matrix_pt(delta, tensors)
        logits = kappa[None, :, None] * P

        pm.Potential("ll", categorical_loglik(logits, tensors["choices_oh_pt"], tensors["valid_pt"]))
    return model


# ── plotting ──────────────────────────────────────────────────────────────────

def density_panel(ax, draws, title, xlabel, fill_color):
    med  = float(np.median(draws))
    pd_  = max(np.mean(draws > 0), np.mean(draws < 0)) * 100
    ci80 = np.quantile(draws, [0.10, 0.90])
    ci90 = np.quantile(draws, [0.05, 0.95])
    kde  = gaussian_kde(draws)
    xs   = np.linspace(draws.min(), draws.max(), 512)
    ys   = kde(xs); ys = ys / ys.max()
    CI_Y = -0.08
    ax.fill_between(xs, ys, color=fill_color, linewidth=0)
    ax.plot([ci90[0], ci90[1]], [CI_Y]*2, color=GREY_LINE, lw=1.0, solid_capstyle="round")
    ax.plot([ci80[0], ci80[1]], [CI_Y]*2, color=GREY_LINE, lw=2.5, solid_capstyle="round")
    ax.plot(med, CI_Y, "o", color=GREY_LINE, ms=4, zorder=5)
    ax.axvline(0, color="#666666", ls="--", lw=0.8, alpha=0.7)
    ax.text(med, 1.12, f"med={med:.2f}\npd={pd_:.1f}%",
            ha="center", va="top", fontsize=7.5, color="#555555")
    lim = max(abs(draws.min()), abs(draws.max())) * 1.12
    ax.set_xlim(-lim, lim)
    ax.set_ylim(CI_Y - 0.1, 1.45)
    ax.set_title(title, fontsize=9, pad=4)
    ax.set_xlabel(xlabel, fontsize=8)
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.yaxis.set_visible(False)
    ax.spines["bottom"].set_color("#888888")
    ax.tick_params(axis="x", labelsize=7)


def dotplot_panel(ax, medians, lo, hi, title, xlabel):
    N   = len(medians)
    ord = np.argsort(medians)
    for i, j in enumerate(ord):
        ax.plot([lo[j], hi[j]], [i, i], color="#aaaaaa", lw=0.9, zorder=1)
        ax.plot(medians[j], i, "o", color=GREY_LINE, ms=3.5, zorder=2)
    ax.axvline(0, color="#666666", ls="--", lw=0.8, alpha=0.7)
    ax.set_yticks(np.arange(N))
    ax.set_yticklabels([f"P{ord[i]+1:02d}" for i in range(N)], fontsize=5.5)
    ax.set_title(title, fontsize=9, pad=4)
    ax.set_xlabel(xlabel, fontsize=8)
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(axis="x", labelsize=7)


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    subjects = load_subjects(DATA_DIR)
    tensors  = make_tensors(subjects)

    # ── fit ───────────────────────────────────────────────────────────────────
    print("\n=== Fitting Model 1 (alpha, beta, kappa, delta) ===")
    with build_model_1(tensors) as m1:
        idata_m1 = pm.sample(draws=1000, tune=1000, chains=4,
                             target_accept=0.9, progressbar=True, random_seed=1)

    print("\n=== Fitting Model 2 (kappa, delta) ===")
    with build_model_2(tensors) as m2:
        idata_m2 = pm.sample(draws=1000, tune=1000, chains=4,
                             target_accept=0.9, progressbar=True, random_seed=2)

    # ── extract ───────────────────────────────────────────────────────────────
    def flat(idata, var):
        return idata.posterior[var].values.reshape(-1)

    def flat_sbj(idata, var):
        v = idata.posterior[var].values        # (chains, draws, N)
        return v.reshape(-1, v.shape[-1])      # (4000, N)

    # group posteriors on natural scale
    g_delta_m1 = sigmoid(flat(idata_m1, "mu_delta"))
    g_delta_m2 = sigmoid(flat(idata_m2, "mu_delta"))
    g_kappa_m1 = flat(idata_m1, "mu_kappa")
    g_kappa_m2 = flat(idata_m2, "mu_kappa")
    g_alpha_m1 = sigmoid(flat(idata_m1, "mu_alpha"))
    g_beta_m1  = flat(idata_m1, "mu_beta")

    # subject posteriors (already on natural scale via Deterministic)
    s_delta_m1 = flat_sbj(idata_m1, "delta_sbj")
    s_delta_m2 = flat_sbj(idata_m2, "delta_sbj")
    s_kappa_m1 = flat_sbj(idata_m1, "kappa_sbj")
    s_kappa_m2 = flat_sbj(idata_m2, "kappa_sbj")
    s_alpha_m1 = flat_sbj(idata_m1, "alpha_sbj")
    s_beta_m1  = flat_sbj(idata_m1, "beta_sbj")

    def subj_stats(mat):
        return (np.median(mat, 0), np.quantile(mat, 0.05, 0), np.quantile(mat, 0.95, 0))

    # ── figure ────────────────────────────────────────────────────────────────
    fig = plt.figure(figsize=(16, 10))
    gs  = fig.add_gridspec(2, 6, height_ratios=[3.5, 6.5],
                           hspace=0.45, wspace=0.40,
                           top=0.93, bottom=0.06, left=0.05, right=0.98)

    FILL_M1   = "#bcd4e6"   # light blue  — M1
    FILL_M2   = "#f5c6a0"   # light orange — M2
    FILL_ONLY = "#c8c8c8"   # gray — M1-only params

    fig.suptitle(
        "Hierarchical Bayesian parameter estimation  "
        "(M1: α + β + κ + δ     M2: κ + δ)",
        fontsize=11, y=0.98
    )

    # Row 0 — group-level posteriors
    group_panels = [
        (g_delta_m1, "δ   (M1)",     "δ (decay rate)",           FILL_M1),
        (g_delta_m2, "δ   (M2)",     "δ (decay rate)",           FILL_M2),
        (g_kappa_m1, "κ   (M1)",     "κ (perseveration)",        FILL_M1),
        (g_kappa_m2, "κ   (M2)",     "κ (perseveration)",        FILL_M2),
        (g_alpha_m1, "α   (M1)",     "α (learning rate)",        FILL_ONLY),
        (g_beta_m1,  "β   (M1)",     "β (inv. temperature)",     FILL_ONLY),
    ]
    for c, (draws, title, xl, fc) in enumerate(group_panels):
        density_panel(fig.add_subplot(gs[0, c]), draws, title, xl, fc)

    # Row 1 — subject-level dot plots
    subj_panels = [
        (s_delta_m1, "δ   (M1)",  "δ"),
        (s_delta_m2, "δ   (M2)",  "δ"),
        (s_kappa_m1, "κ   (M1)",  "κ"),
        (s_kappa_m2, "κ   (M2)",  "κ"),
        (s_alpha_m1, "α   (M1)",  "α"),
        (s_beta_m1,  "β   (M1)",  "β"),
    ]
    for c, (mat, title, xl) in enumerate(subj_panels):
        med, lo, hi = subj_stats(mat)
        dotplot_panel(fig.add_subplot(gs[1, c]), med, lo, hi, title, xl)

    out = "param_recovery.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"\nSaved → {out}")


if __name__ == "__main__":
    main()
