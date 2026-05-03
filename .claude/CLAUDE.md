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
prefer using these:
put `rm(list = ls())` at the start
then use a `#### SETUP ####` header where you load libraries, source required functions and handle the name of folders that will be needed for the script
