rm(list = ls())

#### SETUP ####
library(dplyr)
library(readr)
library(stringr)
library(cmdstanr)
library(posterior)

DATA_DIR   <- "../../data/ioc-task/pilot20"
MODEL_FILE <- "../../models/alpha_beta_kappa_decay/alpha_beta_kappa_decay.stan"
DRAWS_DIR  <- "bayesian_draws"

dir.create(DRAWS_DIR, showWarnings = FALSE)

KEY_TO_CARD <- c(arrowleft = 1L, arrowup = 2L, arrowright = 3L)

INCLUDED_IDS <- c(
  "6980990e5c9007100eb282b6", "69808775dc84b90f4adafb2f", "61563a4b0def9000ccc976ec",
  "60f19a691466276fe085b461", "69dac2125e535db5a698ea18", "6980792fded33a62e27ce7cc",
  "6981150699107501d80e74b6", "667bd577710d52a05ac09036", "6981e6c2e26c88d954f297eb",
  "69d555ce85e30d6215e559d9", "69829236d776a93cf3afa632", "69d5525ec7afcfce08d8608b",
  "6980d9a70a7862a47c69046d", "6984a9246122d3bd4ca0833e", "69728435c9476fe76dd2ab2f",
  "69e913482ae5864d44e6387c", "697a645e36e6f14eea2b396b", "698341d57fe7b870bddf91b8",
  "697caeea2ec1c2604535f8aa", "62ebe597372fdef388b734b3"
)

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid) || !(pid %in% INCLUDED_IDS)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df <- bind_rows(df_list)

#### PREPARE STAN DATA ####
df <- df |>
  filter(task == "gambling_choice", block_number != "training", is_choice_valid == TRUE) |>
  mutate(
    block_number   = as.integer(block_number),
    trial_number   = as.integer(trial_number),
    reward         = as.integer(reward),
    ch_card        = KEY_TO_CARD[choice_key],
    unavail_card   = KEY_TO_CARD[unavailable_key],
    # two offered cards: sorted so lower index = card_left, higher = card_right
    card_left      = ifelse(unavail_card == 1L, 2L, 1L),
    card_right     = ifelse(unavail_card == 3L, 2L, 3L),
    selected_offer = as.integer(ch_card == card_right)
  ) |>
  arrange(participant, block_number, trial_number) |>
  mutate(participant_idx = as.integer(factor(participant))) |>
  group_by(participant, block_number) |>
  mutate(first_trial_in_block = as.integer(row_number() == 1)) |>
  group_by(participant) |>
  mutate(first_trial = as.integer(row_number() == 1)) |>
  ungroup()

Nsubjects <- n_distinct(df$participant)

cat("Total trials:", nrow(df), "\n")
cat("Subjects:    ", Nsubjects, "\n")

# Save participant index mapping for later use
participant_map <- df |>
  distinct(participant, participant_idx) |>
  arrange(participant_idx)
write_csv(participant_map, file.path(DRAWS_DIR, "participant_map.csv"))

stan_data <- list(
  Ndata                = nrow(df),
  Nsubjects            = Nsubjects,
  Narms                = 3L,
  subject_trial        = df$participant_idx,
  ch_card              = df$ch_card,
  reward               = df$reward,
  card_left            = df$card_left,
  card_right           = df$card_right,
  first_trial_in_block = df$first_trial_in_block,
  first_trial          = df$first_trial,
  selected_offer       = df$selected_offer
)

#### FIT MODEL ####
model <- cmdstan_model(MODEL_FILE)

fit <- model$sample(
  data            = stan_data,
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1000,
  iter_sampling   = 1000,
  adapt_delta     = 0.95,
  refresh         = 200
)

group_vars <- c("mu_alpha", "mu_beta", "mu_kappa", "mu_decay",
                "sigma_alpha", "sigma_beta", "sigma_kappa", "sigma_decay")
sbj_vars   <- c(paste0("alpha_sbj[", 1:Nsubjects, "]"),
                paste0("beta_sbj[",  1:Nsubjects, "]"),
                paste0("kappa_sbj[", 1:Nsubjects, "]"),
                paste0("decay_sbj[", 1:Nsubjects, "]"))

fit$summary(variables = group_vars)

#### SAVE DRAWS ####
draws_group <- fit$draws(variables = group_vars, format = "df") |>
  select(all_of(group_vars))

draws_sbj <- fit$draws(variables = sbj_vars, format = "df") |>
  select(all_of(sbj_vars))

write_csv(draws_group, file.path(DRAWS_DIR, "posterior_draws_group.csv"))
write_csv(draws_sbj,   file.path(DRAWS_DIR, "posterior_draws_subject.csv"))

cat("\nSaved group draws   ->", file.path(DRAWS_DIR, "posterior_draws_group.csv"), "\n")
cat("Saved subject draws ->", file.path(DRAWS_DIR, "posterior_draws_subject.csv"), "\n")
