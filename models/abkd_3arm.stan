// M1: Hierarchical RL model with Q-learning + decaying perseveration
// 3-arm free-choice (softmax over all 3 arms)
//
// Q initialized at 0.5, updated via Rescorla-Wagner across all blocks.
// Perseveration trace: E[a] = delta^persev_exp * prev_arm_oh[a]
//   persev_exp and prev_arm_oh are precomputed in R (= 0 at block boundaries).
// Decision: categorical softmax(beta * Q + kappa * E)

data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=3>         choice;        // chosen arm (1-indexed)
  array[Ndata] real                           reward;
  array[Ndata] int<lower=0, upper=1>         first_trial;   // 1 = first trial of this subject (reset Q)
  array[Ndata] real<lower=0>                 persev_exp;    // run_after[t-1] - 1, 0 at block starts
  array[Ndata, 3] real<lower=0, upper=1>     prev_arm_oh;   // one-hot of prev arm, zeros at block starts
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

  vector[Nsubjects] alpha_raw;
  vector[Nsubjects] beta_raw;
  vector[Nsubjects] kappa_raw;
  vector[Nsubjects] delta_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_sbj;
  vector[Nsubjects]                   beta_sbj;
  vector[Nsubjects]                   kappa_sbj;
  vector<lower=0, upper=1>[Nsubjects] delta_sbj;

  for (s in 1:Nsubjects) {
    alpha_sbj[s] = inv_logit(mu_alpha + sigma_alpha * alpha_raw[s]);
    beta_sbj[s]  = mu_beta  + sigma_beta  * beta_raw[s];
    kappa_sbj[s] = mu_kappa + sigma_kappa * kappa_raw[s];
    delta_sbj[s] = inv_logit(mu_delta + sigma_delta * delta_raw[s]);
  }

  // forward pass — data must be sorted by (subject, block, trial)
  vector[Ndata] log_lik_trial;
  {
    vector[3] Q = rep_vector(0.5, 3);
    for (t in 1:Ndata) {
      int s = subject_trial[t];
      if (first_trial[t] == 1) Q = rep_vector(0.5, 3);

      vector[3] E;
      for (a in 1:3)
        E[a] = delta_sbj[s]^persev_exp[t] * prev_arm_oh[t, a];

      vector[3] logits = beta_sbj[s] * Q + kappa_sbj[s] * E;
      log_lik_trial[t] = categorical_logit_lpmf(choice[t] | logits);

      Q[choice[t]] += alpha_sbj[s] * (reward[t] - Q[choice[t]]);
    }
  }
}

model {
  mu_alpha ~ normal(0, 3);
  mu_beta  ~ normal(0, 3);
  mu_kappa ~ normal(0, 2);
  mu_delta ~ normal(0, 3);

  sigma_alpha ~ normal(0, 1);
  sigma_beta  ~ normal(0, 1);
  sigma_kappa ~ normal(0, 1);
  sigma_delta ~ normal(0, 1);

  alpha_raw ~ normal(0, 1);
  beta_raw  ~ normal(0, 1);
  kappa_raw ~ normal(0, 1);
  delta_raw ~ normal(0, 1);

  target += sum(log_lik_trial);
}

generated quantities {
  real alpha_pop = inv_logit(mu_alpha);
  real beta_pop  = mu_beta;
  real kappa_pop = mu_kappa;
  real delta_pop = inv_logit(mu_delta);
}
