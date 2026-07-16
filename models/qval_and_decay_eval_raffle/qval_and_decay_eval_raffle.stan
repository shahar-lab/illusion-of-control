data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;
  int<lower=2> Nraffle;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;

  // arm ids offered each trial (global 1..Narms), chosen arm is one of them
  array[Ndata, Nraffle] int<lower=1, upper=Narms> offered_arms;
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
    alpha_rl_sbj[subject]  = inv_logit(mu_alpha_rl  + sigma_alpha_rl  * alpha_rl_raw[subject]);
    alpha_per_sbj[subject] = inv_logit(mu_alpha_per + sigma_alpha_per * alpha_per_raw[subject]);
    beta_per_sbj[subject]  = mu_beta_per + sigma_beta_per * beta_per_raw[subject];
    // log-normal distribution
    beta_rl_sbj[subject]   = exp(mu_beta_rl + sigma_beta_rl * beta_rl_raw[subject]);
  }
}

model {
  mu_alpha_rl  ~ normal(0, 3);
  mu_alpha_per ~ normal(0, 3);

  mu_beta_per ~ normal(0, 3);
  // Beta prior tightened for the log scale (exp transformation)
  mu_beta_rl  ~ normal(0, 3);

  sigma_alpha_rl  ~ normal(0, 3);
  sigma_alpha_per ~ normal(0, 3);
  sigma_beta_rl   ~ normal(0, 3);
  sigma_beta_per  ~ normal(0, 3);

  alpha_rl_raw  ~ normal(0, 1);
  alpha_per_raw ~ normal(0, 1);
  beta_rl_raw   ~ normal(0, 1);
  beta_per_raw  ~ normal(0, 1);

  {
    vector[Narms] Q_cards;
    vector[Narms] E_cards;
    vector[Nraffle] logits;
    int ch_pos;
    real PE_rl;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards = rep_vector(0.5, Narms);
        E_cards = rep_vector(0.0, Narms);
      }

      // gather logits over the offered arms only; locate the chosen arm's raffle position
      ch_pos = 0;
      for (a in 1:Nraffle) {
        int arm = offered_arms[t, a];
        logits[a] = (beta_rl_sbj[subject] * Q_cards[arm]) + (beta_per_sbj[subject] * E_cards[arm]);
        if (arm == ch_card[t]) ch_pos = a;
      }
      total_log_lik += categorical_logit_lpmf(ch_pos | logits);

      // Q: only chosen arm updated (classic RW)
      PE_rl = reward[t] - Q_cards[ch_card[t]];
      Q_cards[ch_card[t]] += alpha_rl_sbj[subject] * PE_rl;

      // E: all arms decay toward 0; chosen arm pulled toward 1
      E_cards = (1 - alpha_per_sbj[subject]) * E_cards;
      E_cards[ch_card[t]] += alpha_per_sbj[subject];
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_rl_pop  = inv_logit(mu_alpha_rl);
  real alpha_per_pop = inv_logit(mu_alpha_per);
  real beta_per_pop  = mu_beta_per;
  real beta_rl_pop   = exp(mu_beta_rl);
}
