# User Quick Start Guide

This gem is included with the OpenStudio installer.  All you need to do is add `require openstudio-standards` to your `measure.rb` file:
    


    class MyMeasureName < OpenStudio::Ruleset::ModelUserScript  
	  
     require 'openstudio-standards'
     ...


### {OpenStudio::Model::Model#create_prototype_building}

{OpenStudio::Model::Model#create_prototype_building}
    
    # Create a Small Office, 90.1-2010, in ASHRAE Climate Zone 5A (Chicago)
    model.create_prototype_building('SmallOffice', '90.1-2010', 'ASHRAE 169-2006-5A')

{OpenStudio::Model::Model#create_prototype_building}

### Create a code baseline model

TODO

### Run a sizing run inside of a measure.rb

TODO