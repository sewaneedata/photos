################################################################################
# Setup system

# remotes::install_github("maju116/platypus")
library(tensorflow)
library(keras)
# library(reticulate)
if (Sys.info()["user"]=="hieungannguyen"){
  use_python("~/miniforge3/bin/python")
  use_condaenv("tf_env")
}
library(tidyverse)
library(platypus)
library(abind)

test_yolo <- yolo3(
  net_h = 416, # Input image height. Must be divisible by 32
  net_w = 416, # Input image width. Must be divisible by 32
  grayscale = FALSE, # Should images be loaded as grayscale or RGB
  n_class = 80, # Number of object classes (80 for COCO dataset)
  anchors = coco_anchors # Anchor boxes
)

################################################################################

# Before running the below, download this file
# into your photos repo: https://pjreddie.com/media/files/yolov3.weights
test_yolo %>% load_darknet_weights("yolov3.weights")

# Uncomment the below
relative_paths <- list.files('images',
                             all.files = TRUE,
                             full.names = TRUE,
                             recursive = TRUE,
                             pattern = 'jpg')

# # Comment out the below (once you have confirmed it works)
# relative_paths <- c(
#   "images/Malde_Images/SDI_Haiti_Trial-2/20160813-P1080496.jpg",
#   "images/Malde_Images/SDI_Haiti_Trial-2/20160813-P1080497.jpg"
# )

test_img_paths <- file.path(getwd(), relative_paths)
# install_tensorflow()
# reticulate::py_config()
# reticulate::py_install("pillow")

################################################################################

# Loop through each photo and save the labelled plot
label_dir <- 'images_labelled'
if(!dir.exists(label_dir)){
  dir.create(label_dir)
}
predictions_dir <- 'predictions'
if(!dir.exists(predictions_dir)){
  dir.create(predictions_dir)
}

# Create a list for saving results
results_list <- list()

# loop through each photo and get prediction
counter <- 0
for(i in 1:length(test_img_paths)){
  message('Plotting ', i, ' of ', length(test_img_paths))


  # Get the specific path
  test_img_path <- test_img_paths[i]

  # Get the relative path
  relative_path <- relative_paths[i]

  # Transform the relative path into a file name which is compatible
  # with data (instead of photo)
  relative_data_path <- file.path(predictions_dir, paste0(unlist(lapply(strsplit(relative_path, split = '.', fixed = TRUE), function(x){x[1]})), '.RData'))
  relative_data_path <- gsub('/', '&&&', relative_data_path)
  relative_data_path <- gsub('predictions&&&', 'predictions/', relative_data_path)
  already_exists <- file.exists(relative_data_path)

  if(already_exists){
    load(relative_data_path)
  } else {
    # predictions do not exist for this file, we need to run from scratch

    test_img <- test_img_path %>%
      map(~ {
        image_load(., target_size = c(416, 416), grayscale = FALSE) %>%
          image_to_array() %>%
          `/`(255)
      }) %>%
      abind(along = 4) %>%
      aperm(c(4, 1:3))
    test_preds <- test_yolo %>% predict(test_img)

    # # Take a peak at the predictions
    # str(test_preds)

    try({
      test_boxes <- get_boxes(
        preds = test_preds, # Raw predictions form YOLOv3 model
        anchors = coco_anchors, # Anchor boxes
        labels = coco_labels, # Class labels
        obj_threshold = 0.6, # Object threshold
        nms = TRUE, # Should non-max suppression be applied
        nms_threshold = 0.6, # Non-max suppression threshold
        correct_hw = FALSE # Should height and width of bounding boxes be corrected to image height and width
      )
      # Save the results in the results list
      these_results <- test_boxes[[1]]
      out <- bind_cols(
        these_results,
        tibble(path = relative_paths[i])
      )
      # save the prediction
      save(out, file = relative_data_path)

      plot_boxes(
        images_paths = test_img_path, # Images paths
        boxes = test_boxes,#list(test_boxes), # Bounding boxes
        correct_hw = TRUE, # Should height and width of bounding boxes be corrected to image height and width
        labels = coco_labels, # Class labels
        save_dir = label_dir,
        plot_images = TRUE
      )
    })

    counter <- counter + 1
    results_list[[counter]] <- out

  }
}
  results <- bind_rows(results_list)

  image_files <- list.files ("images", full.names = TRUE, recursive = TRUE, all.files = TRUE)
list <- read_exif(image_files, tags = c("filename", "imagesize", "DateTimeOriginal", "ImageSize", "ImageWidth", "ImageHeight"), quiet = FALSE)
  merged_meta <- merge(results, list, by.x = 'path', by.y = 'SourceFile')

  merged_meta <- merged_meta %>% mutate (year = substr(DateTimeOriginal, 1, 4),
                                       month = substr(DateTimeOriginal, 6, 7),
                                       day = substr(DateTimeOriginal, 9, 10), 
                                       time = substr(DateTimeOriginal, 12, 16))

  # There was some kind of error in the images meta that listed 2015 files as 2051, this should correct it
  merged_meta$year[merged_meta$year == 2051] <- 2015
  
  data <- merged_meta %>%
          group_by(year, label) %>%
          tally
  # Isolating Haiti files from the mix of Haiti and Rock Art files produced 
  merged_meta_haiti_only <- merged_meta %>% 
                            filter(!grepl('ALV', FileName))
  
  # Careful with the path below, make sure you change it as necessary to your working directory
  write_csv(overview, '~/Documents/tutorial/data.csv')


  # Got here? Great. Look here for how to do this on your own custom data:
  # https://github.com/maju116/platypus#yolov3-object-detection-with-custom-dataset
