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
  real mu_delta;
  real mu_beta_rl;
  real mu_beta_per;

  real<lower=0> sigma_alpha_rl;
  real<lower=0> sigma_delta;
  real<lower=0> sigma_beta_rl;
  real<lower=0> sigma_beta_per;

  vector[Nsubjects] alpha_rl_raw;
  vector[Nsubjects] delta_raw;
  vector[Nsubjects] beta_rl_raw;
  vector[Nsubjects] beta_per_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_rl_sbj;
  vector<lower=0, upper=1>[Nsubjects] delta_sbj;
  vector<lower=0>[Nsubjects] beta_rl_sbj;
  vector[Nsubjects] beta_per_sbj;

  for (subject in 1:Nsubjects) {
    alpha_rl_sbj[subject] = inv_logit(mu_alpha_rl + sigma_alpha_rl * alpha_rl_raw[subject]);
    delta_sbj[subject]    = inv_logit(mu_delta    + sigma_delta    * delta_raw[subject]);
    beta_rl_sbj[subject]  = exp(mu_beta_rl        + sigma_beta_rl  * beta_rl_raw[subject]);
    beta_per_sbj[subject] = mu_beta_per            + sigma_beta_per * beta_per_raw[subject];
  }
}

model {
  mu_alpha_rl ~ normal(0, 3);
  mu_delta    ~ normal(0, 3);
  mu_beta_per ~ normal(0, 3);
  // Beta prior tightened for the log scale (exp transformation)
  mu_beta_rl  ~ normal(0, 1.5);

  sigma_alpha_rl ~ normal(0, 2);
  sigma_delta    ~ normal(0, 2);
  sigma_beta_rl  ~ normal(0, 2);
  sigma_beta_per ~ normal(0, 2);

  alpha_rl_raw ~ normal(0, 1);
  delta_raw    ~ normal(0, 1);
  beta_rl_raw  ~ normal(0, 1);
  beta_per_raw ~ normal(0, 1);

  // Likelihood computed locally rather than as a saved transformed parameter:
  // a per-trial log_lik array written out for every posterior draw becomes
  // prohibitively large once Ndata (Nsubjects x Ntrials) gets big.
  {
    vector[Narms] Q_cards;
    vector[Narms] E_cards;
    vector[Narms] logits;
    real total_log_lik = 0;
    int streak;
    int prev_choice;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards   = rep_vector(0.5, Narms);
        E_cards   = rep_vector(0.0, Narms);
        streak      = 0;
        prev_choice = 0;
      }

      logits = (beta_rl_sbj[subject] * Q_cards) + (beta_per_sbj[subject] * E_cards);
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // Rescorla-Wagner Q update
      Q_cards[ch_card[t]] += alpha_rl_sbj[subject] * (reward[t] - Q_cards[ch_card[t]]);

      // Streak tracking
      if (ch_card[t] == prev_choice) {
        streak += 1;
      } else {
        streak = 1;
      }
      prev_choice = ch_card[t];

      // E update: unchosen arms reset to 0, chosen arm gets delta^(streak-1)
      E_cards = rep_vector(0.0, Narms);
      E_cards[ch_card[t]] = pow(delta_sbj[subject], streak - 1);
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_rl_pop = inv_logit(mu_alpha_rl);
  real delta_pop    = inv_logit(mu_delta);
  real beta_rl_pop  = exp(mu_beta_rl);
  real beta_per_pop = mu_beta_per;
}
