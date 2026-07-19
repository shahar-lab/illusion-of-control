#### simulate decay-RL + decay-habit block for participant ----
sim.block = function(subject, parameters, cfg) {

  print(paste("subject", subject))

  decay_rl = parameters["decay_rl"]
  decay_h  = parameters["decay_h"]
  rho_rl   = parameters["rho_rl"]
  rho_h    = parameters["rho_h"]

  Narms     = cfg$Narms
  Ntrials   = cfg$Ntrials
  expvalues = cfg$expvalues

  df_list = vector("list", Ntrials)

  Q_cards = rep(0.0, Narms)
  H_cards = rep(0.0, Narms)

  for (trial in 1:Ntrials) {

    logits  = Q_cards + H_cards
    prob    = exp(logits) / sum(exp(logits))
    ch_card = sample(1:Narms, 1, prob = prob)
    reward  = sample(c(0, 1), 1, prob = c(1 - expvalues[ch_card, trial], expvalues[ch_card, trial]))
    prob_ch = prob[ch_card]

    dfnew = tibble(
      subject = subject,
      trial   = trial,
      ch_card = ch_card,
      reward  = reward,
      Q_cards = list(Q_cards),
      H_cards = list(H_cards),
      Q_ch    = Q_cards[ch_card],
      H_ch    = H_cards[ch_card],
      prob_ch = prob_ch
    )
    df_list[[trial]] = dfnew

    Q_cards          = (1 - decay_rl) * Q_cards
    Q_cards[ch_card] = Q_cards[ch_card] + rho_rl * reward

    H_cards          = (1 - decay_h) * H_cards
    H_cards[ch_card] = H_cards[ch_card] + rho_h
  }

  return(bind_rows(df_list))
}
