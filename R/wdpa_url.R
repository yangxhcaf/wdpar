#' @include internal.R
NULL

#' Download URL for the World Database on Protected Areas
#'
#' Obtain the URL for downloading data from the World Database on Protected
#' Areas (WDPA).
#'
#' @param x \code{character} country for desired data. This argument
#'   can be the name of the country (e.g. \code{"Liechtenstein"}) or the
#'   ISO-3 code for the country (e.g. \code{"LIE"}). This argument can also
#'   be set to \code{"global"} to obtain the URL for the global dataset.
#'
#' @param wait \code{logical} if data is not immediately available for download
#'   should the session be paused until it is ready for download? If argument
#'   to \code{wait} is \code{FALSE} and the data is not ready then an error
#'   will be thrown. Defaults to \code{FALSE}.
#'
#' @return \code{character} URL to download the data.
#'
#' @seealso \code{\link{wdpa_fetch}}, \code{\link[countrycode]{countrycode}}.
#'
#' @examples
#' \donttest{
#' # obtain url for New Zealand data
#' nzl_url <- wdpa_url("New Zealand", wait = TRUE)
#' print(nzl_url)
#'
#' # obtain url for New Zealand data using its ISO3 code
#' nzl_url <- wdpa_url("NZL", wait = TRUE)
#' print(nzl_url)
#'
#' # obtain url for global data
#' global_url <- wdpa_url("global")
#' print(global_url)
#' }
#' @export
wdpa_url <- function(x, wait = FALSE) {
  # validate arguments
  assertthat::assert_that(assertthat::is.string(x), assertthat::is.flag(wait),
                          curl::has_internet())
  # declare hidden function
  try_and_find_url <- function(x) {
    ## initialize web driver
    result <- suppressMessages(tryCatch({
      url <- character(0)
      pjs <- wdman::phantomjs(verbose = FALSE)
      rd <- RSelenium::remoteDriver(port = 4567L, browserName = "phantomjs")
      rd$open(silent = TRUE)
      rd$maxWindowSize()
      rd$navigate(paste0("https://protectedplanet.net/country/", x))
      Sys.sleep(2) # wait 2 seconds for page to load
      elem <- rd$findElement(using = "css", ".link-with-icon--bold")
      elem$clickElement()
      Sys.sleep(2) # wait 2 seconds for page to load
      elem <- rd$findElement(using = "css", ".link-with-icon+ .link-with-icon")
      elem$clickElement()
      Sys.sleep(2) # wait 2 seconds for dialog to open
      ## extract html for modal
      src <- xml2::read_html(rd$getPageSource()[[1]][[1]], encoding = "UTF-8")
      divs <- xml2::xml_find_all(src, ".//div")
      divs <- divs[which(xml2::xml_attr(divs, "id") == "download-modal")]
      ## parse download link
      attrs <- xml2::xml_attr(xml2::xml_find_all(divs, ".//a"), "href")
      url <- grep("shapefile", attrs, fixed = TRUE, value = TRUE)
    },
    finally = {
      ## clean up web driver
      try(rd$close(), silent = TRUE)
      try(rd$close(), silent = TRUE)
      try(pjs$stop(), silent = TRUE)
      try(pjs$stop(), silent = TRUE)
    }))
    ## prepare output
    if (length(url) == 0)
      return(NA_character_)
    return(paste0("https://www.protectedplanet.net", url))
  }
  # find url
  if (x == "global") {
    out <- "http://wcmc.io/wdpa_current_release"
  } else {
    ## convert x to country ISO3 code
    x <- country_code(x)
    ## initialize web driver
    ## check if data is ready for download
    attempted_url <- try_and_find_url(x)
    ## return NA if not ready and not wait
    if (is.na(attempted_url) && !wait) {
      stop(paste("data is not yet available for download; try again later",
                 "or use wait=TRUE"))
    } else {
      ## otherwise check for url in 5 minute increments
      while (is.na(attempted_url)) {
        Sys.sleep(60 * 5)
        attempted_url <- try_and_find_url(x)
      }
      ## now that data is available, store the url
      out <- attempted_url
    }
  }
  # return url
  return(out)
}
