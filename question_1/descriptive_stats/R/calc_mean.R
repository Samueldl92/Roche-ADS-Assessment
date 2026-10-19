#' Arithmetic mean
#'
#' Calculates the arithmetic mean of a numeric vector.
#'
#' @details
#' Edge cases:
#' * An empty vector, or one that is empty after removing missing values,
#'   returns `NA_real_` with a warning.
#' * If `x` contains `NA` or `NaN` and `na.rm = FALSE` the result is `NA_real_`.
#' * A single value returns that value.
#'
#' @param x A numeric vector without infinite values.
#' @param na.rm Logical. Should missing values (`NA`, `NaN`) be removed before
#'   computing? Defaults to `FALSE`.
#'
#' @return A single numeric value.
#' @seealso [calc_median()], [calc_mode()]
#' @export
#'
#' @examples
#' calc_mean(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10))
#' calc_mean(c(1, NA, 3), na.rm = TRUE)
#' calc_mean(c(1, NA, 3))
#' calc_mean(7)
calc_mean <- function(x, na.rm = FALSE) {
  input <- validate_input(x, na.rm)
  if (input$has_na) return(NA_real_)
  if (length(input$x) == 0L) return(empty_result())
  sum(input$x) / length(input$x)
}
