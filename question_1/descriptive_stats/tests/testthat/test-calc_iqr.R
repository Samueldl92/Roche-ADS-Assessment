example_data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

test_that("calc_iqr matches the assessment example", {
  expect_equal(calc_iqr(example_data), 3)
})

test_that("calc_iqr is Q3 minus Q1", {
  expect_equal(calc_iqr(example_data), calc_q3(example_data) - calc_q1(example_data))
  expect_equal(calc_iqr(1:9), 4.5)
})

test_that("calc_iqr agrees with stats::IQR for the same quantile type", {
  set.seed(7)
  x <- rnorm(50)
  expect_equal(calc_iqr(x, type = 7), stats::IQR(x))
  expect_equal(calc_iqr(example_data, type = 7), stats::IQR(example_data))
})

test_that("calc_iqr is zero for a single or constant value", {
  expect_equal(calc_iqr(5), 0)
  expect_equal(calc_iqr(c(3, 3, 3)), 0)
})

test_that("calc_iqr is never negative", {
  set.seed(3)
  for (i in 1:20) {
    expect_gte(calc_iqr(rnorm(sample(1:30, 1))), 0)
  }
})

test_that("calc_iqr handles missing values", {
  expect_true(is.na(calc_iqr(c(1, NA, 3))))
  expect_equal(calc_iqr(c(NA, example_data), na.rm = TRUE), 3)
})

test_that("calc_iqr gives a single warning for empty input", {
  expect_warning(res <- calc_iqr(numeric(0)), "no non-missing values")
  expect_identical(res, NA_real_)
  # a second warning would fail the test, so check there is exactly one
  warnings <- character()
  withCallingHandlers(
    calc_iqr(numeric(0)),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(warnings, 1L)
})

test_that("calc_iqr rejects invalid input", {
  expect_error(calc_iqr("a"), "must be a numeric vector")
  expect_error(calc_iqr(1:3, type = 0), "between 1 and 9")
})
