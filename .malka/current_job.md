# Approved jobs: classic_qval recovery (random walk vs p = 0.5)

1. models/classic_qval/ — alpha = inv_logit(mu + sigma*raw), beta = exp(mu + sigma*raw); Q0 = 0.5; chosen-arm delta rule; categorical_logit(beta * Q). Priors mu ~ N(0,3), sigma ~ half-N(0,3), raw ~ N(0,1). No per-trial saved arrays.
2. parameter_recoveries/classic_qval_randomwalk_param_recovery/ — 3 arms all offered; Gaussian walk SD 0.05, clamped [0,1], start runif(0,1), one walk shared by subjects.
3. parameter_recoveries/classic_qval_p50_param_recovery/ — 3 arms, p(win) = 0.5 constant.
Both: Ntrials 150; alpha = plogis(N(0, 0.85)), beta = exp(N(-0.25, 0.75)); fixed seeds shared across folders, nested N=35 within N=200. Runs sanity_n20 (500+500), n35 and n200 (4 chains, 2000+2000) in run subfolders. Report divergences/Rhat/ESS, Pearson r, bias, slope, 90% CI coverage, posterior SD, population coverage, alpha-beta posterior and error correlations. No verdict thresholds. Repo 7-script layout + Word docx report.
4. parameter_recoveries/classic_qval_comparison.md.
