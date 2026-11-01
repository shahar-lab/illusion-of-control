data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;
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
  // alpha: inv_logit-normal, matches plogis(rnorm(mu, sigma)) in generate_data.R
  vector<lower=0, upper=1>[Nsubjects] alpha_sbj = inv_logit(mu_alpha + sigma_alpha * alpha_raw);
  // beta: log-normal, matches exp(rnorm(mu, sigma)) in generate_data.R
  vector<lower=0>[Nsubjects] beta_sbj = exp(mu_beta + sigma_beta * beta_raw);
}

model {
  mu_alpha ~ normal(0, 3);
  mu_beta  ~ normal(0, 3);

  sigma_alpha ~ normal(0, 3);
  sigma_beta  ~ normal(0, 3);

  alpha_raw ~ std_normal();
  beta_raw  ~ std_normal();

  {
    vector[Narms] Q_cards;
    real PE_rl;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards = rep_vector(0.5, Narms);
      }

      total_log_lik += categorical_logit_lpmf(ch_card[t] | beta_sbj[subject] * Q_cards);

      // only chosen arm updated (classic RW)
      PE_rl = reward[t] - Q_cards[ch_card[t]];
      Q_cards[ch_card[t]] += alpha_sbj[subject] * PE_rl;
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_pop = inv_logit(mu_alpha);
  real beta_pop  = exp(mu_beta);
}
