# Using the `sewaneedata` S3 bucket

- You need credentials. Save the `.csv` provided to you as `credentials/aws.csv`. 
- If you don't have credentials, email `sewanee@databrew.cc`. 



- 00_read_data.R: This file reads the credentials for the Amazon bucket where the files are stored. 


- example_platypus.R: This file use Platypus to run predictions on the files/photos in question (after they are pulled from the aws bucket). The username in line 5 should be changed to your computer's username. After running predictions, images are labelled with predictions bounding boxes and saved to a folder called "images_labelled". You should go ahead and create this folder in the same directory where the photos are stored on your local drive. Subsequently, create a "predictions" folder in that same directory, this is where each photo's predicitons will be saved.


- analysis.R: This file pulls the predicitons from the predicitons folder's metadata into a table that is used for analysis of all the predictions.


- photos_shiny_app.R: This file creates a shiny app dashboard and uses the output of analysis.R to collect all labeled items. "data.csv" in lines 15 should be replaced by whatever table name you use to bind the rows from analysis.R
