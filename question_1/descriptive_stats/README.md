# descriptiveStats

Mean, median, mode, Q1, Q3 and IQR for numeric vectors, with input validation
and defined behaviour for empty vectors, `NA` values and single values.

## Install

From the repository root:

```r
devtools::install("question_1/descriptive_stats")
library(descriptiveStats)
```

## Usage

```r
data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

calc_mean(data)    # 4.3
calc_median(data)  # 4.5
calc_mode(data)    # 5
calc_q1(data)      # 2.5
calc_q3(data)      # 5.5
calc_iqr(data)     # 3
```

| Function | Returns |
|----------|---------|
| `calc_mean(x, na.rm)` | arithmetic mean |
| `calc_median(x, na.rm)` | median |
| `calc_mode(x, na.rm)` | all most frequent values, `NA` if no value repeats |
| `calc_q1(x, na.rm, type)` | first quartile |
| `calc_q3(x, na.rm, type)` | third quartile |
| `calc_iqr(x, na.rm, type)` | `Q3 - Q1` |

## Edge cases

* Empty vector (or empty after `na.rm = TRUE`): `NA_real_` with a warning.
* `NA` or `NaN` in `x` with `na.rm = FALSE`: `NA_real_`, as in base R.
* Single value: that value (IQR is 0).
* Ties in `calc_mode`: every tied value, sorted. No repeated value: `NA_real_`.
* Non-numeric input, `Inf`, a bad `na.rm` or a bad `type`: an error that says what was expected.

## Two points about the assessment example

The statement lists `calc_mean(data) # 3.3`, but the values add up to 43 over
10 observations, so the mean is 4.3. The tests check 4.3.

The expected `Q1 = 2.5` and `Q3 = 5.5` do not come from any of the nine
quantile types in `stats::quantile()` (type 7 gives 2.25 and 5, type 6 gives
2 and 5.25) nor from the median of each half (2 and 5). They do come from
taking the position `h = p * n + 1` in the sorted data, interpolating
linearly and capping `h` at `n`. That rule is the default (`type = "assessment"`)
so the example is reproduced. Pass `type = 1:9` to get the matching
`stats::quantile()` definition, for instance `calc_q1(data, type = 7)`.

## Development

```r
devtools::document()
devtools::test()
devtools::check()
```
