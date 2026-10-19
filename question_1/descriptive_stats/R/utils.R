# Internal helpers shared by the exported functions.

# Checks `x` and `na.rm` and returns list(x, has_na). `x` is the numeric vector
# to work on (missing values dropped when na.rm = TRUE). `has_na` is TRUE when
# missing values remain, in which case the caller returns NA.
validate_input <- function(x, na.rm) {
  if (!is.numeric(x) || is.factor(x) || !is.null(dim(x))) {
    stop("`x` must be a numeric vector, not ", class(x)[1], ".", call. = FALSE)
  }
  if (!is.logical(na.rm) || length(na.rm) != 1L || is.na(na.rm)) {
    stop("`na.rm` must be a single TRUE or FALSE.", call. = FALSE)
  }
  if (any(is.infinite(x))) {
    stop(
      "`x` must not contain infinite values (found ", sum(is.infinite(x)), ").",
      call. = FALSE
    )
  }

  missing_x <- is.na(x)
  if (na.rm) {
    x <- x[!missing_x]
    has_na <- FALSE
  } else {
    has_na <- any(missing_x)
  }
  list(x = as.numeric(x), has_na = has_na)
}

# Result for a statistic that cannot be computed without data.
empty_result <- function() {
  warning("`x` has no non-missing values; returning NA.", call. = FALSE)
  NA_real_
}

validate_type <- function(type) {
  is_assessment <- is.character(type) && length(type) == 1L &&
    identical(type, "assessment")
  is_r_type <- is.numeric(type) && length(type) == 1L && !is.na(type) &&
    type %in% 1:9
  if (!is_assessment && !is_r_type) {
    stop(
      "`type` must be \"assessment\" or a single integer between 1 and 9, ",
      "not ", deparse(type), ".",
      call. = FALSE
    )
  }
  if (is_r_type) as.integer(type) else type
}

# x is already validated and has no missing values.
quantile_value <- function(x, p, type) {
  if (identical(type, "assessment")) {
    # Position h = p * n + 1 on the sorted data, linear interpolation between
    # the neighbouring values, h capped at n. For the assessment example
    # (n = 10) Q1 sits at h = 3.5 -> (2 + 3) / 2 = 2.5 and Q3 at h = 8.5
    # -> (5 + 6) / 2 = 5.5.
    x <- sort(x)
    n <- length(x)
    h <- min(p * n + 1, n)
    lower <- floor(h)
    upper <- ceiling(h)
    return(x[lower] + (h - lower) * (x[upper] - x[lower]))
  }
  unname(stats::quantile(x, probs = p, type = type, names = FALSE))
}

calc_quartile <- function(x, p, type, na.rm) {
  type <- validate_type(type)
  input <- validate_input(x, na.rm)
  if (input$has_na) return(NA_real_)
  if (length(input$x) == 0L) return(empty_result())
  quantile_value(input$x, p, type)
}
