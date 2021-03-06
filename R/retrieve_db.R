#' @title get_daymet_featureids
#'
#' @description
#' \code{get_daymet_featureids} Queries and retrieves daymet data from postgres database stored in an array format
#'
#' @param con database connection returned from RPostgreSQL::dbConnect
#' @param featureids numeric or character vector of featureids
#' 
#' @return Returns Dreturns data frame of daymet data with columns: [featureid, date, tmax, tmin, prcp, dayl, srad, vp, swe]
#' @details
#' Intended for use with the sheds_new database on the osensei server
#' 
#' @examples
#' 
#' \dontrun{
#' con <- dbConnect(dbDriver("PostgreSQL"), dbname="daymet")
#' 
#' x0 <- get_daymet_featureids(con)                  # throws error: missing featureids
#' x0 <- get_daymet_featureids(con, featureids = "") # returns empty dataframe
#' x1 <- get_daymet_featureids(con, featureids = c(201407698))
#' x2 <- get_daymet_featureids(con, featureids = c(201407698, 201407699))
#' x3 <- get_daymet_featureids(con, featureids = c("201407698", "201407699"))
#' x5 <- get_daymet_featureids(con, featureids = c(201407698, 201407699, 201407700, 201407701, 201407702))
#' dbDisconnect(con)
#' 
#' # ggplot(x2, aes(date, tmin)) +
#' #   geom_line() +
#' #   facet_wrap(~featureid)
#' }
#' @export
get_daymet_featureids <- function(con, featureids) {
  featureids_string <- paste0("{", paste0(featureids, collapse=","), "}")
  
  sql <- paste0("select * from get_daymet_featureids('", featureids_string, "');")
  dbGetQuery(con, sql)
}


# Retrieve data from postgres database
#
# requires working directory
#
# returns three RData files: observed temperature time series, landscape/landuse, and climate data from daymet
#
# usage: $ Rscript derive_metrics.R <input ??? json> <output temperatureData rdata> <output covariateData rdata> <output climateData rdata>
# example: $ Rscript retrieve_db.R ./wd??? ./temperatureData.RData ./covariateData.RData ./climateData.RData
pullData <- function(connection) {
  
  library(jsonlite)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(RPostgreSQL)
  library(ggplot2)
  
# table references
tbl_locations <- tbl(db, 'locations') %>%
  rename(location_id=id, location_name=name, location_description=description) %>%
  select(-created_at, -updated_at)
tbl_agencies <- tbl(db, 'agencies') %>%
  rename(agency_id=id, agency_name=name) %>%
  select(-created_at, -updated_at)
tbl_series <- tbl(db, 'series') %>%
  rename(series_id=id) %>%
  select(-created_at, -updated_at)
tbl_variables <- tbl(db, 'variables') %>%
  rename(variable_id=id, variable_name=name, variable_description=description) %>%
  select(-created_at, -updated_at)
tbl_values <- tbl(db, 'values') %>%
  rename(value_id=id)
tbl_daymet <- tbl(db, 'daymet')
tbl_covariates <- tbl(db, 'covariates')

# list of agencies to keep
# keep_agencies <- c('MADEP', 'MAUSGS')

##### Need way to filter data that has a "yes" QAQC flag

# fetch locations
df_locations <- left_join(tbl_locations, tbl_agencies, by=c('agency_id'='agency_id')) %>%
  # filter(agency_name %in% keep_agencies) %>%
  filter(agency_name != "TEST") %>%
  rename(featureid=catchment_id) %>%
  collect
summary(df_locations)
unique(df_locations$agency_name)

# fetch covariates
df_covariates <- filter(tbl_covariates, featureid %in% df_locations$featureid) %>%
  collect %>%
  spread(variable, value) # convert from long to wide by variable
summary(df_covariates)

# fetch temperature data
df_values <- left_join(tbl_series,
                       dplyr::select(tbl_variables, variable_id, variable_name),
                       by=c('variable_id'='variable_id')) %>%
  dplyr::select(-file_id) %>%
  filter(location_id %in% df_locations$location_id,
         variable_name=="TEMP") %>%
  left_join(tbl_values,
            by=c('series_id'='series_id')) %>%
  collect %>%
  mutate(datetime=with_tz(datetime, tzone='EST'),
         date = as.Date(datetime),
         series_id = as.character(series_id))
summary(df_values)

samples_series_day <- df_values %>%
  dplyr::group_by(series_id, date) %>%
  dplyr::summarise(n_series_day = n())
summary(samples_series_day)

median_samples <- samples_series_day %>%
  dplyr::group_by(series_id) %>%
  dplyr::summarise(median_freq = median(n_series_day), min_n90 = median_freq*0.9)
summary(median_samples)

series_90 <- samples_series_day %>%
  dplyr::left_join(median_samples, by = c("series_id")) %>%
  dplyr::filter(n_series_day > min_n90)
summary(series_90)

foo <- filter(df_values, filter = series_id == 900)
ggplot(foo, aes(datetime, value)) + geom_point()

df_values <- df_values %>%
  left_join(series_90, by = c("series_id", "date")) %>%
  filter(n_series_day > min_n90) 

df_values <- df_values %>%
  group_by(series_id, date, location_id, agency_id) %>%
  filter(flagged == "FALSE") %>%
  filter(variable_name == "TEMP") %>%
  summarise(temp = mean(value), maxTemp = max(value), minTemp = min(value), n_obs = mean(n_series_day))
summary(df_values)

df_locations <- collect(select(tbl_locations, location_id, location_name, latitude, longitude, featureid=catchment_id))

df_agencies <- collect(tbl_agencies)

temperatureData <- df_values %>%
  left_join(df_locations, by = 'location_id') %>%
  left_join(df_agencies, by = 'agency_id') %>%
  select(location_id, agency_name, location_name, latitude, longitude, featureid, date, temp, maxTemp, minTemp, n_obs) %>%
  mutate(agency_name=factor(agency_name),
         location_name=factor(location_name))

# If n_obs = 1, we assume that this is a mean temperature. Therefore the min and max for those days should be NA
# Can't do ifelse with an NA replace in dplyr because it changes the data types
temperatureData <- temperatureData %>%
  mutate(maxTemp = ifelse(minTemp == maxTemp, -9999, maxTemp)) %>%
  mutate(minTemp = ifelse(maxTemp == -9999, -9999, minTemp))

# solution from Hadley - use NA_real_
temperatureData <- temperatureData %>%
  mutate(maxTemp = ifelse(maxTemp > -10 | is.na(maxTemp), maxTemp, NA_real_), 
         minTemp = ifelse(minTemp > -10, minTemp, NA_real_),
         temp = ifelse(temp > -10, temp, NA_real_)
  )

# Need to deal with water temperature between -10 - 0 to decide out of water = NA vs. imperfect or in ice and should = 0

# create temperatureData input dataset
temperatureData <- df_values %>%
summary(temperatureData)

# create covariateData input dataset
covariateData <- left_join(select(df_locations, location_id, location_name, latitude, longitude, featureid),
                           df_covariates,
                           by=c('featureid'='featureid')) %>%
  mutate(location_name=factor(location_name))
summary(covariateData)

# create climateData input dataset
climate <- tbl_daymet %>%
  filter(featureid %in% df_locations$featureid)

climateData <- collect(climate)

####### Do we want to put these in a subfolder?

saveRDS(temperatureData, file=output_file1)
saveRDS(covariateData, file=output_file2)
saveRDS(climateData, file=output_file3)
}
