#### MODEL: classic_qval_and_unchosen_eval_zero ####
# Generating code for the classic_qval_and_unchosen_eval_zero model.
# Lives in models/classic_qval_and_unchosen_eval_zero/ alongside classic_qval_and_unchosen_eval_zero.stan (project_rules §2.III).
# Fitting and evaluation happen in analysis/ or simulation/ folders, never here.

generate_classic_qval_and_unchosen_eval_zero <- function(alpha_rl, delta, beta_rl, beta_per,
                                                          n_trials, n_arms, reward_probs) {
  Q      <- rep(0.5, n_arms)
  E      <- rep(0.0, n_arms)
  streak     <- 0
  prev_choice <- 0

  trial  <- integer(n_trials)
  choice <- integer(n_trials)
  reward <- integer(n_trials)

  for (t in seq_len(n_trials)) {
    logits     <- beta_rl * Q + beta_per * E
    probs      <- exp(logits - max(logits))
    probs      <- probs / sum(probs)
    chosen     <- sample.int(n_arms, size = 1, prob = probs)
    r          <- rbinom(1, 1, reward_probs[chosen])

    Q[chosen]  <- Q[chosen] + alpha_rl * (r - Q[chosen])

    if (chosen == prev_choice) {
      streak <- streak + 1
    } else {
      streak <- 1
    }
    prev_choice <- chosen

    E          <- rep(0.0, n_arms)
    E[chosen]  <- delta ^ (streak - 1)

    trial[t]  <- t
    choice[t] <- chosen
    reward[t] <- r
  }

  data.frame(trial = trial, choice = choice, reward = reward)
}
