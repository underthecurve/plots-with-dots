library(sf)
library(tidyverse)
library(tigris)
library(tidycensus)
options(tigris_use_cache=TRUE)
options(tigris_class="sf")

## References
# https://tarakc02.github.io/dot-density/
# https://www.trafforddatalab.io/info/demographics/ethnicity/index.html
# https://www.cultureofinsight.com/blog/2018/05/02/2018-04-08-multivariate-dot-density-maps-in-r-with-sf-ggplot2/
# http://web.stanford.edu/~cengel/cgi-bin/anthrospace/dot-density-maps-in-r
# https://msu.edu/~kg/nytimes_dotdensity.htm
# https://github.com/mountainMath/dotdensity/blob/master/R/dot-density.R
# https://walkerke.github.io/tidycensus/articles/spatial-data.html

## Inspiration
# https://www.washingtonpost.com/graphics/2018/national/segregation-us-cities/
# https://demographics.coopercenter.org/racial-dot-map
# http://www.radicalcartography.net/index.html?frenchkisses
# https://xkcd.com/1939/
# http://media.apps.chicagotribune.com/chicago-census/less-than-five.html
# https://www.nytimes.com/interactive/2015/07/08/us/census-race-map.html
 
## Get data

census_api_key("YOUR API KEY HERE")

v17 <- load_variables(2017, "acs5", cache = TRUE)

v17 %>% filter(grepl('B03002', name))  %>% as.data.frame()

baltcity <- get_acs("block group", table = "B03002", cache_table = TRUE,
                    geometry = TRUE, state = "24", county = '510',
                    year = 2017)

baltcity <- baltcity %>%
  mutate(cat = case_when(
    #  variable == 'B03002_001' ~ "total",
    variable == 'B03002_003' ~ "white",
    variable == 'B03002_004' ~ "black",
    variable == 'B03002_005' | variable == 'B03002_007' | variable == 'B03002_008' | variable == 'B03002_009' ~ "other",
    variable == 'B03002_006' ~ "asian",
    variable == 'B03002_012' ~ "hisp")) %>% 
  filter(!is.na(cat)) %>% group_by(GEOID, NAME, cat) %>% summarise(estimate = sum(estimate))

## Remove water areas
# https://walkerke.github.io/tidycensus/articles/spatial-data.html

st_erase <- function(x, y) {
  st_difference(x, st_union(st_combine(y)))
}

baltcity_water <- area_water("MD", "Baltimore city", class = "sf")
baltcity_erase <- st_erase(baltcity, baltcity_water)

## Estimate number and location of dots

# random rounding algorithm
# https://github.com/mountainMath/dotdensity/blob/master/R/dot-density.R
random_round <- function(x) {
  v=as.integer(x)
  r=x-v
  test=runif(length(r), 0.0, 1.0)
  add=rep(as.integer(0),length(r))
  add[r>test] <- as.integer(1)
  value=v+add
  ifelse(is.na(value) | value<0,0,value)
  return(value)
}

balcity_split <- baltcity_erase %>%
  split(.$cat)

generate_samples <- function(data) 
  suppressMessages(st_sample(data, size = random_round(data$estimate / 10)))

points <- map(balcity_split, generate_samples)
points <- imap(points, 
               ~st_sf(data_frame(cat = rep(.y, length(.x))),
                      geometry = .x))
points <- do.call(rbind, points)

## Plot

points <- points %>%
  mutate(cat = factor(
    cat,
    levels = c("black", "white",
               "hisp", "asian", "other", "multi")))

plot <- ggplot() + 
  geom_sf(data = points, 
          aes(colour = cat,
              fill = cat), size = .1, alpha = 0.5)  + theme_void() +
  theme(panel.grid.major = element_line(colour = 'transparent')) + 
  scale_color_brewer(type = "qual", palette = 2) + 
  scale_fill_brewer(type = "qual", palette = 2) +
  geom_sf(data = baltcity_water, colour = "#eef7fa", size = .1,
          fill = "#e6f3f7")

ggsave('baltcity_dotplot.pdf', plot, device = 'pdf', width = 8, height = 6)
