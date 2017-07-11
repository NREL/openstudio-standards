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

require 'json'
require "#{File.dirname(__FILE__)}/btap"

class NECB_2011 < OpenStudio::Model::Model

  def initialize()
    super()
    @standard = "NECB 2011"
    @climate_zone = 'NECB HDD Method'
  end

  def check_weather_file()
    #Get HDD from weather file.
    if not self.weatherFile.is_initialized or self.weatherFile.get.path.empty? or not File.exists?(self.weatherFile.get.path.get.to_s)
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has not been assigned a weather file that exists.')
    end
  end

  #this method will create a new prototype building based on the NECB 2011
  def create_prototype_building(building_type, climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false)
    template = @standard
    climate_zone = @climate_zone
    lookup_building_type = get_lookup_name(building_type)

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
        'template' => template,
        'building_type' => building_type
    }

    prototype_input = find_object($os_standards['prototype_inputs'], search_criteria, nil)

    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for #{search_criteria}, cannot create model.")
      return false
    end
    debug_incremental_changes = false
    # set climate zone and building type
    getBuilding.setStandardsBuildingType(building_type)
    load_building_type_methods(building_type)
    load_geometry(building_type, template)
    add_design_days_and_weather_file(climate_zone, epw_file)
    check_weather_file()
    getBuilding.setName("#{template}-#{building_type}-#{climate_zone}-#{epw_file} created: #{Time.new}")
    assign_space_type_stubs('Space Function', template, define_space_type_map(building_type, template, climate_zone)) # TO DO: add support for defining NECB 2011 archetype by building type (versus space function)
    add_loads(template)
    apply_infiltration_standard(template)
    modify_surface_convection_algorithm(template)
    add_constructions(building_type, template, climate_zone)
    apply_prm_construction_types(template)
    apply_prm_baseline_window_to_wall_ratio(template, nil)
    apply_prm_baseline_skylight_to_roof_ratio(template)
    create_thermal_zones(building_type, template, climate_zone)
    if building_type == 'SmallHotel' && template != 'NECB 2011'
      getBuildingStorys.each {|item| item.remove}
      building_story_map = PrototypeBuilding::SmallHotel::define_building_story_map(building_type, template, climate_zone)
      assign_building_story(building_type, template, climate_zone, building_story_map)
    end
    assign_spaces_to_stories
    return false if runSizingRun("#{sizing_run_dir}/SR0") == false
    add_hvac(building_type, epw_file)
    add_swh(building_type, template, climate_zone, prototype_input, epw_file)
    apply_sizing_parameters(building_type, template)
    yearDescription.get.setDayofWeekforStartDay('Sunday')
    getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
    getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)
    if runSizingRun("#{sizing_run_dir}/SR1") == false
      return false
    end
    apply_multizone_vav_outdoor_air_sizing(template)

    # This is needed for NECB 2011 as a workaround for sizing the reheat boxes
    if @standard == 'NECB 2011'
      getAirTerminalSingleDuctVAVReheats.each { |iobj| iobj.set_heating_cap }
    end
    apply_prototype_hvac_assumptions(building_type, template, climate_zone)

    # Apply the HVAC efficiency standard
    apply_hvac_efficiency_standard(template, climate_zone)

    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    if building_type == 'LargeHotel'
      PrototypeBuilding::LargeHotel.large_hotel_add_daylighting_controls(template, self)
    elsif building_type == 'Hospital'
      PrototypeBuilding::Hospital.hospital_add_daylighting_controls(template, self)
    else
      add_daylighting_controls(template)
    end

    if building_type == 'QuickServiceRestaurant'
      PrototypeBuilding::QuickServiceRestaurant.update_exhaust_fan_efficiency(template, self)
    elsif building_type == 'FullServiceRestaurant'
      PrototypeBuilding::FullServiceRestaurant.update_exhaust_fan_efficiency(template, self)
    elsif building_type == 'Outpatient'
      PrototypeBuilding::Outpatient.update_exhaust_fan_efficiency(template, self)
    end

    if building_type == 'HighriseApartment'
      PrototypeBuilding::HighriseApartment.update_fan_efficiency(self)
    end

    # Add output variables for debugging
    if debug
      request_timeseries_outputs
    end

    # Finished
    model_status = 'final'
    save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)
    return true
  end

  def add_hvac(building_type,epw_file)
    boiler_fueltype, baseboard_type, mau_type, mau_heating_coil_type, mua_cooling_type, chiller_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type, swh_fueltype = BTAP::Environment.get_canadian_system_defaults_by_weatherfile_name(epw_file)
    BTAP::Compliance::NECB2011.necb_autozone_and_autosystem(self, runner = nil, use_ideal_air_loads = false, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, chiller_type, mua_cooling_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type, swh_fueltype, building_type)
  end

  def check_spaces_are_assigned_spacetypes()
    space_types = Array.new
    unassigned = Array.new
    #Loop through spaces.
    getSpaces.each do |space|
      if space.spaceType.is_initialized
        #store spacetype if not already in array.
        space_types << space.spaceType.get unless space_types.include?(space.spaceType.get)
      else
        #Store the space that has no space type assigned.
        unassigned << space
      end
      #Inform user of unassigned spaces.
      if unassigned.size > 0
        names = unassigned.map {|space| space.name}
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'These spaces have no spactypes assigned. All spaces must have a spacetype :#{names}') if unassigned.size > 0
        return false
      end
    end
    unknown_space_types = []
    space_types.each do |space_type|
      #Check if this spacetype exists in the standards database.
      if $os_standards["space_types"].detect {|st| st["template"] == @standard and st["building_type"] == space_type.standardsBuildingType and st["space_type"] == space_type.standardsSpaceType}.nil?
        unknown_space_types << st
      end
    end
    #Inform user of unassigned spaces.
    if unknown_space_types.size > 0
      names = unknown_space_types.map {|space| space.name}
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'These spacetypes are not defined as part of the #{@standard}. All spaces must have a spacetype :#{names}') if unassigned.size > 0
      return false
    end
    return true
  end

  #This model determines the dominant NECB schedule type
  #@param self [OpenStudio::model::Model] A model object
  #return s.each [String]
  def get_dominant_necb_schedule_type()
    # lookup necb space type properties
    space_type_properties = self.find_objects($os_standards["space_types"], {"template" => 'NECB 2011'})

    # Here is a hash to keep track of the m2 running total of spacetypes for each
    # sched type.
    s = Hash[
        "A", 0,
        "B", 0,
        "C", 0,
        "D", 0,
        "E", 0,
        "F", 0,
        "G", 0,
        "H", 0,
        "I", 0
    ]
    #iterate through spaces in building.
    wildcard_spaces = 0
    self.getSpaces.each do |space|
      found_space_type = false
      #iterate through the NECB spacetype property table
      space_type_properties.each do |spacetype|
        unless space.spaceType.empty?
          if space.spaceType.get.standardsSpaceType.empty? || space.spaceType.get.standardsBuildingType.empty?
            OpenStudio::logFree(OpenStudio::Error, "openstudio.Standards.Model", "Space #{space.name} does not have a standardSpaceType defined")
            found_space_type = false
          elsif space.spaceType.get.standardsSpaceType.get == spacetype['space_type'] && space.spaceType.get.standardsBuildingType.get == spacetype['building_type']
            if "*" == spacetype['necb_schedule_type']
              wildcard_spaces =+1
            else
              s[spacetype['necb_schedule_type']] = s[spacetype['necb_schedule_type']] + space.floorArea() if "*" != spacetype['necb_schedule_type'] and "- undefined -" != spacetype['necb_schedule_type']
            end
            #puts "Found #{space.spaceType.get.name} schedule #{spacetype[2]} match with floor area of #{space.floorArea()}"
            found_space_type = true
          elsif "*" != spacetype['necb_schedule_type']
            #found wildcard..will not count to total.
            found_space_type = true
          end
        end
      end
      raise ("Did not find #{space.spaceType.get.name} in NECB space types.") if found_space_type == false
    end
    #finds max value and returns NECB schedule letter.
    raise("Only wildcard spaces in model. You need to define the actual spaces. ") if wildcard_spaces == self.getSpaces.size
    dominant_schedule = s.each {|k, v| return k.to_s if v == s.values.max}
    return dominant_schedule
  end

  #This method determines the spacetype schedule type. This will re
  #@author phylroy.lopez@nrcan.gc.ca
  #@param space [String]
  #@return [String]:["A","B","C","D","E","F","G","H","I"] spacetype
  def get_necb_schedule_type(space)
    raise ("Undefined spacetype for space #{space.get.name}) if space.spaceType.empty?") if space.spaceType.empty?
    raise ("Undefined standardsSpaceType or StandardsBuildingType for space #{space.spaceType.get.name}) if space.spaceType.empty?") if space.spaceType.get.standardsSpaceType.empty? | space.spaceType.get.standardsBuildingType.empty?
    space_type_properties = space.model.find_object($os_standards["space_types"], {"template" => 'NECB 2011', "space_type" => space.spaceType.get.standardsSpaceType.get, "building_type" => space.spaceType.get.standardsBuildingType.get})
    return space_type_properties['necb_schedule_type'].strip
  end

  # This method will return the FWDR required by the hdd
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param hdd [Float]
  def get_standard_max_fdwr()
    self.check_weather_file()
    hdd = BTAP::Environment::WeatherFile.new(self.weatherFile.get.path.get).hdd18.to_f.round
    value = $os_standards["necb_fdwr"].detect {|fdwr| fdwr["standard"] = @standard and fdwr["hdd_min"] < hdd and fdwr["hdd_max"].to_i > hdd}["fdwr"].to_s
    return eval(value).to_f
  end

  #This model gets the standard climate zone name
  #@author phylroy.lopez@nrcan.gc.ca
  #@param hdd [Float]
  #@return [Fixnum] climate zone 4-8
  def get_standard_climate_zone_name()
    #Get HDD from weather file.
    self.check_weather_file()
    hdd = BTAP::Environment::WeatherFile.new(self.weatherFile.get.path.get).hdd18.to_f.round
    #check for climate zone index from NECB 3.2.2.X
    return $os_standards["necb_climate_zones"].detect {|zone| zone["standard"] = @standard and zone["hdd_min"] < hdd and zone["hdd_max"].to_i > hdd}["climate_zone_name"].to_s
  end

  #This model gets the surface conductance for the standard
  #@author phylroy.lopez@nrcan.gc.ca
  #@param hdd [Float]
  #@return [Fixnum] climate zone 4-8
  def get_standard_surface_conductance(surface_type)
    #Get HDD from weather file.
    self.check_weather_file()
    valid_types = $os_standards["necb_surface_conductances"].map {|row| row["intended_surface_type"]}
    OpenStudio::logFree(OpenStudio::Error, "necb2011", "Space #{surface_type} is not of #{valid_types}") unless valid_types.include?(surface_type)
    value = $os_standards["necb_surface_conductances"].detect {|zone| zone["standard"] = @standard and zone["intended_surface_type"] == surface_type and zone["climate_zone_name"] == self.get_standard_climate_zone_name()}
    if value.nil?
      OpenStudio::logFree(OpenStudio::Error, "necb2011", "Space #{surface_type} for climate zone #{self.get_standard_climate_zone_name()} could not be found in os standards spreadsheet necb_surface_conductaces")
      return nil
    end
    return value['conductance'].to_f
  end


