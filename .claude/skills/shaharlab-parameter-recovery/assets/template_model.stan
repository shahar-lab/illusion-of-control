// Template for a hierarchical parameter-recovery Stan model in this lab.
// 4-parameter Q-value + decaying-perseveration-trace model shown here; drop
// alpha_rl/beta_rl/Q_cards for a perseveration-only model. Whatever the actual
// parameter set, follow the two structural rules below — both are hard-won fixes
// for real bugs (see STAN_PITFALLS.md).

data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;
}

parameters {
  real mu_alpha_rl;
  real mu_alpha_per;
  real mu_beta_rl;
  real mu_beta_per;

  real<lower=0> sigma_alpha_rl;
  real<lower=0> sigma_alpha_per;
  real<lower=0> sigma_beta_rl;
  real<lower=0> sigma_beta_per;

  vector[Nsubjects] alpha_rl_raw;
  vector[Nsubjects] alpha_per_raw;
  vector[Nsubjects] beta_rl_raw;
  vector[Nsubjects] beta_per_raw;
}

transformed parameters {
  // RULE: only ever keep Nsubjects-length (or scalar) quantities here. Never an
  // Ndata-length array like log_lik[Ndata] — see STAN_PITFALLS.md #1.
  vector<lower=0, upper=1>[Nsubjects] alpha_rl_sbj;
  vector<lower=0, upper=1>[Nsubjects] alpha_per_sbj;
  vector[Nsubjects] beta_per_sbj;
  vector<lower=0>[Nsubjects] beta_rl_sbj;   // log-normal, bounded > 0

  for (subject in 1:Nsubjects) {
    alpha_rl_sbj[subject]  = inv_logit(mu_alpha_rl  + sigma_alpha_rl  * alpha_rl_raw[subject]);
    alpha_per_sbj[subject] = inv_logit(mu_alpha_per + sigma_alpha_per * alpha_per_raw[subject]);
    beta_per_sbj[subject]  = mu_beta_per + sigma_beta_per * beta_per_raw[subject];
    beta_rl_sbj[subject]   = exp(mu_beta_rl + sigma_beta_rl * beta_rl_raw[subject]);
  }
}

model {
  mu_alpha_rl  ~ normal(0, 3);
  mu_alpha_per ~ normal(0, 3);
  mu_beta_per  ~ normal(0, 3);
  mu_beta_rl   ~ normal(0, 1.5);

  sigma_alpha_rl  ~ normal(0, 2);
  sigma_alpha_per ~ normal(0, 2);
  sigma_beta_rl   ~ normal(0, 2);
  sigma_beta_per  ~ normal(0, 2);

  alpha_rl_raw  ~ normal(0, 1);
  alpha_per_raw ~ normal(0, 1);
  beta_rl_raw   ~ normal(0, 1);
  beta_per_raw  ~ normal(0, 1);

  // RULE: compute the likelihood as a local, unsaved accumulator in an anonymous
  // block. Do NOT declare `vector[Ndata] log_lik;` in transformed parameters — that
  // gets written to the output CSV for every posterior draw and OOM-crashes larger
  // runs. See STAN_PITFALLS.md #1.
  {
    vector[Narms] Q_cards;
    vector[Narms] E_cards;
    vector[Narms] logits;
    real PE_rl;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards = rep_vector(0.5, Narms);
        E_cards = rep_vector(0.0, Narms);
      }

      logits = (beta_rl_sbj[subject] * Q_cards) + (beta_per_sbj[subject] * E_cards);
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // Q: only chosen arm updated (classic Rescorla-Wagner)
      PE_rl = reward[t] - Q_cards[ch_card[t]];
      Q_cards[ch_card[t]] += alpha_rl_sbj[subject] * PE_rl;

      // E: all arms decay toward 0; chosen arm pulled toward 1
      E_cards = (1 - alpha_per_sbj[subject]) * E_cards;
      E_cards[ch_card[t]] += alpha_per_sbj[subject];
    }

    target += total_log_lik;
  }
}

generated quantities {
  // RULE: only scalars here (population-level quantities used by
  // plot_population_posteriors.R). If you ever add a local recomputation block for
  // per-trial trajectories, give its variables distinct names (e.g. `Q_cards_gq`) —
  // reusing `Q_cards`/`E_cards` from transformed parameters is a duplicate-identifier
  // compile error. See STAN_PITFALLS.md #2. In practice: don't add such a block at all
  // unless something downstream actually reads it (nothing has, so far).
  real alpha_rl_pop  = inv_logit(mu_alpha_rl);
  real alpha_per_pop = inv_logit(mu_alpha_per);
  real beta_per_pop  = mu_beta_per;
  real beta_rl_pop   = exp(mu_beta_rl);
}
