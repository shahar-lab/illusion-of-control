rm(list = ls())

library(dplyr)
library(readr)
library(purrr)
library(stringr)
library(jsonlite)
library(lme4)
library(ggplot2)
library(patchwork)

DATA_DIR <- "../../data/ioc-one-piot10"
FIGURES  <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

#### LOAD & COMBINE ####
df_raw <- list.files(DATA_DIR, full.names = TRUE) |>
  set_names(str_extract(basename(list.files(DATA_DIR)), "[a-f0-9]{24}")) |>
  map_dfr(~ read_csv(.x, show_col_types = FALSE), .id = "subj")

#### FILTER VALID TASK TRIALS ####
df <- df_raw |>
  filter(
    task            == "gambling_choice",
    block_number    != "training",
    is_choice_valid == TRUE
  ) |>
  mutate(
    rt           = suppressWarnings(as.numeric(rt)),
    reward       = as.integer(reward),
    trial_number = as.integer(trial_number)
  ) |>
  filter(!is.na(rt), !is.na(reward))

#### COMPUTE WITHIN-BLOCK LAGS ####
# Use within-block lag to avoid cross-block contamination
df <- df |>
  group_by(subj, block_number) |>
  arrange(trial_number, .by_group = TRUE) |>
  mutate(
    choice_lag1  = lag(choice_key),
    reward_lag1  = lag(reward),
    unavail_lag0 = unavailable_keys          # current trial's unavailable keys
  ) |>
  ungroup() |>
  filter(!is.na(choice_lag1), !is.na(reward_lag1))

#### FILTER: STAY TRIALS WHERE PREVIOUS MACHINE WAS AVAILABLE THIS TRIAL ####
df <- df |>
  mutate(
    prev_available = map2_lgl(
      choice_lag1, unavail_lag0,
      ~ !(.x %in% fromJSON(.y))
    ),
    stay = choice_key == choice_lag1
  ) |>
  filter(stay, prev_available)

cat(sprintf("Stay trials (prev machine available): %d  across %d subjects\n",
            nrow(df), n_distinct(df$subj)))
cat(sprintf("reward_oneback (0 = loss, 1 = win): %s\n",
            paste(sort(unique(df$reward_lag1)), collapse = " / ")))

df <- df |> rename(reward_oneback = reward_lag1)

#### MIXED EFFECTS MODEL ####
fit <- lmer(rt ~ reward_oneback + (1 + reward_oneback | subj),
            data = df, REML = TRUE)

cat("\n=== Model summary ===\n")
print(summary(fit))

#### FIXED-EFFECT PREDICTIONS ####
fe <- fixef(fit)
pred_fe <- tibble(
  reward_oneback = c(0L, 1L),
  rt_pred        = c(fe[["(Intercept)"]],
                     fe[["(Intercept)"]] + fe[["reward_oneback"]])
)

fe_delta_ms <- fe[["reward_oneback"]]

#### SUBJECT-LEVEL MEANS ####
subj_means <- df |>
  group_by(subj, reward_oneback) |>
  summarise(mean_rt = mean(rt), n = n(), .groups = "drop")

#### SUBJECT-LEVEL RANDOM-EFFECT DELTAS ####
re <- ranef(fit)$subj
subj_slopes <- tibble(
  subj        = rownames(re),
  intercept_i = fe[["(Intercept)"]] + re[["(Intercept)"]],
  slope_i     = fe[["reward_oneback"]] + re[["reward_oneback"]]
) |>
  mutate(
    rt_loss = intercept_i,
    rt_win  = intercept_i + slope_i,
    delta   = rt_win - rt_loss
  )

#### COLORS ####
# Okabe-Ito blue/orange for loss/win
col_loss <- "#4477AA"
col_win  <- "#EE6677"
cond_colors <- c("0" = col_loss, "1" = col_win)
cond_labels <- c("0" = "Not rewarded", "1" = "Rewarded")

#### PLOT A: SPAGHETTI ####
p_spaghetti <- ggplot(
  subj_means,
  aes(x = factor(reward_oneback, labels = cond_labels),
      y = mean_rt, group = subj)
) +
  geom_line(colour = "grey70", linewidth = 0.5) +
  geom_point(aes(colour = factor(reward_oneback)), size = 2.5, alpha = 0.85) +
  # fixed-effect line
  geom_line(
    data = pred_fe,
    aes(x = factor(reward_oneback, labels = cond_labels), y = rt_pred, group = 1),
    colour = "grey15", linewidth = 1.8, inherit.aes = FALSE
  ) +
  geom_point(
    data = pred_fe,
    aes(x = factor(reward_oneback, labels = cond_labels), y = rt_pred),
    colour = "grey15", size = 4.5, shape = 18, inherit.aes = FALSE
  ) +
  scale_colour_manual(values = cond_colors, guide = "none") +
  scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " s")) +
  labs(
    x        = "Previous trial outcome",
    y        = "Mean response time",
    title    = "RT on stay trials by prior reward",
    subtitle = sprintf(
      "lmer: log(RT) ~ reward_oneback + (1 + reward_oneback | subj)  •  N = %d subjects",
      n_distinct(df$subj)
    )
  ) +
  theme_classic(base_size = 13) +
  theme(plot.subtitle = element_text(size = 9, colour = "grey40"))

#### PLOT B: SUBJECT DELTAS ####
p_delta <- ggplot(subj_slopes, aes(x = delta)) +
  geom_vline(xintercept = 0,          linetype = "dashed", colour = "grey50", linewidth = 0.6) +
  geom_vline(xintercept = fe_delta_ms, colour = "grey15",  linewidth = 1.1) +
  geom_dotplot(
    fill = "#56B4E9", colour = "white",
    binwidth = 15, dotsize = 0.9
  ) +
  annotate(
    "text", x = fe_delta_ms, y = Inf,
    label  = sprintf("Fixed\neffect\n%+.0f ms", fe_delta_ms),
    hjust  = -0.1, vjust = 1.2, size = 3.2, colour = "grey15"
  ) +
  scale_y_continuous(NULL, breaks = NULL) +
  labs(
    x     = "Δ RT  (rewarded − not rewarded)  [ms]",
    title = "Per-subject RT difference (stay trials)"
  ) +
  theme_classic(base_size = 13)

#### COMBINE & SAVE ####
combined <- p_spaghetti / p_delta +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

out_path <- file.path(FIGURES, "rt_reward_stay.png")
ggsave(out_path, combined, width = 6, height = 9, dpi = 150, bg = "white")
cat(sprintf("\nSaved: %s\n", out_path))
