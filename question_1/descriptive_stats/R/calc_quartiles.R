#' First and third quartiles
#'
#' Calculate the first quartile (Q1, 25th percentile) or the third quartile
#' (Q3, 75th percentile) of a numeric vector.
#'
#' @section Which quartile definition?:
#' Quartiles have no single definition. The assessment example,
#' `c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)`, expects `Q1 = 2.5` and `Q3 = 5.5`, and
#' none of the nine types of [stats::quantile()] reproduces that: type 7 (the R
#' default) gives 2.25 and 5, type 6 gives 2 and 5.25, and the median of each
#' half gives 2 and 5. The simple rule that does is the default
#' `type = "assessment"`: after sorting, take position `h = p * n + 1` (capped
#' at `n`) and interpolate linearly between the two neighbouring values.
#' Use `type = 1:9` to get the matching [stats::quantile()] type instead, for
#' example `type = 7` to agree with `quantile(x, 0.25)`.
#'
#' @details
#' Edge cases:
#' * An empty vector, or one that is empty after removing missing values,
#'   returns `NA_real_` with a warning.
#' * If `x` contains `NA` or `NaN` and `na.rm = FALSE` the result is `NA_real_`.
#' * A single value returns that value.
#'
#' @inheritParams calc_mean
#' @param type Quartile definition: `"assessment"` (default) or an integer from
#'   1 to 9 passed to [stats::quantile()].
#'
#' @return A single numeric value.
#' @seealso [calc_iqr()], [calc_median()]
#' @name calc_quartiles
#'
#' @examples
#' data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
#' calc_q1(data)             # 2.5
#' calc_q3(data)             # 5.5
#' calc_q1(data, type = 7)   # 2.25, same as quantile(data, 0.25)
#' calc_q3(c(1, NA, 3, 9), na.rm = TRUE)
NULL

#' @rdname calc_quartiles
#' @export
calc_q1 <- function(x, na.rm = FALSE, type = "assessment") {
  calc_quartile(x, 0.25, type, na.rm)
}

#' @rdname calc_quartiles
#' @export
calc_q3 <- function(x, na.rm = FALSE, type = "assessment") {
  calc_quartile(x, 0.75, type, na.rm)
}
