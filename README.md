# OpenStudio Standards Repository 

This repository contains the data used by OpenStudio to create and use standards for constructions, lighting, occupancy, ventilation, and other building related items. Standards data is defined in a spreadsheet and then exported to JSON format via scripts.  Each version of OpenStudio will come with a JSON export of the current version of this data.  Several measures also use this exported data.

This repository is meant for common, generic data that is widely used.  It is not meant for user or project specific data. Users may fork this repository to add their own information to the standards spreadsheets.  This custom data can then be exported to JSON format and accessed as a resource in user specific measures.

The current workflow to add information to the OpenStudio standard is to:

1. Edit the resources/OpenStudio_Standards.xlsx and resources/Master_Schedules.osm files
1. Run `rake build:standards` to create OpenStudio_Standards.json. If this is the first time running, then run the following:

    ```
    bundle
    rake build:standards
    ```
    
1. Validate the JSON export using the TestScheduleLinks.rb and TestConstructionSets.rb scripts
1. The files SpaceTypeGenerator.rb and ConstructionSetGenerator.rb contain classes to read OpenStudio_Standards.json
1. Run CreateTemplateModels.rb this will generate new OSM template files

The reference directory is for any reference materials, not used by the scripts in the main workflow

The scripts directory is for loose scripts which may be helpful but are not used in the main workflow

The test directory is for automated tests that run on the output OpenStudio_Standards.json

## Development

1. Change all code to use version 2 of the standards JSON format
1. Move the building of the OpenStudio templates into a Rake task
1. Move the tests into a Rake task
1. Move SpaceTypeGenerator and ConstructionSetGenerator into the lib directory
1. Update all Ruby code to conform to Rubocop style rules
1. Add additional export formats such as gbXML