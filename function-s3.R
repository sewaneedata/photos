################################################################################
# Photo inventory using S3 only

library(aws.s3)
library(readr)
library(dplyr)
library(exifr)
library(exiftoolr)

source('function-analyze_photo.R') # setup_system(), analyze_photo()


################################################################################
################################################################################
################################################################################
# Setup access to AWS S3 bucket

load_aws_credentials <- function(){
  # Read in credentials
  suppressMessages({
    #creds <- read_csv('credentials/aws_datalab_student.csv', progress=FALSE)
    creds <- read_csv('credentials/aws_datalab_admin.csv', progress=FALSE)
  })

  Sys.setenv(
    "AWS_ACCESS_KEY_ID" = creds$`Access key ID`,
    "AWS_SECRET_ACCESS_KEY" = creds$`Secret access key`,
    "AWS_DEFAULT_REGION" = "us-east-2"
  )

  }

################################################################################
################################################################################
################################################################################
# Inventory S3 bucket

inventory_bucket <- function(){
  load_aws_credentials()

  # Get bucket details
  bucket <- get_bucket(bucket = 'sewaneedatalab', max = Inf)

  # Summarize in a dataframe
  df <- data.frame(file=sapply(bucket,'[[',1),
                   uploaded=sapply(bucket,'[[',2),
                   size=sapply(bucket,'[[',4))
  head(df)

  return(df)
}


################################################################################
################################################################################
################################################################################
# Prepare destinations for each file in bucket

prep_destinations <- function(bucket){

  # Establish base path name
  base_path <- gsub('photos/','',bucket$file) ; head(base_path)

  # Establish destination for processed image
  proc_img_path <- paste0('photos/processed/images/',base_path)

  # Establish destination for prediction results
  safe_path <- gsub('/','&&&',base_path) ; head(safe_path)
  safe_path <- paste0(unlist(lapply(strsplit(safe_path,
                                             split = '.',
                                             fixed = TRUE),
                                    function(x){x[1]})),
                      '.RData')
  proc_results_path <- paste0('photos/processed/results/',safe_path)
  head(proc_results_path)

  # Add columns to bucket df
  bucket$base_path <- base_path
  bucket$proc_img_path <- proc_img_path
  bucket$safe_path <- safe_path
  bucket$proc_results_path <- proc_results_path
  head(bucket)

  return(bucket)
}

################################################################################
################################################################################
################################################################################
# Download 10 images

download_image_batch <- function(n_images=10,
         page_i = 1,
         verbose=TRUE){

  #n_images=10
  #page_i=1
  #verbose=TRUE
  #download_image_batch(n_images, page_i)

  # Stage tmp directory
  tmp_dir <- tempdir()
  img_dir <- paste0(tmp_dir,'/img_gallery/')
  if(dir.exists(img_dir)){unlink(img_dir,recursive=TRUE)}
  dir.create(img_dir)

  # Inventorying files
  if(verbose){message('Inventorying processed photographs on AWS S3 ...')}
  s3files <- inventory_bucket()
  procfiles <- s3files[grep('processed/images',s3files$file),]
  procfiles <- procfiles[grep('malde',tolower(procfiles$file)),]
  procfiles <- procfiles[-grep('-2.jpg',tolower(procfiles$file)),]
  #procfiles <- procfiles[-grep('RData',procfiles$file),]
  procfiles <- procfiles[rev(order(procfiles$uploaded)),]
  procfiles %>% head(20)

  starti <- (page_i - 1)*n_images + 1
  endi <- (page_i - 1)*n_images + n_images

  # make sure starti and endi are not longer than number of files
  if(starti > nrow(procfiles)){
    starti <- 1
    endi <- n_images
  }else{
    if(endi > nrow(procfiles)){
      endi <- nrow(procfiles)
    }
  }

  starti
  endi
  if(verbose){message('Downloading images for viewing ...')}
  i=10
  imgfiles <- c()
  for(i in starti:endi){
    if(verbose){message('--- image ',i,' ...')}
    fili <- procfiles$file[i] ; fili
    filecore <- gsub('photos/processed/images/','',fili)
    filecore <- gsub('/','&&&',filecore)
    imgfiles <- c(imgfiles, filecore)
    local_path <- paste0(img_dir,'/',filecore)
    local_path
    save_object(object = fili,
                bucket = 'sewaneedatalab',
                file = local_path)
  }

  dir(img_dir)
  imgfiles

  return(list(tmp = img_dir,
              img = imgfiles))
}

################################################################################
################################################################################
################################################################################
# Process a photo from s3

