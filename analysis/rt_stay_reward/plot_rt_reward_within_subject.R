rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(patchwork)
library(rstanarm)

DATA_DIR <- "../../data/ioc-task/pilot20"
FIGURES  <- "figures"
dir.create(FIGURES, showWarnings = FALSE)

INCLUDED_IDS <- c(
  "6980990e5c9007100eb282b6", "69808775dc84b90f4adafb2f", "61563a4b0def9000ccc976ec",
  "60f19a691466276fe085b461", "69dac2125e535db5a698ea18", "6980792fded33a62e27ce7cc",
  "6981150699107501d80e74b6", "667bd577710d52a05ac09036", "6981e6c2e26c88d954f297eb",
  "69d555ce85e30d6215e559d9", "69829236d776a93cf3afa632", "69d5525ec7afcfce08d8608b",
  "6980d9a70a7862a47c69046d", "6984a9246122d3bd4ca0833e", "69728435c9476fe76dd2ab2f",
  "69e913482ae5864d44e6387c", "697a645e36e6f14eea2b396b", "698341d57fe7b870bddf91b8",
  "697caeea2ec1c2604535f8aa", "62ebe597372fdef388b734b3"
)

#### LOAD & FILTER ####
all_files <- list.files(DATA_DIR, full.names = TRUE)
df_list   <- list()

for (f in all_files) {
  pid <- str_extract(f, "[a-f0-9]{24}")
  if (is.na(pid) || !(pid %in% INCLUDED_IDS)) next
  df_list[[pid]] <- read_csv(f, show_col_types = FALSE) |> mutate(participant = pid)
}

df <- bind_rows(df_list) |>
  filter(task == "gambling_choice") |>
  mutate(
    rt              = suppressWarnings(as.numeric(rt)),
    reward          = as.integer(reward),
    is_choice_valid = as.logical(is_choice_valid),
    block_number    = as.character(block_number),
    trial_number    = as.integer(trial_number)
  ) |>
  filter(block_number != "training", is_choice_valid == TRUE, !is.na(rt)) |>
  group_by(participant, block_number) |>
  arrange(trial_number, .by_group = TRUE) |>
  mutate(
    choice_key_nback = lag(choice_key, n = 1),
    reward_nback     = lag(reward,     n = 1),
    valid_nback      = lag(is_choice_valid, n = 1)
  ) |>
  ungroup() |>
  filter(
    !is.na(choice_key_nback),
    !is.na(reward_nback),
    valid_nback == TRUE,
    choice_key_nback != unavailable_key,
    rt > 100, rt < 5000
  ) |>
  mutate(
    stay         = as.integer(choice_key == choice_key_nback),
    reward_label = factor(as.integer(reward_nback), levels = c(0, 1),
                          labels = c("Unrewarded", "Rewarded"))
  )

stay_df <- df |>
  filter(stay == 1) |>
  mutate(
    log_rt = log(rt)
  )

cat("Stay trials:", nrow(stay_df), "| N subjects:", n_distinct(stay_df$participant), "\n")

#### FIT MODEL ####
cat("Fitting model...\n")

fit <- stan_lmer(
  formula          = log_rt ~ reward_label + (1 + reward_label | participant),
  data             = stay_df,
  prior            = normal(0, 0.5),
  prior_intercept  = normal(7, 1),
  prior_covariance = decov(regularization = 2),
  chains           = 4,
  cores            = 4,
  iter             = 2000,
  warmup           = 1000,
  refresh          = 0,
  seed             = 42
)

#### EXTRACT GROUP POSTERIOR ####
newdata_cond <- data.frame(
  reward_label = factor(c("Unrewarded", "Rewarded"), levels = c("Unrewarded", "Rewarded"))
)

post_log <- posterior_linpred(fit, newdata = newdata_cond, re.form = NA)

group_ci <- data.frame(
  reward_label = factor(c("Unrewarded", "Rewarded"), levels = c("Unrewarded", "Rewarded")),
  med  = exp(apply(post_log, 2, median)),
  lo90 = exp(apply(post_log, 2, quantile, 0.05)),
  hi90 = exp(apply(post_log, 2, quantile, 0.95))
)

cat("\nGroup posterior:\n")
print(group_ci)

#### PER-SUBJECT MEANS ####
subj_long <- stay_df |>
  group_by(participant, reward_label) |>
  summarise(mean_rt = mean(rt), .groups = "drop")

