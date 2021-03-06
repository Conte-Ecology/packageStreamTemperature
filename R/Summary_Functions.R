#' @title rmse: root mean squared error
#'
#' @description
#' \code{rmse} returns root mean squared error
#'
#'@param error Vector of residual error from a model
#' @details
#' var: blah, blah, blah
#' value: something, something
#' @export
rmse <- function(error, na.rm = T) {
  sqrt(mean(error^2, na.rm = T))
}


#' @title nse: Nash-Sutcliffe Efficiency
#'
#' @description
#' \code{nse} returns Nash-Sutcliffe Efficiency coefficient
#'
#' @param obs numeric vector of observed values
#' @param pred numeric vector of predicted values with the same length as obs
#' @param warn logical whether to print or supress the warning message when NSE not calculated
#' @details
#' var: blah, blah, blah
#' value: something, something
#' @export
nse <- function(obs, pred, warn = FALSE) {
  denom <- sum((obs - mean(obs, na.rm = TRUE))^2, na.rm = TRUE)
  if (denom != 0) {
    NSE <- 1 - (sum((obs - pred)^2, na.rm = TRUE)/denom)
  }
  else {
    NSE <- NA_real_
    if(warn) warning("Division by 0, cannot calculate NSE")
  }
  return(NSE)
}



#' @title mae: mean absolute error
#'
#' @description
#' \code{mae} returns mean absolute error
#'
#'@param error Vector of residual error from a model
#' @details
#' var: blah, blah, blah
#' value: something, something
#' @export
mae <- function(error, na.rm = T) {
  mean(abs(error), na.rm = T)
}


#' @title avgCoefs: Calculate the mean coefficient estimates from the MCMC iterations
#'
#' @description
#' \code{avgCoefs} returns a dplyr tbl_df with the mean, sd, and 95% credible intervals for each parameter
#'
#'@param ggs.obj An object generated with the ggmcmc::ggs() function that organizes the jags output mcmc.list
#'@param family Optional character string specifying the subset of the parameters to average (e.g. "B.0" for parameters B.0[1], B.0[2], B.0[3], etc.)
#' @details
#' blah, blah, blah
#' @export
avgCoefs <- function(ggs.obj, family = NULL) {
  #detach("package:ggmcmc", unload = TRUE)
  require(dplyr)
  if(class(family) == "character") {
    means <- ggs.obj %>%
      group_by(Parameter = Parameter) %>%
      filter(grepl(paste0('^', family), Parameter)) %>%
      dplyr::summarise(mean=mean(value), sd=sd(value), qLo=quantile(value,probs=c(0.025)),qHi=quantile(value,probs=c(0.975)))
  } else {
    means <- ggs.obj %>%
      group_by(Parameter = Parameter) %>%
      dplyr::summarise(mean=mean(value), sd=sd(value), qLo=quantile(value,probs=c(0.025)),qHi=quantile(value,probs=c(0.975)))
  }
  return(means)
}


#' @title nameCoefs: Match names of coefficients to the parameter names generated by coda
#'
#' @description
#' \code{nameCoefs} returns a dataframe of the coefficient summary plus the original names
#'
#' @param coef.summary Dataframe generated with the avgCoefs function
#' @param rand.levels Levels of the random effects factor (e.g. levels(as.factor(data$site)))
#' @param family Character string of the coda group names to match to the original names (e.g. "B.site")
#' @param conditional Logical if true match the names to the conditional (specific) estimates for the random effects. If false match the names with the mean summary effects.
#' @param form Formula object used for fitting the random effects indicated in family (e.g. formulae$site.form)
#' @param name Optional character string to rename the coefficient name column
#' @details
#' var: blah, blah, blah
#' value: something, something
#' coefs <- colnames(data.cal$data.random.sites)
#' @export
nameCoefs <- function (coef.summary, rand.levels, family, conditional = TRUE, form = NULL, name = NULL, coefs = NULL) {
    if(conditional) {
      if(class(coefs) == "character") {
    B.mean <- dplyr::filter(coef.summary, grepl(paste0('^',family), coef.summary$Parameter))
    
    B.mean$index <- as.numeric(sub(".*?([0-9]+),([0-9]).", replacement = "\\1", B.mean$Parameter))
    B.mean$index2 <- as.numeric(sub(".*?([0-9]+),([0-9]).", replacement = "\\2", B.mean$Parameter))
    
    df <- data.frame(rand.levels, index = 1:length(rand.levels))
    if(class(name) == "character") {
      names(df) <- c(name, "index")
    } else {
      names(df) <- c(family, "index")
    }
    df.coef <- data.frame(coef = coefs, index2 = 1:length(coefs))
    
    B.mean <- dplyr::left_join(B.mean, df, by = "index")
    B.mean <- dplyr::left_join(B.mean, df.coef, by = "index2")
  } else {
    B.mean <- dplyr::filter(coef.summary, grepl(paste0('^',family), coef.summary$Parameter))
    
    B.mean$index <- as.numeric(sub(".*?([0-9]+).", replacement = "\\1", B.mean$Parameter))
    
    df <- data.frame(rand.levels, index = 1:length(rand.levels))
    if(class(name) == "character") {
      names(df) <- c(name, "index")
      } else {
        names(df) <- c(family, "index")
      }
    
    # recombine to link year and index number of the year
    B.mean <- dplyr::left_join(B.mean, df, by = "index")
  }
  
    } else {
      B.mean <- dplyr::filter(coef.summary, grepl(paste0('^',family), coef.summary$Parameter))
      
      B.mean$index <- as.numeric(sub(".*?([0-9]+).", replacement = "\\1", B.mean$Parameter))
      
      df.coef <- data.frame(coef = coefs, index2 = 1:length(coefs))
      if(class(name) == "character") {
        names(df.coef) <- c(name, "index")
      } else {
        names(df.coef) <- c(family, "index")
      }
      
      # recombine to link year and index number of the year
      B.mean <- dplyr::left_join(B.mean, df.coef, by = "index")
    }
  return(B.mean)
}





