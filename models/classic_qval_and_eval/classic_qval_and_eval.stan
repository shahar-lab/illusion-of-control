data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;
  
  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;
  array[Ndata] int<lower=0, upper=1> first_trial_in_block;
}

parameters {
  real mu_alpha_rl;
  real mu_alpha_per;
  real mu_beta_rl;
  real mu_beta_per;
  
  real<lower=0> sigma_alpha_rl;
  real<lower=0> sigma_alpha_per;
  real<lower=0> sigma_beta_rl;
  real<lower=0> sigma_beta_per;
  
  vector[Nsubjects] alpha_rl_raw;
  vector[Nsubjects] alpha_per_raw;
  vector[Nsubjects] beta_rl_raw;
  vector[Nsubjects] beta_per_raw;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_rl_sbj;
  vector<lower=0, upper=1>[Nsubjects] alpha_per_sbj;
  vector[Nsubjects] beta_per_sbj;
  // Bounded at 0!
  vector<lower=0>[Nsubjects] beta_rl_sbj; 
  
  for (subject in 1:Nsubjects) {
    alpha_rl_sbj[subject] = inv_logit(mu_alpha_rl + sigma_alpha_rl * alpha_rl_raw[subject]);
    alpha_per_sbj[subject] = inv_logit(mu_alpha_per + sigma_alpha_per * alpha_per_raw[subject]);
    
    // log-normal distribution
    beta_rl_sbj[subject] = exp(mu_beta_rl + sigma_beta_rl * beta_rl_raw[subject]);
    beta_per_sbj[subject] = exp(mu_beta_per + sigma_beta_per * beta_per_raw[subject]);
  }
  
  real PE_rl;
  real PE_per;
  
  vector[Narms] logits; 
  vector[Ndata] log_lik;
  vector[Narms] Q_cards;
  vector[Narms] E_cards;

  for (t in 1:Ndata) {
    int subject = subject_trial[t];
    
    // Reset initial Q values
    if (t == 1 || subject != subject_trial[t - 1]) {
      Q_cards = rep_vector(0.5, Narms);
    }
    
    // Reset E values at start of each block
    if (first_trial_in_block[t] == 1) {
      E_cards = rep_vector(0.0, Narms);
    }
    
    logits = (beta_rl_sbj[subject] * Q_cards) + (beta_per_sbj[subject] * E_cards);
    
    log_lik[t] = categorical_logit_lpmf(ch_card[t] | logits);
    
    PE_rl = reward[t] - Q_cards[ch_card[t]];
    PE_per = 1.0 - E_cards[ch_card[t]];
    
    Q_cards[ch_card[t]] += alpha_rl_sbj[subject] * PE_rl;
    E_cards[ch_card[t]] += alpha_per_sbj[subject] * PE_per;
  }
}

model {
  mu_alpha_rl ~ normal(0, 3);
  mu_alpha_per ~ normal(0, 3);
  
  // Beta priors tightened for the log scale (exp transformation)
  mu_beta_rl ~ normal(0, 1.5);
  mu_beta_per ~ normal(0, 1.5);
  
  sigma_alpha_rl ~ normal(0, 2);
  sigma_alpha_per ~ normal(0, 2);
  sigma_beta_rl ~ normal(0, 2);
  sigma_beta_per ~ normal(0, 2);
  
  alpha_rl_raw ~ normal(0, 1);
  alpha_per_raw ~ normal(0, 1);
  beta_rl_raw ~ normal(0, 1);
  beta_per_raw ~ normal(0, 1);
  
  target += sum(log_lik);
}