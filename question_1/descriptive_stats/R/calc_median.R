#' Median
#'
#' Calculates the median of a numeric vector. With an even number of values it
#' is the mean of the two central values.
#'
#' @details
#' Edge cases:
#' * An empty vector, or one that is empty after removing missing values,
#'   returns `NA_real_` with a warning.
#' * If `x` contains `NA` or `NaN` and `na.rm = FALSE` the result is `NA_real_`.
#' * A single value returns that value.
#'
#' @inheritParams calc_mean
#'
#' @return A single numeric value.
#' @seealso [calc_mean()], [calc_q1()], [calc_q3()]
#' @export
#'
#' @examples
#' calc_median(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10))
#' calc_median(c(3, 1, 2))
#' calc_median(c(1, NA, 3, 10), na.rm = TRUE)
calc_median <- function(x, na.rm = FALSE) {
  input <- validate_input(x, na.rm)
  if (input$has_na) return(NA_real_)
  n <- length(input$x)
  if (n == 0L) return(empty_result())
  sorted <- sort(input$x)
  middle <- (n + 1L) %/% 2L
  if (n %% 2L == 1L) sorted[middle] else (sorted[middle] + sorted[middle + 1L]) / 2
}
