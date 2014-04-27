# OpenStudio Standards Repository 

This repository contains the data used by OpenStudio to create and use standards for constructions, lighting, occupancy, ventilation, and other building related items.

Standards data is defined in a spreadsheet and then exported to JSON format via scripts.  Each version of OpenStudio will come with a JSON export of the current version of this data.  However, users may modify the spreadsheet and create their own JSON exports which may be loaded into OpenStudio to override the built in data.  Users may create pull requests to merge their data into the master spreadsheet.  However, git cannot neatly merge data in Excel format so these merges must be performed by hand.

The current workflow to add information to the OpenStudio standard is to:

1. Edit the OpenStudio_Standards.xlsx and Master_Schedules.osm files
2. Run the ExportStandardsToJSON.rb script to create OpenStudio_Standards.json
3. Validate the JSON export using the TestScheduleLinks.rb and TestConstructionSets.rb scripts
4. The files SpaceTypeGenerator.rb and ConstructionSetGenerator.rb contain classes to read OpenStudio_Standards.json
5. Run CreateTemplateModels.rb this will generate new OSM template files 

The reference directory is for any reference materials, not used by the scripts in the main workflow

The scripts directory is for loose scripts which may be helpful but are not used in the main workflow

The test directory is for automated tests that run on the output OpenStudio_Standards.json