analyze_photo_s3 <- function(bucket_file,
                             test_yolo,
                             to_img=TRUE,
                             to_plot=TRUE,
                             delete_temp=TRUE,
                             debug=TRUE){

  if(debug){message('Loading credentials ...')}
  load_aws_credentials()

  if(debug){message('Preparing destination paths ...')}
  #bucket_file <- bucket[1,]
  fili <- prep_destinations(bucket_file)

  # Prepare working folders
  if(debug){message('Creating temp folders, if needed ...')}
  if(! dir.exists('temp')){dir.create('temp')}
  if(! dir.exists('temp/labelled')){dir.create('temp/labelled')}

  if(debug){message('Preparing local filenames ...')}
  this_file_type <- strsplit(fili$file,'.',fixed=TRUE)[[1]][2]
  local_path <- paste0('temp/current_image.',this_file_type) ; local_path
  local_label_path <- paste0('temp/labelled/current_image.',this_file_type) ; local_label_path

  # Download object locally, temporarily
  if(debug){message('Downloading the image to a temporary local file ...')}
  save_object(object = fili$file,
              bucket = 'sewaneedatalab',
              file = local_path)

  # Analyze
  if(debug){message('Analyzing photo ...')}
  out <- analyze_photo(img_path = local_path,
                       test_yolo = test_yolo,
                       label_dir = 'temp/labelled/',
                       debug=debug,
                       to_img=to_img,
                       to_plot=to_plot)

  # Upload result
  dfi <- fili
  local_results <- 'temp/results.RData'
  if(!is.null(out)){

    # Save locally
    if(debug){message('Saving result to a local temp file ...')}
    save(out,file=local_results)

    # Upload RData to S3
    if(file.exists(local_results)){
      if(debug){message('Uploading table results to AWS S3 ...')}
      put_object(file=local_results,
               object=fili$proc_results_path,
               bucket='sewaneedatalab')
    }

    # Upload results image to to S3
    if(file.exists(local_label_path)){
      if(debug){message('Uploading labelled image to AWS S3 ...')}
      put_object(file=local_label_path,
                 object=fili$proc_img_path,
                 bucket='sewaneedatalab')
    }

    # Test that upload worked
    #save_object(object = fili$proc_img_path,
    #            bucket = 'sewaneedatalab',
    #            file = 'temp/confirm_labels.jpg')

    # Add to local dataframe
    out$path <- NULL

  }else{
    out <- data.frame(xmin=NA,ymin=NA,xmax=NA,ymax=NA,p_obj=NA,label_id=NA,label=NA)
  }
  dfi <- data.frame(fili,out)

  # Delete local files
  if(delete_temp){
    if(debug){message('Cleaning up ...')}

    # temp/current_image.jpg
    if(file.exists(local_path)){file.remove(local_path)}

    # temp/results.RData
    if(file.exists(local_results)){file.remove(local_results)}

    # temp/labelled/current_image.jpg
    if(file.exists(local_label_path)){file.remove(local_label_path)}

    # temp/confirm_labels.jpg
    if(file.exists('temp/confirm_labels.jpg')){file.remove('temp/confirm_labels.jpg')}
  }

  if(debug){message('Finished!')}
  return(dfi)
}

################################################################################
################################################################################
# Process a ***local*** photo and send result to S3

#local_file <- local_files <- '/Users/erickeen/Desktop/090519_2892.jpg'
#analyze_local_photo_s3(local_files)

# local_files is a dataframe resulting from fileInput in shiny

