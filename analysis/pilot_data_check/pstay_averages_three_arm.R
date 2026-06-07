rm(list = ls())

library(dplyr)
library(readr)
library(purrr)

DATA_DIR <- "../../data/ioc-all-pilot10"

load_and_prep <- function(path) {
  df <- read_csv(path, show_col_types = FALSE)

  df |>
    filter(task == "gambling_choice") |>
    mutate(
      reward          = as.integer(reward),
      is_choice_valid = as.logical(is_choice_valid),
      block_number    = as.character(block_number),
      trial_number    = as.integer(trial_number)
    ) |>
    filter(block_number != "training", is_choice_valid == TRUE)
}

compute_pstay <- function(task_df) {
  # Verify trial_number is unique within each block before lagging.
  # Duplicates (e.g. from page refresh) would cause lag() to pair wrong trials.
  dup_check <- task_df |>
    group_by(block_number, trial_number) |>
    filter(n() > 1)

  if (nrow(dup_check) > 0) {
    warning(sprintf(
      "Subject %s has %d duplicate trial_number(s) within blocks — keeping last row per trial.",
      unique(task_df$subject_id), nrow(dup_check)
    ))
    task_df <- task_df |>
      group_by(block_number, trial_number) |>
      slice_tail(n = 1) |>
      ungroup()
  }

  task_df |>
    group_by(block_number) |>
    arrange(trial_number, .by_group = TRUE) |>
    mutate(
      choice_nback = lag(choice_key, n = 1),
      reward_nback = lag(reward,     n = 1)
    ) |>
    ungroup() |>
    filter(!is.na(choice_nback), !is.na(reward_nback)) |>
    mutate(stay = as.integer(choice_key == choice_nback))
}

files <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)

results <- map(files, \(f) {
  task_df  <- load_and_prep(f)
  wsls_df  <- compute_pstay(task_df)

  tibble(
    subject_id      = unique(task_df$subject_id),
    pstay_no_reward = mean(wsls_df$stay[wsls_df$reward_nback == 0], na.rm = TRUE),
    pstay_reward    = mean(wsls_df$stay[wsls_df$reward_nback == 1], na.rm = TRUE),
    n_trials        = nrow(wsls_df)
  )
}) |>
  list_rbind() |>
  arrange(subject_id) |>
  mutate(across(c(pstay_no_reward, pstay_reward), \(x) round(x, 3)))

cat("=== pstay by subject — ioc-all-pilot10 (three-arm) ===\n\n")
print(as.data.frame(results), row.names = FALSE)

cat("\n--- Group means ---\n")
cat(sprintf("pstay | no reward : %.3f\n", mean(results$pstay_no_reward)))
cat(sprintf("pstay | reward    : %.3f\n", mean(results$pstay_reward)))
cat(sprintf("WSLS delta        : %.3f\n",
            mean(results$pstay_reward - results$pstay_no_reward)))
