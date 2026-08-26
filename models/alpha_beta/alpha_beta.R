# Simulate Rescorla-Wagner block for participant
sim_block = function(subject, parameters, cfg) {

  print(paste("Processing subject", subject))

  # Extract parameters
  alpha                 = parameters[["alpha"]]
  beta                  = parameters[["beta"]]

  # Extract configuration
  n_arms                = cfg$Narms
  n_trials              = cfg$Ntrials
  n_raffle              = cfg$Nraffle
  n_blocks              = cfg$Nblocks
  exp_values            = cfg$expvalues

  Q_cards               = rep(0.5, n_arms)
  df                    = data.frame()

  for (block in seq_len(n_blocks)) {
    for (trial in seq_len(n_trials)) {
      # Sample offered cards
      options             = sample(1:n_arms, n_raffle)

      # Get Q-values for offered cards
      Q_offered           = Q_cards[options]

      # Compute choice probabilities
      probs               = exp(beta * Q_offered) / sum(exp(beta * Q_offered))

      # Player's choice
      chosen_card             = sample(options, 1, prob = probs)
      chosen_key              = which(options == chosen_card)

      # Outcome
      outcome_probs       = c(1 - exp_values[chosen_card, trial],   exp_values[chosen_card, trial])
      reward              = sample(0:1, 1, prob = outcome_probs)

      # Calculate prediction error
      PE             = reward - Q_cards[chosen_card]

      # Create trial record
      new_df          = data.frame(
        # Behavioral data
        subject           = subject,
        block             = block,
        trial             = trial,
        card_right        = options[2],
        card_left         = options[1],
        chosen_card       = chosen_card,
        chosen_key        = chosen_key,
        reward            = reward,

        # Latents 
        Q_chosen          = Q_cards[chosen_card],
        Q_unchosen        = Q_cards[options[which(options != chosen_card)]],
        Q_right           = Q_cards[options[2]],
        Q_left            = Q_cards[options[1]],
        PE                = PE,
        alpha             = alpha,
        beta              = beta,

        # Data for Stan
        selected_offer    = chosen_key - 1L,
        first_trial_in_block = as.integer(trial == 1),
        first_trial       = as.integer(trial == 1 & block == 1)        
      )

      df               = rbind(df, new_df)

      # Update Q-value for chosen card
      Q_cards[chosen_card]    = Q_cards[chosen_card] + alpha * PE
    }
  }

  df
}