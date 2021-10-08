################################################################################
# Functions to analyze a single photo
################################################################################

setup_system <- function(){
  # Install R packages
  if(! 'platypus' %in% installed.packages()){remotes::install_github("maju116/platypus")}
  if(! 'tensorflow' %in% installed.packages()){install.packages('tensorflow')}
  if(! 'keras' %in% installed.packages()){install.packages('keras')}
  if(! 'tidyverse' %in% installed.packages()){install.packages('tidyverse')}
  if(! 'abind' %in% installed.packages()){install.packages('abind')}

  # Load packages
  library(tensorflow)
  library(keras)
  library(tidyverse)
  library(platypus)
  library(abind)

  #install_tensorflow()
  #reticulate::py_config()
  #reticulate::py_install("pillow")

  # Set parameters
  test_yolo <- yolo3(
    net_h = 416, # Input image height. Must be divisible by 32
    net_w = 416, # Input image width. Must be divisible by 32
    grayscale = FALSE, # Should images be loaded as grayscale or RGB
    n_class = 80, # Number of object classes (80 for COCO dataset)
    anchors = coco_anchors # Anchor boxes
  )

  # Load weights
  # Before running the below, download this file
  # into your photos repo: https://pjreddie.com/media/files/yolov3.weights
  test_yolo %>% load_darknet_weights("yolov3.weights")

  return(test_yolo)
}

################################################################################

#img_path <- test_img_path
#to_plot=TRUE
#debug=TRUE
#label_dir=NULL

analyze_photo <- function(img_path,
                          test_yolo,
                          label_dir = NULL,
                          to_img = TRUE,
                          to_plot = FALSE,
                          debug = FALSE){

  if(debug){message('Making predictions ...')}
  test_img <- img_path %>%
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

  if(debug){message('Getting boxes, if any ...')}
  out <- NULL
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
      tibble(path = img_path)
    )

    if(to_img){
      if(debug){message('Producing plot ...')}
      plot_boxes(
        images_paths = img_path, # Images path
        boxes = test_boxes, # Bounding boxes
        correct_hw = TRUE, # Should height and width of bounding boxes be corrected to image height and width
        labels = coco_labels, # Class labels
        save_dir = label_dir,
        plot_images = to_plot
      )
    }
  })

  return(out)

}

################################################################################

