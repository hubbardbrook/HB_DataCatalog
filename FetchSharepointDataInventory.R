library(httr)
library(readxl)

# Function to read Excel file from SharePoint URL
read_sharepoint_excel <- function(url) {
  # Download the file
  response <- GET(url, config(ssl_verifypeer = FALSE))
  
  # Check if the download was successful
  if (status_code(response) != 200) {
    stop("Failed to download the file. Status code: ", status_code(response))
  }
  
  # Create a temporary file
  temp_file <- tempfile(fileext = ".xlsx")
  
  # Write the content to the temporary file
  writeBin(content(response, "raw"), temp_file)
  
  # Read the Excel file
  df <- read_excel(temp_file)
  
  # Remove the temporary file
  unlink(temp_file)
  
  return(df)
}

# URL of your SharePoint Excel file
url <- "https://universitysystemnh.sharepoint.com/:x:/t/HubbardBrook/EXFAJdG37VxOsrGI5jMhxmcBc1vTpUnZw1WPtiP3Q5Mc4A?download=1"

# Read the Excel file
df <- data.frame(read_sharepoint_excel(url))

# subset to just cataloged datasets, save as df 'ps' (for package state)
ps=df[which(df$status=="cataloged"),]

