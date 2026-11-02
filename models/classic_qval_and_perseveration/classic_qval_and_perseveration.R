#### simulate classic qval + perseveration block for participant ----
# alpha in [0, 1], beta > 0, kappa unbounded: a fixed bonus added to the logit of the previous choice
sim.block = function(subject, parameters, cfg) {

  print(paste('subject', subject))

  alpha = parameters['alpha']
  beta  = parameters['beta']
  kappa = parameters['kappa']

  Narms     = cfg$Narms
  Ntrials   = cfg$Ntrials
  expvalues = cfg$expvalues
  options   = 1:Narms

  df_list = vector("list", Ntrials)

  Q_cards   = rep(0.5, Narms)
  prev_card = NA

  block = 1

  for (trial in 1:Ntrials) {

    # same rule as categorical_logit(beta * Q + kappa * [previous choice]) in the Stan model
    persev = rep(0, Narms)
    if (!is.na(prev_card)) persev[prev_card] = kappa

    logits     = beta * Q_cards + persev
    prob_cards = exp(logits) / sum(exp(logits))

    ch_card = sample(options, 1, prob = prob_cards)

    reward = sample(c(0, 1), 1, prob = c(1 - expvalues[ch_card, trial], expvalues[ch_card, trial]))

    PE_rl = reward - Q_cards[ch_card]

    dfnew = tibble(
      subject              = subject,
      alpha                = alpha,
      beta                 = beta,
      kappa                = kappa,
      block                = block,
      trial                = trial,
      first_trial_in_block = if_else(trial == 1, 1, 0),
      first_trial          = if_else(trial == 1, 1, 0),
      prev_card            = prev_card,
      ch_card              = ch_card,
      stay                 = as.numeric(ch_card == prev_card),
      reward               = reward,
      PE_rl                = PE_rl,
      Q_cards              = list(Q_cards),
      logits               = list(logits),
      prob_cards           = list(prob_cards),
      Q_ch                 = Q_cards[ch_card],
      prob_ch              = prob_cards[ch_card]
    )
    df_list[[trial]] = dfnew

    # only chosen arm updated (classic RW)
    Q_cards[ch_card] = Q_cards[ch_card] + alpha * PE_rl

    prev_card = ch_card
  }

  return(bind_rows(df_list))
}
