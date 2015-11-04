
# Code Structure

# /openstudio-standards

The `openstudio-standards` gem code.

## /data

The raw data used by the library.  Files in this directory should not contain code.

### /geometry

These files contain 3D building geometry that is often used as a starting point for prototypical models.

### /standards

These files contain information from energy codes/standards, as well as typical building characteristics.  Examples include HVAC efficiency values, performance curves, construction U-values, and schedules. The code accesses this information when applying a standard or creating a prototypical building.

Rather than editing the JSON files directly, developers should edit [The OpenStudio_Standards Google Spreadsheet](https://docs.google.com/spreadsheets/d/15-mlZrWbA4srtFHtWRP1dgPeuI5plFdjCb1B79fEukI/edit?usp=sharing)

**TODO** Show how to export the spreadsheet `Standards.export_OpenStudio_HVAC_Standards.rb`

### /weather

These files contain weather information for representative locations. The `.epw` files contain typical annual weather data, the `.ddy` files contain design day information, and the `.stat` files contain a summary of the weather in that location.

## /lib/openstudio-standards

The functional code.

### /btap

These files contain methods to apply the Canadian energy code (NECB) to models, as well as code to create the typical Canadian prototype models.  Many of the methods in here are duplicative of methods in the /standards directory, and will be migrated there over time.

### /hvac_sizing

These files extend OpenStudio classes to allow users to run a sizing run and access autosized HVAC equipment values (capacities, flow rates, etc.), and to pull these values back into the model if desired.

### /prototypes

These files extend OpenStudio classes to apply typical assumptions that are not governed by a standard, and for which reasonable values exist.  For example, the configuration of the HVAC systems, assumptions for fan pressure drops, etc.  These assumptions come from sources like the DOE Prototype, the DOE Reference Buildings, and the Canadian Archetype Buildings.

### /standards

These files extend OpenStudio classes to enable them to modify their inputs to meet a specific standard.  For example, the Chiller:Electric:EIR object has a new method that sets its COP and performance curves based on the selected standard, the capacity, and the compressor type.  These methods rely on the information in the `/data/standards` directory for lookups.

### /weather

These files extend the OpenStudio classes to allow a model to import design days, pull water mains temperature from the .stat file, and assign the correct weather file to the model.

## /test

This directory contains the simulation results from the legacy IDF files, as well as test fixtures which will run the Measure, create the models, and then compare the model results against the legacy IDF files.

## docs

This is where the documentation (like this very page) lives.  Note that the code documentation is not here.  Those pages are generated on-the-fly from the source code, and are not committed to the repository.

# /measures

Each folder in this directory contains an [OpenStudio Measure](http://nrel.github.io/OpenStudio-user-documentation/getting_started/about_measures/) that requires the `openstudio-standards` gem to operate correctly.  When the tests for this repository are run, in addition to running the tests in the `/openstudio-standards/test` directory, it also runs the Measure-specific tests found in the `/MeasureName/tests` directory. Eventually, the tests for these Measures will be run by a dedicated Measure testing framework, but for now they are included in this repository to ensure that changes to the `openstudio-standards` gem do not break them.