#### SETUP ####

library(tidyverse)
library(here)

source(here("apps", "model_explorer", "helpers.R"))
source(here("apps", "model_explorer", "wsls.R"))

sim_funs = map(set_names(names(model_specs)), load_model)

report = function(label, ok) {
  cat(sprintf("%-4s %s\n", if (ok) "PASS" else "FAIL", label))
  ok
}

softmax = function(x) exp(x) / sum(exp(x))

#### CASES ####

cases = list(
  list(model = "classic_qval_and_perseveration", params = c(alpha = 0.5, beta = 2.72, kappa = 0.5), pwin = c(0.5, 0.5, 0.5), seed = 1, n = 15),
  list(model = "classic_qval_and_perseveration", params = c(alpha = 0.2, beta = 6, kappa = -1.3), pwin = c(0.2, 0.5, 0.8), seed = 4242, n = 20),
  list(model = "classic_qval_and_eval", params = c(alpha_rl = 0.5, beta_rl = 2.72, alpha_per = 0.5, beta_per = 1.5), pwin = c(0.5, 0.5, 0.5), seed = 1, n = 15),
  list(model = "classic_qval_and_eval", params = c(alpha_rl = 0.8, beta_rl = 1, alpha_per = 0.1, beta_per = -2), pwin = c(0.9, 0.1, 0.4), seed = 99, n = 10),
  list(model = "qval_and_decay_eval", params = c(alpha_rl = 0.5, beta_rl = 2.72, alpha_per = 0.5, beta_per = 1.5), pwin = c(0.5, 0.5, 0.5), seed = 1, n = 15),
  list(model = "qval_and_decay_eval", params = c(alpha_rl = 0.3, beta_rl = 4, alpha_per = 0.9, beta_per = 3), pwin = c(0.3, 0.6, 0.7), seed = 2027, n = 20)
)

#### CHECKS ####

check_case = function(cs) {
  tag  = sprintf("[%s seed=%d n=%d]", cs$model, cs$seed, cs$n)
  full = run_sim(sim_funs[[cs$model]], cs$params, cs$pwin, 150, cs$seed)
  tbl  = trial_table(full, cs$model, cs$params) |> slice_head(n = cs$n)
  ref  = run_sim(sim_funs[[cs$model]], cs$params, cs$pwin, cs$n, cs$seed)
  rows = function(col) unname(do.call(rbind, ref[[col]]))
  cols = function(prefix) unname(as.matrix(select(tbl, matches(paste0("^", prefix, "[0-9]+$")))))

  ok = c(
    report(paste(tag, "trial == sim.block"), identical(tbl$trial, ref$trial)),
    report(paste(tag, "Q1-Q3 == sim.block Q_cards"), identical(cols("Q"), rows("Q_cards"))),
    report(paste(tag, "p1-p3 == sim.block prob_cards"), identical(cols("p"), rows("prob_cards"))),
    report(paste(tag, "chosen == sim.block ch_card"), identical(tbl$chosen, ref$ch_card)),
    report(paste(tag, "reward == sim.block reward"), identical(tbl$reward, ref$reward))
  )

  Q = cols("Q")
  if (cs$model == "classic_qval_and_perseveration") {
    ok = c(ok, report(paste(tag, "prev_choice == sim.block prev_card"), identical(tbl$prev_choice, ref$prev_card)))
    bonus = matrix(0, nrow(Q), ncol(Q))
    has_prev = !is.na(tbl$prev_choice)
    bonus[cbind(which(has_prev), tbl$prev_choice[has_prev])] = tbl$kappa_bonus[has_prev]
    logits = cs$params[["beta"]] * Q + bonus
    ok = c(ok, report(paste(tag, "kappa_bonus NA only on trial 1"), identical(which(is.na(tbl$kappa_bonus)), 1L)))
  } else {
    ok = c(ok, report(paste(tag, "E1-E3 == sim.block E_cards"), identical(cols("E"), rows("E_cards"))))
    logits = cs$params[["beta_rl"]] * Q + cs$params[["beta_per"]] * cols("E")
  }

  w      = fit_wsls(full)
  ch     = full$ch_card
  stay   = as.numeric(ch[-1] == ch[-length(ch)])
  rprev  = full$reward[-nrow(full)] - 0.5
  rates  = tapply(stay, rprev, mean)
  b_lpm  = unname(c(mean(rates), diff(rates)))
  b_lgt  = unname(c(mean(qlogis(rates)), diff(qlogis(rates))))
  ok = c(ok,
    report(paste(tag, "WSLS uses the same 150-trial agent (trials 2-150)"),
           identical(w$data$trial, 2:150) && identical(w$data$stay, stay) && identical(w$data$rew_prev, rprev)),
    report(paste(tag, "WSLS linear b0/b1 == mean / diff of stay rates"),
           isTRUE(all.equal(unname(coef(w$lpm)), b_lpm, tolerance = 1e-10))),
    report(paste(tag, "WSLS logistic b0/b1 == mean / diff of logit stay rates"),
           w$separation || isTRUE(all.equal(unname(coef(w$lgt)), b_lgt, tolerance = 1e-6)))
  )
  if (cs$model == "classic_qval_and_perseveration") {
    ok = c(ok, report(paste(tag, "WSLS stay == sim.block stay column"), identical(w$data$stay, full$stay[-1])))
  }

  p_re = t(apply(logits, 1, softmax))
  ok = c(ok, report(paste(tag, "softmax(table Q/E/kappa) == p1-p3"), isTRUE(all.equal(p_re, cols("p"), tolerance = 1e-12))))
  all(ok)
}

results = map_lgl(cases, check_case)
cat(sprintf("\nOVERALL: %s (%d/%d cases passed)\n", if (all(results)) "PASS" else "FAIL", sum(results), length(results)))
