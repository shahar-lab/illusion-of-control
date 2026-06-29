data {
  
 int<lower=1> Ndata;                // Total number of trials (for all subjects)
  int<lower=1> Nsubjects; //number of subjects

  int<lower=2> Narms; //number of overall alternatives

  int<lower=2> Nraffle; //number of cards per trial

  int<lower=2> Ndims; //number of dimensions
  

  array [Ndata] int<lower=1, upper=Nsubjects> subject_trial; // Which subject performed each trial

  //Behavioral data:

  //each variable being a subject x trial matrix

  //the data is padded in make_standata function so that all subjects will have the same number of trials

  array[Ndata] int<lower=0> ch_card; //index of which card was chosen coded 1 to 4

  array[Ndata] int<lower=0> ch_key; //index of which card was chosen coded 1 to 4

  array[Ndata] int<lower=0> reward; //outcome of bandit arm pull

  array[Ndata] int<lower=0> card_left; //first offered card in the current offer pair

  array[Ndata] int<lower=0> card_right; //second offered card in the current offer pair

  array [Ndata] int <lower=0,upper=1> first_trial_in_block; // binary indicator

  array[Ndata] int<lower=0> selected_offer;

}

parameters {
  // Group-level (population) parameters
  real mu_alpha;        // Mean learning rate across subjects
  real mu_beta;         // Mean inverse temperature across subjects
  real mu_kappa;        // Mean perseveration bias across subjects
  
  // Group-level standard deviations (for subject-level variability)
  real<lower=0> sigma_alpha;          // Variability in learning rate
  real<lower=0> sigma_beta;           // Variability in inverse temperature
  real<lower=0> sigma_kappa;          // Variability in perseveration bias
  
  // Non-centered parameters (random effects in standard normal space)
  vector[Nsubjects] alpha_raw;
  vector[Nsubjects] beta_raw;
  vector[Nsubjects] kappa_raw;

}


transformed parameters {
  vector<lower=0,upper=1>[Nsubjects] alpha_sbj; // learning rate
  vector[Nsubjects] beta_sbj; // inverse temp
  
  for (subject in 1:Nsubjects){
    alpha_sbj[subject] = inv_logit(mu_alpha + sigma_alpha * alpha_raw[subject]);
    beta_sbj[subject] = mu_beta + sigma_beta * beta_raw[subject];
    kappa_sbj[subject] = mu_kappa + sigma_kappa * kappa_raw[subject];
  }
  real alpha_t;
  real beta_t;
  real kappa_t;
	
  real PE_card;
  vector[Narms] Qnet;
  vector [Ndata] Qnet_diff;
  vector [Narms] Q_cards;

    int prev_choice = 0;
  for (t in 1:Ndata) {
    alpha_t = alpha_sbj[subject_trial[t]];
    beta_t  = beta_sbj[subject_trial[t]];
    kappa_t = kappa_sbj[subject_trial[t]];

    if (first_trial_in_block[t] == 1) {
      Q_cards = rep_vector(0.5, Narms);
      prev_choice = 0;
    }

    Qnet[1] = Q_cards[card_left[t]] + (card_left[t] == prev_choice ? kappa_t : 0);
    Qnet[2] = Q_cards[card_right[t]] + (card_right[t] == prev_choice ? kappa_t : 0);

    // likelihood function
    Qnet_diff[t]  = beta_t * (Qnet[2] - Qnet[1]); //higher values of Qnet_diff mean higher chance to choose the second offered card

    // calculating PEs
    PE_card = reward[t] - Q_cards[ch_card[t]];

    // Update chosen card values; ch_key indexes the chosen offer within the pair
    Q_cards[ch_card[t]] += alpha_t * PE_card; //update card_value according to reward
    prev_choice = ch_card[t];
  }
}

model {
  
  // Priors for group-level parameters
  mu_alpha ~ normal(0, 3);
  mu_beta ~ normal(0, 3);
  mu_kappa ~ normal(0, 3);
  
  // Priors for group-level standard deviations
  sigma_alpha ~ normal(0, 2);
  sigma_beta ~ normal(0, 2);
  sigma_kappa ~ normal(0, 2);
  
  // Priors for subject-specific effects
  alpha_raw ~ normal(0, 1);
  beta_raw  ~ normal(0, 1);
  kappa_raw ~ normal(0, 1);
  
  target += bernoulli_logit_lpmf(selected_offer | Qnet_diff);
}

generated quantities {
  vector[Ndata] log_lik;
  for (n in 1:Ndata) {
    log_lik[n] = bernoulli_logit_lpmf(selected_offer[n] | Qnet_diff[n]);
  }
}
