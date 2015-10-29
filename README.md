# OpenStudio-Standards

This library (a Ruby Gem) is an extension of the {https://www.openstudio.net/ OpenStudio SDK} that allows you to apply standards (like ASHRAE 90.1, Canada's NECB, etc.) to your OpenStudio model.

## Quick Start Guide

This gem is included with the OpenStudio installer.  All you need to do is add `require openstudio-standards` to your `measure.rb` file:
    
```ruby
    class MyMeasureName < OpenStudio::Ruleset::ModelUserScript
      require 'openstudio-standards'
      ...
```

### Create a {https://www.energycodes.gov/commercial-prototype-building-models/ DOE Prototype Building Model}

TODO

### Create a code baseline model

TODO

### Run a sizing run inside of a measure.rb

TODO

## Complete Documentation

{http://www.rubydoc.info/github/NREL/openstudio-standards/ Complete Online Documentation} 

## Developer Information

If you are a developer, see the {file:openstudio-standards/docs/DeveloperInformation.md Developer Information page}.
