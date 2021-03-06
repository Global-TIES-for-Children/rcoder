#' Link a coding from others for recoding
#'
#' Coding objects can be linked together to create mappings from one or more
#' codings to another. This creates a `data.frame` that outlines how the codings
#' are linked, to be used in `make_recode_query()`.
#'
#' @param to A coding to be linked to
#' @param ... Codings to be linked from
#' @param .to_suffix A suffix signifying which columns in the output `data.frame`
#'   came from `to`
#' @param .drop_unused Logical flag to drop any codes in `to` that have no
#'   counterparts in `...`
#' @return A `linked_coding_df` with all necessary information for a recoding
#'   query
#'
#' @export
link_codings <- function(to, ..., .to_suffix = "to", .drop_unused = TRUE) {
  rc_assert(is.coding(to))

  from <- rlang::dots_list(...)

  if (length(from) == 1) {
    from <- from[[1]]
  }

  if (!is.coding(from)) {
    if (!is.list(from)) {
      rc_err("`...` must be a coding or codings.")
    }

    if (!all(vlapply(from, is.coding))) {
      rc_err("Not all of `...` is a coding object.")
    }
  }

  if (!is.coding(from)) {
    from_dat <- coding_list_to_df(from)
  } else {
    from_dat <- as.data.frame(from, suffix = 1)
  }

  to_dat <- as.data.frame(to, suffix = .to_suffix)

  if (nrow(to_dat) < nrow(from_dat)) {
    rc_err("Not all cases covered while linking codings.")
  }

  if (isTRUE(.drop_unused)) {
    to_dat <- drop_unused_links(to_dat, from_dat)
  }

  # Only include link, value, and label
  filter_pattern <- paste0(paste0("^", c("link", "value", "label")), collapse = "|")
  to_dat <- to_dat[, grepl(filter_pattern, names(to_dat))]
  from_dat <- from_dat[, grepl(filter_pattern, names(from_dat))]

  if (length(intersect(to_dat$link, from_dat$link)) == 0) {
    if (!is.coding(from)) {
      from_str <- paste0(
        paste0("\t", vcapply(from, as.character)),
        collapse = "\n"
      )
    } else {
      from_str <- paste0("\t", as.character(from))
    }

    to_str <- paste0("\t", as.character(to))

    rc_err(c(
      "No common links identified. ",
      "It's possible that you didn't define your labels correctly?\n",
      "For reference, these are the input codings:\n",
      "From:\n",
      "{from_str}\n",
      "To:\n",
      "{to_str}"
    ))
  }

  dat <- merge(to_dat, from_dat, by = "link", all.x = TRUE)
  class(dat) <- c(class(dat), "linked_coding_df")

  if (nrow(dat) < 1) {
    print("to_dat:")
    print(to_dat)
    print("from_dat:")
    print(from_dat)
    print("to:")
    print(as.character(to))

    if (!is.coding(from)) {
      print("from:")

      for (el in from) {
        print(as.character(el))
      }
    } else {
      print(as.character(from))
    }

    rc_err(c(
      "A problem has occurred. ",
      "Contact the developer with the provided ",
      "'to_dat', 'to', 'from_dat', and 'from' values."
    ))
  }

  dat
}

coding_list_to_df <- function(coding_list) {
  suffixes <- if (!is.null(names(coding_list))) {
    # Assumed to be the wave tags
    names(coding_list)
  } else {
    1:length(coding_list)
  }

  mapped <- Map(
    function(.x, .y) as.data.frame(.x, suffix = .y),
    coding_list,
    suffixes
  )

  if (length(mapped) > 1) {
    Reduce(function(x, y) merge(x, y, by = "link", all = TRUE), mapped)
  } else {
    mapped[[1]]
  }
}

drop_unused_links <- function(to_dat, from_dat) {
  from_links <- from_dat$link
  to_links <- to_dat$link

  to_dat[to_links %in% from_links, ]
}
