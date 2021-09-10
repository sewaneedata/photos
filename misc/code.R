library(aws.s3)
library(readr)

# Read in credentials
creds <- read_csv('credentials/aws.csv')

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = creds$`Access key ID`,
  "AWS_SECRET_ACCESS_KEY" = creds$`Secret access key`,
  "AWS_DEFAULT_REGION" = "us-east-2"
)

# Get bucket details
get_bucket(bucket = 'sewaneedata')

# Define a directory of photos to upload
photos_directory <- '~/Desktop/photos/'

# Upload photos
if(Sys.info()['user'] == 'joebrew'){
  photos <-dir(photos_directory)
  for(i in 1:length(photos)){
    message(i, ' of ', length(photos))
    this_photo <- photos[i]
    this_path <- file.path(photos_directory, this_photo)
    put_object(
      file = this_path, 
      object = this_photo, 
      bucket = "sewaneedata"
    )
  }
}

# Download a photo
save_object("test1.jpg", file = "itworked.jpg", bucket = "sewaneedata")
'itworked.jpg' %in% dir()
