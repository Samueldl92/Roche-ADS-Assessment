#' Interquartile range
#'
#' Calculates the interquartile range, `IQR = Q3 - Q1`, using [calc_q1()] and
#' [calc_q3()].
#'
#' @details
#' Edge cases follow [calc_q1()] and [calc_q3()]: an empty vector returns
#' `NA_real_` with a warning, missing values give `NA_real_` unless
#' `na.rm = TRUE`, and a single value has an IQR of 0.
#'
#' @inheritParams calc_q1
#'
#' @return A single non-negative numeric value.
#' @seealso [calc_q1()], [calc_q3()]
#' @export
#'
#' @examples
#' data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
#' calc_iqr(data)            # 3
#' calc_iqr(data, type = 7)  # 2.75, same as stats::IQR(data)
#' calc_iqr(c(2, NA, 8), na.rm = TRUE)
calc_iqr <- function(x, na.rm = FALSE, type = "assessment") {
  q1 <- calc_q1(x, na.rm = na.rm, type = type)
  # An empty input already warned once through calc_q1().
  q3 <- suppressWarnings(calc_q3(x, na.rm = na.rm, type = type))
  q3 - q1
}
