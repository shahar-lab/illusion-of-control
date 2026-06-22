"""
Plot population posteriors for M1 (alpha, beta, kappa, delta)
from the existing draws_m1.nc (ArviZ/PyMC format).
"""

import os
import numpy as np
import arviz as az
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.stats import gaussian_kde
from scipy.special import expit

os.chdir(os.path.dirname(os.path.abspath(__file__)))
os.makedirs("figures", exist_ok=True)

idata = az.from_netcdf("draws_m1.nc")

def flat(var):
    return idata.posterior[var].values.reshape(-1)

# population parameters on natural scale
alpha_pop = expit(flat("mu_alpha"))
beta_pop  = flat("mu_beta")
kappa_pop = flat("mu_kappa")
delta_pop = expit(flat("mu_delta"))

GREY = "#444444"
FILL = "#b8d4e8"

def density_panel(ax, draws, title, xlabel, xlim=None, show_zero=False):
    med  = float(np.median(draws))
    pd_  = max(np.mean(draws > 0), np.mean(draws < 0)) * 100
    ci90 = np.quantile(draws, [0.05, 0.95])
    xs   = np.linspace(draws.min(), draws.max(), 512)
    kde  = gaussian_kde(draws)
    ys   = kde(xs); ys = ys / ys.max()

    CI_Y = -0.08
    ax.fill_between(xs, ys, color=FILL, linewidth=0)
    ax.fill_between(xs[(xs >= ci90[0]) & (xs <= ci90[1])],
                    ys[(xs >= ci90[0]) & (xs <= ci90[1])],
                    color="#5a9ec9", linewidth=0, alpha=0.6)
    ax.plot([ci90[0], ci90[1]], [CI_Y]*2, color=GREY, lw=1.2, solid_capstyle="round")
    ax.plot(med, CI_Y, "o", color=GREY, ms=5, zorder=5)

    if show_zero:
        ax.axvline(0,   color="#888888", ls="--", lw=0.9, alpha=0.8)
    ax.axvline(med, color="#aaaaaa", ls=":",  lw=0.8)

    ann = f"med={med:.2f}\npd={pd_:.1f}%" if show_zero else f"med={med:.2f}"
    ax.text(med, 1.12, ann, ha="center", va="top", fontsize=8, color=GREY)

    ax.set_ylim(CI_Y - 0.1, 1.55)
    if xlim:
        ax.set_xlim(*xlim)
    ax.set_title(title, fontsize=11, pad=6)
    ax.set_xlabel(xlabel, fontsize=9)
    ax.spines[["top","right","left"]].set_visible(False)
    ax.yaxis.set_visible(False)
    ax.tick_params(axis="x", labelsize=8)

fig, axes = plt.subplots(1, 4, figsize=(14, 4))
fig.subplots_adjust(wspace=0.4, top=0.82, bottom=0.18)

density_panel(axes[0], alpha_pop, "A  α", "α  (learning rate)",      xlim=(0,1))
density_panel(axes[1], beta_pop,  "B  β", "β  (inverse temperature)", show_zero=True)
density_panel(axes[2], kappa_pop, "C  κ", "κ  (perseveration)",       show_zero=True)
density_panel(axes[3], delta_pop, "D  δ", "δ  (decay rate)",          xlim=(0,1))

fig.suptitle("M1 population posteriors — ioc-all-fixed-pilot (N=18)", fontsize=12, y=0.97)
fig.savefig("figures/param_recovery_m1_population.png", dpi=150,
            bbox_inches="tight", facecolor="white")
print("Saved: figures/param_recovery_m1_population.png")
