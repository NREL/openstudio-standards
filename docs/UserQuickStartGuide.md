# User Quick Start Guide

## Create DOE Prototype Building Measure

Starting with OpenStudio 1.11.3, the "Create DOE Prototype Building" Measure is available on BCL and can be used like any other Measure.

1. Components & Measures > Find Measures, download Whole Building > Space Types > Create DOE Prototype Building
2. Components & Measures > Apply Measure Now > Whole Building > Space Types > Create DOE Prototype Building
2. Pick the building type/climate zone/vintage
3. Run

## Using OpenStudio-Standards in Measures
**This gem is included with the OpenStudio installer**.  All you need to do is add `require openstudio-standards` to your `measure.rb` file and you will have access to the methods in this gem:
    
    class MyMeasureName < OpenStudio::Ruleset::ModelUserScript  
	  
     require 'openstudio-standards'
     ...

## Installing OpenStudio-Standards from RubyGems
If you want to install a newer release of this gem from RubyGems.org than what is available in the OpenStudio installer.

1. Install Ruby:
      1. **On Mac**:
      2. Install Ruby 2.2.4 using [rbenv](http://octopress.org/docs/setup/rbenv/) (`ruby -v` from command prompt to check installed version).
      3. **On Windows**:
      4. Install [Ruby 2.2.4](https://rubyinstaller.org/downloads/archives/) (`ruby -v` from command prompt to check installed version).
2. Enable your OpenStudio Application installation to use the version of the gem built through the development process 
    1. **On Windows**, Start > right click Computer > Properties > Advanced system settings > Environment variables.  In the User variables section (top) add a new Variable with the name `GEM_HOME` and the Value `C:\Ruby22-x64\lib\ruby\gems\2.2.0`.
3. Install the gem. (`gem install openstudio-standards` from command prompt)
