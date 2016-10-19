## Elective Destinations Reporting Script

## This code queries the Feedback System database, returns user elective destinations by year
## then writes out to CSV. It is intended for use by my colleagues and is unlikely to be useful
## outside our group.

## set the working directory. This is assumed to be the elective_feedback folder in the home
## directory of a linux system. Windows paths are supported.
# setwd("~/elective_feedback/")

## load essential R packages
library(dplyr)
library(RMySQL)
library(ggplot2)
library(ggmap)
library(leafletR)
## create connection to MySQL database. Documentation here:
## https://cran.r-project.org/web/packages/DBI/index.html

feedback_db <- dbConnect(MySQL(),user="",host="",password="",db="")

## execute query on the database using SQL. This retrieves destination address as typed
dbGetQuery(feedback_db, "SET NAMES utf8")

destinations <- dbGetQuery(feedback_db, "SELECT
          user_location as student,
          instance_location as elective_number,
          date_location as year,
          country,
          institution
      FROM (
          SELECT
              an.heraldID AS user_location,
              an.instance AS instance_location,
              LEFT(an.date, 4) as date_location,
              trim(ac.text) as institution
          FROM
              fb.Answers an,
              fb.AnswerComments ac
          WHERE
              an.answerID = ac.answerID
          AND
              an.questionID = 116
          ORDER BY
              date_location, user_location, instance_location, institution
      ) AS tbl_country
      JOIN (
          SELECT 
              an.heraldID AS user_country,
              an.instance AS instance_country,
              LEFT(an.date, 4) as date_country,
              trim(it.title) as country
          FROM
              fb.Answers an,
              fb.AnswerItems ai,
              fb.Items it
          WHERE
              an.answerID = ai.answerID
          AND
              ai.itemID = it.itemID
          AND
              an.questionID = 115
          ORDER BY
              date_country, user_country, instance_country, country
      ) AS tbl_institution
      WHERE 
          tbl_institution.user_country =     tbl_country.user_location
      AND tbl_institution.instance_country = tbl_country.instance_location
      AND tbl_institution.date_country =     tbl_country.date_location
      ;")

## tidy up line endings in retrieved data.
destinations$institution <- gsub("\\r\\n",", ",destinations$institution)

## add destination latitude and longitude. Mutate function from dplyr package adds
## new computed column
mutate(destinations,geocode(destinations$institution, source = "google", output = "latlona"))

## disconnect from the database
dbDisconnect(feedback_db)

## output results to CSV
write.csv(destinations, file = "elective_destinations.csv") #, fileEncoding = "UTF-8")

## reshape the data into a table showing frequency of destination by year
p_destinations <- data.frame(table(destinations$country,destinations$year))

## rename the columns for the reshaped data frame
names(p_destinations) <- c("Country", "Year", "Frequency")

## create a plot showing log of frequency by destination, by year.
## This plot quickly shows up which destinations are regularly visited
print(ggplot(p_destinations, aes(Year, Country)) + geom_point(size = log2(p_destinations$Frequency)))

## create GeoJSON file and then generate Leaflet output

toGeoJSON(data = locations_latlon, name = "elective_destinations", lat.lon = c("lat","lon"))
leaflet(data = "elective_destinations.geojson", title = "Destinations of Elective Students", overwrite = T)

