example_data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

test_that("calc_median matches the assessment example", {
  expect_equal(calc_median(example_data), 4.5)
})

test_that("calc_median handles odd and even lengths", {
  expect_equal(calc_median(c(3, 1, 2)), 2)
  expect_equal(calc_median(c(4, 1, 3, 2)), 2.5)
})

test_that("calc_median agrees with stats::median", {
  set.seed(1)
  for (n in c(2, 5, 10, 11, 100)) {
    x <- rnorm(n)
    expect_equal(calc_median(x), stats::median(x))
  }
})

test_that("calc_median handles a single value and repeated values", {
  expect_equal(calc_median(7), 7)
  expect_equal(calc_median(c(2, 2, 2)), 2)
})

test_that("calc_median handles missing values", {
  expect_true(is.na(calc_median(c(1, NA, 3))))
  expect_equal(calc_median(c(1, NA, 3, 10), na.rm = TRUE), 3)
})

test_that("calc_median warns and returns NA for empty input", {
  expect_warning(res <- calc_median(numeric(0)), "no non-missing values")
  expect_identical(res, NA_real_)
  expect_warning(res <- calc_median(NA_real_, na.rm = TRUE), "no non-missing values")
  expect_identical(res, NA_real_)
})

test_that("calc_median rejects invalid input", {
  expect_error(calc_median("a"), "must be a numeric vector")
  expect_error(calc_median(c(1, -Inf)), "infinite values")
  expect_error(calc_median(1:3, na.rm = NULL), "single TRUE or FALSE")
})
