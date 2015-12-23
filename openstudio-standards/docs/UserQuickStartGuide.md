# User Quick Start Guide
Currently, to use the gem you must install it manually following the instructions below.

In the future, this gem will be included with the OpenStudio installer.  All you will need to do is add `require openstudio-standards` to your `measure.rb` file:
    
    class MyMeasureName < OpenStudio::Ruleset::ModelUserScript  
	  
     require 'openstudio-standards'
     ...

## Installing the OpenStudio Standards Gem

1. Install the {https://www.openstudio.net/downloads latest version of OpenStudio}.  Minimum supported version is 1.9.0. 
2. **On Windows**, install {http://rubyinstaller.org/ Ruby 2.0} (`ruby -v` from command prompt to check installed version).  
3. **On Mac** Ruby 2.0 is already installed.
4. **On Windows**, Start > right click Computer > Properties > Advanced system settings > Environment variables.  In the User variables section (top) add a new Variable with the name `GEM_PATH` and the Value `C:\Users\yourusernamehere`.
5. {https://github.com/NREL/openstudio-standards/archive/master.zip Download the source code} or {https://github.com/NREL/openstudio-standards.git clone the source code} using {https://git-scm.com/ Git}.
5. In a command prompt, navigate to the `openstudio-standards/openstudio-standards` directory of the source code.
5. `gem build openstudio-standards.gemspec`   ENTER to build the gem.
6. `gem install --user-install openstudio-standards-0.1.0.gem`   ENTER to install the gem.

Now, your installed versions of OpenStudio will have access to this gem.  If you install new versions of OpenStudio, they will also have access to this gem.

## Using the Create DOE Prototype Building Measure

1. Install the gem using the instructions above.
2. In the OpenStudio App > Preferences > Change My Measures Directory, point to the opensutdio-standards/measures directory.
3. Components & Measures > Apply Measure Now > Whole Building > Space Types > Create DOE Prototype Building
4. Pick the building type/climate zone/vintage
5. Run

## Updating the Gem

If changes are made to the gem source code and you want to use those changes, repeat steps 5-8 of the installation instructions.


