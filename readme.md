# OpenStudio Standards Repository 

This repository contains the data used by OpenStudio to create and use standards for constructions, lighting, occupancy, ventilation, and other building related items.

Standards data is defined in a spreadsheet and then exported to JSON format via scripts.  Each version of OpenStudio will come with a JSON export of the current version of this data.  However, users may modify the spreadsheet and create their own JSON exports which may be loaded into OpenStudio to override the built in data.  Users may create pull requests to merge their data into the master spreadsheet.  However, git cannot neatly merge data in Excel format so these merges must be performed by hand.

### TODO List
+ Move main spreadsheet to top level
+ Move JSON export scripts to top level