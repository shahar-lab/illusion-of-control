// decay_eval_only without pooling: each subject's parameters get fixed priors,
// so subjects are estimated independently. Same choice and update rule as decay_eval_only.
data {
  int<lower=1> Ndata;
  int<lower=1> Nsubjects;
  int<lower=2> Narms;

  array[Ndata] int<lower=1, upper=Nsubjects> subject_trial;
  array[Ndata] int<lower=1, upper=Narms> ch_card;
  array[Ndata] int<lower=0, upper=1> reward;
}

parameters {
  vector[Nsubjects] alpha_per_logit;
  vector[Nsubjects] beta_per_sbj;
}

transformed parameters {
  vector<lower=0, upper=1>[Nsubjects] alpha_per_sbj = inv_logit(alpha_per_logit);
}

model {
  alpha_per_logit ~ normal(0, 1.5);
  beta_per_sbj    ~ normal(0, 5);

  {
    vector[Narms] E_cards;
    vector[Narms] logits;
    real total_log_lik = 0;

    for (t in 1:Ndata) {
      int subject = subject_trial[t];

      if (t == 1 || subject != subject_trial[t - 1]) {
        E_cards = rep_vector(0.0, Narms);
      }

      logits = beta_per_sbj[subject] * E_cards;
      total_log_lik += categorical_logit_lpmf(ch_card[t] | logits);

      // All arms decay toward 0; chosen arm pulled toward 1.
      E_cards = (1 - alpha_per_sbj[subject]) * E_cards;
      E_cards[ch_card[t]] += alpha_per_sbj[subject];
    }

    target += total_log_lik;
  }
}