=begin
  # This method will add basic constuctions base on space type. This will not modify the U-values. That will happen in
  # another method.
  def assign_basic_constructions_based_on_space_types()
    #Prereq. All spaces must be assign a spacetype and the spacetype must exist in the standard being used.
    self.check_spaces_are_assigned_spacetypes()
    #Get Number of above ground building stories.
    above_ground_stories = self.building.get.standardsNumberOfAboveGroundStories()
    total_stories = self.building.get.standardsNumberOfStories()
    getSpaces.each do |space|
      space_type = space.spaceType.get
      #check Openstudio Standards database to get default constructions name and contructions
      #check to see if this default construction already exists.. if not create it.
      #Assign the default construction set directly to the space.
    end
  end
=end

  # this will create a copy and convert all construction sets to NECB reference conductances.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param self [OpenStudio::model::Model] A model object
  #@param default_surface_construction_set [String]
  #@return [Boolean] returns true if sucessful, false if not
  def set_construction_to_standard_conductance(default_surface_construction_set, runner = nil)
    BTAP::runner_register("Info", "set_construction_set_to_necb!", runner)
    if self.weatherFile.empty? or self.weatherFile.get.path.empty? or not File.exists?(self.weatherFile.get.path.get.to_s)

      BTAP::runner_register("Error", "Weather file is not defined. Please ensure the weather file is defined and exists.", runner)
      return false
    end
    hdd = BTAP::Environment::WeatherFile.new(self.weatherFile.get.path.get).hdd18
    old_name = default_surface_construction_set.name.get.to_s
    climate_zone_index = get_climate_zone_index()
    new_name = "#{old_name} at climate #{get_climate_zone_name()}"

    #convert conductance values to rsi values. (Note: we should really be only using conductances)
    wall_rsi = 1.0 / (standard_conductance('ExteriorWall'))
    floor_rsi = 1.0 / (standard_conductance('ExteriorFloor'))
    roof_rsi = 1.0 / (standard_conductance('GroundContactFloor'))
    ground_wall_rsi = 1.0 / (standard_conductance('GroundContactWall'))
    ground_floor_rsi = 1.0 / (standard_conductance('GroundContactFloor'))
    ground_roof_rsi = 1.0 / (standard_conductance('GroundContactRoof'))
    door_rsi = 1.0 / (standard_conductance('ExteriorDoor'))
    window_rsi = 1.0 / (standard_conductance('ExteriorWindow'))
    BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(self,
                                                                                                 new_name,
                                                                                                 default_surface_construction_set,
                                                                                                 wall_rsi,
                                                                                                 floor_rsi,
                                                                                                 roof_rsi,
                                                                                                 ground_wall_rsi,
                                                                                                 ground_floor_rsi,
                                                                                                 ground_roof_rsi,
                                                                                                 window_rsi,
                                                                                                 nil,
                                                                                                 nil,
                                                                                                 window_rsi,
                                                                                                 nil,
                                                                                                 nil,
                                                                                                 door_rsi,
                                                                                                 door_rsi,
                                                                                                 nil,
                                                                                                 nil,
                                                                                                 door_rsi,
                                                                                                 window_rsi,
                                                                                                 nil,
                                                                                                 nil,
                                                                                                 window_rsi,
                                                                                                 nil,
                                                                                                 nil,
                                                                                                 window_rsi,
                                                                                                 nil,
                                                                                                 nil
    )
    BTAP::runner_register("Info", "set_construction_set_to_necb! was sucessful.", runner)
    return true
  end

  # This method will convert in place(over write) a construction set to necb conductances.
  #@author phylroy.lopez@nrcan.gc.ca
  def set_all_constructions_to_standard_conductances!(runner = nil)
    self.getDefaultConstructionSets.each do |set|
      self.set_construction_to_standard_conductance(set, runner)
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    self.getPlanarSurfaces.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(self, nil)
  end

  def self.necb_spacetype_system_selection(heatingDesignLoad = nil, coolingDesignLoad = nil, runner = nil, building_type = nil)
    spacezoning_data = Struct.new(
        :space, # the space object
        :space_name, # the space name
        :building_type_name, # space type name
        :space_type_name, # space type name
        :necb_hvac_system_selection_type, #
        :system_number, # the necb system type
        :number_of_stories, #number of stories
        :horizontal_placement, # the horizontal placement (norht, south, east, west, core)
        :vertical_placment, # the vertical placement ( ground, top, both, middle )
        :people_obj, # Spacetype people object
        :heating_capacity,
        :cooling_capacity,
        :is_dwelling_unit, #Checks if it is a dwelling unit.
        :is_wildcard)


    #Array to store schedule objects
    schedule_type_array = []


    #find the number of stories in the model this include multipliers.
    number_of_stories = self.get_number_of_above_ground_floors(self, building_type, "NECB 2011", runner)
    #set up system array containers. These will contain the spaces associated with the system types.
    space_zoning_data_array = []

    #First pass of spaces to collect information into the space_zoning_data_array .
    self.getSpaces.each do |space|


      #this will get the spacetype system index 8.4.4.8A  from the SpaceTypeData and BuildingTypeData in  (1-12)
      space_system_index = nil
      if space.spaceType.empty?
        space_system_index = nil
      else
        #gets row information from standards spreadsheet.
        space_type_property = space.model.find_object($os_standards["space_types"], {"template" => 'NECB 2011', "space_type" => space.spaceType.get.standardsSpaceType.get, "building_type" => space.spaceType.get.standardsBuildingType.get})
        raise("could not find necb system selection type for space: #{space.name} and spacetype #{space.spaceType.get.standardsSpaceType.get}") if space_type_property.nil?
        #stores the Building or SpaceType System type name.
        necb_hvac_system_selection_type = space_type_property['necb_hvac_system_selection_type']
      end


      #Get the heating and cooling load for the space. Only Zones with a defined thermostat will have a load.
      #Make sure we don't have sideeffects by changing the argument variables.
      cooling_load = coolingDesignLoad
      heating_load = heatingDesignLoad
      if space.spaceType.get.standardsSpaceType.get == "- undefined -"
        cooling_load = 0.0
        heating_load = 0.0
      else
        cooling_load = space.thermalZone.get.coolingDesignLoad.get * space.floorArea * space.multiplier / 1000.0 if cooling_load.nil?
        heating_load = space.thermalZone.get.heatingDesignLoad.get * space.floorArea * space.multiplier / 1000.0 if heating_load.nil?
      end

      #identify space-system_index and assign the right NECB system type 1-7.
      system = nil
      is_dwelling_unit = false
      case necb_hvac_system_selection_type
        when nil
          raise ("#{space.name} does not have an NECB system association. Please define a NECB HVAC System Selection Type in the google docs standards database.")
        when 0, "- undefined -"
          #These are spaces are undefined...so they are unconditioned and have no loads other than infiltration and no systems
          system = 0
        when "Assembly Area" #Assembly Area.
          if number_of_stories <= 4
            system = 3
          else
            system = 6
          end

        when "Automotive Area"
          system = 4

        when "Data Processing Area"
          if coolingDesignLoad > 20 #KW...need a sizing run.
            system = 2
          else
            system = 1
          end

        when "General Area" #[3,6]
          if number_of_stories <= 2
            system = 3
          else
            system = 6
          end

        when "Historical Collections Area" #[2],
          system = 2

        when "Hospital Area" #[3],
          system = 3

        when "Indoor Arena" #,[7],
          system = 7

        when "Industrial Area" #  [3] this need some thought.
          system = 3

        when "Residential/Accomodation Area" #,[1], this needs some thought.
          system = 1
          is_dwelling_unit = true

        when "Sleeping Area" #[3],
          system = 3
          is_dwelling_unit = true

        when "Supermarket/Food Services Area" #[3,4],
          system = 3

        when "Supermarket/Food Services Area - vented"
          system = 4

        when "Warehouse Area"
          system = 4

        when "Warehouse Area - refrigerated"
          system = 5
        when "Wildcard"
          system = nil
          is_wildcard = true
        else
          raise ("NECB HVAC System Selection Type #{necb_hvac_system_selection_type} not valid")
      end
      #get placement on floor, core or perimeter and if a top, bottom, middle or single story.
      horizontal_placement, vertical_placement = BTAP::Geometry::Spaces::get_space_placement(space)
      #dump all info into an array for debugging and iteration.
      unless space.spaceType.empty?
        space_type_name = space.spaceType.get.standardsSpaceType.get
        building_type_name = space.spaceType.get.standardsBuildingType.get
        space_zoning_data_array << spacezoning_data.new(space,
                                                        space.name.get,
                                                        building_type_name,
                                                        space_type_name,
                                                        necb_hvac_system_selection_type,
                                                        system,
                                                        number_of_stories,
                                                        horizontal_placement,
                                                        vertical_placement,
                                                        space.spaceType.get.people,
                                                        heating_load,
                                                        cooling_load,
                                                        is_dwelling_unit,
                                                        is_wildcard
        )
        schedule_type_array << BTAP::Compliance::NECB2011::determine_necb_schedule_type(space).to_s
      end
    end


    return schedule_type_array.uniq!, space_zoning_data_array
  end

  # This method will take a model that uses NECB 2011 spacetypes , and..
  # 1. Create a building story schema.
  # 2. Remove all existing Thermal Zone defintions.
  # 3. Create new thermal zones based on the following definitions.
  # Rule1 all zones must contain only the same schedule / occupancy schedule.
  # Rule2 zones must cater to similar solar gains (N,E,S,W)
  # Rule3 zones must not pass from floor to floor. They must be contained to a single floor or level.
  # Rule4 Wildcard spaces will be associated with the nearest zone of similar schedule type in which is shared most of it's internal surface with.
  # Rule5 For NECB zones must contain spaces of similar system type only.
  # Rule6 Residential / dwelling units must not share systems with other space types.
  # @author phylroy.lopez@nrcan.gc.ca
  # @param self [OpenStudio::model::Model] A model object
  # @return [String] system_zone_array
  def necb_autozone_and_autosystem(
      runner = nil,
      use_ideal_air_loads = false,
      boiler_fueltype = "NaturalGas",
      mau_type = true,
      mau_heating_coil_type = "Hot Water",
      baseboard_type = "Hot Water",
      chiller_type = "Scroll",
      mua_cooling_type = "DX",
      heating_coil_types_sys3 = "Gas",
      heating_coil_types_sys4 = "Gas",
      heating_coil_types_sys6 = "Hot Water",
      fan_type = "AF_or_BI_rdg_fancurve",
      swh_fueltype = "NaturalGas",
      building_type = nil)

    #Create a data struct for the space to system to placement information.


    #system assignment.
    unless ["NaturalGas", "Electricity", "PropaneGas", "FuelOil#1", "FuelOil#2", "Coal", "Diesel", "Gasoline", "OtherFuel1"].include?(boiler_fueltype)
      BTAP::runner_register("ERROR", "boiler_fueltype = #{boiler_fueltype}", runner)
      return
    end

    unless [true, false].include?(mau_type)
      BTAP::runner_register("ERROR", "mau_type = #{mau_type}", runner)
      return
    end

    unless ["Hot Water", "Electric"].include?(mau_heating_coil_type)
      BTAP::runner_register("ERROR", "mau_heating_coil_type = #{mau_heating_coil_type}", runner)
      return false
    end

    unless ["Hot Water", "Electric"].include?(baseboard_type)
      BTAP::runner_register("ERROR", "baseboard_type = #{baseboard_type}", runner)
      return false
    end


    unless ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"].include?(chiller_type)
      BTAP::runner_register("ERROR", "chiller_type = #{chiller_type}", runner)
      return false
    end
    unless ["DX", "Hydronic"].include?(mua_cooling_type)
      BTAP::runner_register("ERROR", "mua_cooling_type = #{mua_cooling_type}", runner)
      return false
    end

    unless ["Electric", "Gas", "DX"].include?(heating_coil_types_sys3)
      BTAP::runner_register("ERROR", "heating_coil_types_sys3 = #{heating_coil_types_sys3}", runner)
      return false
    end

    unless ["Electric", "Gas", "DX"].include?(heating_coil_types_sys4)
      BTAP::runner_register("ERROR", "heating_coil_types_sys4 = #{heating_coil_types_sys4}", runner)
      return false
    end

    unless ["Hot Water", "Electric"].include?(heating_coil_types_sys6)
      BTAP::runner_register("ERROR", "heating_coil_types_sys6 = #{heating_coil_types_sys6}", runner)
      return false
    end

    unless ["AF_or_BI_rdg_fancurve", "AF_or_BI_inletvanes", "fc_inletvanes", "var_speed_drive"].include?(fan_type)
      BTAP::runner_register("ERROR", "fan_type = #{fan_type}", runner)
      return false
    end
    # REPEATED CODE!!
    unless ["Electric", "Hot Water"].include?(heating_coil_types_sys6)
      BTAP::runner_register("ERROR", "heating_coil_types_sys6 = #{heating_coil_types_sys6}", runner)
      return false
    end
    # REPEATED CODE!!
    unless ["Electric", "Gas"].include?(heating_coil_types_sys4)
      BTAP::runner_register("ERROR", "heating_coil_types_sys4 = #{heating_coil_types_sys4}", runner)
      return false
    end

    # Ensure that floors have been assigned by user.
    raise("No building stories have been defined.. User must define building stories and spaces in model.") unless self.getBuildingStorys.size > 0
    #BTAP::Geometry::BuildingStoreys::auto_assign_stories(model)

    #this method will determine the spaces that should be set to each system
    schedule_type_array, space_zoning_data_array = self.necb_spacetype_system_selection(nil, nil, runner, building_type)

    #Deal with Wildcard spaces. Might wish to have logic to do coridors first.
    space_zoning_data_array.each do |space_zone_data|
      #If it is a wildcard space.
      if space_zone_data.system_number.nil?
        #iterate through all adjacent spaces from largest shared wall area to smallest.
        # Set system type to match first space system that is not nil.
        adj_spaces = space_zone_data.space.get_adjacent_spaces_with_shared_wall_areas(true)
        if adj_spaces.nil?
          puts ("Warning: No adjacent spaces for #{space_zone_data.space.name} on same floor, looking for others above and below to set system")
          adj_spaces = space_zone_data.space.get_adjacent_spaces_with_shared_wall_areas(false)
        end
        adj_spaces.each do |adj_space|
          #if there are no adjacent spaces. Raise an error.
          raise ("Could not determine adj space to space #{space_zone_data.space.name.get}") if adj_space.nil?
          adj_space_data = space_zoning_data_array.find {|data| data.space == adj_space[0]}
          if adj_space_data.system_number.nil?
            next
          else
            space_zone_data.system_number = adj_space_data.system_number
            break
          end
        end
        raise ("Could not determine adj space system to space #{space_zone_data.space.name.get}") if space_zone_data.system_number.nil?
      end
    end


    #remove any thermal zones used for sizing to start fresh. Should only do this after the above system selection method.
    self.getThermalZones.each {|zone| zone.remove}


    #now lets apply the rules.
    # Rule1 all zones must contain only the same schedule / occupancy schedule.
    # Rule2 zones must cater to similar solar gains (N,E,S,W)
    # Rule3 zones must not pass from floor to floor. They must be contained to a single floor or level.
    # Rule4 Wildcard spaces will be associated with the nearest zone of similar schedule type in which is shared most of it's internal surface with.
    # Rule5 NECB zones must contain spaces of similar system type only.
    # Rule6 Multiplier zone will be part of the floor and orientation of the base space.
    # Rule7 Residential / dwelling units must not share systems with other space types.
    #Array of system types of Array of Spaces
    system_zone_array = []
    #Lets iterate by system
    (0..7).each do |system_number|
      system_zone_array[system_number] = []
      #iterate by story
      story_counter = 0
      self.getBuildingStorys.each do |story|
        #puts "Story:#{story}"
        story_counter = story_counter + 1
        #iterate by operation schedule type.
        schedule_type_array.each do |schedule_type|
          #iterate by horizontal location
          ["north", "east", "west", "south", "core"].each do |horizontal_placement|
            #puts "horizontal_placement:#{horizontal_placement}"
            [true, false].each do |is_dwelling_unit|
              space_array = Array.new
              space_zoning_data_array.each do |space_info|
                #puts "Spacename: #{space_info.space.name}:#{space_info.space.spaceType.get.name}"
                if space_info.system_number == system_number and
                    space_info.space.buildingStory.get == story and
                    BTAP::Compliance::NECB2011::determine_necb_schedule_type(space_info.space).to_s == schedule_type and
                    space_info.horizontal_placement == horizontal_placement and
                    space_info.is_dwelling_unit == is_dwelling_unit
                  space_array << space_info.space
                end
              end

              #create Thermal Zone if space_array is not empty.
              if space_array.size > 0
                # Process spaces that have multipliers associated with them first.
                # This map define the multipliers for spaces with multipliers not equals to 1
                space_multiplier_map = {}
                # This map define the multipliers for spaces with multipliers not equals to 1
                case building_type
                  when 'LargeHotel'
                    space_multiplier_map = PrototypeBuilding::LargeHotel.define_space_multiplier
                  when 'MidriseApartment'
                    space_multiplier_map = PrototypeBuilding::MidriseApartment.define_space_multiplier
                  when 'LargeOffice'
                    space_multiplier_map = PrototypeBuilding::LargeOffice.define_space_multiplier
                  when 'Hospital'
                    space_multiplier_map = PrototypeBuilding::Hospital.define_space_multiplier
                  else
                    space_multiplier_map = {}
                end
                #create new zone and add the spaces to it.
                space_array.each do |space|
                  # Create thermalzone for each space.
                  thermal_zone = OpenStudio::Model::ThermalZone.new(self)
                  # Create a more informative space name.
                  thermal_zone.setName("Sp-#{space.name} Sys-#{system_number.to_s} Flr-#{story_counter.to_s} Sch-#{schedule_type.to_s} HPlcmt-#{horizontal_placement} ZN")
                  # Add zone mulitplier if required.
                  thermal_zone.setMultiplier(space_multiplier_map[space.name.to_s]) unless space_multiplier_map[space.name.to_s].nil?
                  # Space to thermal zone. (for archetype work it is one to one)
                  space.setThermalZone(thermal_zone)
                  # Get thermostat for space type if it already exists.
                  space_type_name = space.spaceType.get.name.get
                  thermostat_name = space_type_name + ' Thermostat'
                  thermostat = self.getThermostatSetpointDualSetpointByName(thermostat_name)
                  if thermostat.empty?
                    OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name} ZN")
                    raise (" Thermostat #{thermostat_name} not found for space name: #{space.name}")
                  else
                    thermostatClone = thermostat.get.clone(self).to_ThermostatSetpointDualSetpoint.get
                    thermal_zone.setThermostatSetpointDualSetpoint(thermostatClone)
                  end
                  # Add thermal to zone system number.
                  system_zone_array[system_number] << thermal_zone
                end
              end
            end
          end
        end
      end
    end #system iteration

    #Create and assign the zones to the systems.
    unless use_ideal_air_loads == true
      hw_loop_needed = false
      system_zone_array.each_with_index do |zones, system_index|
        next if zones.size == 0
        if (system_index == 1 && (mau_heating_coil_type == 'Hot Water' || baseboard_type == 'Hot Water'))
          hw_loop_needed = true
        elsif (system_index == 2 || system_index == 5 || system_index == 7)
          hw_loop_needed = true
        elsif ((system_index == 3 || system_index == 4) && baseboard_type == 'Hot Water')
          hw_loop_needed = true
        elsif (system_index == 6 && (mau_heating_coil_type == 'Hot Water' || baseboard_type == 'Hot Water'))
          hw_loop_needed = true
        end
        if (hw_loop_needed) then
          break
        end
      end
      if (hw_loop_needed)
        hw_loop = OpenStudio::Model::PlantLoop.new(self)
        always_on = self.alwaysOnDiscreteSchedule
        BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(self, hw_loop, boiler_fueltype, always_on)
      end
      system_zone_array.each_with_index do |zones, system_index|
        #skip if no thermal zones for this system.
        next if zones.size == 0
        #            puts "Zone Names for System #{system_index}"
        #            puts "system_index = #{system_index}"
        case system_index
          when 0, nil
            #Do nothing no system assigned to zone. Used for Unconditioned spaces
          when 1
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(self, zones, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, hw_loop)
          when 2
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(self, zones, boiler_fueltype, chiller_type, mua_cooling_type, hw_loop)
          when 3
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys3(self, zones, boiler_fueltype, heating_coil_types_sys3, baseboard_type, hw_loop)
          when 4
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys4(self, zones, boiler_fueltype, heating_coil_types_sys4, baseboard_type, hw_loop)
          when 5
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys5(self, zones, boiler_fueltype, chiller_type, mua_cooling_type, hw_loop)
          when 6
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys6(self, zones, boiler_fueltype, heating_coil_types_sys6, baseboard_type, chiller_type, fan_type, hw_loop)
          when 7
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys7(self, zones, boiler_fueltype, chiller_type, mua_cooling_type, hw_loop)
        end
      end
    else
      #otherwise use ideal loads.
      self.getThermalZones.each do |thermal_zone|
        thermal_zone_ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(self)
        thermal_zone_ideal_loads.addToThermalZone(thermal_zone)
      end
    end
    #Check to ensure that all spaces are assigned to zones except undefined ones.
    errors = []
    self.getSpaces.each do |space|
      if space.thermalZone.empty? and space.spaceType.get.name.get != 'Space Function - undefined -'
        errors << "space #{space.name} with spacetype #{space.spaceType.get.name.get} was not assigned a thermalzone."
      end
    end
    if errors.size > 0
      raise(" #{errors}")
    end
  end

end