analyze_local_photo_s3 <- function(local_files,
                             test_yolo,
                             to_img=TRUE,
                             to_plot=TRUE,
                             delete_temp=TRUE,
                             debug=TRUE){

  if(debug){message('Setting up system for ML analysis ...')}
  test_yolo <- setup_system()

  if(debug){message('Loading AWS S3 credentials ...')}
  load_aws_credentials()

  if(debug){message('Inventorying files in S3 bucket ...')}
  bucket <- inventory_bucket()

  # Stage results
  df <- data.frame()

  if(debug){message('Looping through each file ...')}
  for(i in 1:nrow(local_files)){
    #print(local_files)
    local_file_i <- local_files[i,]
    #print(local_file_i)
    local_file <- local_file_i$datapath
    real_name <- local_file_i$name
    #print(local_file)
    #print(real_name)

    if(debug){message(paste0(real_name,' :: Image ',i,' out of ',nrow(local_files),' ...'))}

    if(debug){message('Preparing filepaths ...')}
    # Get file extension
    this_file_type <- strsplit(local_file,'.',fixed=TRUE)[[1]][2]
    this_file_type

    # Prepare temp directory
    tmp_dir <- tempdir()
    tmp_labelled_dir <- paste0(tmp_dir,'/labelled')
    if(!dir.exists(tmp_labelled_dir)){dir.create(tmp_labelled_dir)}

    # Prepare results paths
    safe_path <- gsub('/','&&&',local_file) ; head(safe_path)
    safe_core <- strsplit(safe_path,'.',fixed=TRUE)[[1]][1] ; safe_core

    real_safe_path <- gsub('/','&&&',real_name) ; head(real_safe_path)
    real_safe_core <- strsplit(real_safe_path,'.',fixed=TRUE)[[1]][1] ; real_safe_core
    s3_raw_path <- paste0('photos/shiny/',real_safe_core,'.',this_file_type)

    tmp_labelled_path <- paste0(safe_core,'.',this_file_type) ; tmp_labelled_path
    dir_paths <- strsplit(local_file,'/',fixed=TRUE)[[1]]
    tmp_labelled_path <- paste0(tmp_labelled_dir,'/',dir_paths[length(dir_paths)]) ; tmp_labelled_path
    s3_labelled_path <- paste0('photos/processed/images/',real_safe_core,'.',this_file_type) ; s3_labelled_path

    tmp_results_path <- paste0(safe_core,'.RData') ; tmp_results_path
    s3_results_path <-  paste0('photos/processed/results/',real_safe_core,'.RData') ; s3_results_path

    # Check to see if this photo has already been analyzed and uploaded to S3
    if(s3_results_path %in% bucket$file){
      if(debug){message('Results for this file are already on AWS S3 drive. Not re-running -- stopping here.')}
      dfi <- NULL
    }else{
      if(debug){message('Results for this file not found on AWS S3. Going to analyze ...')}

      # Analyze
      if(debug){message('Analyzing photo ...')}
      out <- analyze_photo(img_path = local_file,
                           test_yolo = test_yolo,
                           label_dir = tmp_labelled_dir,
                           debug=debug,
                           to_img=to_img,
                           to_plot=to_plot)
      out

      if(is.null(out)){
        message('No objects found! Not returning a labelled image.')
        out <- data.frame(xmin=NA,ymin=NA,xmax=NA,ymax=NA,p_obj=NA,label_id=NA,label=NA)
      }else{
        if(file.exists(tmp_labelled_path)){
          if(debug){message('Uploading labelled image to AWS S3 ...')}
          put_object(file=tmp_labelled_path,
                     object=s3_labelled_path,
                     bucket='sewaneedatalab')
        }
      }

      out
      out$path <- NULL
      out$file <- local_file
      out$label_img <- tmp_labelled_path

      if(debug){message('Saving result(s) to a local temp file ...')}
      save(out,file=tmp_results_path)

      if(file.exists(tmp_results_path)){
        if(debug){message('Uploading table results to AWS S3 ...')}
        put_object(file=tmp_results_path,
                   object=s3_results_path,
                   bucket='sewaneedatalab')
      }

      if(file.exists(local_file)){
        if(debug){message('Uploading raw image to S3 too ...')}
        put_object(file=local_file,
                   object=s3_raw_path,
                   bucket='sewaneedatalab')
      }

      #dfi <- data.frame(file=local_file,out)
      dfi <- out
    } # end of if results file already exists

    df <- rbind(df,dfi)
  } # end of for loop through files

  if(debug){message('Finished!')}
  return(df)
}


################################################################################
################################################################################
################################################################################

gather_predictions <- function(local_only=FALSE){

  # Get current list of predictions
  if(file.exists('predictions.csv')){
    message('predictions.csv already exists ...')
    predictions <- read.csv('predictions.csv')
  }else{
    predictions <- data.frame()
  }

  # Staging final result
  tot_predictions <- predictions

  if(!local_only){

    message('Inventorying predictions currently in S3 bucket...')
    df <- inventory_bucket()
    head(df)

    # Get the list of all predictions in the S3 predictions folder
    preds <- df[grep('results',df$file),]
    preds <- preds[grep('malde',tolower(preds$file)),]
    head(preds)
    nrow(preds)

    # Ask which predictions are not yet local
    predictions
    not_yet_downloaded <- which(! preds$file %in% predictions$file)
    not_yet_downloaded

    if(length(not_yet_downloaded)>0){
      message('Need to download some new predictions ...')

      preds_to_download <- preds[not_yet_downloaded,]

      results_list <- list()
      local_path <- 'temp/downloaded_result.RData'
      i=1

      # Loop through each of the prediction files and read into memory
      for(i in 1:nrow(preds_to_download)){
        message(i,' out of ',nrow(preds_to_download),' ...')
        save_object(object = preds_to_download$file[i],
                    bucket = 'sewaneedatalab',
                    file = local_path)
        load(local_path)
        out$file <- preds_to_download$file[i]
        print(out)
        results_list[[i]] <- out
        file.remove(local_path)
      }

      head(predictions)
      predictions$path <- NULL

      # Add these new predictions to the existing list
      new_predictions <- bind_rows(results_list)
      if(! 'label_img' %in% names(predictions)){predictions$label_img <- NA}
      tot_predictions <- rbind(predictions, new_predictions)

      # Update the list on file
      write.csv(tot_predictions,'predictions.csv',row.names=FALSE,quote=FALSE)
    }else{
      message('No new predictions found. Returning current file ...')
    }
  }else{
    message('Running locally only -- not checking AWS S3 for new photos or predictions')
  }
  return(tot_predictions)
}


