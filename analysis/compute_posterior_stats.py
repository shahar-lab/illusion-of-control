"""
Compute 90% CI and BF_10 (Savage-Dickey) for all plotted posteriors across:
  - wsls_belief_subgroups/wsls_three_panels.png  (3× beta_mu)
  - wm_wsls/wm_wsls.png                          (slope)
  - param_recovery/param_recovery.png            (mu_alpha, mu_beta, mu_kappa, mu_delta from M1;
                                                   mu_kappa, mu_delta from M2)
  - running_wsls/wsls_scatter_posterior.png      (beta_mu, N=18)

BF_10 = prior_density(0) / posterior_KDE(0)  [Savage-Dickey density ratio]
"""

import os, re, sys, warnings
import numpy as np
import pandas as pd
import pymc as pm
import arviz as az
from scipy.stats import gaussian_kde, norm

warnings.filterwarnings("ignore")

ROOT     = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(ROOT, "../data/ioc-all-fixed-pilot/task")

MISUNDERSTOOD  = {"67dae998d8f2cfb8a8e3bf03"}
FELT_DIFFERENT = {"677009b08130c3028f6a8a6d","68598a1d4cebd213b2abb1d9",
                  "69b7e04340b00585acbb91ac","6a0092581cd317f1ff1765a2"}
OMITTED = MISUNDERSTOOD | FELT_DIFFERENT


# ── helpers ───────────────────────────────────────────────────────────────────
def ci90(draws):
    lo, hi = np.quantile(draws, [0.05, 0.95])
    return lo, hi

def bf10_savage_dickey(draws, prior_sigma, prior_mu=0.0):
    """Savage-Dickey BF_10 for H0: theta=0."""
    prior_density_at_0 = norm.pdf(0.0, prior_mu, prior_sigma)
    kde = gaussian_kde(draws, bw_method="scott")
    post_density_at_0  = float(kde(0.0)[0])
    if post_density_at_0 < 1e-12:
        return np.inf
    return prior_density_at_0 / post_density_at_0

def sigmoid(x): return 1.0 / (1.0 + np.exp(-x))

def row(label, draws, prior_sigma, prior_mu=0.0, transform=None):
    d = draws if transform is None else transform(draws)
    lo, hi = ci90(d)
    med    = float(np.median(d))
    pd_    = max(np.mean(d > 0), np.mean(d < 0)) * 100
    bf     = bf10_savage_dickey(draws, prior_sigma, prior_mu)
    return {"Parameter": label,
            "Median": f"{med:.3f}",
            "90% CI": f"[{lo:.3f}, {hi:.3f}]",
            "pd (%)": f"{pd_:.1f}",
            "BF₁₀": f"{bf:.2f}"}


