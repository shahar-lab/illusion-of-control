#### simulate Rescorla-Wagner block for participant (Model 3: Alpha/Beta) ----
sim.block = function(subject, parameters, cfg){ 
    
  print(paste('subject', subject))
  
  #set parameters
  alpha_rl  = parameters['alpha_rl']
  alpha_per = parameters['alpha_per']
  beta_rl   = parameters['beta_rl']
  beta_per  = parameters['beta_per']

  #set initial var
  Narms      = cfg$Narms
  Ntrials    = cfg$Ntrials
  expvalues  = cfg$expvalues
  options    = 1:Narms

  df_list    = vector("list", Ntrials)

  #initialize values at 0 for symmetric -1/1 bounds
  Q_cards = rep(0.5, Narms)
  E_cards = rep(0, Narms)
  
  block = 1 # Single block as requested

  for (trial in 1:Ntrials){

    # integrate Q values and perseveration traces
    Qnet = (beta_rl * Q_cards) + (beta_per * E_cards)

    prob_cards = exp(Qnet) / sum(exp(Qnet)) 

    #players choice
    ch_card = sample(options, 1, prob = prob_cards)

    #outcome 
    reward = sample(c(0, 1), 1, prob = c(1 - expvalues[ch_card, trial], expvalues[ch_card, trial])) 
    
    PE_rl    = reward - Q_cards[ch_card]
    PE_per   = 1 - E_cards[ch_card]
    
    #save trial's data
    dfnew = data.frame(
      subject              = subject,
      block                = block,
      trial                = trial,
      first_trial_in_block = if_else(trial==1, 1, 0),
      first_trial          = if_else(trial==1, 1, 0),
      ch_card              = ch_card,
      reward               = reward,
      PE_rl                = PE_rl,
      PE_per               = PE_per,
      Q_cards              = list(Q_cards),
      E_cards              = list(E_cards),
      prob_cards           = list(prob_cards),
      Q_ch                 = Q_cards[ch_card],
      E_ch                 = E_cards[ch_card],
      prob_ch              = prob_cards[ch_card]
    )
    df_list[[trial]] = dfnew
    
    #updating Q-values 
    Q_cards[ch_card] = Q_cards[ch_card] + alpha_rl * PE_rl

    #updating Perseveration 
    E_cards[ch_card] = E_cards[ch_card] + alpha_per * PE_per
  }     
  
  return (bind_rows(df_list))
}