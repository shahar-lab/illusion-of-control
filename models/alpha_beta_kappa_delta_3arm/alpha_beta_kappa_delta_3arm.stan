data {
  int<lower=1> n_data;
  int<lower=1> n_subjects;
  int<lower=2> n_arms;

  array[n_data] int<lower=1, upper=n_subjects> subject_index;
  array[n_data] int<lower=1, upper=n_arms> ch_card;
  array[n_data] int<lower=0, upper=1> reward;
  array[n_data] int<lower=0, upper=1> first_trial_in_block;
}

parameters {
  real mu_alpha;
  real mu_beta;
  real mu_kappa;
  real mu_delta;

  real<lower=0> sigma_alpha;
  real<lower=0> sigma_beta;
  real<lower=0> sigma_kappa;
  real<lower=0> sigma_delta;

  vector[n_subjects] alpha_raw;
  vector[n_subjects] beta_raw;
  vector[n_subjects] kappa_raw;
  vector[n_subjects] delta_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[n_subjects] alpha_sbj;
  vector[n_subjects] beta_sbj;
  vector<lower=0, upper=1>[n_subjects] kappa_sbj;
  vector[n_subjects] delta_sbj;

  for (subject in 1:n_subjects) {
    alpha_sbj[subject] = inv_logit(mu_alpha + sigma_alpha * alpha_raw[subject]);
    beta_sbj[subject]  = mu_beta + sigma_beta * beta_raw[subject];
    kappa_sbj[subject] = inv_logit(mu_kappa + sigma_kappa * kappa_raw[subject]);
    delta_sbj[subject] = mu_delta + sigma_delta * delta_raw[subject];
  }
}

model {
  mu_alpha ~ normal(0, 4);
  mu_beta  ~ normal(0, 4);
  mu_kappa ~ normal(0, 4);
  mu_delta ~ normal(0, 4);

  sigma_alpha ~ normal(0, 4);
  sigma_beta  ~ normal(0, 4);
  sigma_kappa ~ normal(0, 4);
  sigma_delta ~ normal(0, 4);

  alpha_raw ~ normal(0, 1);
  beta_raw  ~ normal(0, 1);
  kappa_raw ~ normal(0, 1);
  delta_raw ~ normal(0, 1);

  // Likelihood: categorical softmax over all n_arms (no raffle subsetting)
  {
    array[n_subjects] vector[n_arms] Q_cards_by_subject;
    array[n_subjects] vector[n_arms] E_cards_by_subject;
    for (s in 1:n_subjects) {
      Q_cards_by_subject[s] = rep_vector(0.5, n_arms);
      E_cards_by_subject[s] = rep_vector(0.0, n_arms);
    }

    real total_log_lik = 0;

    for (t in 1:n_data) {
      int s = subject_index[t];

      // Reset Q-values and E-values at start of new block
      if (first_trial_in_block[t] == 1) {
        Q_cards_by_subject[s] = rep_vector(0.5, n_arms);
        E_cards_by_subject[s] = rep_vector(0.0, n_arms);
      }

      vector[n_arms] logits = beta_sbj[s] * Q_cards_by_subject[s] + delta_sbj[s] * E_cards_by_subject[s];
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // Q: only chosen arm updated (classic Rescorla-Wagner)
      real PE = reward[t] - Q_cards_by_subject[s][ch_card[t]];
      Q_cards_by_subject[s][ch_card[t]] += alpha_sbj[s] * PE;

      // E: all arms decay toward 0; chosen arm pulled toward 1
      E_cards_by_subject[s] = (1 - kappa_sbj[s]) * E_cards_by_subject[s];
      E_cards_by_subject[s][ch_card[t]] += kappa_sbj[s];
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_pop = inv_logit(mu_alpha);
  real beta_pop  = mu_beta;
  real kappa_pop = inv_logit(mu_kappa);
  real delta_pop = mu_delta;
}
