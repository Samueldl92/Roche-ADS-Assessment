example_data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

test_that("calc_mean returns the arithmetic mean", {
  # The assessment text says 3.3, but the values add up to 43 over 10 values.
  expect_equal(calc_mean(example_data), 4.3)
  expect_equal(calc_mean(c(1, 2, 3)), 2)
  expect_equal(calc_mean(c(-2, 2)), 0)
  expect_equal(calc_mean(c(0.1, 0.2, 0.3)), 0.2)
})

test_that("calc_mean accepts integers and returns a double", {
  expect_equal(calc_mean(1:4), 2.5)
  expect_type(calc_mean(1:4), "double")
})

test_that("calc_mean does not depend on the order of the values", {
  expect_equal(calc_mean(rev(example_data)), calc_mean(example_data))
})

test_that("calc_mean handles a single value", {
  expect_equal(calc_mean(7), 7)
})

test_that("calc_mean handles missing values", {
  expect_true(is.na(calc_mean(c(1, NA, 3))))
  expect_true(is.na(calc_mean(c(1, NaN, 3))))
  expect_equal(calc_mean(c(1, NA, 3), na.rm = TRUE), 2)
  expect_equal(calc_mean(c(1, NaN, 3), na.rm = TRUE), 2)
})

test_that("calc_mean warns and returns NA for empty input", {
  expect_warning(res <- calc_mean(numeric(0)), "no non-missing values")
  expect_identical(res, NA_real_)
  expect_warning(res <- calc_mean(c(NA_real_, NA_real_), na.rm = TRUE),
                 "no non-missing values")
  expect_identical(res, NA_real_)
})

test_that("calc_mean rejects invalid input", {
  expect_error(calc_mean("a"), "must be a numeric vector, not character")
  expect_error(calc_mean(NULL), "must be a numeric vector")
  expect_error(calc_mean(list(1, 2)), "must be a numeric vector, not list")
  expect_error(calc_mean(factor(c("a", "b"))), "must be a numeric vector")
  expect_error(calc_mean(matrix(1:4, 2)), "must be a numeric vector")
  expect_error(calc_mean(c(1, Inf)), "infinite values")
  expect_error(calc_mean(1:3, na.rm = NA), "single TRUE or FALSE")
  expect_error(calc_mean(1:3, na.rm = "yes"), "single TRUE or FALSE")
  expect_error(calc_mean(1:3, na.rm = c(TRUE, FALSE)), "single TRUE or FALSE")
})
