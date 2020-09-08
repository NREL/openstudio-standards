
# Repository Structure

## /data

The raw data used by the library.  Files in this directory should not contain code.

### /costing

These files contain information on construction and material costs.  Not used by most Standards.

### /geometry

These files contain 3D building geometry that is often used as a starting point for prototypical models.  It also contains JSON files that describe the HVAC systems to be used with the geometry.

### /standards

These files contain information from energy codes/standards, as well as typical building characteristics.  Examples include HVAC efficiency values, performance curves, construction U-values, and schedules. The code accesses this information when applying a standard or creating a prototypical building.

Rather than editing the JSON files directly, developers should edit [The OpenStudio_Standards Google Spreadsheet](https://docs.google.com/spreadsheets/d/15-mlZrWbA4srtFHtWRP1dgPeuI5plFdjCb1B79fEukI/edit?usp=sharing)
- To get edit access to this spreadsheet, contact <mailto:andrew.parker@nrel.gov>.

### /weather

These files contain weather information for representative locations. The `.epw` files contain typical annual weather data, the `.ddy` files contain design day information, and the `.stat` files contain a summary of the weather in that location.

## /lib/openstudio-standards

The functional code that makes up the openstudio-standards library.

### /btap

These files contain methods to apply the Canadian energy code (NECB) to models, as well as code to create the typical Canadian prototype models.  Many of the methods in here are duplicative of methods in the /standards directory, and will be migrated there over time.

### /hvac_sizing

These files extend OpenStudio classes to allow users to run a sizing run and access autosized HVAC equipment values (capacities, flow rates, etc.), and to pull these values back into the model if desired.  These methods will eventually be moved into the OpenStudio C++.

### /prototypes

These files apply typical assumptions that are not governed by a standard, and for which reasonable values exist.  For example, the configuration of the HVAC systems, assumptions for fan pressure drops, etc.  These assumptions come from sources like the DOE Prototype, the DOE Reference Buildings, and the Canadian Archetype Buildings.

### /refs

This file contains a list of codes, standards, technical reports, and other documents that are referenced in the documentation for methods in the library.

### /utilities

These files contain methods to perform common tasks such as runnning simulations, logging errors, etc.

### /standards

These files modify model inputs to meet a specific standard.  For example, there is a method that modifies a Chiller:Electric:EIR and sets its COP and performance curves based on the selected standard, the capacity, and the compressor type.  These methods rely on the information in the `/data/standards` directory for lookups.

Each subdirectory contains methods for a specific standard.  Methods that are defined higher up in the directory structure may be re-implemented (and therefore overwritten) by methods further down in the structure.

### /weather

These files import design days to models, pull water mains temperature from the .stat file, and assign the correct weather file to the model.

## /test

This directory contains unit tests which run various portions of the code and ensure that it is working.  When new functionality is added to this library, corresponding unit tests should be added as well.

## docs

This is where the documentation (like this very page) lives.  Note that the code documentation is not here.  Those pages are generated on-the-fly from the source code, and are not committed to the repository.  The scorecards directory contains model information for the SmallOfficeDetailed, MediumOfficeDetailed, LargeOfficeDetailed, Laboratory, and Supermarket prototypes.
