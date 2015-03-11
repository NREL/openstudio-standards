# OpenStudio Standards Repository 

## Purpose

This repository contains the data used by OpenStudio to create and use standards for constructions, lighting, occupancy, ventilation, and other building related items. Standards data is defined in a spreadsheet and then exported to JSON format via scripts.  Each version of OpenStudio will come with a JSON export of the current version of this data.  Several measures also use this exported data.

This repository is meant for common, generic data that is widely used.  It is not meant for user or project specific data. Users may fork this repository to add their own information to the standards spreadsheets.  This custom data can then be exported to JSON format and accessed as a resource in user specific measures.

## Setup
1. Open a command prompt inside the top-level openstudio-standards directory
2. Run `bundle` ENTER. This installs the correct libraries

## Adding information to OpenStudio standards

1. Edit the `resources/OpenStudio_Standards.xlsx` file
2. Open a command prompt inside the top-level openstudio-standards directory
3. Run `rake build:standards` to create `OpenStudio_Standards.json`
4. Check the changes in `OpenStudio_Standards.json` to make sure they reflect what you added/ modified in `OpenStudio_Standards.xlsx`   
5. Run `rake test:check_validity` to check for errors in `OpenStudio_Standards.json`.  Fix any errors.
6. Commit both the `OpenStudio_Standards.xlsx` and `OpenStudio_Standards.json` at the same time.

## Creating the OpenStudio templates

1. Open a command prompt inside the top-level openstudio-standards directory
2. Run `rake build:template_models`.  This creates a directory called `templates` which will contain the resulting .osms.

## Directory structure

- `build/` contains the `OpenStudio_Standards.json`, which is exported via `rake build:standards`
- `lib/` contains libraries of methods used for accessing the data in `OpenStudio_Standards.json` from a Measure
- `reference/` contains reference materials, which are not used in the main workflow
- `resources/` contains the `OpenStudio_Standards.xlsx`, which is the data entry point
- `scripts/` contains loose scripts which may be helpful but are not used in the main workflow
- `templates/` contains the OpenStudio template models, generated via `rake build:template_models`
- `test/` contains automated tests that check `OpenStudio_Standards.json` via `rake test:check_validity`

## Development TODO

1. Update all Ruby code to conform to Rubocop style rules
2. Add additional export formats such as gbXML