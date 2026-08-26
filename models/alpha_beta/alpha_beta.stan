data {
  int<lower=1> n_data;                      // Total number of trials (for all subjects)
  int<lower=1> n_subjects;                  // Number of subjects
  int<lower=2> n_arms;                      // Number of overall alternatives
  int<lower=2> n_raffle;                    // Number of cards per trial
  int<lower=2> n_dims;                      // Number of dimensions

  // Behavioral data (each variable being a subject x trial matrix)
  // Data is padded in make_standata function so all subjects have same number of trials
  array[n_data] int<lower=1, upper=n_subjects> subject_index;
  array[n_data] int<lower=1, upper=n_arms> ch_card;       // Index of which card was chosen (1 to n_arms)
  array[n_data] int<lower=1, upper=n_raffle> ch_key;      // Position of chosen card in options (1 to n_raffle)
  array[n_data] int<lower=0, upper=1> reward;             // Outcome of bandit arm pull
  array[n_data] int<lower=1, upper=n_arms> card_left;     // Offered card in left bandit
  array[n_data] int<lower=1, upper=n_arms> card_right;    // Offered card in right bandit
  array[n_data] int<lower=0, upper=1> first_trial_in_block;  // Binary indicator
  array[n_data] int<lower=0, upper=1> selected_offer;        // Binary choice (0=left, 1=right)
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

  // Trial-level decision variable
  vector[n_data] Q_diff;

  // Compute Q-values and log-odds for each trial
  {
    // Local variables for Q-value learning (per subject)
    array[n_subjects] vector[n_arms] Q_cards_by_subject;
    for (s in 1:n_subjects) {
      Q_cards_by_subject[s] = rep_vector(0.5, n_arms);
    }

    for (t in 1:n_data) {
      int s = subject_index[t];

      // Reset Q-values at start of new block
      if (first_trial_in_block[t] == 1) {
        Q_cards_by_subject[s] = rep_vector(0.5, n_arms);
      }

      // Get Q-values for offered cards (left and right)
      real Q_left_val = Q_cards_by_subject[s][card_left[t]];
      real Q_right_val = Q_cards_by_subject[s][card_right[t]];

      // Compute log-odds difference (higher values favor right option)
      Q_diff[t] = beta_sbj[s] * (Q_right_val - Q_left_val);

      // Calculate prediction error
      real PE = reward[t] - Q_cards_by_subject[s][ch_card[t]];

      // Update chosen card's Q-value
      Q_cards_by_subject[s][ch_card[t]] += alpha_sbj[s] * PE;
    }
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

  // Likelihood
  target += bernoulli_logit_lpmf(selected_offer | Q_diff);
}

generated quantities {
  vector[n_data] log_lik;
  for (n in 1:n_data) {
    log_lik[n] = bernoulli_logit_lpmf(selected_offer[n] | Q_diff[n]);
  }
}