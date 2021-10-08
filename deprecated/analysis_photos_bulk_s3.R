################################################################################
################################################################################
# Bulk process S3 files
################################################################################
################################################################################

source('function-analyze_photo.R') # setup_system(), analyze_photo()
source('function-s3.R')

################################################################################
################################################################################

# Setup system for analyzing photos
# (tensorflow, keras, yolo, etc.)
test_yolo <- setup_system()

# Get contents of AWS S3 bucket
bucket <- inventory_bucket()
head(bucket)

# Limit bucket to files that begin with 'photos'
bucket <- bucket[substr(bucket$file,1,6) == 'photos' ,]
bucket <- bucket[grep('malde',tolower(bucket$file)),]
nrow(bucket)

# Stage results dataframe
results <- data.frame()

# Loop through each file
i=1
for(i in 1880:nrow(bucket)){
  fili <- bucket[i,]
  head(fili)

  result_i <- analyze_photo_s3(bucket_file = fili,
                               test_yolo = test_yolo,
                               to_img = TRUE,
                               to_plot = TRUE,
                               delete_temp = TRUE,
                               debug = FALSE)

  results <- rbind(results, result_i)

  write.csv(results,file='processed_in_s3.csv',quote=FALSE,row.names=FALSE)
  message('File ',i,' out of ',nrow(bucket),' ...')
}



