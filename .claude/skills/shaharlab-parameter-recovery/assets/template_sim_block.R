#### simulate <model_name> block for participant ----
# Adjust the parameter list, update rule, and tracked quantities (Q_cards / E_cards / ...)
# to match the actual model. This 4-parameter Q-value + perseveration-trace shape is the
# most common starting point in this lab; drop alpha_rl/beta_rl/Q_cards for a
# perseveration-only model, or add more state as needed.
sim.block = function(subject, parameters, cfg) {

  print(paste('subject', subject))

  alpha_rl  = parameters['alpha_rl']
  alpha_per = parameters['alpha_per']
  beta_rl   = parameters['beta_rl']
  beta_per  = parameters['beta_per']

  Narms     = cfg$Narms
  Ntrials   = cfg$Ntrials
  expvalues = cfg$expvalues
  options   = 1:Narms

  df_list = vector("list", Ntrials)

  Q_cards = rep(0.5, Narms)
  E_cards = rep(0, Narms)

  block = 1

  for (trial in 1:Ntrials) {

    Qnet       = (beta_rl * Q_cards) + (beta_per * E_cards)
    prob_cards = exp(Qnet) / sum(exp(Qnet))

    ch_card = sample(options, 1, prob = prob_cards)

    reward = sample(c(0, 1), 1, prob = c(1 - expvalues[ch_card, trial], expvalues[ch_card, trial]))

    PE_rl = reward - Q_cards[ch_card]

    # IMPORTANT: tibble(), not data.frame() — see STAN_PITFALLS.md #3. data.frame()
    # silently corrupts list(vector) columns like Q_cards/E_cards below.
    dfnew = tibble(
      subject              = subject,
      block                = block,
      trial                = trial,
      first_trial_in_block = if_else(trial == 1, 1, 0),
      first_trial          = if_else(trial == 1, 1, 0),
      ch_card              = ch_card,
      reward               = reward,
      PE_rl                = PE_rl,
      Q_cards              = list(Q_cards),
      E_cards              = list(E_cards),
      prob_cards           = list(prob_cards),
      Q_ch                 = Q_cards[ch_card],
      E_ch                 = E_cards[ch_card],
      prob_ch              = prob_cards[ch_card]
    )
    df_list[[trial]] = dfnew

    # Q: only chosen arm updated (classic Rescorla-Wagner)
    Q_cards[ch_card] = Q_cards[ch_card] + alpha_rl * PE_rl

    # E: all arms decay toward 0; chosen arm pulled toward 1 — drop this and use the
    # frozen-unchosen-arm update (E_cards[ch_card] += alpha_per * (1 - E_cards[ch_card]))
    # if the model calls for that variant instead. Recovery in this lab's runs has
    # consistently been notably better with the decaying update — see summary.md files
    # across models for the actual numbers.
    E_cards          = (1 - alpha_per) * E_cards
    E_cards[ch_card] = E_cards[ch_card] + alpha_per
  }

  return(bind_rows(df_list))
}
