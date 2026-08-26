# Simulate Rescorla-Wagner block for participant (n-arm, no raffle: every arm offered every trial)
sim_block = function(subject, parameters, cfg) {

  print(paste("Processing subject", subject))

  # Extract parameters
  alpha                 = parameters[["alpha"]]
  beta                  = parameters[["beta"]]

  # Extract configuration
  n_arms                = cfg$Narms
  n_trials              = cfg$Ntrials
  n_blocks              = cfg$Nblocks
  exp_values            = cfg$expvalues

  Q_cards               = rep(0.5, n_arms)
  df                    = tibble()

  for (block in seq_len(n_blocks)) {
    for (trial in seq_len(n_trials)) {

      # Compute choice probabilities over all arms (no raffle subsetting)
      probs             = exp(beta * Q_cards) / sum(exp(beta * Q_cards))

      # Player's choice
      chosen_card       = sample(1:n_arms, 1, prob = probs)

      # Outcome
      outcome_probs     = c(1 - exp_values[chosen_card, trial], exp_values[chosen_card, trial])
      reward            = sample(0:1, 1, prob = outcome_probs)

      # Calculate prediction error
      PE                = reward - Q_cards[chosen_card]

      # Create trial record
      new_df            = tibble(
        # Behavioral data
        subject           = subject,
        block             = block,
        trial             = trial,
        ch_card           = chosen_card,
        reward            = reward,

        # Latents
        Q_chosen          = Q_cards[chosen_card],
        PE                = PE,
        alpha             = alpha,
        beta              = beta,

        # Data for Stan
        first_trial_in_block = as.integer(trial == 1),
        first_trial       = as.integer(trial == 1 & block == 1)
      )

      df                = bind_rows(df, new_df)

      # Update Q-value for chosen card
      Q_cards[chosen_card] = Q_cards[chosen_card] + alpha * PE
    }
  }

  df
}
