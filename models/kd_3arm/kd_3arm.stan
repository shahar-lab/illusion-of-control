// KD: Hierarchical model with decaying perseveration only (no Q-learning)
// 3-arm free-choice (softmax over all 3 arms)
//
// No value learning: Q fixed at 0.5 throughout.
// Perseveration trace: E[a] = delta^persev_exp * prev_arm_oh[a]
// Decision: categorical softmax(kappa * E)
// Data format identical to abkd_3arm.stan.

data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=3>         choice;
  array[Ndata] real                           reward;
  array[Ndata] int<lower=0, upper=1>         first_trial;
  array[Ndata] real<lower=0>                 persev_exp;
  array[Ndata, 3] real<lower=0, upper=1>     prev_arm_oh;
}

parameters {
  real mu_kappa;
  real mu_delta;

  real<lower=0> sigma_kappa;
  real<lower=0> sigma_delta;

  vector[Nsubjects] kappa_raw;
  vector[Nsubjects] delta_raw;
}

transformed parameters {
  vector[Nsubjects]                   kappa_sbj;
  vector<lower=0, upper=1>[Nsubjects] delta_sbj;

  for (s in 1:Nsubjects) {
    kappa_sbj[s] = mu_kappa + sigma_kappa * kappa_raw[s];
    delta_sbj[s] = inv_logit(mu_delta + sigma_delta * delta_raw[s]);
  }

  vector[Ndata] log_lik_trial;
  {
    for (t in 1:Ndata) {
      int s = subject_trial[t];

      vector[3] E;
      for (a in 1:3)
        E[a] = delta_sbj[s]^persev_exp[t] * prev_arm_oh[t, a];

      vector[3] logits = kappa_sbj[s] * E;
      log_lik_trial[t] = categorical_logit_lpmf(choice[t] | logits);
    }
  }
}

model {
  mu_kappa ~ normal(0, 2);
  mu_delta ~ normal(0, 3);

  sigma_kappa ~ normal(0, 1);
  sigma_delta ~ normal(0, 1);

  kappa_raw ~ normal(0, 1);
  delta_raw ~ normal(0, 1);

  target += sum(log_lik_trial);
}

generated quantities {
  real kappa_pop = mu_kappa;
  real delta_pop = inv_logit(mu_delta);
}
