#' Import EnergyPlus .epg group file
#'
#' \code{read_epg} returns a tibble which contains the necessary infomation in
#' order to run simulations using \code{\link{run_epg}}.
#'
#' @param epg A file path of EnergyPlus .epg file.
#' @return A tibble.
#' @importFrom readr read_csv cols col_integer
#' @importFrom dplyr as_tibble mutate select one_of
#' @importFrom purrr map_at
#' @export
# read_epg{{{1
read_epg <- function(epg){

    assertthat::assert_that(is_epg_file(epg), msg = "Invalid epg file.")

    sim_info <- readr::read_csv(file = epg, comment = "!",
                                col_names = c("model", "weather", "output_name", "run_times"),
                                col_types = cols(.default = "c", run_times = col_integer()),
                                trim_ws = TRUE)

    sim_info <- dplyr::as_tibble(
        purrr::map_at(sim_info, c("model", "weather", "output_name"), file_path)
    )
    sim_info <- dplyr::mutate(sim_info, output_dir = file_path(dirname(output_name)))
    sim_info <- dplyr::mutate(sim_info, output_prefix = file_prefix(output_name))
    sim_info <- dplyr::select(sim_info, dplyr::one_of("model", "weather", "output_dir", "output_prefix", "run_times"))

    class(sim_info) <- c("epg", "eplusr_job", class(sim_info))

    return(sim_info)
}
# }}}1

# is_epg_file {{{1
is_epg_file <- function (epg) {
    if (assertthat::is.string(epg)) {
        if (has_epg_ext(epg)) {
            assertthat::assert_that(assertthat::is.readable(epg))
            try_epg <- readr::read_csv(epg, comment = "!", n_max = 0,
                col_names = FALSE,
                col_types = readr::cols(.default = readr::col_character())
            )
            if (identical(ncol(try_epg), 4L)) {
                TRUE
            } else {
                FALSE
            }
        } else {
            FALSE
        }
    } else {
        FALSE
    }
}
# }}}1

# validate_job {{{1
validate_job <- function (job, type = c("epg", "jeplus", "epat")) {
    assertthat::assert_that(inherits(job, "eplusr_job"),
        msg = "Input is not an eplusr job object."
    )
    type <- rlang::arg_match(type)
    val_job <- switch(type,
        epg = validate_epg(epg),
        jeplus = validate_jeplus(job),
        epat = validate_epat(job)
    )

    return(val_job)
}

validate_epg <- function (epg) {
    if (is_epg_file(epg)) {
        job <- read_epg(epg)
    } else {
        if (inherits(epg, "epg")) {
            job <- epg
        } else {
            stop("'epg' should be an 'epg' object or a file path of an .epg file.",
                 call. = FALSE)
        }
    }

    return(job)
}
# }}}1

# as_epg {{{1
as_epg <- function (x) {
    assertthat::assert_that(is.data.frame(x))
    assertthat::assert_that(identical(ncol(x), 4L))

    col_names = c("model", "weather", "output_name", "run_times")
    assertthat::assert_that(all(!is.na(match(colnames(x), colnames))),
        msg = paste0("Input shoud be a data.frame with columns ",
            sQuote(col_names), "."
        )
    )

    epg <- x
    class(epg) <- unique(c("epg", "eplusr_job", class(sim_info)))

    return(epg)
}
# }}}1

# run_epg{{{1
run_epg <- function (epg, cores = NULL, output_suffix = c("C", "L", "D"),
                     special_run = NULL, eplus_ver = NULL, eplus_dir = NULL) {

    job <- validate_job(epg, "epg")
    # Get inputs {{{2
    run_times <- job[["run_times"]]
    models <- purrr::map2_chr(job[["model"]], run_times, ~rep(.x, times = .y))
    weathers <- purrr::map2_chr(job[["weather"]], run_times, ~rep(.x, times = .y))
    output_dirs <- purrr::map2_chr(job[["output_dir"]], run_times, ~rep(.x, times = .y))
    output_prefixes <- purrr::map2_chr(job[["output_prefix"]], run_time,s ~rep(.x, times = .y))
    # }}}2
    # Write the epg file to output dir {{{2
    if (identical(length(unique(output_dirs)), 1L)) {
        write_epg(epg, file_path(output_dirs[1], "run.epg"))
    }
    # }}}2
    # Run {{{2
    run_multi(models = models, weathers = weathers, cores = cores,
              output_dirs = output_dirs, output_prefixes = output_prefixes,
              output_suffix = output_suffix, special_run = special_run,
              eplus_ver = eplus_ver, eplus_dir = eplus_dir, show_msg = TRUE)
    # }}}2

}
# }}}1

# write_epg{{{1
write_epg <- function(epg, path, head_info = NULL){
    assertthat::assert_that(inherits(epg, "epg"))

    header <- paste(
        "! EnergyPlus Group File",
        "! ------------------------------------------------------------------------------------------------",
        "! Each line represents a specific simulation. If you don't want a simulation to run, add a comment",
        "! character (an exclamation point) to the beginning of that line. Commas are used to separate the ",
        "! fields. Each line consists of the following fields: ",
        "!",
        "!    input file name, weather file name, output file name (no extension), counter",
        "!",
        "! ------------------------------------------------------------------------------------------------",
        sep = "\n", collapse = "\n")

    epg_content <- dplyr::mutate(epg,
        output_name = file_path(output_dir, output_prefix),
        output_dir = NULL, output_prefix = NULL
    )
    epg_content <- dplyr::select(epg_content,
        model, weather, output_name, run_times
    )
    # Add 6 leading padding spaces to 'run_times' to create the same format as
    # original EnergyPlus.
    epg_content <- dplyr::mutate(epg_content,
        run_times = stringr::str_pad(as.character(run_times), 7L, "left")
    )

    content <- readr::format_csv(epg_content, col_names = FALSE)
    epg_info <- paste(header, content, sep = "\n", collapse = "\n")

    if (!is.null(head_info)) {
        assertthat::assert_that(is.character(head_info))
        head_info <- paste0("! ", head_info, collapse = "\n")
        extra_head <- paste(
            paste0("! Generated by eplusr ", packageVersion("eplusr")),
            "! ================================================================================================",
            "!",
            head_info,
            "!",
            "! ================================================================================================",
            "!",
            sep = "\n", collapse = "\n"
        )

        epg_info <- paste(extra_head, epg_info, "\n", sep = "\n", collapse = "\n")
    }

    readr::write_lines(epg_info, path)

    return(invisible())
}
# }}}1