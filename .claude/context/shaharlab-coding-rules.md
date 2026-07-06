# Instructions for R coding 

These are instructions and guidelines for writing R scripts in this repository.

## R programming context

Always write clear, readable R code.

Code should be easy to understand, easy to edit, and consistent with the existing style of this repository.

## Core R coding guidelines

Follow these guidelines when writing R code:

* Use clear, descriptive object names.
* Follow the style and structure of the existing R code in this repository before introducing new patterns.
* Keep scripts focused on the task they are meant to perform.
* Use only the minimum number of headers needed to make the code easy to navigate.
* Comment only when the code is not readable from the object names and structure.
* Avoid explaining code that is already clear.
* Align `<-` and `=` within related blocks when this improves readability.
* Use the base R pipe `|>` rather than `%>%`, unless the existing code uses `%>%` or a package requires it.


## what you should not do and avoid when writing in R 

Avoid over-commenting.

* Do not to use `set.seed()` unless the user explicitly asks for reproducible random output.
* Do not to use `tryCatch()` unless there is a clear reason to recover from an expected error.
* Do not to use `stop()` lines unless the user explicitly asks for strict validation or the error is necessary to prevent incorrect results.
* Do not use apply, vapply or their like unless you really have to



## Preferred R style

These are preferred guidelines, but use judgment when the task or existing code calls for a different approach.

* Prefer `tidyverse` and `dplyr` when they fit the task.
* Prefer simple, explicit code over clever or compact code.
* Prefer readable intermediate objects over long nested expressions.
* Prefer not to write custom function() becuase they make reading much harder

## Writing conventions 
* prefer to use `df` for the main data.frame when ever possible
* in our lab we use the variabels "reward", "reward_oneback", "choice", "stay_ch" very often. Use when appropriate. 

## Preferred R libraries

Prefer these libraries when they fit the task:

```r
library(tidyverse)
library(dplyr)
library(ggplot2)
library(tidyr)
library(readr)
library(purrr)
library(stringr)
library(tibble)
library(cmdstanr)
library(posterior)
library(ggdist)
library(bayesplot)
```

## Mandatory Plotting Rule: `/plot-posterior` for Posteriors

**For all posterior distribution plots (parameter summaries, credible intervals, etc.):**
- You MUST use the `/plot-posterior` skill from shaharlab_plotting
- Do NOT write raw ggplot code for posterior visualization
- This applies to all brms model parameter plots, MCMC diagnostics, and posterior summaries

The skill handles all posterior-related visualizations. Direct users to the skill when they need posterior plots.

## how to use headers in R

Use this format for main headers:

```r
#### HEADER ####
```

Use only `#` for smaller subtitles:

```r
# Smaller subtitle
```

## how to start your script

**Main script (main.R):**
- Put `rm(list = ls())` at the start
- Use a `#### SETUP ####` header where you:
  - Load all required libraries (including `library(here)`)
  - Define `project_root <- here::here()` to anchor all paths to the root `project.Rproj` file
  - Define all folder paths using `file.path()` (e.g., `artifacts_dir <- file.path(project_root, "analysis", "my_analysis", "artifacts")`)
  - Source required functions
- Then use `#### EXECUTE PIPELINE ####` to source the scripts in `code/`

**Sourced scripts (code/*.R):**
- Do NOT include `rm(list = ls())`
- Do NOT load libraries (they are loaded in main.R)
- Start directly with a functional header (e.g., `#### CREATE EXAMPLE DATA ####`, `#### LOAD MODEL ####`)
- Inherit paths and libraries from the parent environment when sourced from main.R
