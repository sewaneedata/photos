setwd('~/Documents/photos/')
library(dplyr)
library(readr)
library(ggplot2)

# Get the list of all predictions in the predictions folder
preds <- dir('predictions/')

results_list <- list()
# Loop through each of the prediction files and read into memory
for(i in 1:length(preds)){
  message(i)
  file_path <- file.path('predictions', preds[i])
  load(file_path)
  results_list[[i]] <- out
}
predictions <- bind_rows(results_list)

# Silly example: prevalence of different objects
pd <- predictions %>%
  group_by(label) %>%
  tally %>%
  arrange(desc(n))
pd
