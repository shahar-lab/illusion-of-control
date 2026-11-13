# reads: data/collected/ioc-per-baseline/*.csv · writes: artifacts/df.rds, artifacts/participant_map.csv

#### LOAD DATA ####

files <- list.files(data_path, pattern = "^ioc-per-baseline_.*_SESSION_.*\\.csv$", full.names = TRUE)

df_collected <- files |>
  lapply(read_csv, col_types = cols(.default = "c"), show_col_types = FALSE) |>
  bind_rows()

#### KEEP MAIN-TASK CHOICES ####

# Training trials and timeouts are dropped; every machine is available on every trial
df <- df_collected |>
  filter(task == "gambling_choice",
         block_number != "training",
         is_choice_valid == "true") |>
  mutate(
    block_number = as.integer(block_number),
    trial_number = as.integer(trial_number),
    choice       = key_to_card[choice_key]
  ) |>
  arrange(subject_id, block_number, trial_number)

participant_map <- df |>
  distinct(subject_id) |>
  mutate(subject = row_number(),
         label   = paste0("P", subject))

df <- df |>
  left_join(participant_map, by = "subject_id") |>
  group_by(subject) |>
  mutate(stay_ch = as.integer(choice == lag(choice) & block_number == lag(block_number))) |>
  ungroup() |>
  select(subject, label, block_number, trial_number, choice, choice_color, stay_ch, rt)

cat("Collected choice rows:", sum(df_collected$task == "gambling_choice", na.rm = TRUE), "\n")
cat("Kept trials:          ", nrow(df), "\n")
print(count(df, label))

#### SAVE ####

saveRDS(df, file.path(artifacts_dir, "df.rds"))
write_csv(participant_map, file.path(artifacts_dir, "participant_map.csv"))
