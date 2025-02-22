#' calc_dots
#'
#' A function which calculates the position of number and position
#'     of dots in the final plot for each row of data.
#'
#' credit to Paul Campbell for the function in his blogpost https://www.cultureofinsight.com/blog/2018/05/02/2018-04-08-multivariate-dot-density-maps-in-r-with-sf-ggplot2/
#'
#' @param df the merged df of a shapefile and population data
#' @param col_names a vector of col_names to select from this merged data. If selecting all columns, can leave as NULL
#' @param n_per_dot the number of n people in each category for every dot
#' @param ncores a numeric, number of parallel cores to use for dot sampling. Default set to 1, so no multicore parralelisation. To set to the maximum of cores available use: `parallel::detectCores()`
#' @param col_keep a vector of column names from `df` to bind back to the resulting dots, default NULL 
#' @import sf parallel
#' @importFrom data.table rbindlist
#' @author 
#' Paul Campbell, Robert Hickman
#' @export
#' @examples 
#' \dontrun{
#' london_shapefile <- sf.dotdensity::london_shapefile
#' london_election_data <- sf.dotdensity::london_election_data
#' # get the data to plot
#' # merge a shapefile with the population data
#' london_sf_data <- merge(london_shapefile, london_election_data, by = "ons_id")
#' 
#' #the columns we want to select and plot
#' parties <- names(london_sf_data)[4:8]
#' #set up a colour scale for these if so inclined
#' colours = c("deepskyblue", "red", "gold", "purple", "green")
#' names(colours) = parties
#' 
#' #how many people should lead to one dot
#' people_per_dots <- 1000
#' 
#' #calculate the dot positions for each column
#' london_dots <- calc_dots(df = london_sf_data,
#'                          col_names = parties,
#'                          n_per_dot = people_per_dots,
#'                          col_keep = "constituency_name")
#' }

 
 
calc_dots <- function(df, 
                      col_names, 
                      n_per_dot, 
                      ncores = 1,
                      col_keep = NULL) {
  if(is.null(col_names)) col_names = names(df)
  if(!is.null(col_keep)) {
    stopifnot(col_keep %in% colnames(df))
    df_k <- st_set_geometry(df[,col_keep], NULL)
  }

  # get the numbers of dots for each observation
  num_dots <- as.data.frame(df)
  num_dots <- num_dots[which(names(df) %in% col_names)]

  # round the numbers generated by the division
  num_dots <- num_dots / n_per_dot
  num_dots <- do.call("cbind", lapply(names(num_dots), function(x) {
    data <- random_round(unlist(num_dots[x]))
    df <- data.frame(data)
    names(df) <- x
    return(df)
  }))

  #calculate the position of each dot within the shapefile boundaries
  data <- parallel::mclapply(names(num_dots), function(x) {
    dots_df <- sf::st_sample(df, size = unlist(num_dots[x]), type = "random")
    dots_df <- sf::st_coordinates(st_cast(dots_df, "POINT"))
    dots_df <- as.data.frame(dots_df)
    names(dots_df) <- c("lon", "lat")
    dots_df$variable <- x
    if(!is.null(col_keep)) {
      dots_df <- cbind(dots_df,
                       df_k[rep(seq_len(nrow(df_k)), 
                                times =  unlist(num_dots[x], use.names = F)),]
                       )
    }
    return(dots_df)
  }, mc.cores = ncores)

  #bind this data together and randomly shuffle
  #sf_dots <- do.call("rbind", data) Using data.table should be faster
  sf_dots <-  data.table::rbindlist(data)
  sf_dots <- sf_dots[sample(1:nrow(sf_dots)),]
  return(sf_dots)
}


