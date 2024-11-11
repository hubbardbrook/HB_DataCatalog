#############################################
# dataCat.R
# 
# mary.martin@unh.edu 20241016
# Purpose: build a datatable for the HB website local data catalog
#   This is a revised script to generate the data catalog file on the wordpress site
#   this revision now runs on all publicly available data - no pw protected databases for local info
# Inputs are - sharepoint xlsx file that tracks data status locally and provides additional info to enhance user
#   experience in searching for data
# Requirements: The following script is sourced and should be located in the same folder as this main script: FetchSharepointDataInventory.R
# Usage: Run this script, then move the wptablefeed.csv file to the website and updated the table to refresh to this new version
# Note: once this runs a few times and I gain a little confidence, I will consider adding a command to ftp directly to wordpress to refresh the site
#############################################

library(EDIutils)
library(tidyverse)
library(httr)
library("stringr")   
library(xml2)

# set the working directory to the location of the script
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# source the script that gets local package info from sharepoint spreadsheet
# returns dataframe ps(package state)
source("FetchSharepointDataInventory.R")

# Fetch the basic eml info directly from EDI for each package
# consider getting abstract and making that display as a hoverover on the website table
res<-search_data_packages(
  query = "q=*&fq=-scope:ecotrends&fq=scope:knb-lter-hbr&fq=-scope:lter-landsat*&fl=id,packageid,doi,title,pubdate,begindate,enddate")

names(res)=c("id","PackageId","doi","Title","pubdate","begindate","enddate")

res$Title=gsub("[\r\n]", " ", res$Title)
res$Title=gsub("\\s+", " ", res$Title)


# extract begin and end YEAR
res$startYear=as.POSIXlt(as.Date(res$begindate))$year + 1900
res$endYear=as.POSIXlt(as.Date(res$enddate))$year + 1900
# if dataset has start/end dates, create column that shows them with dash separator
res$yearrange="NA"
res$yearrange = paste0(res$startYear," - ",res$endYear)
index= grep("NA",res$yearrange)
res$yearrange[index] = " "

#create the edilink
res$edilink=paste0("https://portal.edirepository.org/nis/mapbrowse?packageid=",res$PackageId)

# Fetch the pesky keywords and authors as xml so you can insert a separator
k<-search_data_packages(
  query = "q=*&fq=-scope:ecotrends&fq=scope:knb-lter-hbr&fq=-scope:lter-landsat*&fl=id,packageid,keyword,author",
  as = "xml"
)

kw <- data.frame(
  PackageId=character(), 
  Originators=character(),
  Keywords=character(), 
  stringsAsFactors=FALSE)

count=1
for (doc in xml_find_all(k, ".//document")) {
  print(doc)
  # Get the keywords from the current doc
  keyword_elements <- xml_find_all(doc, ".//keyword")
  keyword_strings <- xml_text(keyword_elements)
  
  # This doesn't get the authors where HBWaTER and USFS are institution authors.
  # see solution below to get those from cite.edirepository.org
  kw[count,3] <- paste(keyword_strings, collapse = ";")
  # Get the authors from the current doc
  author_elements <- xml_find_all(doc, ".//author")
  author_strings <- xml_text(author_elements)
  
  kw[count,2] <- paste(author_strings, collapse = "; ")
  # get the packageid
  pid <- xml_find_all(doc, ".//packageid")
  pidstring  <- xml_text(pid)
  kw[count,1] <- pidstring
  
  count=count+1
}

# tidy up keywords where some strings have newlines or consec white spaces
kw$Keywords=gsub("[\r\n]", " ", kw$Keywords)
kw$Keywords=gsub("\\s+", " ", kw$Keywords)

# merge the tidier keywords with the main table
resj=merge(res,kw, by = "PackageId")

# get the dataset citations so that you have a nicer listing of authors
# you could probably do that where I do the keywords now from xml, but it doesn't
# populate the records where author is an institution (USFS and HBWaTER)
for(i in 1:dim(resj)[1]){
 print(i) 
 CMD=paste0('GET ("https://cite.edirepository.org/cite/',resj[i,1],'")')
 # sleep can be removed if you are whitelisted to make rapid EDI queries
 Sys.sleep(0.5)
 print(CMD)
 c=content(eval(parse( text = CMD )))
  
 print(c$authors)
 resj[i,"Originators"]=c$authors
}

# FetchSharepointDataInventory returns ps dataframe (aka package state in the originalmetabase database)
# add data category based on sort order codes in ps (local package state table)
# apply category name to sort order values
ps$category=0
index=which(substr(ps$pub_notes,1,1)==1)
ps$category[index]="Hydrometeorology"
index=which(substr(ps$pub_notes,1,1)==2)
ps$category[index]="Water Chemistry"
index=which(substr(ps$pub_notes,1,1)==3)
ps$category[index]="Soils"
index=which(substr(ps$pub_notes,1,1)==4)
ps$category[index]="Vegetation"
index=which(substr(ps$pub_notes,1,1)==5)
ps$category[index]="Heterotrophs"
index=which(substr(ps$pub_notes,1,1)==8)
ps$category[index]="Documentation"
index=which(substr(ps$pub_notes,1,1)==9)
ps$category[index]="Spatial Datasets"

# subset out the columns that are to be used in the datatable
pscat=ps[,c("dataset_archive_id","category","ltercore","pub_notes")]
# merge the EDI query dataframe with ps
m=merge(resj,pscat, by.x="id",by.y="dataset_archive_id")

##### Write out wordpress data table #################
# pull out the columns needed for website table
wptablefeed=m[,c("PackageId","Title","Originators","yearrange","ltercore","edilink","category","pub_notes","Keywords")]
# sort packages based on pub_notes
wptablefeed.order=wptablefeed[order(wptablefeed$pub_notes),]
# write out the table
write.table(wptablefeed.order,"wptablefeed.csv",row.names=FALSE,sep=",",na=" ")
