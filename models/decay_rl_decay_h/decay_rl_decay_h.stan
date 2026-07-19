data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;
}

parameters {
  real mu_decay_rl;
  real mu_decay_h;
  real mu_rho_rl;
  real mu_rho_h;

  real<lower=0> sigma_decay_rl;
  real<lower=0> sigma_decay_h;
  real<lower=0> sigma_rho_rl;
  real<lower=0> sigma_rho_h;

  vector[Nsubjects] decay_rl_raw;
  vector[Nsubjects] decay_h_raw;
  vector[Nsubjects] rho_rl_raw;
  vector[Nsubjects] rho_h_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] decay_rl_sbj;
  vector<lower=0, upper=1>[Nsubjects] decay_h_sbj;
  vector[Nsubjects] rho_rl_sbj;
  vector[Nsubjects] rho_h_sbj;

  for (subject in 1:Nsubjects) {
    decay_rl_sbj[subject] = inv_logit(mu_decay_rl + sigma_decay_rl * decay_rl_raw[subject]);
    decay_h_sbj[subject]  = inv_logit(mu_decay_h  + sigma_decay_h  * decay_h_raw[subject]);
    rho_rl_sbj[subject]   = mu_rho_rl + sigma_rho_rl * rho_rl_raw[subject];
    rho_h_sbj[subject]    = mu_rho_h  + sigma_rho_h  * rho_h_raw[subject];
  }
}

model {
  mu_decay_rl ~ normal(0, 3);
  mu_decay_h  ~ normal(0, 3);
  mu_rho_rl   ~ normal(0, 3);
  mu_rho_h    ~ normal(0, 3);

  sigma_decay_rl ~ normal(0, 3);
  sigma_decay_h  ~ normal(0, 3);
  sigma_rho_rl   ~ normal(0, 3);
  sigma_rho_h    ~ normal(0, 3);

  decay_rl_raw ~ normal(0, 1);
  decay_h_raw  ~ normal(0, 1);
  rho_rl_raw   ~ normal(0, 1);
  rho_h_raw    ~ normal(0, 1);

  {
    vector[Narms] Q_cards;
    vector[Narms] H_cards;
    vector[Narms] logits;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards = rep_vector(0.0, Narms);
        H_cards = rep_vector(0.0, Narms);
      }

      logits = Q_cards + H_cards;
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      Q_cards = (1 - decay_rl_sbj[subject]) * Q_cards;
      Q_cards[ch_card[t]] += rho_rl_sbj[subject] * reward[t];

      H_cards = (1 - decay_h_sbj[subject]) * H_cards;
      H_cards[ch_card[t]] += rho_h_sbj[subject];
    }

    target += total_log_lik;
  }
}

generated quantities {
  real decay_rl_pop = inv_logit(mu_decay_rl);
  real decay_h_pop  = inv_logit(mu_decay_h);
  real rho_rl_pop   = mu_rho_rl;
  real rho_h_pop    = mu_rho_h;
}