#### PLOTTING ####
pal <- c("Unrewarded" = "#E69F00", "Rewarded" = "#56B4E9")

# ---- Panel A: Posterior distributions ----
post_long <- data.frame(
  Unrewarded = exp(post_log[, 1]),
  Rewarded   = exp(post_log[, 2])
) |>
  pivot_longer(everything(), names_to = "condition", values_to = "rt_est") |>
  mutate(condition = factor(condition, levels = c("Unrewarded", "Rewarded")))

dens_list <- lapply(levels(post_long$condition), function(cond) {
  vals <- post_long$rt_est[post_long$condition == cond]
  d    <- density(vals, n = 512)
  data.frame(x = d$x, y = d$y / max(d$y), condition = cond, stringsAsFactors = FALSE)
})
dens_df <- bind_rows(dens_list) |>
  mutate(condition = factor(condition, levels = c("Unrewarded", "Rewarded")))

ci_df <- post_long |>
  group_by(condition) |>
  summarise(
    med  = median(rt_est),
    lo90 = quantile(rt_est, 0.05),
    hi90 = quantile(rt_est, 0.95),
    .groups = "drop"
  )

all_rt <- post_long$rt_est
r      <- range(all_rt); span <- diff(r)
xlims  <- c(r[1] - 0.20 * span, r[2] + 0.20 * span)

p_post <- ggplot(dens_df, aes(x = x, y = y, fill = condition, colour = condition)) +
  geom_area(alpha = 0.50, position = "identity") +
  geom_segment(
    data = ci_df,
    aes(x = lo90, xend = hi90, y = -0.04, yend = -0.04, colour = condition),
    linewidth = 1.5, inherit.aes = FALSE
  ) +
  geom_point(
    data = ci_df,
    aes(x = med, y = -0.04, colour = condition),
    size = 3, inherit.aes = FALSE
  ) +
  scale_fill_manual(values = pal) +
  scale_colour_manual(values = pal) +
  scale_x_continuous(labels = function(x) paste0(round(x), " ms")) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid           = element_blank(),
    axis.title.y         = element_blank(),
    axis.text.y          = element_blank(),
    axis.ticks.y         = element_blank(),
    axis.line.y          = element_blank(),
    axis.line.x          = element_line(colour = "grey30"),
    legend.position      = c(1, 0.95),
    legend.justification = c("right", "top"),
    legend.background    = element_blank(),
    legend.key           = element_blank()
  ) +
  labs(x = "Mean RT — stay trials (ms)", fill = NULL, colour = NULL) +
  coord_cartesian(xlim = xlims, ylim = c(-0.15, 1.15), clip = "off")

# ---- Panel B: Within-subject connected dots ----
p_within <- ggplot() +
  geom_line(
    data = subj_long,
    aes(x = as.numeric(reward_label), y = mean_rt, group = participant),
    colour = "grey70", linewidth = 0.4, alpha = 0.7
  ) +
  geom_point(
    data = subj_long,
    aes(x = as.numeric(reward_label), y = mean_rt, colour = reward_label),
    size = 2, alpha = 0.75
  ) +
  geom_linerange(
    data = group_ci,
    aes(x = as.numeric(reward_label), ymin = lo90, ymax = hi90),
    linewidth = 3, colour = "grey20", alpha = 0.25
  ) +
  geom_point(
    data = group_ci,
    aes(x = as.numeric(reward_label), y = med),
    size = 4, shape = 18, colour = "grey20"
  ) +
  scale_colour_manual(values = pal, guide = "none") +
  scale_x_continuous(
    breaks = c(1, 2),
    labels = c("Unrewarded", "Rewarded"),
    expand = expansion(add = 0.4)
  ) +
  scale_y_continuous(labels = function(x) paste0(round(x), " ms")) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.line.y        = element_line(colour = "grey30"),
    axis.title.x       = element_blank()
  ) +
  labs(y = "Mean RT — stay trials (ms)")

#### COMBINE AND SAVE ####
combined <- p_post / p_within +
  plot_layout(heights = c(1, 2)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(face = "bold"))

ggsave(
  file.path(FIGURES, "rt_reward_within_subject.png"),
  combined,
  width  = 5,
  height = 8,
  dpi    = 150,
  bg     = "white"
)
cat("\nSaved:", file.path(FIGURES, "rt_reward_within_subject.png"), "\n")
