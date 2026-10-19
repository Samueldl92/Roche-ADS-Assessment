example_data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

test_that("calc_mode matches the assessment example", {
  expect_equal(calc_mode(example_data), 5)
})

test_that("calc_mode returns every tied value in increasing order", {
  expect_equal(calc_mode(c(1, 1, 2, 2, 3)), c(1, 2))
  expect_equal(calc_mode(c(3, 3, 1, 1, 2)), c(1, 3))
  expect_equal(calc_mode(c(1, 1, 2, 2)), c(1, 2))
})

test_that("calc_mode returns NA when no value repeats", {
  expect_identical(calc_mode(c(1, 2, 3)), NA_real_)
  expect_identical(calc_mode(c(5, 4)), NA_real_)
})

test_that("calc_mode of a single value or a constant vector is that value", {
  expect_equal(calc_mode(7), 7)
  expect_equal(calc_mode(c(2, 2, 2)), 2)
})

test_that("calc_mode works with negative and decimal values", {
  expect_equal(calc_mode(c(-1.5, -1.5, 0, 2)), -1.5)
  expect_equal(calc_mode(c(0.1, 0.1, 0.3)), 0.1)
})

test_that("calc_mode handles missing values", {
  expect_true(is.na(calc_mode(c(4, NA, 4, 2))))
  expect_equal(calc_mode(c(4, NA, 4, 2), na.rm = TRUE), 4)
  # NA is not counted as a value, even when it is the most common entry
  expect_equal(calc_mode(c(NA, NA, NA, 1, 1, 2), na.rm = TRUE), 1)
})

test_that("calc_mode warns and returns NA for empty input", {
  expect_warning(res <- calc_mode(numeric(0)), "no non-missing values")
  expect_identical(res, NA_real_)
  expect_warning(res <- calc_mode(c(NA, NA_real_), na.rm = TRUE),
                 "no non-missing values")
  expect_identical(res, NA_real_)
})

test_that("calc_mode rejects invalid input", {
  expect_error(calc_mode(c("a", "a")), "must be a numeric vector")
  expect_error(calc_mode(c(Inf, Inf)), "infinite values")
  expect_error(calc_mode(1:3, na.rm = 2), "single TRUE or FALSE")
})
