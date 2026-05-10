# /// script
# dependencies = [
#   "numpy", "pandas", "matplotlib",
# ]
# ///
"""
Computational model of the Illusion-of-Control bandit task.

The game:
  - 3 machines (0, 1, 2). Each trial one machine is randomly unavailable.
  - The model chooses among the 2 available machines via softmax.
  - Chosen machine pays out with probability = scarcity.
  - Q-values updated by Rescorla-Wagner delta rule.
  - Perseveration bias (kappa): extra log-odds added to the previously chosen
    machine when forming the softmax (Lau & Glimcher 2005; Wilson & Collins 2019).

Parameter sweep:
  alpha in [0.1, 0.2, 0.3, 0.5]   — learning rate (typical human range)
  beta  in [1,   3,   6,   10 ]    — inverse temperature (typical human range)
  → 16 combinations, each a separate colored+styled line

Perseveration (fixed):
  kappa = 1.5  (standard midpoint from RL bandit literature)

Scarcity sweep:
  0 %, 5 %, …, 100 %  — reward probability of every machine

Outcome measure:
  p_stay_win  = P(stay | prev rewarded,     prev machine available)
  p_stay_lose = P(stay | prev not rewarded, prev machine available)
  wsls_effect = p_stay_win − p_stay_lose

Outputs (saved next to this script):
  wsls_by_scarcity.csv
  wsls_by_scarcity.png
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.lines as mlines

# ── Paths ─────────────────────────────────────────────────────────────────────

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Parameters ────────────────────────────────────────────────────────────────

N_TRIALS        = 150       # full game length (matches real task)
N_SIMS          = 5_000        # simulated games per scarcity level (use 10_000 for final run)
N_MACHINES      = 3
SCARCITY_LEVELS = np.round(np.arange(0.0, 1.05, 0.05), 2)
RNG_SEED        = 42
KAPPA           = 0.3       # perseveration bias (standard literature value)

# Human-typical parameter ranges (Daw 2011; Collins & Frank 2012; Ouden et al. 2013)
ALPHAS = [0.3]   # learning rates
BETAS  = [4]    # inverse temperatures

# Visual encoding: color → alpha, linestyle → beta
ALPHA_COLORS    = ["#E69F00", "#56B4E9", "#009E73", "#0072B2"]   # Okabe-Ito
BETA_LINESTYLES = ["-", "--", "-.", ":"]

rng = np.random.default_rng(RNG_SEED)

# ── Simulation ────────────────────────────────────────────────────────────────

def simulate_session(scarcity, alpha, beta, kappa, n_trials, rng):
    """
    Run one session. Returns list of {"stayed": 0/1, "prev_reward": 0/1}
    for trials where the previous machine was available.
    """
    q           = np.full(N_MACHINES, 0.5)
    prev_choice = None
    prev_reward = None
    records     = []

    for _ in range(n_trials):
        unavailable = rng.integers(N_MACHINES)
        available   = [m for m in range(N_MACHINES) if m != unavailable]

        # Softmax with perseveration: logit = beta*Q + kappa*(m == prev_choice)
        logits = np.array([
            beta * q[m] + (kappa if m == prev_choice else 0.0)
            for m in available
        ])
        exp_l  = np.exp(logits - logits.max())
        probs  = exp_l / exp_l.sum()
        choice = available[rng.choice(len(available), p=probs)]
        reward = int(rng.random() < scarcity)

        if prev_choice is not None and prev_choice in available:
            records.append({
                "stayed":      int(choice == prev_choice),
                "prev_reward": prev_reward,
            })

        q[choice] += alpha * (reward - q[choice])
        prev_choice = choice
        prev_reward = reward

    return records


def run_sweep(scarcity_levels, alpha, beta, kappa, n_trials, n_sims, rng):
    rows = []
    for scarcity in scarcity_levels:
        p_stay_wins  = []
        p_stay_loses = []
        for _ in range(n_sims):
            trials = simulate_session(scarcity, alpha, beta, kappa, n_trials, rng)
            if not trials:
                continue
            df        = pd.DataFrame(trials)
            win_mask  = df["prev_reward"] == 1
            lose_mask = df["prev_reward"] == 0
            if win_mask.any():
                p_stay_wins.append(df.loc[win_mask,  "stayed"].mean())
            if lose_mask.any():
                p_stay_loses.append(df.loc[lose_mask, "stayed"].mean())

        p_sw = float(np.mean(p_stay_wins))  if p_stay_wins  else np.nan
        p_sl = float(np.mean(p_stay_loses)) if p_stay_loses else np.nan
        rows.append({
            "scarcity":    scarcity,
            "p_stay_win":  p_sw,
            "p_stay_lose": p_sl,
            "wsls_effect": p_sw - p_sl if not (np.isnan(p_sw) or np.isnan(p_sl)) else np.nan,
        })
    return pd.DataFrame(rows)


# ── Run all 16 combinations ───────────────────────────────────────────────────

all_results = {}
for alpha in ALPHAS:
    for beta in BETAS:
        key = (alpha, beta)
        print(f"  alpha={alpha}, beta={beta} ...")
        all_results[key] = run_sweep(
            SCARCITY_LEVELS, alpha=alpha, beta=beta, kappa=KAPPA,
            n_trials=N_TRIALS, n_sims=N_SIMS, rng=rng,
        )

# ── Save CSV ──────────────────────────────────────────────────────────────────

rows = []
for (alpha, beta), df in all_results.items():
    df = df.copy()
    df["alpha"] = alpha
    df["beta"]  = beta
    rows.append(df)

combined = pd.concat(rows, ignore_index=True)
csv_path = os.path.join(OUT_DIR, "wsls_by_scarcity.csv")
combined.to_csv(csv_path, index=False)
print(f"\nSaved: {csv_path}")

# ── Plot ──────────────────────────────────────────────────────────────────────

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle(
    f"Computational model: Win-Stay / Lose-Shift by reward scarcity\n"
    f"κ={KAPPA} (perseveration),  {N_TRIALS} trials/session,  {N_SIMS} simulations per point",
    fontsize=11,
)

for ai, alpha in enumerate(ALPHAS):
    color = ALPHA_COLORS[ai]
    for bi, beta in enumerate(BETAS):
        ls  = BETA_LINESTYLES[bi]
        df  = all_results[(alpha, beta)]
        pct = df["scarcity"] * 100

        # Left: solid = win, dashed = lose (linestyle already encodes beta via bi)
        # Use linewidth to separate win (thicker) from lose (thinner)
        ax1.plot(pct, df["p_stay_win"],  color=color, linestyle=ls, linewidth=1.8,
                 alpha=0.85)
        ax1.plot(pct, df["p_stay_lose"], color=color, linestyle=ls, linewidth=0.9,
                 alpha=0.55)

        ax2.plot(pct, df["wsls_effect"], color=color, linestyle=ls, linewidth=1.8,
                 alpha=0.85)

# Left panel
ax1.axvline(50, color="black", linestyle=":", linewidth=0.7, alpha=0.5)
ax1.set_xlabel("Scarcity (reward probability, %)")
ax1.set_ylabel("P(stay)")
ax1.set_ylim(0, 1)
ax1.set_xlim(0, 100)
ax1.set_title("Stay probability by outcome\n(thick = win, thin = lose)")
ax1.grid(True, alpha=0.25)

# Right panel
ax2.axhline(0,  color="black", linestyle="--", linewidth=0.7, alpha=0.5)
ax2.axvline(50, color="black", linestyle=":",  linewidth=0.7, alpha=0.5)
ax2.set_xlabel("Scarcity (reward probability, %)")
ax2.set_ylabel("WSLS effect  [P(stay|win) − P(stay|lose)]")
ax2.set_xlim(0, 100)
ax2.set_title("Win-Stay / Lose-Shift effect")
ax2.grid(True, alpha=0.25)

# Shared legend (outside the panels)
alpha_handles = [
    mlines.Line2D([], [], color=ALPHA_COLORS[i], linewidth=2,
                  label=f"α = {a}")
    for i, a in enumerate(ALPHAS)
]
beta_handles = [
    mlines.Line2D([], [], color="gray", linestyle=BETA_LINESTYLES[i], linewidth=2,
                  label=f"β = {b}")
    for i, b in enumerate(BETAS)
]
fig.legend(
    handles=alpha_handles + beta_handles,
    loc="lower center",
    ncol=len(ALPHAS) + len(BETAS),
    fontsize=8.5,
    frameon=True,
    bbox_to_anchor=(0.5, -0.06),
)

plt.tight_layout(rect=[0, 0.06, 1, 1])
png_path = os.path.join(OUT_DIR, "wsls_by_scarcity.png")
fig.savefig(png_path, dpi=150, bbox_inches="tight")
print(f"Saved: {png_path}")
plt.close(fig)

print("\nDone.")
