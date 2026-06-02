rm(list = ls())

#### SETUP ####
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(patchwork)

DATA_DIR    <- "../../data/ioc-all-pilot10"
N_QUANTILES <- 5
FIGURES     <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

#### LOAD DATA ####
all_files <- list.files(DATA_DIR, full.names = TRUE, pattern = "\\.csv$")
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df <- bind_rows(df_list)
cat("Loaded", length(df_list), "participants\n")

#### FILTER & COMPUTE STAY ####
wsls_df <- df |>
  filter(task == "gambling_choice", is_choice_valid == TRUE) |>
  mutate(
    rt           = as.numeric(rt),
    reward       = as.integer(reward),
    trial_number = as.integer(trial_number)
  ) |>
  group_by(participant, block_number) |>
  arrange(trial_number, .by_group = TRUE) |>
  mutate(
    choice_nback = lag(choice_key, n = 1),
    reward_nback = lag(reward,     n = 1)
  ) |>
  ungroup() |>
  filter(
    block_number != "training",
    !is.na(choice_nback),
    !is.na(reward_nback),
    !is.na(rt)
  ) |>
  mutate(
    stay         = as.integer(choice_key == choice_nback),
    reward_nback = as.integer(reward_nback)
  )

cat("Trials entering Vincent analysis:", nrow(wsls_df), "\n")
cat("Participants:", length(unique(wsls_df$participant)), "\n")
cat("Overall P(stay | no reward):", round(mean(wsls_df$stay[wsls_df$reward_nback == 0]), 3), "\n")
cat("Overall P(stay | reward):   ", round(mean(wsls_df$stay[wsls_df$reward_nback == 1]), 3), "\n")

#### ASSIGN WITHIN-SUBJECT RT QUANTILES ####
wsls_df <- wsls_df |>
  group_by(participant) |>
  mutate(rt_quantile = ntile(rt, N_QUANTILES)) |>
  ungroup()

#### VINCENT AVERAGE ####
# Step 1: P(stay) per participant x quantile x reward condition
subj_summary <- wsls_df |>
  group_by(participant, rt_quantile, reward_nback) |>
  summarise(p_stay = mean(stay), n = n(), .groups = "drop")

# Step 2: grand mean across participants per quantile x reward condition
vincent_df <- subj_summary |>
  group_by(rt_quantile, reward_nback) |>
  summarise(
    mean_p_stay  = mean(p_stay),
    se           = sd(p_stay) / sqrt(n()),
    n_subjects   = n(),
    .groups      = "drop"
  ) |>
  mutate(
    reward_label = factor(reward_nback, levels = c(0, 1),
                          labels = c("Not rewarded", "Rewarded")),
    ci_lo = mean_p_stay - 1.96 * se,
    ci_hi = mean_p_stay + 1.96 * se
  )

#### REWARD EFFECT (DIFFERENCE BETWEEN CONDITIONS) ####
effect_df <- subj_summary |>
  pivot_wider(names_from = reward_nback, values_from = c(p_stay, n),
              names_prefix = "") |>
  rename(p_stay_0 = `p_stay_0`, p_stay_1 = `p_stay_1`) |>
  filter(!is.na(p_stay_0), !is.na(p_stay_1)) |>
  mutate(reward_effect = p_stay_1 - p_stay_0) |>
  group_by(rt_quantile) |>
  summarise(
    mean_effect  = mean(reward_effect),
    se_effect    = sd(reward_effect) / sqrt(n()),
    n_subjects   = n(),
    .groups      = "drop"
  ) |>
  mutate(
    ci_lo = mean_effect - 1.96 * se_effect,
    ci_hi = mean_effect + 1.96 * se_effect
  )

cat("\nVincent reward effect by RT quantile:\n")
print(effect_df |> select(rt_quantile, mean_effect, se_effect))

#### COLORS ####
clr_rewarded    <- "#56B4E9"   # blue
clr_unrewarded  <- "#E69F00"   # amber
clr_effect      <- "#0072B2"   # dark blue

#### PLOT A: VINCENT LINES ####
p_vincent <- ggplot(vincent_df,
                    aes(x = rt_quantile, y = mean_p_stay,
                        colour = reward_label, group = reward_label)) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi, fill = reward_label),
              alpha = 0.15, colour = NA) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3.5) +
  scale_colour_manual(values = c("Not rewarded" = clr_unrewarded,
                                 "Rewarded"     = clr_rewarded),
                      name = "Previous outcome") +
  scale_fill_manual(values = c("Not rewarded" = clr_unrewarded,
                               "Rewarded"     = clr_rewarded),
                    guide = "none") +
  scale_x_continuous(breaks = 1:N_QUANTILES,
                     labels = paste0("Q", 1:N_QUANTILES)) +
  scale_y_continuous(limits = c(0, 1),
                     breaks = seq(0, 1, 0.25),
                     labels = scales::percent_format(accuracy = 1)) +
  labs(
    x        = "RT quantile (fastest → slowest)",
    y        = "P(stay)",
    title    = "Stay probability by RT quantile",
    subtitle = sprintf("N = %d participants | 5 within-subject quantiles | 1-back reward",
                       length(unique(wsls_df$participant)))
  ) +
  theme_classic(base_size = 13) +
  theme(
    legend.position  = "top",
    legend.title     = element_text(size = 11),
    panel.grid.major.y = element_line(colour = "grey92")
  )

#### PLOT B: REWARD EFFECT ####
p_effect <- ggplot(effect_df, aes(x = rt_quantile, y = mean_effect)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.7) +
  geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), fill = clr_effect, alpha = 0.2) +
  geom_line(linewidth = 1.2, colour = clr_effect) +
  geom_point(size = 3.5, colour = clr_effect) +
  scale_x_continuous(breaks = 1:N_QUANTILES,
                     labels = paste0("Q", 1:N_QUANTILES)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    x     = "RT quantile (fastest → slowest)",
    y     = "Δ P(stay)   [reward − no reward]",
    title = "Reward effect (win-stay tendency) by RT quantile"
  ) +
  theme_classic(base_size = 13) +
  theme(panel.grid.major.y = element_line(colour = "grey92"))

#### COMBINE ####
combined <- p_vincent / p_effect +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

out_path <- file.path(FIGURES, "vincent_reward_rt.png")
ggsave(out_path, combined, width = 7, height = 10, dpi = 150, bg = "white")
cat("\nSaved:", out_path, "\n")