################################################################################
################################################################################
################################################################################
# Simple metadata retrieval function

retrieve_metadata <- function(local_path){
  this_meta <- read_exif(local_path, tags = c("filename", "imagesize", "DateTimeOriginal", "ImageSize", "ImageWidth", "ImageHeight"), quiet = TRUE)
  this_meta$FileName <- local_path
  this_meta

  if('DateTimeOriginal' %in% names(this_meta)){
    this_meta <- this_meta %>% mutate (year = substr(DateTimeOriginal, 1, 4),
                                       month = substr(DateTimeOriginal, 6, 7),
                                       day = substr(DateTimeOriginal, 9, 10),
                                       time = substr(DateTimeOriginal, 12, 16))
    #glimpse(this_meta)
    if(this_meta$year == 2051){this_meta$year <- 2015}
  }

  return(this_meta)
}

################################################################################
################################################################################
################################################################################

gather_image_metadata <- function(local_only=FALSE){

  # Get current table of image metadata
  if(file.exists('image_metadata.csv')){
    message('image_metadata.csv already exists. Starting with existing file ...')
    meta <- read.csv('image_metadata.csv')
  }else{
    message('image_metadata.csv not found in working directory. Creating new file ...')
    meta <- data.frame()
  }

  # Stage the final result
  tot_meta <- meta

  if(!local_only){

    message('Inventorying predictions currently in S3 bucket...')
    df <- inventory_bucket()
    head(df)

    # Filter photos list to only those we want
    nrow(df)
    img <- df[- grep('results',df$file),] ; nrow(img) # remove results files
    img <- img[- grep('processed',img$file),] ; nrow(img) # remove processed photos (showing boxes)
    img <- img[grep('malde',tolower(img$file)),] ; nrow(img) # only use malde photos
    img <- img[!is.na(img$file),] ; nrow(img) # make sure there is a valid filename

    # Ask which predictions are not yet local
    meta
    not_yet_downloaded <- which(! img$file %in% meta$FileName)
    not_yet_downloaded

    if(length(not_yet_downloaded)>0){
      message('Need to download metadata for new photos ...')

      img_to_download <- img[not_yet_downloaded,]
      img_to_download <- img_to_download[!is.na(img_to_download$file),]
      nrow(img_to_download)

      results <- data.frame()
      i=1

      # Loop through each of the prediction files and read into memory
      for(i in 1:nrow(img_to_download)){
        message(i,' out of ',nrow(img_to_download),' ...')

        this_file <- img_to_download$file[i]
        this_file

        this_file_type <- strsplit(this_file,'.',fixed=TRUE)[[1]][2]
        local_path <- paste0('temp/current_image.',this_file_type) ; local_path

        try(save_object(object = this_file,
                        bucket = 'sewaneedatalab',
                        file = local_path))

        if(file.exists(local_path)){
          this_meta <- retrieve_metadata(local_path)
          this_meta
          #glimpse(this_meta)
          if('DateTimeOriginal' %in% names(this_meta)){
            results <- rbind(results,this_meta)
          }
          file.remove(local_path)
        }else{
          message('Photo does not exist in S3 -- or at least cannot be downloaded. Skipping and moving on!')
        } # end of if file exists
      }

      # Add these new predictions to the existing list
      results
      #glimpse(results)

      tot_meta <- rbind(meta, results)
      tail(tot_meta)

      # Update the list on file
      write.csv(tot_meta,'image_metadata.csv',row.names=FALSE,quote=FALSE)
    }else{
      message('No new images need inventorying. Returning current file of metadata ...')
    }
    }else{
      message('Running locally only -- not checking AWS S3 for new photos or predictions')
    }

  message('Finished!')
  return(tot_meta)

}
