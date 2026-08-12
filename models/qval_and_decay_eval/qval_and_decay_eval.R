#### simulate qval + decay-eval block for participant ----
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

    # Q: only chosen arm updated (classic RW)
    Q_cards[ch_card] = Q_cards[ch_card] + alpha_rl * PE_rl

    # E: all arms decay toward 0; chosen arm pulled toward 1
    E_cards          = (1 - alpha_per) * E_cards
    E_cards[ch_card] = E_cards[ch_card] + alpha_per
  }

  return(bind_rows(df_list))
}
