# Data Exploration Guide (Ben's Starting Point)

**Use this guide when you (Ben) first encounter raw data.**

Before designing any preprocessing pipeline, you must understand the raw data thoroughly. This guide walks you through systematic exploration.

## Step 1: Load and Inspect Structure

```r
# Load the data
raw_data <- readRDS("path/to/raw_data.RDS")
# OR
raw_data <- read.csv("path/to/raw_data.csv")

# Basic structure
str(raw_data)              # Shows class and first few values of each column
head(raw_data, 10)         # First 10 rows
dim(raw_data)              # Dimensions: n rows × p columns
names(raw_data)            # Column names
```

**What to note:**
- How many rows? (sample size)
- How many columns? (number of variables)
- What are the column names? (Can you guess each variable's purpose?)
- What is the current class of each column? (numeric, character, logical, factor, Date, etc.)

---

## Step 2: Examine Each Column Individually

For each column, ask:

### What is this column supposed to represent?
- Is it an ID? (should be unique)
- Is it a demographic? (age, gender, education)
- Is it a measured outcome? (score, count, reaction time)
- Is it a categorical grouping? (treatment, region, category)
- Is it a date/time? (visit date, enrollment date)
- Is it a text response? (open-ended comment, note)

### What is its current data type?
```r
class(raw_data$column_name)
```

**Then check:**
- Is the type correct for the intended variable? (e.g., is an ID numeric when it should be character?)
- If numeric, what is the range? Does it make sense?
  ```r
  summary(raw_data$column_name)
  range(raw_data$column_name, na.rm = TRUE)
  ```
- If character/factor, what are the unique values?
  ```r
  unique(raw_data$column_name)
  table(raw_data$column_name)
  ```
- If logical, what proportion is TRUE vs FALSE?
  ```r
  table(raw_data$column_name)
  ```

### Are there missing values?
```r
sum(is.na(raw_data$column_name))
mean(is.na(raw_data$column_name))  # Proportion missing
```

**What to note:**
- How many NAs? (absolute count)
- What proportion? (percentage)
- Is missing data expected in this column?
- Is missing data random or systematic? (e.g., only in recent rows)

---

## Step 3: Whole-Dataset Missing Pattern

```r
# Overall missing data summary
colSums(is.na(raw_data))

# Visualize missing pattern (counts per column)
# Or use:
missing_per_column <- data.frame(
  column = names(raw_data),
  n_missing = colSums(is.na(raw_data)),
  pct_missing = colMeans(is.na(raw_data)) * 100
)
print(missing_per_column)

# Check: how many rows have NO missing values?
n_complete_rows <- sum(complete.cases(raw_data))
cat("Complete rows (no missing):", n_complete_rows, "of", nrow(raw_data), "\n")
```

---

## Step 4: Look for Data Quality Issues

### Impossible or Out-of-Range Values
```r
# Example: age should be 18-100
summary(raw_data$age)
# If you see negative ages or ages > 150, flag it

# Example: percentage should be 0-100
summary(raw_data$percentage)
# If you see values > 100 or < 0, flag it
```

### String Encoding Problems
```r
# Check for "NA" stored as a string instead of proper NA
raw_data$column_name[1:20]  # Inspect first 20 values
# Do you see "NA", "NULL", "N/A", "None", "." as strings?

# Check for inconsistent capitalization or spacing
unique(raw_data$category)  # Is it "Male", "male", "MALE", or "M"?
```

### Duplicate Rows
```r
# Check for completely identical rows
n_duplicated <- sum(duplicated(raw_data))
cat("Duplicate rows:", n_duplicated, "\n")

# Check for duplicate IDs (if ID column exists)
if ("id" %in% names(raw_data)) {
  n_dup_ids <- sum(duplicated(raw_data$id))
  cat("Duplicate IDs:", n_dup_ids, "\n")
}
```

### Unexpected Data Types
```r
# If a column SHOULD be numeric but is character:
head(raw_data$column_name)  # Inspect values
# Are there letters mixed in? Commas? Currency symbols?

# If a column SHOULD be a date but is character:
head(raw_data$date_col)
# What format is it in? YYYY-MM-DD? MM/DD/YYYY? DD.MM.YYYY?
```

---

## Step 5: Summary Report (Before Preprocessing Plan)

After exploration, compile your findings:

```
DATA EXPLORATION REPORT
=======================

Dataset: raw_data
Dimensions: 100 rows × 8 columns
Complete cases: 94 rows (94%)

COLUMNS:
--------

1. id (numeric)
   - Unique values: 100 ✓
   - Range: 1-100
   - Missing: 0
   - Verdict: OK, keep as-is

2. age (numeric)
   - Range: 22-68
   - Missing: 0
   - Verdict: OK, but check if we want to exclude <18 or >75

3. gender (character)
   - Unique values: "F", "M", "Other"
   - Counts: F=52, M=45, Other=3
   - Missing: 0
   - Verdict: CONVERT to factor with explicit levels

4. score (character) ⚠️
   - Unique values: "0.5", "1.2", "NA", "2.5", ...
   - Missing: 0 (BUT "NA" strings present!)
   - Verdict: CRITICAL - handle "NA" strings before as.numeric()

5. date_visit (character)
   - Example values: "2020-01-15", "2021-03-22", ...
   - Format: appears to be YYYY-MM-DD
   - Missing: 0
   - Verdict: CONVERT to Date with format = "%Y-%m-%d"

6. region (character)
   - Unique values: "North", "South", "East", "West"
   - Counts: North=30, South=28, East=21, West=21
   - Missing: 0
   - Verdict: CONVERT to factor OR keep as character

7. outcome (character)
   - Unique values: "Yes", "No", "Maybe"
   - Counts: Yes=50, No=40, Maybe=10
   - Missing: 0
   - Verdict: CONVERT to factor (ordered or unordered?)

8. notes (character)
   - Example: "Patient reported...", "Follow-up needed", ...
   - Missing: 6 values
   - Verdict: KEEP as character (text); document that 6 rows have missing notes

DATA QUALITY ISSUES:
--------------------

Minor:
- 6 missing values in notes column (OK, keep them)

Critical:
- score column contains "NA" strings that must be handled before numeric conversion
```

---

## Step 6: Questions for the User

After exploration, ask the user:

```
Based on my exploration of your data, I have a few clarifying questions:

1. **Filtering thresholds:**
   - Age ranges from 22-68. Should I keep all ages, or filter to a range like 18-75?
   - Should I remove rows with missing values in ANY column, or only specific columns?

2. **Type conversions:**
   - Is outcome ("Yes", "No", "Maybe") ordinal or nominal? Should I use ordered = TRUE?
   - Should region be kept as character or converted to factor?

3. **Data validation:**
   - I found 6 missing values in the notes column. Should I remove these rows or keep them?
   - The score column contains some "NA" strings. Shall I convert to proper NA values?

4. **Analysis intent:**
   - What is your planned analysis? (Linear model? Classification? Descriptive?)
   - This helps me determine if current data types are suitable.

Please clarify before I proceed with preprocessing.
```

---

## Exploration Command Cheat Sheet

```r
# Quick overview
str(raw_data)
head(raw_data)
summary(raw_data)

# Missingness
colSums(is.na(raw_data))
sum(complete.cases(raw_data))

# Single column deep-dive
unique(raw_data$col)           # Unique values
table(raw_data$col)            # Frequency table
range(raw_data$col, na.rm=T)   # Min-max (numeric)
class(raw_data$col)            # Data type

# Data quality checks
sum(duplicated(raw_data))      # Duplicate rows
sum(duplicated(raw_data$id))   # Duplicate IDs
table(raw_data$col) |> sort(decreasing=TRUE)  # Value frequencies

# Cross-variable checks
xtabs(~ col1 + col2, raw_data)  # Cross-tabulation (categorical)
cor(raw_data[, c("num1", "num2")], use="pairwise")  # Correlation
```

---

## Next Step: Propose Preprocessing Plan

Once exploration is complete, use the findings to create your **Preprocessing Plan** (see BEN-INSTRUCTIONS.md, Phase 2).

Present this plan to the user and **wait for approval** before writing code.
