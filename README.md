# Hubbard Brook Data Catalog

This repository contains R code to build the table used for the local Hubbard Brook datacatalog.
This primarily uses the LTER PASTA+ API and also makes a call to a local table that
we use to track additional information about each dataset. The latter improves the user
experience in browsing for data by enforcing a sort order based on category of data (Hydrology, Meteorology,
Vegetation, Animals, Soil, GIS, etc). It also applies LTER Core Research Area codes that may not be present in
older dataset.
