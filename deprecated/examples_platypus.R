################################################################################
# Setup system

source('function-analyze_photo.R')
setup_system()

################################################################################
# Get image paths

relative_paths <- list.files('images',
                             all.files = TRUE,
                             full.names = TRUE,
                             recursive = TRUE,
                             pattern = 'jpg')

# Uncomment the below if you want to practice on a single image
#relative_paths <- relative_paths[1]

test_img_paths <- file.path(getwd(), relative_paths)


################################################################################
# Establish folders for depositing results

label_dir <- 'images_labelled'
if(!dir.exists(label_dir)){
  dir.create(label_dir)
}

predictions_dir <- 'predictions'
if(!dir.exists(predictions_dir)){
  dir.create(predictions_dir)
}

################################################################################
# Loop through each photo and save the labelled plot

# Create a list for saving results
results_list <- list()

# Loop through each photo and get prediction
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
    # predictions do not exist for this file, so we need to run from scratch

    out <- analyze_photo(test_img_path,
                  label_dir,
                  debug=FALSE,
                  to_img=TRUE,
                  to_plot=TRUE)

    if(!is.null(out)){
      out$path <- relative_paths[i]
      out
      save(out, file = relative_data_path)
    }

    counter <- counter + 1
    results_list[[counter]] <- out
  }
}

results <- bind_rows(results_list)
results
