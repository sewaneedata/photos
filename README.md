# ML inventory of objects in photographs

## Setup 

- You need `admin` credentials from Sewanee DataLab's AWS account in order to work on this rep. Save the `.csv` files provided to you as `credentials/aws_datalab_admin.csv`.  If you don't have credentials, email `datalab@sewanee.edu`. 

- Load the object detection algorithms in the file `yolo3.weights` from [this website.](https://pjreddie.com/media/files/yolov3.weights). Put that file in this repo (it is large: 248 MB). 

- The first time you load packages may be clunky, primarily due to the installation of `tensorflow` and `keras`, the machine-learning packages that power the `platypus` package used in this project.  If you run into issues, open up the file `function-analyze-photo.R` and walk through the code for the `setup_system()` function one row at a time. 


## Important files  

### `function-analyze-photo.R`

This code contains core functions for analyzing a photo. 

- The function **`setup_system()`** is used to load all packages and datasets needed to identify objects in photos. It is called prior to any loop of code that involves analyzing photos.  

- The function **`analyze_photo()`** is the core function that identifies objects in photos and produces outputs (labelled version of image and a tabular summary of results).   

### `function-s3.R`

This file contains all the code for interacting with S3 bucket.  

- The functions **`load_aws_credentials()** and **`inventory_bucket()`** access and inventory the files stored in the 'photos' bucket in Sewanee DataLab's AWS S3 account.  

- The function **`prep_destinations()`** prepares all the filepath versions needed to pass photos and results back and forth between the local shiny directory and the S3 bucket. 

- The function **`analyze_photo_s3()`** is a wrapper for `analyze_photo()`. It downloads an image from S3, analyzes it, and uploads the results back to S3.  

- The function **`analyze_local_photo_s3()`** is a slightly different version of the previous function. This function analyzes a local file and uploads the results *and the original photo file* to the S3 bucket. **Important:** This is the function used in the Shiny app for processing photos.  

- The function **`gather_predictions()`** inventories the S3 bucket for all predictions. It is designed to first check for a local file, `predictions.csv`, in the working directory. If that file exists, it will only add the results on S3 that are not yet in that `csv` (this saves a bunch of time). If that file does not exist, the entire S3 bucket will be inventoried (will take a long time).  

- The function **`gather_image_metadata()`** inventories the S3 bucket for all raw images and stores their metadata (date created, image size, etc.). This function performs the same kind of check as `gather_predictions()` described above: it maintains a local `csv`, and only processes S3 images that are not yet in that local version (saves time).  

 

#### `app.R`

This is the Shiny app.  The app can work without S3 credentials as long as the `checkboxInput` that asks, 
"Only use local data to refresh?" is checked, and there is a `predictions.csv` and an `image_metadata.csv` in your working directory. 



#### Folder `deprecated`

Contains original code from DataLab summer 2021 to ensure that nothing was lost in the major overhaul needed to integrate this project with S3 compatibility. 