# ── data loading ──────────────────────────────────────────────────────────────
def load_raw():
    records = []
    for fname in sorted(os.listdir(DATA_DIR)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-all_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        df  = pd.read_csv(os.path.join(DATA_DIR, fname), low_memory=False)
        gb  = (df[(df["task"]=="gambling_choice") &
                   (df["block_number"].astype(str)!="training") &
                   (df["is_choice_valid"].astype(str).str.lower()=="true")]
               .copy()
               .assign(block_number=lambda x: x["block_number"].astype(int))
               .sort_values(["block_number","trial_number"])
               .reset_index(drop=True))
        gb["reward"]       = pd.to_numeric(gb["reward"], errors="coerce")
        gb["trial_number"] = pd.to_numeric(gb["trial_number"], errors="coerce")
        gb["is_choice_valid"] = gb["is_choice_valid"].astype(str).str.lower()=="true"
        records.append({"pid": pid, "df": gb})
    return records

def make_wsls_df(records, exclude=set()):
    frames = []
    for rec in records:
        if rec["pid"] in exclude:
            continue
        gb = rec["df"].copy()
        gb["participant"] = rec["pid"]
        frames.append(gb)
    raw = pd.concat(frames, ignore_index=True)
    raw = raw.sort_values(["participant","block_number","trial_number"])
    raw["choice_prev"]   = raw.groupby(["participant","block_number"])["choice_key"].shift(1)
    raw["reward_prev"]   = raw.groupby(["participant","block_number"])["reward"].shift(1)
    raw["is_valid_prev"] = raw.groupby(["participant","block_number"])["is_choice_valid"].shift(1)
    raw = raw[(raw["trial_number"]>1) & raw["is_choice_valid"] &
              raw["is_valid_prev"].fillna(False) & raw["choice_prev"].notna() &
              raw["reward_prev"].notna()].copy()
    raw["stay"]        = (raw["choice_key"]==raw["choice_prev"]).astype(int)
    raw["reward_prev"] = raw["reward_prev"].astype(int)
    pids   = sorted(raw["participant"].unique())
    pid_map= {p:i for i,p in enumerate(pids)}
    raw["subj_idx"] = raw["participant"].map(pid_map)
    return raw, pids

def fit_wsls(df, n_subjects, label, cache_path=None):
    if cache_path and os.path.exists(cache_path):
        print(f"  Loading {cache_path}")
        return az.from_netcdf(cache_path)
    print(f"  Fitting WSLS {label} (N={n_subjects}, {len(df)} trials) …")
    with pm.Model():
        alpha_mu    = pm.Normal("alpha_mu", 0, 2)
        beta_mu     = pm.Normal("beta_mu",  0, 2)
        alpha_sigma = pm.HalfNormal("alpha_sigma", 1)
        beta_sigma  = pm.HalfNormal("beta_sigma",  1)
        alpha_z = pm.Normal("alpha_z", 0, 1, shape=n_subjects)
        beta_z  = pm.Normal("beta_z",  0, 1, shape=n_subjects)
        pm.Deterministic("alpha", alpha_mu + alpha_sigma*alpha_z)
        pm.Deterministic("beta",  beta_mu  + beta_sigma *beta_z)
        log_odds = ((alpha_mu + alpha_sigma*alpha_z)[df["subj_idx"].values]
                    + (beta_mu + beta_sigma*beta_z)[df["subj_idx"].values]
                    * df["reward_prev"].values)
        pm.Bernoulli("stay", logit_p=log_odds, observed=df["stay"].values)
        idata = pm.sample(1000, tune=1000, chains=4, target_accept=0.9,
                          progressbar=True, random_seed=42)
    if cache_path:
        az.to_netcdf(idata, cache_path)
    return idata


# ── main ──────────────────────────────────────────────────────────────────────
rows = []

# 1. wsls_belief_subgroups: three panels
print("\n=== wsls_three_panels ===")
all_records = load_raw()

groups = [
    ("All participants (N=18)",           set(),    os.path.join(ROOT,"running_wsls/wsls_18_draws.nc")),
    ("Understood correctly (N=17)",       MISUNDERSTOOD, None),
    ("Felt = instructed (N=13)",          OMITTED,  os.path.join(ROOT,"running_wsls/wsls_13_draws.nc")),
]
for label, excl, cache in groups:
    df, pids = make_wsls_df(all_records, excl)
    idata    = fit_wsls(df, len(pids), label, cache)
    draws    = idata.posterior["beta_mu"].values.flatten()
    rows.append(row(f"WSLS β_μ — {label}", draws, prior_sigma=2.0))

# 2. wm_wsls: slope posterior
print("\n=== wm_wsls ===")
WM_DIR  = os.path.join(ROOT, "../data/ioc-all-fixed-pilot/wm")
CACHE_WSLS = os.path.join(ROOT, "wm_wsls/wsls_18_all_draws.nc")
CACHE_REG  = os.path.join(ROOT, "wm_wsls/reg_draws.nc")

# -- WM K scores (Cowan formula) --
def load_wm_k(wm_dir):
    ks = {}
    for fname in sorted(os.listdir(wm_dir)):
        if not fname.endswith(".csv"):
            continue
        m = re.match(r"ioc-wm_([a-f0-9]{24})_SESSION", fname)
        if not m:
            continue
        pid = m.group(1)
        if pid in OMITTED:
            continue
        df  = pd.read_csv(os.path.join(wm_dir, fname), low_memory=False)
        exp = df[(df["trial_name"]=="test_squares") & (df["block_type"]=="exp")].copy()
        exp["set_size"] = pd.to_numeric(exp["set_size"], errors="coerce")
        exp["acc_bool"] = exp["accuracy"].astype(str).str.lower()=="true"
        k_list = []
        for ss in [4, 8]:
            trials = exp[exp["set_size"]==ss]
            if len(trials)==0:
                continue
            diff = trials[trials["condition"]=="d"]
            same = trials[trials["condition"]=="s"]
            if len(diff)==0 or len(same)==0:
                continue
            hit = diff["acc_bool"].mean()
            cr  = same["acc_bool"].mean()
            k_list.append(float(ss)*(hit+cr-1))
        if k_list:
            ks[pid] = np.mean(k_list)
    return ks

wm_k_map = load_wm_k(WM_DIR)
print(f"  WM K scores loaded for {len(wm_k_map)} subjects")

# -- WSLS on ALL 18 subjects (matching wm_wsls.py — no exclusion before merge) --
wsls_df_all, pids_all = make_wsls_df(all_records, set())
idata_wsls = fit_wsls(wsls_df_all, len(pids_all), "wm_wsls_step1_all18", CACHE_WSLS)
beta_draws_all = idata_wsls.posterior["beta"].values
beta_median    = np.median(beta_draws_all.reshape(-1, len(pids_all)), axis=0)

# inner join: subjects with both WM and WSLS data
paired = [(wm_k_map[p], beta_median[i]) for i, p in enumerate(pids_all) if p in wm_k_map]
print(f"  Matched subjects: {len(paired)}")
wm_k_arr   = np.array([x[0] for x in paired])
wsls_b_arr = np.array([x[1] for x in paired])

# -- Bayesian regression --
if os.path.exists(CACHE_REG):
    print(f"  Loading {CACHE_REG}")
    idata_reg = az.from_netcdf(CACHE_REG)
else:
    print(f"  Fitting WM→WSLS regression (N={len(wm_k_arr)}) …")
    wm_k_z = (wm_k_arr - wm_k_arr.mean()) / wm_k_arr.std()
    with pm.Model():
        intercept = pm.Normal("intercept", 0, 2)
        slope     = pm.Normal("slope",     0, 2)
        sigma     = pm.HalfNormal("sigma", 1)
        pm.Normal("obs", mu=intercept + slope*wm_k_z, sigma=sigma, observed=wsls_b_arr)
        idata_reg = pm.sample(1000, tune=1000, chains=4, target_accept=0.9,
                              progressbar=True, random_seed=42)
    az.to_netcdf(idata_reg, CACHE_REG)

slope_draws = idata_reg.posterior["slope"].values.flatten()
rows.append(row("WM→WSLS slope (WM K z-scored)", slope_draws, prior_sigma=2.0))

# 3. param_recovery: M1 and M2
print("\n=== param_recovery ===")
flat = lambda idata, v: idata.posterior[v].values.flatten()

idata_m1 = az.from_netcdf(os.path.join(ROOT, "param_recovery/draws_m1.nc"))
idata_m2 = az.from_netcdf(os.path.join(ROOT, "param_recovery/draws_m2.nc"))

rows.append(row("M1 α — group mean (sigmoid scale)", flat(idata_m1,"mu_alpha"),
                prior_sigma=3.0, transform=sigmoid))
rows.append(row("M1 β — group mean (raw)",           flat(idata_m1,"mu_beta"),
                prior_sigma=3.0))
rows.append(row("M1 κ — group mean (raw)",           flat(idata_m1,"mu_kappa"),
                prior_sigma=2.0))
rows.append(row("M1 δ — group mean (sigmoid scale)", flat(idata_m1,"mu_delta"),
                prior_sigma=3.0, transform=sigmoid))
rows.append(row("M2 κ — group mean (raw)",           flat(idata_m2,"mu_kappa"),
                prior_sigma=2.0))
rows.append(row("M2 δ — group mean (sigmoid scale)", flat(idata_m2,"mu_delta"),
                prior_sigma=3.0, transform=sigmoid))

# 4. wsls_scatter_posterior: beta_mu N=18 (same as WSLS panel 1 above — already computed)
#    (wsls_18_draws.nc — already captured in row 1)

# ── print table ───────────────────────────────────────────────────────────────
df_out = pd.DataFrame(rows)
print("\n\n" + "="*80)
print(df_out.to_string(index=False))
print("="*80)
df_out.to_csv(os.path.join(ROOT, "posterior_stats.csv"), index=False)
print(f"\nSaved → {os.path.join(ROOT, 'posterior_stats.csv')}")
