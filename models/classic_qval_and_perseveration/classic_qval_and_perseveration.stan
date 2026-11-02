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
  real mu_kappa;

  real<lower=0> sigma_alpha;
  real<lower=0> sigma_beta;
  real<lower=0> sigma_kappa;

  vector[Nsubjects] alpha_raw;
  vector[Nsubjects] beta_raw;
  vector[Nsubjects] kappa_raw;
}

transformed parameters {
  // alpha: inv_logit-normal, matches plogis(rnorm(mu, sigma)) in generate_data.R
  vector<lower=0, upper=1>[Nsubjects] alpha_sbj = inv_logit(mu_alpha + sigma_alpha * alpha_raw);
  // beta: log-normal, matches exp(rnorm(mu, sigma)) in generate_data.R
  vector<lower=0>[Nsubjects] beta_sbj = exp(mu_beta + sigma_beta * beta_raw);
  // kappa: normal, unbounded (positive = repeat, negative = switch)
  vector[Nsubjects] kappa_sbj = mu_kappa + sigma_kappa * kappa_raw;
}

model {
  mu_alpha ~ normal(0, 3);
  mu_beta  ~ normal(0, 3);
  mu_kappa ~ normal(0, 3);

  sigma_alpha ~ normal(0, 3);
  sigma_beta  ~ normal(0, 3);
  sigma_kappa ~ normal(0, 3);

  alpha_raw ~ std_normal();
  beta_raw  ~ std_normal();
  kappa_raw ~ std_normal();

  {
    vector[Narms] Q_cards;
    vector[Narms] logits;
    real PE_rl;
    int prev_card;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        Q_cards   = rep_vector(0.5, Narms);
        prev_card = 0;
      }

      // kappa added to the logit of the previous choice (none on a subject's first trial)
      logits = beta_sbj[subject] * Q_cards;
      if (prev_card > 0) {
        logits[prev_card] += kappa_sbj[subject];
      }
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // only chosen arm updated (classic RW)
      PE_rl = reward[t] - Q_cards[ch_card[t]];
      Q_cards[ch_card[t]] += alpha_sbj[subject] * PE_rl;

      prev_card = ch_card[t];
    }

    target += total_log_lik;
  }
}

generated quantities {
  real alpha_pop = inv_logit(mu_alpha);
  real beta_pop  = exp(mu_beta);
  real kappa_pop = mu_kappa;
}
