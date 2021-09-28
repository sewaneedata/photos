library(aws.s3)
library(readr)
library(dplyr)

################################################################################
# Setup access to AWS S3 bucket

# Read in credentials
creds <- read_csv('credentials/aws_datalab_student.csv')

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = creds$`Access key ID`,
  "AWS_SECRET_ACCESS_KEY" = creds$`Secret access key`,
  "AWS_DEFAULT_REGION" = "us-east-2"
)


################################################################################
# Inventory bucket

# Get bucket details
bucket <- get_bucket(bucket = 'sewaneedatalab',max = Inf)

# Loop through every element of the bucket and extract information
# in a systematic fashion
n_objects <- length(bucket)
results_list <- list()
for(i in 1:n_objects){
  message(i)
  # Get the individual object
  this_photo <- bucket[[i]]
  # save certain attributes
  photo_df <- tibble(key = this_photo$Key,
                     size = this_photo$Size)
  # Deposit the results into the results_list
  results_list[[i]] <- photo_df
}
# Combine all the objects in results_list into one dataframe
results <- bind_rows(results_list)

# Check it out
head(results)

# Save a csv of the results as our photo index
write_csv(results, 'photo_index.csv')


################################################################################
# Download photos locally

# Now that we have an index of all the photos in the bucket
# We want to SAVE those photos locally on the hard drive
if(!dir.exists('images')){
  message('creating an images folder in ', getwd())
  dir.create('images')
} else {
  message('images folder already exists. not creating one.')
}

# Using the "results" data frame so as to get file info
for(i in 1:nrow(results)){
  message(i , ' of ', nrow(results))
  # capture the row
  this_row <- results[i,]
  # define the local path
  local_path <- file.path('images', this_row$key)
  # see if the file exists already or not
  already_got_it <- file.exists(local_path)
  if(already_got_it){
    message('---', this_row$key, ' already downloaded. Skipping.')
  } else {
    message('---Going to download ', this_row$key)
    save_object(object = this_row$key,
               bucket = bucket,
               file = local_path)
  }

}
