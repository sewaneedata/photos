#install.packages("devtools") If devtools is not available
# devtools::install_github("bnosac/image", subdir = "image.darknet", build_vignettes = TRUE)
library(image.darknet)
library(jpeg)
library(Rcpp)
library(png)
library(dplyr)
library(tidyr)
library(here)


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
                          threshold = 0.19)
predictions <- readPNG('predictions.png')
plot(1:2, type='n')

rasterImage(predictions,  1, 1, 2, 2)

# Example done. Now let's functionalize and run through multiple images

# Define functions to capture output
cppFunction('void redir(){FILE* F=freopen("capture.txt","w+",stdout);}')
cppFunction('void resetredir(){FILE* F=freopen("CON","w+",stdout);}')

path <- image_dir <- 'example_images/'

images <- dir(image_dir)

# Save a place to stick labelled images
if(!dir.exists('example_images_labelled')){
  dir.create('example_images_labelled')
}

results_list <- list() # empty list
for(i in 1:length(images)){
  this_image <- file.path(image_dir, images[i])
  redir(); 
  x <- image_darknet_detect(file = this_image, 
                            object = yolo_tiny_voc,
                            threshold = 0.19)
  resetredir();
  # Save the image
  new_image_path <- strsplit(images[i], split = '.', fixed = TRUE)
  new_image_path <- unlist(new_image_path[1])
  new_image_path <- paste0(new_image_path, '.png')
  file.copy('predictions.png',
            file.path('example_images_labelled',
                      new_image_path))
  file.remove('predictions.png')
  # writeLines(readLines('capture.txt'))
  d <- data.frame(txt = unlist(readLines("capture.txt"))) 
  

  ## Take out all the lines that we don't need.
  d <- d %>% 
    filter(!grepl("Boxes", txt)) %>% 
    filter(!grepl("pandoc", txt)) %>% 
    filter(!grepl("unnamed", txt))
  
  ## Find the lines that contain the file names. Make a logical vector called "isfile"
  d$isfile <- grepl(path, d$txt)
  
  ## Take out the path and keep only the file names
  d$txt <- gsub(paste0(path, '/'), "", d$txt)
  
  ## Make a column called file that contains either file names or NA
  d$file <- ifelse(d$isfile, d$txt, NA)
  
  ## All the other lines of text refer to the objects detected
  d$object <- ifelse(!d$isfile, d$txt, NA)
  
  ## Fill down
  d <- tidyr::fill(d, "file")
  
  ## Take out NAs and select the last two columns
  d <- na.omit(d)[, 3:4]
  
  # Separate the text that is held in two parts
  d <- d %>% separate(file, into = c("file", "time"), sep = ":")
  d <- d %>% separate(object, into = c("object", "prob"), sep = ":")
  d <- d %>% filter(!is.na(prob))
  
  # Keep only the prediction time
  d$time <- gsub("Predicted in (.+).$", "\\1", d$time)
  
  # Convert probabilities to numbers
  d$prob <- as.numeric(sub("%", "", d$prob)) / 100
  
  # Optionally remove the file
  file.remove("capture.txt")
  
  # Save the results
  results_list[[i]] <- d
}

# Combine all results
results <- bind_rows(results_list)
