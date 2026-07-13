data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] real reward;
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
  vector<lower=0, upper=1>[Nsubjects] alpha_rl_sbj;
  vector<lower=0, upper=1>[Nsubjects] alpha_per_sbj;
  vector[Nsubjects] beta_per_sbj;
  // Bounded at 0!
  vector<lower=0>[Nsubjects] beta_rl_sbj;

  for (subject in 1:Nsubjects) {
    alpha_rl_sbj[subject]  = inv_logit(mu_alpha_rl  + sigma_alpha_rl  * alpha_rl_raw[subject]);
    alpha_per_sbj[subject] = inv_logit(mu_alpha_per + sigma_alpha_per * alpha_per_raw[subject]);
    beta_per_sbj[subject]  = mu_beta_per + sigma_beta_per * beta_per_raw[subject];

    // log-normal distribution
    beta_rl_sbj[subject]   = exp(mu_beta_rl + sigma_beta_rl * beta_rl_raw[subject]);
  }

  real PE_per;

  vector[Narms] logits;
  vector[Ndata] log_lik;
  vector[Narms] Q_cards;
  vector[Narms] E_cards;

  for (t in 1:Ndata) {
    int subject = subject_trial[t];

    // Reset initial values
    if (t == 1 || subject != subject_trial[t - 1]) {
      Q_cards = rep_vector(0.0, Narms);
      E_cards = rep_vector(0.0, Narms);
    }

    logits = (beta_rl_sbj[subject] * Q_cards) + (beta_per_sbj[subject] * E_cards);

    log_lik[t] = categorical_logit_lpmf(ch_card[t] | logits);

    PE_per = 1.0 - E_cards[ch_card[t]];

    // Decay all Q values, then update chosen arm
    Q_cards = Q_cards * (1.0 - alpha_rl_sbj[subject]);
    Q_cards[ch_card[t]] += alpha_rl_sbj[subject] * reward[t];

    E_cards[ch_card[t]] += alpha_per_sbj[subject] * PE_per;
  }
}

model {
  mu_alpha_rl  ~ normal(0, 3);
  mu_alpha_per ~ normal(0, 3);

  mu_beta_per ~ normal(0, 3);
  // Beta prior tightened for the log scale (exp transformation)
  mu_beta_rl  ~ normal(0, 1.5);

  sigma_alpha_rl  ~ normal(0, 2);
  sigma_alpha_per ~ normal(0, 2);
  sigma_beta_rl   ~ normal(0, 2);
  sigma_beta_per  ~ normal(0, 2);

  alpha_rl_raw  ~ normal(0, 1);
  alpha_per_raw ~ normal(0, 1);
  beta_rl_raw   ~ normal(0, 1);
  beta_per_raw  ~ normal(0, 1);

  target += sum(log_lik);
}

generated quantities {
  real alpha_rl_pop  = inv_logit(mu_alpha_rl);
  real alpha_per_pop = inv_logit(mu_alpha_per);
  real beta_per_pop  = mu_beta_per;

  real beta_rl_pop = exp(mu_beta_rl);

  array[Ndata, Narms] real Q_trial;
  array[Ndata, Narms] real E_trial;

  {
    vector[Narms] Q_cards;
    vector[Narms] E_cards;
    real PE_per;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards = rep_vector(0.0, Narms);
        E_cards = rep_vector(0.0, Narms);
      }

      // Save the current values BEFORE the update
      for (a in 1:Narms) {
        Q_trial[t, a] = Q_cards[a];
        E_trial[t, a] = E_cards[a];
      }

      PE_per = 1.0 - E_cards[ch_card[t]];

      // Decay all Q values, then update chosen arm
      Q_cards = Q_cards * (1.0 - alpha_rl_sbj[subject]);
      Q_cards[ch_card[t]] += alpha_rl_sbj[subject] * reward[t];

      E_cards[ch_card[t]] += alpha_per_sbj[subject] * PE_per;
    }
  }
}
