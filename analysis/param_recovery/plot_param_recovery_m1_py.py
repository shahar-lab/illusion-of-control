"""
Plot M1 population posteriors (alpha, beta, kappa, delta) from draws_m1.nc.
Styled per plot-posterior and plot-colors skill rules.
"""

import os
import numpy as np
import arviz as az
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from scipy.stats import gaussian_kde
from scipy.special import expit

os.chdir(os.path.dirname(os.path.abspath(__file__)))
os.makedirs("figures", exist_ok=True)

idata = az.from_netcdf("draws_m1.nc")

def flat(var):
    return idata.posterior[var].values.reshape(-1)

alpha_pop = expit(flat("mu_alpha"))   # learning rate  ∈ (0,1)  — non-effect
beta_pop  = flat("mu_beta")           # inv temperature — effect (zero meaningful)
kappa_pop = flat("mu_kappa")          # perseveration   — effect (zero meaningful)
delta_pop = expit(flat("mu_delta"))   # decay rate      ∈ (0,1)  — non-effect

# ── style constants ────────────────────────────────────────────────────────────
GREY30  = "#4d4d4d"   # axis line
GREY40  = "#666666"   # zero ref line
GREY65  = "#a6a6a6"   # median line
GREY80  = "#cccccc"   # slab fill
CI80_LW = 3.0
CI90_LW = 1.5
BASE_FS = 11

def xlim_effect(draws):
    """Symmetric around zero."""
    m = max(abs(draws.min()), abs(draws.max())) * 1.08
    return (-m, m)

def xlim_noneffect(draws, pad=0.20):
    r = draws.min(), draws.max()
    span = r[1] - r[0]
    return (r[0] - pad * span, r[1] + pad * span)

def posterior_panel(ax, draws, xlabel, is_effect=False):
    med  = float(np.median(draws))
    pd_  = max(np.mean(draws > 0), np.mean(draws < 0)) * 100
    ci90 = np.quantile(draws, [0.05, 0.95])

    # KDE slab (gray80)
    xs  = np.linspace(draws.min(), draws.max(), 600)
    kde = gaussian_kde(draws, bw_method=0.15)
    ys  = kde(xs)
    ys  = ys / ys.max()
    ax.fill_between(xs, ys, color=GREY80, linewidth=0)

    # 90% CI line + median point below the slab
    CI_Y = -0.08
    ax.plot([ci90[0], ci90[1]], [CI_Y]*2, color=GREY30, lw=CI90_LW, solid_capstyle="round", zorder=3)
    ax.plot(med, CI_Y, "o", color=GREY30, ms=5, zorder=5)

    # zero ref (effect only)
    if is_effect:
        ax.axvline(0, color=GREY40, ls="--", lw=0.9, zorder=2)

    # median line (thin, lighter)
    ax.axvline(med, color=GREY65, ls="--", lw=0.5, zorder=2)

    # annotation
    label = f"[median = {med:.2f}, pd = {pd_:.1f}%]" if is_effect else f"[median = {med:.2f}]"
    ax.text(med, 1.05, label, ha="left", va="bottom", fontsize=7.5,
            color=GREY40, transform=ax.get_xaxis_transform())

    # axes
    if is_effect:
        xl = xlim_effect(draws)
    else:
        xl = xlim_noneffect(draws)
    ax.set_xlim(*xl)
    ax.set_ylim(CI_Y - 0.08, 1.35)
    ax.set_xlabel(xlabel, fontsize=BASE_FS - 1, color="black")

    # style: no y-axis, dark gray x-axis
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.spines["bottom"].set_color(GREY30)
    ax.yaxis.set_visible(False)
    ax.tick_params(axis="x", labelsize=BASE_FS - 2, colors="black")
    ax.set_facecolor("white")

# ── figure: 1 row, 4 panels, wide and short ───────────────────────────────────
fig, axes = plt.subplots(1, 4, figsize=(14, 3.2))
fig.patch.set_facecolor("white")
fig.subplots_adjust(wspace=0.38, left=0.04, right=0.98, top=0.78, bottom=0.26)

panel_labels = "ABCD"
params = [
    (alpha_pop, "α  (learning rate)",      False),
    (beta_pop,  "β  (inverse temperature)", True),
    (kappa_pop, "κ  (perseveration)",       True),
    (delta_pop, "δ  (decay rate)",          False),
]

for i, (ax, (draws, xlabel, is_effect)) in enumerate(zip(axes, params)):
    posterior_panel(ax, draws, xlabel, is_effect=is_effect)
    ax.text(-0.05, 1.18, panel_labels[i], transform=ax.transAxes,
            fontsize=BASE_FS + 1, fontweight="bold", va="top")

fig.savefig("figures/param_recovery_m1_population.png", dpi=150,
            bbox_inches="tight", facecolor="white")
print("Saved: figures/param_recovery_m1_population.png")
