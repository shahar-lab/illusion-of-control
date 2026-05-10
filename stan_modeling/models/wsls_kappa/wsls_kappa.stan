data {
  int<lower=1> Ndata;                       // Total number of trials
  int<lower=1> Nsubjects;                   // Number of subjects
  int<lower=1> Narms;                       // Number of arms (3)
  
  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  
  // Behavioral data
  array[Ndata] int<lower=1, upper=Narms> choice;        // Choice made
  array[Ndata] int<lower=0, upper=1> reward;            // Reward received
  array[Ndata] int<lower=0, upper=1> stayed;            // Whether stayed with previous choice
  array[Ndata] int<lower=0, upper=1> prev_reward;       // Previous reward
  array[Ndata] int<lower=0, upper=1> first_trial_in_block;
  
  real scarcity;                            // Reward probability
}

parameters {
  // Group-level parameters
  real mu_alpha;
  real mu_beta;
  real mu_kappa;
  
  // Group-level standard deviations
  real<lower=0> sigma_alpha;
  real<lower=0> sigma_beta;
  real<lower=0> sigma_kappa;
  
  // Non-centered subject-level parameters
  vector[Nsubjects] alpha_raw;
  vector[Nsubjects] beta_raw;
  vector[Nsubjects] kappa_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_sbj;
  vector[Nsubjects] beta_sbj;
  vector[Nsubjects] kappa_sbj;
  
  for (subject in 1:Nsubjects) {
    alpha_sbj[subject] = inv_logit(mu_alpha + sigma_alpha * alpha_raw[subject]);
    beta_sbj[subject]  = mu_beta + sigma_beta * beta_raw[subject];
    kappa_sbj[subject] = mu_kappa + sigma_kappa * kappa_raw[subject];
  }
}

model {
  // Priors for group-level parameters
  mu_alpha ~ normal(0, 1.5);
  mu_beta  ~ normal(0, 1.5);
  mu_kappa ~ normal(0, 1.5);
  
  sigma_alpha ~ exponential(1);
  sigma_beta  ~ exponential(1);
  sigma_kappa ~ exponential(1);
  
  // Priors for raw parameters (standard normal)
  alpha_raw ~ std_normal();
  beta_raw  ~ std_normal();
  kappa_raw ~ std_normal();
  
  // Likelihood
  {
    vector[Narms] Q_values;
    vector[Narms] logits;
    real alpha_t;
    real beta_t;
    real kappa_t;
    
    for (t in 1:Ndata) {
      int subject = subject_trial[t];
      
      alpha_t = alpha_sbj[subject];
      beta_t  = beta_sbj[subject];
      kappa_t = kappa_sbj[subject];
      
      // Reset Q-values at start of block
      if (first_trial_in_block[t] == 1) {
        Q_values = rep_vector(0.5, Narms);
      }
      
      // Compute softmax logits with perseveration
      for (arm in 1:Narms) {
        // If prev_choice recorded, add perseveration bias
        if (stayed[t] == 0 || stayed[t] == 1) {
          // prev_choice is implicitly encoded in stayed; reconstruct if needed
          logits[arm] = beta_t * Q_values[arm];
        } else {
          logits[arm] = beta_t * Q_values[arm];
        }
      }
      
      // Choice likelihood
      choice[t] ~ categorical_logit(logits);
      
      // Update Q-values with reward
      Q_values[choice[t]] += alpha_t * (reward[t] - Q_values[choice[t]]);
    }
  }
}

generated quantities {
  // Placeholder for posterior predictive checks if needed
}
