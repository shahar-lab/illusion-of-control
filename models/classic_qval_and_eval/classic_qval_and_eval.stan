data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;
  
  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0> reward;
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
  vector[Nsubjects] beta_rl_sbj;
  vector[Nsubjects] beta_per_sbj;
  
  for (subject in 1:Nsubjects) {
    alpha_rl_sbj[subject] = inv_logit(mu_alpha_rl + sigma_alpha_rl * alpha_rl_raw[subject]);
    alpha_per_sbj[subject] = inv_logit(mu_alpha_per + sigma_alpha_per * alpha_per_raw[subject]);
    beta_rl_sbj[subject] = (mu_beta_rl + sigma_beta_rl * beta_rl_raw[subject]);
    beta_per_sbj[subject] = (mu_beta_per + sigma_beta_per * beta_per_raw[subject]);
  }
  
  real alpha_rl_t;
  real alpha_per_t;
  real beta_rl_t;
  real beta_per_t;
  
  real PE_rl;
  real PE_per;
  vector[Narms] Qnet;
  array[Ndata] vector[Narms] Qnet_trial;
  vector[Narms] Q_cards;
  vector[Narms] E_cards;

  for (t in 1:Ndata) {
    alpha_rl_t = alpha_rl_sbj[subject_trial[t]];
    alpha_per_t = alpha_per_sbj[subject_trial[t]];
    beta_rl_t = beta_rl_sbj[subject_trial[t]];
    beta_per_t = beta_per_sbj[subject_trial[t]];

    if (first_trial_in_block[t] == 1) {
      Q_cards = rep_vector(0.5, Narms);
      E_cards = rep_vector(0.0, Narms);
    }
    
    Qnet = (beta_rl_t * Q_cards) + (beta_per_t * E_cards);
    Qnet_trial[t] = Qnet;
    
    PE_rl = reward[t] - Q_cards[ch_card[t]];
    PE_per = 1.0 - E_cards[ch_card[t]];
    
    Q_cards[ch_card[t]] += alpha_rl_t * PE_rl;
    E_cards[ch_card[t]] += alpha_per_t * PE_per;
  }
}

model {
  mu_alpha_rl ~ normal(0, 3);
  mu_alpha_per ~ normal(0, 3);
  mu_beta_rl ~ normal(0, 3);
  mu_beta_per ~ normal(0, 3);
  
  sigma_alpha_rl ~ normal(0, 2);
  sigma_alpha_per ~ normal(0, 2);
  sigma_beta_rl ~ normal(0, 2);
  sigma_beta_per ~ normal(0, 2);
  
  alpha_rl_raw ~ normal(0, 1);
  alpha_per_raw ~ normal(0, 1);
  beta_rl_raw ~ normal(0, 1);
  beta_per_raw ~ normal(0, 1);
  
  for (t in 1:Ndata) {
    target += categorical_logit_lpmf(ch_card[t] | Qnet_trial[t]);
  }
}

generated quantities {
  vector[Ndata] log_lik;
  for (n in 1:Ndata) {
    log_lik[n] = categorical_logit_lpmf(ch_card[n] | Qnet_trial[n]);
  }
}