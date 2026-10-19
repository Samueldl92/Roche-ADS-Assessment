example_data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

test_that("quartiles reproduce the assessment example", {
  expect_equal(calc_q1(example_data), 2.5)
  expect_equal(calc_q3(example_data), 5.5)
})

test_that("the default definition is p * n + 1 with linear interpolation", {
  expect_equal(calc_q1(1:4), 2)    # h = 2
  expect_equal(calc_q3(1:4), 4)    # h = 4, capped at n
  expect_equal(calc_q1(1:9), 3.25) # h = 3.25
  expect_equal(calc_q3(1:9), 7.75) # h = 7.75
})

test_that("order of the input does not matter", {
  expect_equal(calc_q1(rev(example_data)), 2.5)
  expect_equal(calc_q3(c(10, 5, 1, 6, 2, 5, 3, 2, 5, 4)), 5.5)
})

test_that("type 1 to 9 agree with stats::quantile", {
  set.seed(42)
  x <- round(rnorm(37, 50, 10), 1)
  for (type in 1:9) {
    expect_equal(calc_q1(x, type = type),
                 unname(stats::quantile(x, 0.25, type = type)))
    expect_equal(calc_q3(x, type = type),
                 unname(stats::quantile(x, 0.75, type = type)))
  }
  expect_equal(calc_q1(example_data, type = 7), 2.25)
  expect_equal(calc_q3(example_data, type = 6), 5.25)
})

test_that("a numeric type given as double is accepted", {
  expect_equal(calc_q1(example_data, type = 7), calc_q1(example_data, type = 7L))
})

test_that("a single value is its own quartile", {
  expect_equal(calc_q1(5), 5)
  expect_equal(calc_q3(5), 5)
})

test_that("two values", {
  expect_equal(calc_q1(c(1, 3)), 2)
  expect_equal(calc_q3(c(1, 3)), 3)
})

test_that("constant vectors have equal quartiles", {
  expect_equal(calc_q1(c(4, 4, 4, 4)), 4)
  expect_equal(calc_q3(c(4, 4, 4, 4)), 4)
})

test_that("quartiles handle missing values", {
  expect_true(is.na(calc_q1(c(1, NA, 3))))
  expect_true(is.na(calc_q3(c(1, NA, 3))))
  expect_equal(calc_q1(c(NA, example_data), na.rm = TRUE), 2.5)
  expect_equal(calc_q3(c(NA, example_data), na.rm = TRUE), 5.5)
})

test_that("quartiles warn and return NA for empty input", {
  expect_warning(res <- calc_q1(numeric(0)), "no non-missing values")
  expect_identical(res, NA_real_)
  expect_warning(res <- calc_q3(NA_real_, na.rm = TRUE), "no non-missing values")
  expect_identical(res, NA_real_)
})

test_that("quartiles reject invalid input", {
  expect_error(calc_q1("a"), "must be a numeric vector")
  expect_error(calc_q3(c(1, Inf)), "infinite values")
  expect_error(calc_q1(1:3, na.rm = NA), "single TRUE or FALSE")
  expect_error(calc_q1(1:3, type = 10), "between 1 and 9")
  expect_error(calc_q3(1:3, type = "R7"), "between 1 and 9")
  expect_error(calc_q3(1:3, type = c(6, 7)), "between 1 and 9")
  expect_error(calc_q3(1:3, type = NA), "between 1 and 9")
})
