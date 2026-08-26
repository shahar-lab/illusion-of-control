data {
  int<lower=1> n_data;                      // Total number of trials (for all subjects)
  int<lower=1> n_subjects;                  // Number of subjects
  int<lower=2> n_arms;                      // Number of arms (all offered every trial)

  array[n_data] int<lower=1, upper=n_subjects> subject_index;
  array[n_data] int<lower=1, upper=n_arms> ch_card;          // Index of chosen arm (1 to n_arms)
  array[n_data] int<lower=0, upper=1> reward;                // Outcome of bandit arm pull
  array[n_data] int<lower=0, upper=1> first_trial_in_block;  // Binary indicator
}

parameters {
  // Group-level (population) parameters
  real mu_alpha;                // Mean learning rate across subjects
  real mu_beta;                 // Mean inverse temperature across subjects

  // Group-level standard deviations (for subject-level variability)
  real<lower=0> sigma_alpha;    // Variability in learning rate
  real<lower=0> sigma_beta;     // Variability in inverse temperature

  // Non-centered parameters (random effects in standard normal space)
  vector[n_subjects] alpha_raw;
  vector[n_subjects] beta_raw;
}

transformed parameters {
  // Subject-level parameters
  vector<lower=0, upper=1>[n_subjects] alpha_sbj;  // Learning rate per subject
  vector[n_subjects] beta_sbj;                     // Inverse temperature per subject

  for (subject in 1:n_subjects) {
    alpha_sbj[subject] = inv_logit(mu_alpha + sigma_alpha * alpha_raw[subject]);
    beta_sbj[subject] = mu_beta + sigma_beta * beta_raw[subject];
  }
}

model {
  // Priors for group-level parameters
  mu_alpha ~ normal(0, 4);
  mu_beta ~ normal(0, 4);

  // Priors for group-level standard deviations
  sigma_alpha ~ normal(0, 4);
  sigma_beta ~ normal(0, 4);

  // Priors for subject-specific random effects
  alpha_raw ~ normal(0, 1);
  beta_raw ~ normal(0, 1);

  // Likelihood: categorical softmax choice over all n_arms (no raffle subsetting)
  {
    array[n_subjects] vector[n_arms] Q_cards_by_subject;
    for (s in 1:n_subjects) {
      Q_cards_by_subject[s] = rep_vector(0.5, n_arms);
    }

    real total_log_lik = 0;

    for (t in 1:n_data) {
      int s = subject_index[t];

      // Reset Q-values at start of new block
      if (first_trial_in_block[t] == 1) {
        Q_cards_by_subject[s] = rep_vector(0.5, n_arms);
      }

      vector[n_arms] logits = beta_sbj[s] * Q_cards_by_subject[s];
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // Update chosen card's Q-value
      real PE = reward[t] - Q_cards_by_subject[s][ch_card[t]];
      Q_cards_by_subject[s][ch_card[t]] += alpha_sbj[s] * PE;
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_pop = inv_logit(mu_alpha);
  real beta_pop  = mu_beta;
}
