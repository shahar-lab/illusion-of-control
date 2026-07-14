data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;
}

parameters {
  real mu_alpha_per;
  real mu_beta_per;

  real<lower=0> sigma_alpha_per;
  real<lower=0> sigma_beta_per;

  vector[Nsubjects] alpha_per_raw;
  vector[Nsubjects] beta_per_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_per_sbj;
  vector[Nsubjects] beta_per_sbj;

  for (subject in 1:Nsubjects) {
    alpha_per_sbj[subject] = inv_logit(mu_alpha_per + sigma_alpha_per * alpha_per_raw[subject]);
    beta_per_sbj[subject]  = mu_beta_per + sigma_beta_per * beta_per_raw[subject];
  }
}

model {
  mu_alpha_per ~ normal(0, 3);
  mu_beta_per  ~ normal(0, 3);

  sigma_alpha_per ~ normal(0, 2);
  sigma_beta_per  ~ normal(0, 2);

  alpha_per_raw ~ normal(0, 1);
  beta_per_raw  ~ normal(0, 1);

  {
    vector[Narms] E_cards;
    vector[Narms] logits;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        E_cards = rep_vector(0.0, Narms);
      }

      logits = beta_per_sbj[subject] * E_cards;
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // All arms decay toward 0; chosen arm pulled toward 1.
      // E += alpha * (a - E)  =>  E = (1-alpha)*E; E[chosen] += alpha
      E_cards = (1 - alpha_per_sbj[subject]) * E_cards;
      E_cards[ch_card[t]] += alpha_per_sbj[subject];
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_per_pop = inv_logit(mu_alpha_per);
  real beta_per_pop  = mu_beta_per;
}
