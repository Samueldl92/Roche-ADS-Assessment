#' Mode
#'
#' Calculates the most frequent value(s) of a numeric vector.
#'
#' @details
#' Edge cases:
#' * Ties: all values that share the highest frequency are returned in
#'   increasing order, so a multimodal sample returns several values.
#' * No mode: if no value occurs more than once in a vector with at least two
#'   values, `NA_real_` is returned.
#' * A single value is its own mode.
#' * An empty vector, or one that is empty after removing missing values,
#'   returns `NA_real_` with a warning.
#' * If `x` contains `NA` or `NaN` and `na.rm = FALSE` the result is `NA_real_`.
#'
#' @inheritParams calc_mean
#'
#' @return A numeric vector with the modal value(s) in increasing order, or
#'   `NA_real_` when there is no mode.
#' @seealso [calc_mean()], [calc_median()]
#' @export
#'
#' @examples
#' calc_mode(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)) # 5
#' calc_mode(c(1, 1, 2, 2, 3))                 # tie: 1 and 2
#' calc_mode(c(1, 2, 3))                       # no mode: NA
#' calc_mode(c(4, NA, 4, 2), na.rm = TRUE)
calc_mode <- function(x, na.rm = FALSE) {
  input <- validate_input(x, na.rm)
  if (input$has_na) return(NA_real_)
  values <- input$x
  if (length(values) == 0L) return(empty_result())
  if (length(values) == 1L) return(values)

  counts <- table(values)
  top <- max(counts)
  if (top == 1L) return(NA_real_)
  sort(as.numeric(names(counts)[counts == top]))
}
