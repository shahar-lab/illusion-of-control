#### simulate Rescorla-Wagner block for participant ----
sim.block = function(subject, parameters, cfg){
  print(paste('subject', subject))

  #set parameters
  alpha         = plogis(parameters['alpha'])
  beta          = parameters['beta']
  explore       = parameters['explore']
  decay_explore = plogis(parameters['decay_explore'])

  #set initial var
  Narms     = cfg$Narms
  Ntrials   = cfg$Ntrials
  Nraffle   = cfg$Nraffle
  Nblocks   = cfg$Nblocks
  Ndims     = cfg$Ndims
  expvalues = cfg$expvalues
  df        = data.frame()

  for (block in 1:Nblocks){

    Q_cards = rep(0.5, Narms)
    E_cards = rep(0, Narms)

    for (trial in 1:Ntrials){
      #computer offer
      options = sample(1:Narms, 2)

      #value of offered cards
      Q_cards_offered = Q_cards[options]
      E_cards_offered = E_cards[options]

      Qnet = beta * Q_cards_offered + E_cards_offered

      p = exp(Qnet) / sum(exp(Qnet)) #get prob for each action

      ch_card   = sample(options, 1, prob = p)
      unch_card = options[which(options != ch_card)]
      ch_key    = which(options == ch_card)
      unch_key  = which(options != ch_card)

      reward = sample(0:1, 1, prob = c(1 - expvalues[ch_card, trial], expvalues[ch_card, trial]))

      PE_cards = reward - Q_cards[ch_card]

      dfnew = data.frame(
        subject,
        block,
        trial,
        first_trial_in_block = if_else(trial == 1, 1, 0),
        first_trial          = if_else(trial == 1 & block == 1, 1, 0),
        card_right           = options[2],
        card_left            = options[1],
        ch_card,
        ch_key,
        selected_offer       = ch_key - 1,
        reward,
        Q_ch_card            = Q_cards[ch_card],
        Q_unch_card          = Q_cards[options[which(options != ch_card)]],
        Q_right_card         = Q_cards[options[2]],
        Q_left_card          = Q_cards[options[1]],
        exp_val_right        = expvalues[options[2], trial],
        exp_val_left         = expvalues[options[1], trial],
        exp_val_ch           = expvalues[ch_card, trial],
        exp_val_unch         = expvalues[options[which(options != ch_card)], trial],
        E_ch_card            = E_cards[ch_card],
        E_unch_card          = E_cards[options[which(options != ch_card)]],
        PE_cards,
        alpha,
        beta,
        explore,
        decay_explore
      )
      df = rbind(df, dfnew)

      #update Q
      Q_cards[ch_card] = Q_cards[ch_card] + alpha * PE_cards

      #decay all E, then add explore to chosen
      E_cards          = E_cards * decay_explore
      E_cards[ch_card] = E_cards[ch_card] + explore
    }
  }

  return(df)
}