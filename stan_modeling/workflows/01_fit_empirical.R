##### SETUP ####
rm(list = ls())
source('functions/my_starter.R')

path = set_workingmodel()

##### LOAD STAN DATA ####
sample = 'story'
data_path = paste0('data/data_analysis/empirical_standata_', sample, '.Rdata')

##### COMPILE MODEL ####
modelfit_compile(path, format = FALSE)

##### SAMPLE POSTERIOR ####
modelfit_mcmc(
  path,
  data_path = data_path,
  mymcmc = list(
    datatype = 'empirical',
    samples  = 2000,
    warmup   = 2000,
    chains   = 4,
    cores    = 4
  )
)

# This script compiles and fits the model for empirical data.
# Use stan_modeling/workflows/02_analyze_empirical.R to inspect results.


