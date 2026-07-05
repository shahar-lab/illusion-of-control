// DR: Hierarchical model with accumulating perseveration trace only (no Q-learning)
// 3-arm free-choice (softmax over all 3 arms)
//
// No value learning: choice is driven purely by the perseveration trace E.
// Perseveration trace E accumulates choice history and resets to 0 at block boundaries:
//   each trial: E *= delta            (decay all arms, 0 < delta < 1)
//   after the choice is observed: E[choice] += rho
// Decision uses E after that trial's decay but before that trial's own increment,
// so the just-made choice cannot explain itself.
// Decision: categorical softmax(E)
// Data format matches abdr_3arm.stan, minus reward/first_trial (no Q to reset).

data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=3>         choice;               // chosen arm (1-indexed)
  array[Ndata] int<lower=0, upper=1>         first_trial_in_block; // 1 = first trial of this block (reset E)
}

parameters {
  real mu_delta;
  real mu_rho;

  real<lower=0> sigma_delta;
  real<lower=0> sigma_rho;

  vector[Nsubjects] delta_raw;
  vector[Nsubjects] rho_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] delta_sbj;
  vector[Nsubjects]                   rho_sbj;

  for (s in 1:Nsubjects) {
    delta_sbj[s] = inv_logit(mu_delta + sigma_delta * delta_raw[s]);
    rho_sbj[s]   = mu_rho   + sigma_rho   * rho_raw[s];
  }

  // forward pass — data must be sorted by (subject, block, trial)
  vector[Ndata] log_lik_trial;
  {
    vector[3] E = rep_vector(0.0, 3);
    for (t in 1:Ndata) {
      int s = subject_trial[t];
      if (first_trial_in_block[t] == 1) E = rep_vector(0.0, 3);

      E *= delta_sbj[s];

      vector[3] logits = E;
      log_lik_trial[t] = categorical_logit_lpmf(choice[t] | logits);

      E[choice[t]] += rho_sbj[s];
    }
  }
}

model {
  mu_delta ~ normal(0, 3);
  mu_rho   ~ normal(0, 2);

  sigma_delta ~ normal(0, 1);
  sigma_rho   ~ normal(0, 1);

  delta_raw ~ normal(0, 1);
  rho_raw   ~ normal(0, 1);

  target += sum(log_lik_trial);
}

generated quantities {
  real delta_pop = inv_logit(mu_delta);
  real rho_pop   = mu_rho;
}
