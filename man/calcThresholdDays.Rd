% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Derive_Metrics.R
\name{calcThresholdDays}
\alias{calcThresholdDays}
\title{calcThresholdDays}
\usage{
calcThresholdDays(grouped.df, derived.df, temp.threshold, summer = FALSE)
}
\arguments{
\item{grouped.df}{Dataframe grouped by featureid then year}

\item{derived.df}{Dataframe of derived metrics}

\item{temp.threshold}{Optional numeric temperature threshold value in degrees C}
}
\value{
Returns Dataframe of derived metrics (e.g. max temperature predicted over daymet record) for each featureid across all years
}
\description{
\code{calcThresholdDays} Calculates the median number of days per year that a stream is predicted to exceed a threshold temperature
}
\details{
blah, blah, blah, something, something
}
\examples{

\dontrun{

}
}

