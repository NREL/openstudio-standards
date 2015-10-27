# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

require "singleton"
require 'fileutils'
require 'csv'
require 'fileutils'
require "date"
release_mode = false
folder = "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/"

if release_mode == true
  #Copy BTAP files to measure from lib folder. Use this to create independant measure. 
  Dir.glob("#{folder}/**/*rb").each do |file|
    FileUtils.cp(file, File.dirname(__FILE__))
  end
  require "#{File.dirname(__FILE__)}/btap.rb"
else
  #For only when using git hub development environment.
  require "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/btap.rb"
end


# start the measure
class BtapEquestConverter < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "btap equest converter"
  end

  # human readable description
  def description
    return "This measure will take an eQuest *.inp file and attempt to convert the geometry into openstudio and bring it into a osm format. This will remove your current openstudio model.  Once the measure is complete, you may save the file as a osm file.   INP file argument is the location of the INP file. It will create an OSM file with the same name in the same folder. Please ensure that your path includes ONLY forward slashes '/'."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure will read a DOE 2.2 *.inp file and attempt to convert the geometry to OS geometry (Surfaces, Zones, Floors). It does just geometry at the moment.  Open the OpenStudio application, go to the measures tab, click on the 'My' folder icon to open your 'My Measures' directory.  Unzip the attached measure and drag it into your 'My Measures' directory.  Click on the 'Components & Measures->Apply Measure Now' file menu.  Select the 'btap_equest_converter' measure under 'Envelope.Form', type in the path to a .INP file on your computer.  Make sure to replace any backslashes '\' in your path with forward slashes '/'.  Hit 'Apply Measure', if all goes well you will see a report about the measure's operation and can accept the changes to your model.  Then save your OSM and open it in the SketchUp plug-in to verify that the model imported correctly."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the space to add to the model
    #inp_file = OpenStudio::Ruleset::OSArgument::makePathArgument("INPModelPath",true,"osm")
    inp_file = OpenStudio::Ruleset::OSArgument.makeStringArgument("inp_file", true)
    inp_file.setDisplayName("inp_file")
    inp_file.setDescription("Full path of DOE 2.2 inp file. USE FORWARD SLASH ONLY IN PATH")
    args << inp_file

    return args
  end

      def dans_checks(model,inp_file,runner = nil)
      #****Performing geometry validation measure as taken from https://github.com/NREL/OpenStudio/blob/develop/openstudiocore/ruby/openstudio/sketchup_plugin/user_scripts/Reports/OSM_Diagnostic_Script.rb
      #**** on July 21st, 2015. 
    
      remove_warnings = true
      remove_errors = true
    
    

      # number of surfaces
      surfaces = model.getPlanarSurfaces
      # puts "Model has " + surfaces.size.to_s + " planar surfaces"

      # number of base surfaces
      base_surfaces = model.getSurfaces
    

      # number of base surfaces
      sub_surfaces = model.getSubSurfaces
   
    
    

      savediagnostic = false # this will change to true later in script if necessary
      puts "Removing catchall objects (objects unknown to your version of OpenStudio)"
      switch = 0
      model.getObjectsByType("Catchall".to_IddObjectType).each do |obj|
        puts "*(error) '" + obj.name.to_s + "' object type is unkown to OpenStudio"
        switch = 1
        if remove_errors
          puts "**(removing object)  '#{obj.name.to_s}'"
          remove = obj.remove
          savediagnostic = true
        end
      end
      if switch == 0 then puts "none" end

      puts ""
      puts "Removing objects that fail draft validity test"
      switch = 0
      model.objects.each do |object|
        if !object.isValid("Draft".to_StrictnessLevel)
          report = object.validityReport("Draft".to_StrictnessLevel)
          puts "*(error)" + report.to_s
          switch = 1
          if remove_errors
            puts "**(removing object)  '#{object.name}'"
            remove = object.remove
            savediagnostic = true
          end
        end
      end
      if switch == 0 then puts "none" end

      base_surfaces = model.getSurfaces
      # Find base surfaces with less than three vertices
      puts ""
      puts "Surfaces with less than three vertices"
      switch = 0
      base_surfaces.each do |base_surface|
        vertices = base_surface.vertices
        if vertices.size < 3
          puts "*(warning) '" + base_surface.name.to_s + "' has less than three vertices"
          switch = 1
          if remove_errors
            puts "**(removing object) '#{base_surface.name.to_s}'"
            # remove surfaces with less than three vertices
            remove = base_surface.remove
            savediagnostic = true
          end
        end
      end
      if switch == 0 then puts "none" end

      sub_surfaces = model.getSubSurfaces
      # Find base sub-surfaces with less than three vertices
      puts ""
      puts "Surfaces with less than three vertices"
      switch = 0
      sub_surfaces.each do |sub_surface|
        vertices = sub_surface.vertices
        if vertices.size < 3
          puts "*(warning) '" + sub_surface.name.to_s + "' has less than three vertices"
          switch = 1
          if remove_errors
            puts "**(removing object) '#{sub_surface.name.to_s}'"
            # remove sub-surfaces with less than three vertices
            remove = sub_surface.remove
            savediagnostic = true
          end
        end
      end
      if switch == 0 then puts "none" end

      surfaces = model.getSurfaces
      # Find surfaces with greater than 25 vertices (split out sub-surfaces and test if they hvae more than 4 vertices)
      puts ""
      puts "Surfaces with more than 25 vertices"
      switch = 0
      surfaces.each do |surface|
        vertexcount = surface.vertices.size
        if vertexcount > 25
          puts "*(info) '" + surface.name.to_s + "' has " + vertexcount.to_s + " vertices"
          switch = 1
        end
      end
      if switch == 0 then puts "none" end

      base_surfaces = model.getSurfaces
      # Find base surfaces with area < 0.1
      puts ""
      puts "Surfaces with area less than 0.1 m^2"
      switch = 0
      base_surfaces.each do |base_surface|
        grossarea = base_surface.grossArea
        if grossarea < 0.1
          puts "*(warning) '" + base_surface.name.to_s + "' has area of " + grossarea.to_s + " m^2"
          switch = 1
          if remove_warnings
            puts "**(removing object) '#{base_surface.name.to_s}'"
            # remove base surfaces with less than 0.1 m^2
            remove = base_surface.remove
            savediagnostic = true
          end
        end
      end
      if switch == 0 then puts "none" end

      sub_surfaces = model.getSubSurfaces
      # Find sub-surfaces with area < 0.1
      puts ""
      puts "Surfaces with area less than 0.1 m^2"
      switch = 0
      sub_surfaces.each do |sub_surface|
        grossarea = sub_surface.grossArea
        if grossarea < 0.1
          puts "*(warning) '" + sub_surface.name.to_s + "' has area of " + grossarea.to_s + " m^2"
          switch = 1
          if remove_warnings
            puts "**(removing object) '#{sub_surface.name.to_s}'"
            # remove sub-surfaces with less than three vertices
            remove = sub_surface.remove
            savediagnostic = true
          end
        end
      end
      if switch == 0 then puts "none" end

      # Find surfaces within surface groups that share same vertices
      puts ""
      puts "Surfaces and SubSurfaces which have similar geometry within same surface group"
      switch = 0
      planar_surface_groups = model.getPlanarSurfaceGroups
      planar_surface_groups.each do |planar_surface_group|

        planar_surfaces = []
        planar_surface_group.children.each do |child|
          planar_surface = child.to_PlanarSurface
          next if planar_surface.empty?
          planar_surfaces << planar_surface.get
        end

        n = planar_surfaces.size

        sub_surfaces = []
        (0...n).each do |k|
          planar_surfaces[k].children.each do |l|
            sub_surface = l.to_SubSurface
            next if sub_surface.empty?
            sub_surfaces << sub_surface.get
          end
        end

        all_surfaces = []
        sub_surfaces.each do |m|  # subsurfaces first so they get removed vs. base surface
          all_surfaces << m
        end
        planar_surfaces.each do |n|
          all_surfaces << n
        end

        n2 = all_surfaces.size # updated with sub-surfaces added at the beginning
        surfaces_to_remove = Hash.new
        (0...n2).each do |i|
          (i+1...n2).each do |j|

            p1 = all_surfaces[i]
            p2 = all_surfaces[j]
       
            if p1.equalVertices(p2) or p1.reverseEqualVertices(p2)
              switch = 1
              puts "*(error) '#{p1.name.to_s}' has similar geometry to '#{p2.name.to_s}' in the surface group named '#{planar_surface_group.name.to_s}'"
              if remove_errors
                puts "**(removing object) '#{p1.name.to_s}'" # remove p1 vs. p2 to avoid failure if three or more similar surfaces in a group
                # don't remove here, just mark to remove
                surfaces_to_remove[p1.handle.to_s] = p1
                savediagnostic = true
              end
            end
          end
        end
        surfaces_to_remove.each_pair {|handle, surface| surface.remove}

      end
      if switch == 0 then puts "none" end
  
      # Find duplicate vertices within surface

      puts "Surfaces and SubSurfaces which have duplicate vertices"
      switch = 0
      planar_surface_groups = model.getPlanarSurfaceGroups
      planar_surface_groups.each do |planar_surface_group|

        planar_surfaces = []
        planar_surface_group.children.each do |child|
          planar_surface = child.to_PlanarSurface
          next if planar_surface.empty?
          planar_surfaces << planar_surface.get
        end

        n = planar_surfaces.size

        sub_surfaces = []
        (0...n).each do |k|
          planar_surfaces[k].children.each do |l|
            sub_surface = l.to_SubSurface
            next if sub_surface.empty?
            sub_surfaces << sub_surface.get
          end
        end

        all_surfaces = []
        sub_surfaces.each do |m|  # subsurfaces first so they get removed vs. base surface
          all_surfaces << m
        end
        planar_surfaces.each do |n|
          all_surfaces << n
        end

        all_surfaces.each do |surface|
          # make array of vertices
          vertices = surface.vertices
    
          # loop through looking for duplicates
          n2 = vertices.size
          switch2 = 0

          (0...n2).each do |i|
            (i+1...n2).each do |j|

              p1 = vertices[i]
              p2 = vertices[j]
       
              # set flag if surface needs be removed
            
              if p1.x == p2.x and p1.y == p2.y and p1.z == p2.z
                switch2 = 1
              end

            end
          end
    
          if switch2 == 1
            switch == 1
            puts "*(error) '#{surface.name.to_s}' has duplicate vertices"
            if remove_errors
              puts "**(removing object) '#{surface.name.to_s}'" # remove p1 vs. p2 to avoid failure if three or more similar surfaces in a group
              remove = surface.remove
              savediagnostic = true
            end
          end
    
        end

      end
      if switch == 0 then puts "none" end
    
      # find and remove orphan sizing:zone objects
      puts ""
      puts "Removing sizing:zone objects that are not connected to any thermal zone"
      #get all sizing:zone objects in the model
      sizing_zones = model.getObjectsByType("OS:Sizing:Zone".to_IddObjectType)
      #make an array to store the names of the orphan sizing:zone objects
      orphaned_sizing_zones = Array.new
      #loop through all sizing:zone objects, checking for missing ThermalZone field
      sizing_zones.each do |sizing_zone|
        sizing_zone = sizing_zone.to_SizingZone.get
        if sizing_zone.isEmpty(1)
          orphaned_sizing_zones << sizing_zone.handle
          puts "*(error)#{sizing_zone.name} is not connected to a thermal zone"
          if remove_errors
            puts "**(removing object)#{sizing_zone.name} is not connected to a thermal zone"
            sizing_zone.remove
            savediagnostic = true
          end
        end
      end
      #summarize the results
      if orphaned_sizing_zones.length > 0
        puts "#{orphaned_sizing_zones.length} orphaned sizing:zone objects were found"
      else
        puts "no orphaned sizing:zone objects were found"
      end


      puts ">>diagnostic test complete"

      if savediagnostic
        newfilename = inp_file.gsub(".inp","_diagnostic.osm")
        if File.exists? newfilename
          # I would like to add a prompt to ask the user if they want to overwrite their file
        end
        puts ""
        puts ">>saving temporary diagnostic version " + newfilename
        model.save(OpenStudio::Path.new(newfilename),true)

      end
      # End measure excerpt. 
    end
  
  
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    BTAP::runner_register("Info","Starting eQuest to OpenStudio Measure", runner)
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    inp_file = runner.getStringArgumentValue("inp_file", user_arguments)

    # check the space_name for reasonableness
    if inp_file.empty?
      message = "Empty inp file path was entered was entered."
      BTAP::runner_register("Error",message, runner)
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("Reading #{inp_file} for import.")

    #validate inp file path. 

    unless File.exist?(inp_file) 
      message = "File does not exist: #{inp_file}"
      BTAP::runner_register("Error",message, runner)
      return false
    end

    #Create an instances of a DOE model
    doe_model = BTAP::EQuest::DOEBuilding.new()
    
    #Load the inp data into the DOE model.
    doe_model.load_inp(inp_file,runner)

    

    #Convert the model to a OSM format.
    newModel = doe_model.create_openstudio_model_new()
    

    # pull original weather file object over
    weatherFile = newModel.getOptionalWeatherFile
    if not weatherFile.empty?
      weatherFile.get.remove
      BTAP::runner_register("Info","Removed alternate model's weather file object.", runner)
 
    end
    originalWeatherFile = model.getOptionalWeatherFile
    if not originalWeatherFile.empty?
      originalWeatherFile.get.clone(newModel)
    end

    # pull original design days over
    newModel.getDesignDays.each { |designDay|
      designDay.remove
    }
    model.getDesignDays.each { |designDay|
      designDay.clone(newModel)
    }

    # remove existing objects from model
    handles = OpenStudio::UUIDVector.new
    model.objects.each do |obj|
      handles << obj.handle
    end
    model.removeObjects(handles)
    # add new file to empty model
    model.addObjects( newModel.toIdfFile.objects )

    #do some built in tests
    self.dans_checks(model,inp_file,runner)

    # check that number of thermal zones, surfaces or subsurfaces are the same in the inp and osm files. 
    doe_spaces = doe_model.find_all_commands("SPACE")
    osm_spaces = model.getSpaces
    BTAP::runner_register("Info","INP file has #{doe_spaces.size} spaces and OSM has #{osm_spaces.size} spaces.", runner)
    if  doe_spaces.size != osm_spaces.size
      BTAP::runner_register("Warning","Number of spaces do not match!", runner)
      #find zones that were not imported and report them to user. 
      doe_spaces.each do |space|
        #Check to see if we already made one like this. If not throw a warning. 
        osm_space = OpenStudio::Model::getSpaceByName(model,space.name)
        if osm_space.empty?
          BTAP::runner_register("Warning","Space #{space.name} was not created!",runner)
        end
      end
    end
    
    
    
    # check that number of thermal zones, surfaces or subsurfaces are the same in the inp and osm files. 
    doe_zones = doe_model.find_all_commands("ZONE")
    osm_zones = model.getThermalZones
    BTAP::runner_register("Info","#{doe_zones.size} zones detected in inp file and #{osm_zones.size} thermalzone created in osm.",runner)
    if  doe_zones.size != osm_zones.size
      BTAP::runner_register("Warning","INP and OSM zone numbers do not match.",runner)
      #find zones that were not imported and report them to user. 
      doe_zones.each do |zone|
        #Check to see if we already made one like this. If not throw a warning. 
        thermal_zone = OpenStudio::Model::getThermalZoneByName(model,zone.name)
        if thermal_zone.empty?
          
          BTAP::runner_register("Warning","Zone #{zone.name} was not created!",runner)
        end
      end
    end
    
    # number of all surfaces
    doe_surfaces = []
    doe_surfaces.concat( doe_model.find_all_commands("EXTERIOR-WALL") ) 
    doe_surfaces.concat( doe_model.find_all_commands("INTERIOR-WALL") )
    doe_surfaces.concat( doe_model.find_all_commands("UNDERGROUND-WALL") )
    doe_surfaces.concat( doe_model.find_all_commands("ROOF") )
    osm_number_of_mirror_surfaces = 0  
    model.getSurfaces.each do|surface| 
      if surface.name.to_s.include?("mirror") 
        osm_number_of_mirror_surfaces = osm_number_of_mirror_surfaces + 1
      end
    end
    osm_surfaces = model.getSurfaces
    message = "#{doe_surfaces.size} EXTERIOR-WALL,INTERIOR-WALL, UNDERGROUND_WALL, and ROOF surfaces detected in inp file and #{osm_surfaces.size} Surfaces created in osm and #{osm_number_of_mirror_surfaces} are mirror surfaces."
    BTAP::runner_register("Info",message,runner)

    #test if all surfaces were translated
    if doe_surfaces.size != ( osm_surfaces.size - osm_number_of_mirror_surfaces)
      message = "INP and OSM surface numbers do not match. There may be errors in the import. Generating Report.."
      BTAP::runner_register("Warning",message,runner)
      #find items that were not imported and report them to user. 
      doe_surfaces.each do |surface|
        #Check to see if we already made one like this. If not throw a warning. 
        osm_surface = OpenStudio::Model::getSurfaceByName(model,surface.name)
        if osm_surface.empty?
          message = "Surface #{surface.name} was not created."
          BTAP::runner_register("Warning",message,runner)
        end
      end
    end
    
    #check subsurfaces
    #Get doe subsurfaces
    doe_subsurfaces = []
    doe_subsurfaces.concat( doe_model.find_all_commands("WINDOW") ) 
    doe_subsurfaces.concat( doe_model.find_all_commands("DOOR") )
    #get OS subsurfaces
    osm_subsurfaces = model.getSubSurfaces
    #inform user. 
    message = "#{doe_subsurfaces.size} WINDOW, and DOOR subsurfaces detected in inp file and #{osm_subsurfaces.size} SubSurfaces created in osm."
    BTAP::runner_register("Info",message,runner)
    #Check to see if all items were imported. 
    if doe_subsurfaces.size != osm_subsurfaces.size
      message = "INP and OSM sub surface numbers do not match. There may be errors in the import. Generating Report"
      BTAP::runner_register("Warning",message,runner)
      #find items that were not imported and report them to user. 
      doe_subsurfaces.each do |subsurface|
        #Check to see if we already made one like this. If not throw a warning. 
        osm_subsurface = OpenStudio::Model::getSubSurfaceByName(model,subsurface.name)
        if osm_subsurface.empty?
          message = "SubSurface #{subsurface.name} was not created."
          BTAP::runner_register("Warning",message,runner)
        end
      end
    end
    message = "No Construction , Materials, Schedules or HVAC were converted. These are not supported yet."
    BTAP::runner_register("Warning",message,runner)
    
    message =  "Model replaced with INP model at #{inp_file}. Please check warnings if any."
    BTAP::runner_register("FinalCondition",message,runner)
    return true

  end
  
end

# register the measure to be used by the application
BtapEquestConverter.new.registerWithApplication
