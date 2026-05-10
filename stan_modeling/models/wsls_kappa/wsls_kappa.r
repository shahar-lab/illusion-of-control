#### Rescorla-Wagner with perseveration bias (WSLS task) ----
#### Based on Python simulate_wsls.py logic
#### 3-armed bandit: one machine unavailable each trial
#### Parameters: alpha (learning), beta (temperature), kappa (perseveration)

sim.block = function(subject, parameters, cfg) {
  print(paste('subject', subject))
  
  # Extract parameters
  alpha = parameters['alpha']
  beta  = parameters['beta']
  kappa = parameters['kappa']
  
  # Extract config
  Narms           = cfg$Narms              # 3 machines
  Ntrials         = cfg$Ntrials_perblock
  Nblocks         = cfg$Nblocks
  scarcity        = cfg$scarcity           # reward probability
  
  df = data.frame()
  
  for (block in 1:Nblocks) {
    Q_values  = rep(0.5, Narms)            # initialize Q-values
    prev_choice = NA
    prev_reward = NA
    
    for (trial in 1:Ntrials) {
      # Randomly make one machine unavailable
      unavailable = sample(1:Narms, 1)
      available   = setdiff(1:Narms, unavailable)
      
      # Softmax with perseveration bias
      # logit = beta * Q + kappa * (choice == prev_choice)
      logits = rep(NA, length(available))
      for (i in seq_along(available)) {
        m = available[i]
        logits[i] = beta * Q_values[m] + (kappa * (m == prev_choice))
      }
      
      # Numerically stable softmax
      logits_max = max(logits, na.rm = TRUE)
      exp_logits = exp(logits - logits_max)
      probs      = exp_logits / sum(exp_logits)
      
      # Choose action
      choice = sample(available, 1, prob = probs)
      
      # Generate reward based on scarcity
      reward = as.integer(runif(1) < scarcity)
      
      # Track WSLS: record if previous choice was available
      stayed = NA
      if (!is.na(prev_choice) && prev_choice %in% available) {
        stayed = as.integer(choice == prev_choice)
      }
      
      # Compute prediction error and update Q-value
      pe = reward - Q_values[choice]
      Q_values[choice] = Q_values[choice] + alpha * pe
      
      # Save trial data
      overall_trial = (block - 1) * Ntrials + trial
      
      dfnew = data.frame(
        subject,
        block,
        trial,
        overall_trial,
        first_trial_in_block  = as.integer(trial == 1),
        first_trial           = as.integer(trial == 1 & block == 1),
        choice                = choice,
        unavailable           = unavailable,
        available_1           = available[1],
        available_2           = available[2],
        reward,
        stayed,
        prev_reward           = prev_reward,
        prev_choice           = prev_choice,
        Q_choice              = Q_values[choice],
        pe,
        alpha,
        beta,
        kappa,
        scarcity
      )
      
      df = rbind(df, dfnew)
      
      # Update for next trial
      prev_choice = choice
      prev_reward = reward
    }
  }
  
  return(df)
}
