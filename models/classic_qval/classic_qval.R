#### simulate classic qval block for participant ----
# alpha and beta arrive on their natural scales (alpha in [0, 1], beta > 0)
sim.block = function(subject, parameters, cfg) {

  print(paste('subject', subject))

  alpha = parameters['alpha']
  beta  = parameters['beta']

  Narms     = cfg$Narms
  Ntrials   = cfg$Ntrials
  expvalues = cfg$expvalues
  options   = 1:Narms

  df_list = vector("list", Ntrials)

  Q_cards = rep(0.5, Narms)

  block = 1

  for (trial in 1:Ntrials) {

    # softmax over all arms, same rule as categorical_logit(beta * Q) in classic_qval.stan
    prob_cards = exp(beta * Q_cards) / sum(exp(beta * Q_cards))

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
      prob_cards           = list(prob_cards),
      Q_ch                 = Q_cards[ch_card],
      prob_ch              = prob_cards[ch_card]
    )
    df_list[[trial]] = dfnew

    # only chosen arm updated (classic RW)
    Q_cards[ch_card] = Q_cards[ch_card] + alpha * PE_rl
  }

  return(bind_rows(df_list))
}
