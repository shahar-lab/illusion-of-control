// AB: Hierarchical RL model with Q-learning only (no perseveration)
// 3-arm free-choice (softmax over all 3 arms)
//
// Q initialized at 0.5 per subject, updated via Rescorla-Wagner, persists across blocks.
// Decision: categorical softmax(beta * Q)

data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=3>         choice;      // chosen arm (1-indexed)
  array[Ndata] real                           reward;
  array[Ndata] int<lower=0, upper=1>         first_trial; // 1 = first trial of this subject (reset Q)
}

parameters {
  real mu_alpha;
  real mu_beta;

  real<lower=0> sigma_alpha;
  real<lower=0> sigma_beta;

  vector[Nsubjects] alpha_raw;
  vector[Nsubjects] beta_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_sbj;
  vector[Nsubjects]                   beta_sbj;

  for (s in 1:Nsubjects) {
    alpha_sbj[s] = inv_logit(mu_alpha + sigma_alpha * alpha_raw[s]);
    beta_sbj[s]  = mu_beta  + sigma_beta  * beta_raw[s];
  }

  // forward pass — data must be sorted by (subject, block, trial)
  vector[Ndata] log_lik_trial;
  {
    vector[3] Q = rep_vector(0.5, 3);
    for (t in 1:Ndata) {
      int s = subject_trial[t];
      if (first_trial[t] == 1) Q = rep_vector(0.5, 3);

      vector[3] logits = beta_sbj[s] * Q;
      log_lik_trial[t] = categorical_logit_lpmf(choice[t] | logits);

      Q[choice[t]] += alpha_sbj[s] * (reward[t] - Q[choice[t]]);
    }
  }
}

model {
  mu_alpha ~ normal(0, 3);
  mu_beta  ~ normal(0, 3);

  sigma_alpha ~ normal(0, 1);
  sigma_beta  ~ normal(0, 1);

  alpha_raw ~ normal(0, 1);
  beta_raw  ~ normal(0, 1);

  target += sum(log_lik_trial);
}

generated quantities {
  real alpha_pop = inv_logit(mu_alpha);
  real beta_pop  = mu_beta;
}
