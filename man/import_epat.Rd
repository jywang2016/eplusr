% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/eplus_read.R
\name{import_epat}
\alias{import_epat}
\title{Import EPAT .json type project}
\usage{
import_epat(json)
}
\arguments{
\item{json}{A file path of a .json file.}
}
\value{
A list containing project info.
}
\description{
\code{import_epat} takes a file path of an .json type project of EPAT, and
return a list containing model paths, weather paths, parametric fields, and
parametric values. The returned list will have an attribute 'job_type' with
value 'epat' which will be used when running jobs using
\link{\code{run_job}}.
}
