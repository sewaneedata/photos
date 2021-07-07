#install.packages("devtools") If devtools is not available
# devtools::install_github("bnosac/image", subdir = "image.darknet", build_vignettes = TRUE)
library(image.darknet)
library(jpeg)


yolo_tiny_voc <- image_darknet_model(type = 'detect', 
                                     model = 'tiny-yolo-voc.cfg', 
                                     weights = system.file(package='image.darknet', 'models', 'tiny-yolo-voc.weights'), 
                                     labels = system.file(package='image.darknet', 'include', 'darknet', 'data', 'voc.names'))


# Define an image and predict on it
this_image <- "example_images/haiti1.jpg"
img <- readJPEG(this_image)
plot(1:2, type='n')

rasterImage(img,  1, 1, 2, 2)

x <- image_darknet_detect(file = this_image, 
                          object = yolo_tiny_voc,
                          threshold = 0.2)
library(png)
predictions <- readPNG('predictions.png')
plot(1:2, type='n')

rasterImage(predictions,  1, 1, 2, 2)

