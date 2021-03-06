% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/eplus_read.R
\name{read_surf_rpt}
\alias{read_surf_rpt}
\title{Read EnergyPlus Surface Details Report from an .eio file.}
\usage{
read_surf_rpt(eio)
}
\arguments{
\item{eio}{A path of an EnergyPlus .eio output file.}
}
\value{
A data.table containing the Surface Details Report.
}
\description{
\code{read_surf_rpt} takes a file path of EnergyPlus .eio output file as
input, and returns a data.table object which contains the contents of the
report. It is worth noting that you have to add an "Output:Surfaces:List"
object in your model in order to generate an Surface Details Report in the
.eio output file.
}
