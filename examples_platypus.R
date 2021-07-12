# remotes::install_github("maju116/platypus")
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


# Before running the below, download this file
# into your photos repo: https://pjreddie.com/media/files/yolov3.weights
test_yolo %>% load_darknet_weights("yolov3.weights")

test_img_paths <- list.files(system.file("extdata", "images", package = "platypus"), full.names = TRUE, pattern = "coco")
test_img_paths <- list.files('example_images',
                             full.names = TRUE,
                             pattern = 'jpg')

# install_tensorflow() 
# reticulate::py_config()
# reticulate::py_install("pillow")
test_imgs <- test_img_paths %>%
  map(~ {
    image_load(., target_size = c(416, 416), grayscale = FALSE) %>%
      image_to_array() %>%
      `/`(255)
  }) %>%
  abind(along = 4) %>%
  aperm(c(4, 1:3))
test_preds <- test_yolo %>% predict(test_imgs)

# Take a peak at the predictions
str(test_preds)

test_boxes <- get_boxes(
  preds = test_preds, # Raw predictions form YOLOv3 model
  anchors = coco_anchors, # Anchor boxes
  labels = coco_labels, # Class labels
  obj_threshold = 0.6, # Object threshold
  nms = TRUE, # Should non-max suppression be applied
  nms_threshold = 0.6, # Non-max suppression threshold
  correct_hw = FALSE # Should height and width of bounding boxes be corrected to image height and width
)

# Take a look at the bounding boxes
test_boxes


plot_boxes(
  images_paths = test_img_paths, # Images paths
  boxes = test_boxes, # Bounding boxes
  correct_hw = TRUE, # Should height and width of bounding boxes be corrected to image height and width
  labels = coco_labels # Class labels
)

# Got here? Great. Look here for how to do this on your own custom data:
# https://github.com/maju116/platypus#yolov3-object-detection-with-custom-dataset