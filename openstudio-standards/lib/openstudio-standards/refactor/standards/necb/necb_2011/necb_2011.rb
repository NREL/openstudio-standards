class NECB_2011_Model < StandardsModel
  @@template = 'NECB 2011'
  register_standard (@@template)
  attr_reader :instvartemplate

  def initialize
    super()
    @instvartemplate = @@template
    #NECB Values
    @standards_data = {}
    @standards_data["coolingSizingFactor"] = 1.3
    @standards_data["heatingSizingFactor"] = 1.3
    @standards_data["conductances"] = {}
    @standards_data["conductances"]["Wall"] = [
        {"thermal_transmittance" => 0.315, "hdd" => 3000},
        {"thermal_transmittance" => 0.278, "hdd" => 3999},
        {"thermal_transmittance" => 0.247, "hdd" => 4999},
        {"thermal_transmittance" => 0.210, "hdd" => 5999},
        {"thermal_transmittance" => 0.210, "hdd" => 6999},
        {"thermal_transmittance" => 0.183, "hdd" => 999999}]
    @standards_data["conductances"]["Roof"] = [
        {"thermal_transmittance" => 0.227, "hdd" => 3000},
        {"thermal_transmittance" => 0.183, "hdd" => 3999},
        {"thermal_transmittance" => 0.183, "hdd" => 4999},
        {"thermal_transmittance" => 0.162, "hdd" => 5999},
        {"thermal_transmittance" => 0.162, "hdd" => 6999},
        {"thermal_transmittance" => 0.142, "hdd" => 999999}]
    @standards_data["conductances"]["Floor"] = [
        {"thermal_transmittance" => 0.227, "hdd" => 3000},
        {"thermal_transmittance" => 0.183, "hdd" => 3999},
        {"thermal_transmittance" => 0.183, "hdd" => 4999},
        {"thermal_transmittance" => 0.162, "hdd" => 5999},
        {"thermal_transmittance" => 0.162, "hdd" => 6999},
        {"thermal_transmittance" => 0.142, "hdd" => 999999}]
    @standards_data["conductances"]["Window"] = [
        {"thermal_transmittance" => 2.400, "hdd" => 3000},
        {"thermal_transmittance" => 2.200, "hdd" => 3999},
        {"thermal_transmittance" => 2.200, "hdd" => 4999},
        {"thermal_transmittance" => 2.200, "hdd" => 5999},
        {"thermal_transmittance" => 2.200, "hdd" => 6999},
        {"thermal_transmittance" => 1.600, "hdd" => 999999}]
    @standards_data["conductances"]["Door"] = [
        {"thermal_transmittance" => 2.400, "hdd" => 3000},
        {"thermal_transmittance" => 2.200, "hdd" => 3999},
        {"thermal_transmittance" => 2.200, "hdd" => 4999},
        {"thermal_transmittance" => 2.200, "hdd" => 5999},
        {"thermal_transmittance" => 2.200, "hdd" => 6999},
        {"thermal_transmittance" => 1.600, "hdd" => 999999}]
    @standards_data["conductances"]["GroundWall"] = [
        {"thermal_transmittance" => 0.568, "hdd" => 3000},
        {"thermal_transmittance" => 0.379, "hdd" => 3999},
        {"thermal_transmittance" => 0.284, "hdd" => 4999},
        {"thermal_transmittance" => 0.284, "hdd" => 5999},
        {"thermal_transmittance" => 0.284, "hdd" => 6999},
        {"thermal_transmittance" => 0.210, "hdd" => 999999}]
    @standards_data["conductances"]["GroundRoof"] = [
        {"thermal_transmittance" => 0.568, "hdd" => 3000},
        {"thermal_transmittance" => 0.379, "hdd" => 3999},
        {"thermal_transmittance" => 0.284, "hdd" => 4999},
        {"thermal_transmittance" => 0.284, "hdd" => 5999},
        {"thermal_transmittance" => 0.284, "hdd" => 6999},
        {"thermal_transmittance" => 0.210, "hdd" => 999999}]
    @standards_data["conductances"]["GroundFloor"] = [
        {"thermal_transmittance" => 0.757, "hdd" => 3000},
        {"thermal_transmittance" => 0.757, "hdd" => 3999},
        {"thermal_transmittance" => 0.757, "hdd" => 4999},
        {"thermal_transmittance" => 0.757, "hdd" => 5999},
        {"thermal_transmittance" => 0.757, "hdd" => 6999},
        {"thermal_transmittance" => 0.379, "hdd" => 999999}]
    @standards_data["fan_variable_volume_pressure_rise"] = 1458.33
    @standards_data["fan_constant_volume_pressure_rise"] =  640.00
  end



  def model_add_hvac(model, building_type, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    boiler_fueltype, baseboard_type, mau_type, mau_heating_coil_type, mua_cooling_type, chiller_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type, swh_fueltype = BTAP::Environment.get_canadian_system_defaults_by_weatherfile_name(epw_file)
    self.necb_autozone_and_autosystem(model, nil, false, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, chiller_type, mua_cooling_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type, swh_fueltype)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end

  def necb_spacetype_system_selection(model, heatingDesignLoad = nil, coolingDesignLoad = nil)
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
    number_of_stories = model.getBuilding.standardsNumberOfAboveGroundStories()
    if number_of_stories.empty?
      raise ("Number of above ground stories not present in geometry model. Please ensure this is defined in your Building Object")
    else
      number_of_stories = number_of_stories.get
    end

    #set up system array containers. These will contain the spaces associated with the system types.
    space_zoning_data_array = []

    #First pass of spaces to collect information into the space_zoning_data_array .
    model.getSpaces.sort.each do |space|


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
        schedule_type_array << determine_necb_schedule_type(space).to_s
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
  # @param model [OpenStudio::model::Model] A model object
  # @return [String] system_zone_array
  def necb_autozone_and_autosystem(
      model = nil,
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
      swh_fueltype = "NaturalGas")

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
    raise("No building stories have been defined.. User must define building stories and spaces in model.") unless model.getBuildingStorys.size > 0
    #BTAP::Geometry::BuildingStoreys::auto_assign_stories(model)

    #this method will determine the spaces that should be set to each system
    schedule_type_array, space_zoning_data_array = necb_spacetype_system_selection(model, nil, nil)

    #Deal with Wildcard spaces. Might wish to have logic to do coridors first.
    space_zoning_data_array.sort {|obj1, obj2| obj1.space_name <=> obj2.space_name}.each do |space_zone_data|
      #If it is a wildcard space.
      if space_zone_data.system_number.nil?
        #iterate through all adjacent spaces from largest shared wall area to smallest.
        # Set system type to match first space system that is not nil.
        adj_spaces = space_zone_data.space.get_adjacent_spaces_with_shared_wall_areas(true)
        if adj_spaces.nil?
          puts ("Warning: No adjacent spaces for #{space_zone_data.space.name} on same floor, looking for others above and below to set system")
          adj_spaces = space_zone_data.space.get_adjacent_spaces_with_shared_wall_areas(false)
        end
        adj_spaces.sort.each do |adj_space|
          #if there are no adjacent spaces. Raise an error.
          raise ("Could not determine adj space to space #{space_zone_data.space.name.get}") if adj_space.nil?
          adj_space_data = space_zoning_data_array.find {|data| data.space == adj_space[0]}
          if adj_space_data.system_number.nil?
            next
          else
            space_zone_data.system_number = adj_space_data.system_number
            puts "#{space_zone_data.space.name.get}"
            break
          end
        end
        raise ("Could not determine adj space system to space #{space_zone_data.space.name.get}") if space_zone_data.system_number.nil?
      end
    end


    #remove any thermal zones used for sizing to start fresh. Should only do this after the above system selection method.
    model.getThermalZones.sort.each {|zone| zone.remove}


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
      model.getBuildingStorys.sort.each do |story|
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
                    self.determine_necb_schedule_type(space_info.space).to_s == schedule_type and
                    space_info.horizontal_placement == horizontal_placement and
                    space_info.is_dwelling_unit == is_dwelling_unit
                  space_array << space_info.space
                end
              end

              #create Thermal Zone if space_array is not empty.
              if space_array.size > 0
                # Process spaces that have multipliers associated with them first.
                # This map define the multipliers for spaces with multipliers not equals to 1
                space_multiplier_map = @space_multiplier_map

                #create new zone and add the spaces to it.
                space_array.each do |space|
                  # Create thermalzone for each space.
                  thermal_zone = OpenStudio::Model::ThermalZone.new(model)
                  # Create a more informative space name.
                  thermal_zone.setName("Sp-#{space.name} Sys-#{system_number.to_s} Flr-#{story_counter.to_s} Sch-#{schedule_type.to_s} HPlcmt-#{horizontal_placement} ZN")
                  # Add zone mulitplier if required.
                  thermal_zone.setMultiplier(space_multiplier_map[space.name.to_s]) unless space_multiplier_map[space.name.to_s].nil?
                  # Space to thermal zone. (for archetype work it is one to one)
                  space.setThermalZone(thermal_zone)
                  # Get thermostat for space type if it already exists.
                  space_type_name = space.spaceType.get.name.get
                  thermostat_name = space_type_name + ' Thermostat'
                  thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
                  if thermostat.empty?
                    OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name} ZN")
                    raise (" Thermostat #{thermostat_name} not found for space name: #{space.name}")
                  else
                    thermostatClone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
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
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
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
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(model, zones, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, hw_loop)
          when 2
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(model, zones, boiler_fueltype, chiller_type, mua_cooling_type)
          when 3
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys3(model, zones, boiler_fueltype, heating_coil_types_sys3, baseboard_type, hw_loop)
          when 4
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys4(model, zones, boiler_fueltype, heating_coil_types_sys4, baseboard_type, hw_loop)
          when 5
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys5(model, zones, boiler_fueltype, chiller_type, mua_cooling_type)
          when 6
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys6(model, zones, boiler_fueltype, heating_coil_types_sys6, baseboard_type, chiller_type, fan_type, hw_loop)
          when 7
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys7(model, zones, boiler_fueltype, chiller_type, mua_cooling_type)
        end
      end
    else
      #otherwise use ideal loads.
      model.getThermalZones.sort.each do |thermal_zone|
        thermal_zone_ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        thermal_zone_ideal_loads.addToThermalZone(thermal_zone)
      end
    end
    #Check to ensure that all spaces are assigned to zones except undefined ones.
    errors = []
    model.getSpaces.sort.each do |space|
      if space.thermalZone.empty? and space.spaceType.get.name.get != 'Space Function - undefined -'
        errors << "space #{space.name} with spacetype #{space.spaceType.get.name.get} was not assigned a thermalzone."
      end
    end
    if errors.size > 0
      raise(" #{errors}")
    end
  end

  #


  #This method ???.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param hdd [Float]
  #@return [Double] a constant float
  def max_fwdr(hdd)
    #NECB 3.2.1.4

    if hdd < 4000
      return 0.40
    elsif hdd >= 4000 and hdd <=7000
      return (2000-0.2 * hdd)/3000
    elsif hdd >7000
      return 0.20
    end
  end

  # This method will set the the envelope (wall, roof, glazings) to  values to
  # the default NECB 2011 values based on the heating degree day value (hdd) surface by surface.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param hdd [Float]
  def set_necb_envelope(model, runner=nil)

    BTAP::runner_register("Info", "set_envelope_surfaces_to_necb!", runner)
    if model.weatherFile.empty? or model.weatherFile.get.path.empty? or not File.exists?(model.weatherFile.get.path.get.to_s)

      BTAP::runner_register("Error", "Weather file is not defined. Please ensure the weather file is defined and exists.", runner)
      return false
    end
    hdd = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get).hdd18

    #interate Through all surfaces
    model.getSurfaces.sort.each do |surface|
      #set fenestration to wall ratio.
      self.set_necb_external_surface_conductance(surface, hdd, false, 1.0)

      #dig into the subsurface and change them as well.
      model.getSubSurfaces.sort.each do |subsurface|
        self.set_necb_external_subsurface_conductance(subsurface, hdd)
      end
    end
  end

  # this will create a copy and convert all construction sets to NECB reference conductances.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param default_surface_construction_set [String]
  #@return [Boolean] returns true if sucessful, false if not
  def set_construction_set_to_necb!(model, default_surface_construction_set,
      runner = nil,
      scale_wall = 1.0,
      scale_floor = 1.0,
      scale_roof = 1.0,
      scale_ground_wall = 1.0,
      scale_ground_floor = 1.0,
      scale_ground_roof = 1.0,
      scale_door = 1.0,
      scale_window = 1.0
  )
    BTAP::runner_register("Info", "set_construction_set_to_necb!", runner)
    if model.weatherFile.empty? or model.weatherFile.get.path.empty? or not File.exists?(model.weatherFile.get.path.get.to_s)

      BTAP::runner_register("Error", "Weather file is not defined. Please ensure the weather file is defined and exists.", runner)
      return false
    end
    hdd = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get).hdd18

    old_name = default_surface_construction_set.name.get.to_s


    climate_zone_index = get_climate_zone_index(hdd)
    new_name = "#{old_name} at climate #{get_climate_zone_name(hdd)}"

    #convert conductance values to rsi values. (Note: we should really be only using conductances in)
    wall_rsi = 1.0 / (scale_wall * @standards_data["conductances"]["Wall"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    floor_rsi = 1.0 / (scale_floor * @standards_data["conductances"]["Floor"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    roof_rsi = 1.0 / (scale_roof * @standards_data["conductances"]["Roof"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    ground_wall_rsi = 1.0 / (scale_ground_wall *  @standards_data["conductances"]["GroundWall"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    ground_floor_rsi = 1.0 / (scale_ground_floor *  @standards_data["conductances"]["GroundFloor"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    ground_roof_rsi = 1.0 / (scale_ground_roof *  @standards_data["conductances"]["GroundRoof"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    door_rsi = 1.0 / (scale_door * @standards_data["conductances"]["Door"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    window_rsi = 1.0 / (scale_window * @standards_data["conductances"]["Window"].find {|i| i["hdd"] > hdd }["thermal_transmittance"])
    BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(model, new_name, default_surface_construction_set,
                                                                                                 wall_rsi, floor_rsi, roof_rsi,
                                                                                                 ground_wall_rsi, ground_floor_rsi, ground_roof_rsi,
                                                                                                 window_rsi, nil, nil,
                                                                                                 window_rsi, nil, nil,
                                                                                                 door_rsi,
                                                                                                 door_rsi, nil, nil,
                                                                                                 door_rsi,
                                                                                                 window_rsi, nil, nil,
                                                                                                 window_rsi, nil, nil,
                                                                                                 window_rsi, nil, nil
    )
    BTAP::runner_register("Info", "set_construction_set_to_necb! was sucessful.", runner)
    return true
  end

  # This method will convert in place(over write) a construction set to necb conductances.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param scale_wall [Float]
  #@param scale_floor [Float]
  #@param scale_roof [Float]
  #@param scale_ground_wall [Float]
  #@param scale_ground_floor [Float]
  #@param scale_ground_roof [Float]
  #@param scale_door [Float]
  #@param scale_window [Float]
  def set_all_construction_sets_to_necb!(model,
      runner = nil,
      scale_wall = 1.0,
      scale_floor = 1.0,
      scale_roof = 1.0,
      scale_ground_wall = 1.0,
      scale_ground_floor = 1.0,
      scale_ground_roof = 1.0,
      scale_door = 1.0,
      scale_window = 1.0)

    model.getDefaultConstructionSets.sort.each do |set|
      self.set_construction_set_to_necb!(model,
                                         set,
                                         runner,
                                         scale_wall,
                                         scale_floor,
                                         scale_roof,
                                         scale_ground_wall,
                                         scale_ground_floor,
                                         scale_ground_roof,
                                         scale_door,
                                         scale_window)
    end
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    model.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(model, nil)
  end

  #This model gets the climate zone column index from tables 3.2.2.x
  #@author phylroy.lopez@nrcan.gc.ca
  #@param hdd [Float]
  #@return [Fixnum] climate zone 4-8
  def get_climate_zone_index(hdd)
    #check for climate zone index from NECB 3.2.2.X
    case hdd
      when 0..2999 then
        return 0 #climate zone 4
      when 3000..3999 then
        return 1 #climate zone 5
      when 4000..4999 then
        return 2 #climate zone 6
      when 5000..5999 then
        return 3 #climate zone 7a
      when 6000..6999 then
        return 4 #climate zone 7b
      when 7000..1000000 then
        return 5 #climate zone 8
    end
  end

  #This model gets the climate zone name and returns the climate zone string.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param hdd [Float]
  #@return [Fixnum] climate zone 4-8
  def get_climate_zone_name(hdd)
    case self.get_climate_zone_index(hdd)
      when 0 then
        return "4"
      when 1 then
        return "5" #climate zone 5
      when 2 then
        return "6" #climate zone 6
      when 3 then
        return "7a" #climate zone 7a
      when 4 then
        return "7b" #climate zone 7b
      when 5 then
        return "8" #climate zone 8
    end
  end

  #Set all external surface conductances to NECB values.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param surface [String]
  #@param hdd [Float]
  #@param is_radiant [Boolian]
  #@param scaling_factor [Float]
  #@return [String] surface as RSI
  def set_necb_external_surface_conductance(surface, hdd, is_radiant = false, scaling_factor = 1.0)
    conductance_value = 0
    climate_zone_index = self.get_climate_zone_index(hdd)

    if surface.outsideBoundaryCondition.downcase == "outdoors"

      case surface.surfaceType.downcase
        when "wall"
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::Wall[climate_zone_index] * scaling_factor
        when "floor"
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::Floor[climate_zone_index] * scaling_factor
        when "roofceiling"
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::Roof[climate_zone_index]
      end
      if (is_radiant)
        conductance_value = conductance_value * 0.80
      end
      return BTAP::Geometry::Surfaces::set_surfaces_construction_conductance([surface], conductance_value)
    end


    if surface.outsideBoundaryCondition.downcase.match(/ground/)
      case surface.surfaceType.downcase
        when "wall"
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::GroundWall[self.get_climate_zone_index(@hdd)]
        when "floor"
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::GroundFloor[self.get_climate_zone_index(@hdd)]
        when "roofceiling"
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::GroundRoof[self.get_climate_zone_index(@hdd)]
      end
      if (is_radiant)
        conductance_value = conductance_value * 0.80
      end
      return BTAP::Geometry::Surfaces::set_surfaces_construction_conductance([surface], conductance_value)

    end
  end

  #Set all external subsurfaces (doors, windows, skylights) to NECB values.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param subsurface [String]
  #@param hdd [Float]
  def set_necb_external_subsurface_conductance(subsurface, hdd)
    conductance_value = 0
    climate_zone_index = get_climate_zone_index(hdd)
    if subsurface.outsideBoundaryCondition.downcase.match("outdoors")
      case subsurface.subSurfaceType.downcase
        when /window/
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductances::Window[climate_zone_index]
        when /door/
          conductance_value = BTAP::Compliance::NECB2011::Data::Conductance::Door[climate_zone_index]
      end
      subsurface.setRSI(1/conductance_value)
    end
  end


  def set_wildcard_schedules_to_dominant_building_schedule(model, runner = nil)

    new_sched_ruleset = OpenStudio::Model::DefaultScheduleSet.new(model) #initialize
    BTAP::runner_register("Info", "set_wildcard_schedules_to_dominant_building_schedule", runner)
    #Set wildcard schedules based on dominant schedule type in building.
    dominant_sched_type = self.determine_dominant_necb_schedule_type(model)
    #puts "dominant_sched_type = #{dominant_sched_type}"
    # find schedule set that corresponds to dominant schedule type
    model.getDefaultScheduleSets.sort.each do |sched_ruleset|
      # just check people schedule
      # TO DO: should make this smarter: check all schedules
      people_sched = sched_ruleset.numberofPeopleSchedule
      people_sched_name = people_sched.get.name.to_s unless people_sched.empty?

      search_string = "NECB-#{dominant_sched_type}"

      if people_sched.empty? == false
        if people_sched_name.include? search_string
          new_sched_ruleset = sched_ruleset
        end
      end
    end

    # replace the default schedule set for the space type with * to schedule ruleset with dominant schedule type

    model.getSpaces.sort.each do |space|
      #check to see if space space type has a "*" wildcard schedule.
      spacetype_name = space.spaceType.get.name.to_s unless space.spaceType.empty?
      if determine_necb_schedule_type(space).to_s == "*".to_s
        new_sched = (spacetype_name).to_s
        optional_spacetype = model.getSpaceTypeByName(new_sched)
        if optional_spacetype.empty?
          BTAP::runner_register("Error", "Cannot find NECB spacetype #{new_sched}", runner)
        else
          BTAP::runner_register("Info", "Setting wildcard spacetype #{spacetype_name} default schedule set to #{new_sched_ruleset.name}", runner)
          optional_spacetype.get.setDefaultScheduleSet(new_sched_ruleset) #this works!
        end
      end
    end # end of do |space|

    return true
  end

  def set_zones_thermostat_schedule_based_on_space_type_schedules(model, runner = nil)
    puts "in set_zones_thermostat_schedule_based_on_space_type_schedules"
    BTAP::runner_register("DEBUG", "Start-set_zones_thermostat_schedule_based_on_space_type_schedules", runner)
    model.getThermalZones.sort.each do |zone|
      BTAP::runner_register("DEBUG", "Zone = #{zone.name} Spaces =#{zone.spaces.size} ", runner)
      array = []

      zone.spaces.sort.each do |space|
        schedule_type = self.determine_necb_schedule_type(space).to_s
        BTAP::runner_register("DEBUG", "space name/type:#{space.name}/#{schedule_type}", runner)

        # if wildcard space type, need to get dominant schedule type
        if "*".to_s == schedule_type
          dominant_sched_type = self.determine_dominant_necb_schedule_type(model)
          schedule_type = dominant_sched_type
        end

        array << schedule_type
      end
      array.uniq!
      if array.size > 1
        BTAP::runner_register("Error", "#{zone.name} has spaces with different schedule types. Please ensure that all the spaces are of the same schedule type A to I.", runner)
        return false
      end


      htg_search_string = "NECB-#{array[0]}-Thermostat Setpoint-Heating"
      clg_search_string = "NECB-#{array[0]}-Thermostat Setpoint-Cooling"

      if model.getScheduleRulesetByName(htg_search_string).empty? == false
        htg_sched = model.getScheduleRulesetByName(htg_search_string).get
      else
        BTAP::runner_register("ERROR", "heating_thermostat_setpoint_schedule NECB-#{array[0]} does not exist", runner)
        return false
      end

      if model.getScheduleRulesetByName(clg_search_string).empty? == false
        clg_sched = model.getScheduleRulesetByName(clg_search_string).get
      else
        BTAP::runner_register("ERROR", "cooling_thermostat_setpoint_schedule NECB-#{array[0]} does not exist", runner)
        return false
      end

      name = "NECB-#{array[0]}-Thermostat Dual Setpoint Schedule"

      # If dual setpoint already exists, use that one, else create one
      if model.getThermostatSetpointDualSetpointByName(name).empty? == false
        ds = model.getThermostatSetpointDualSetpointByName(name).get
      else
        ds = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model, name, htg_sched, clg_sched)
      end

      thermostatClone = ds.clone.to_ThermostatSetpointDualSetpoint.get
      zone.setThermostatSetpointDualSetpoint(thermostatClone)
      BTAP::runner_register("Info", "ThermalZone #{zone.name} set to DualSetpoint Schedule NECB-#{array[0]}", runner)

    end

    BTAP::runner_register("DEBUG", "END-set_zones_thermostat_schedule_based_on_space_type_schedules", runner)
    return true
  end

  # This method confirms if the type is the proper space type
  #@author phylroy.lopez@nrcan.gc.ca
  #@param type [String]
  #@return  [String] item
  def is_proper_spacetype(type)
    BTAP::Compliance::NECB2011::Data::SpaceTypeData.each do |item|
      if item[0] == type
        return item
      end
    end
    return false
  end

  #This model determines the dominant NECB schedule type
  #@param model [OpenStudio::model::Model] A model object
  #return s.each [String]
  def determine_dominant_necb_schedule_type(model)
    # lookup necb space type properties
    space_type_properties = model.find_objects($os_standards["space_types"], {"template" => 'NECB 2011'})

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
    model.getSpaces.sort.each do |space|
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
    raise("Only wildcard spaces in model. You need to define the actual spaces. ") if wildcard_spaces == model.getSpaces.size
    dominant_schedule = s.each {|k, v| return k.to_s if v == s.values.max}
    return dominant_schedule
  end

  #This method determines the spacetype schedule type. This will re
  #@author phylroy.lopez@nrcan.gc.ca
  #@param space [String]
  #@return [String]:["A","B","C","D","E","F","G","H","I"] spacetype
  def determine_necb_schedule_type(space)
    raise ("Undefined spacetype for space #{space.get.name}) if space.spaceType.empty?") if space.spaceType.empty?
    raise ("Undefined standardsSpaceType or StandardsBuildingType for space #{space.spaceType.get.name}) if space.spaceType.empty?") if space.spaceType.get.standardsSpaceType.empty? | space.spaceType.get.standardsBuildingType.empty?
    space_type_properties = space.model.find_object($os_standards["space_types"], {"template" => 'NECB 2011', "space_type" => space.spaceType.get.standardsSpaceType.get, "building_type" => space.spaceType.get.standardsBuildingType.get})
    return space_type_properties['necb_schedule_type'].strip
  end

  # Determine whether or not water fixtures are attached to spaces
  def model_attach_water_fixtures_to_spaces?(model)
    return true
  end

  def model_apply_sizing_parameters(model)
    model.getSizingParameters.setHeatingSizingFactor(@standards_data["coolingSizingFactor"])
    model.getSizingParameters.setCoolingSizingFactor(@standards_data["heatingSizingFactor"])
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set sizing factors to #{@standards_data["heatingSizingFactor"]} for heating and #{@standards_data["coolingSizingFactor"]} for cooling.")
  end

  def fan_constant_volume_apply_prototype_fan_pressure_rise(fan_constant_volume)
    fan_constant_volume.setPressureRise(@standards_data["fan_constant_volume_pressure_rise"])
    return true
  end

  # Sets the fan pressure rise based on the Prototype buildings inputs
  # which are governed by the flow rate coming through the fan
  # and whether the fan lives inside a unit heater, PTAC, etc.
  def fan_variable_volume_apply_prototype_fan_pressure_rise(fan_variable_volume)
    # 1000 Pa for supply fan and 458.33 Pa for return fan (accounts for efficiency differences between two fans)
    fan_variable_volume.setPressureRise(@standards_data["fan_variable_volume_pressure_rise"])
    return true
  end

  def apply_economizers(climate_zone, model)

    # NECB 2011 prescribes ability to provide 100% OA (5.2.2.7-5.2.2.9)
    econ_max_100_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    econ_max_100_pct_oa_sch.setName('Economizer Max OA Fraction 100 pct')
    econ_max_100_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 100 pct Default')
    econ_max_100_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)

    # Check each airloop
    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop_hvac_economizer_required?(air_loop) == true
        # If an economizer is required, determine the economizer type
        # in the prototype buildings, which depends on climate zone.
        economizer_type = nil

            # NECB 5.2.2.8 states that economizer can be controlled based on difference betweeen
            # return air temperature and outside air temperature OR return air enthalpy
            # and outside air enthalphy; latter chosen to be consistent with MNECB and CAN-QUEST implementation
            economizer_type = 'DifferentialEnthalpy'
        # Set the economizer type
        # Get the OA system and OA controller
        oa_sys = air_loop.airLoopHVACOutdoorAirSystem
        if oa_sys.is_initialized
          oa_sys = oa_sys.get
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but it has no OA system.")
          next
        end
        oa_control = oa_sys.getControllerOutdoorAir
        oa_control.setEconomizerControlType(economizer_type)
      end
    end
  end



  # Go through the default construction sets and hard-assigned
  # constructions. Clone the existing constructions and set their
  # intended surface type and standards construction type per
  # the PRM.  For some standards, this will involve making
  # modifications.  For others, it will not.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @return [Bool] returns true if successful, false if not
  def model_apply_prm_construction_types(model)
    set_all_construction_sets_to_necb!(model, runner = nil)
    return true
  end

  # Reduces the WWR to the values specified by the PRM. WWR reduction
  # will be done by moving vertices inward toward centroid.  This causes the least impact
  # on the daylighting area calculations and controls placement.
  #
  # @todo add proper support for 90.1-2013 with all those building
  # type specific values
  # @todo support 90.1-2004 requirement that windows be modeled as
  # horizontal bands.  Currently just using existing window geometry,
  # and shrinking as necessary if WWR is above limit.
  # @todo support semiheated spaces as a separate WWR category
  # @todo add window frame area to calculation of WWR
  def model_apply_prm_baseline_window_to_wall_ratio(model, climate_zone)
    # Loop through all spaces in the model, and
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_wind_m2 = 0
    res_wall_m2 = 0.001
    res_wind_m2 = 0
    sh_wall_m2 = 0.001
    sh_wind_m2 = 0
    total_wall_m2 = 0.001
    total_subsurface_m2 = 0.0
    # Store the space conditioning category for later use
    space_cats = {}
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      wind_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType.casecmp('wall').zero?
        # This wall's gross area (including window area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          wind_area_m2 += ss.netArea * space.multiplier
        end
      end

      # Determine the space category
      # TODO This should really use the heating/cooling loads
      # from the proposed building.  However, in an attempt
      # to avoid another sizing run just for this purpose,
      # conditioned status is based on heating/cooling
      # setpoints.  If heated-only, will be assumed Semiheated.
      # The full-bore method is on the next line in case needed.
      # cat = thermal_zone_conditioning_category(space, template, climate_zone)
      cooled = space_cooled?(space)
      heated = space_heated?(space)
      cat = 'Unconditioned'
      # Unconditioned
      if !heated && !cooled
        cat = 'Unconditioned'
        # Heated-Only
      elsif heated && !cooled
        cat = 'Semiheated'
        # Heated and Cooled
      else
        res = thermal_zone_residential?(space.thermalZone.get() )
        cat = if res
                'ResConditioned'
              else
                'NonResConditioned'
              end
      end
      space_cats[space] = cat
      # NECB 2011 keep track of totals for NECB regardless of conditioned or not.
      total_wall_m2 += wall_area_m2
      total_subsurface_m2 += wind_area_m2 # this contains doors as well.

      # Add to the correct category
      case cat
        when 'Unconditioned'
          next # Skip unconditioned spaces
        when 'NonResConditioned'
          nr_wall_m2 += wall_area_m2
          nr_wind_m2 += wind_area_m2
        when 'ResConditioned'
          res_wall_m2 += wall_area_m2
          res_wind_m2 += wind_area_m2
        when 'Semiheated'
          sh_wall_m2 += wall_area_m2
          sh_wind_m2 += wind_area_m2
      end

    end

    # Calculate the WWR of each category
    wwr_nr = ((nr_wind_m2 / nr_wall_m2) * 100.0).round(1)
    wwr_res = ((res_wind_m2 / res_wall_m2) * 100).round(1)
    wwr_sh = ((sh_wind_m2 / sh_wall_m2) * 100).round(1)
    fdwr = ((total_subsurface_m2 / total_wall_m2) * 100).round(1) # used by NECB 2011

    # Convert to IP and report
    nr_wind_ft2 = OpenStudio.convert(nr_wind_m2, 'm^2', 'ft^2').get
    nr_wall_ft2 = OpenStudio.convert(nr_wall_m2, 'm^2', 'ft^2').get

    res_wind_ft2 = OpenStudio.convert(res_wind_m2, 'm^2', 'ft^2').get
    res_wall_ft2 = OpenStudio.convert(res_wall_m2, 'm^2', 'ft^2').get

    sh_wind_ft2 = OpenStudio.convert(sh_wind_m2, 'm^2', 'ft^2').get
    sh_wall_ft2 = OpenStudio.convert(sh_wall_m2, 'm^2', 'ft^2').get

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR NonRes = #{wwr_nr.round}%; window = #{nr_wind_ft2.round} ft2, wall = #{nr_wall_ft2.round} ft2.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR Res = #{wwr_res.round}%; window = #{res_wind_ft2.round} ft2, wall = #{res_wall_ft2.round} ft2.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR Semiheated = #{wwr_sh.round}%; window = #{sh_wind_ft2.round} ft2, wall = #{sh_wall_ft2.round} ft2.")

    # WWR limit
    wwr_lim = 40.0

    # Check against WWR limit
    red_nr = wwr_nr > wwr_lim ? true : false
    red_res = wwr_res > wwr_lim ? true : false
    red_sh = wwr_sh > wwr_lim ? true : false

    # NECB FDWR limit
    hdd = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get).hdd18
    fdwr_lim = (max_fwdr(hdd) * 100.0).round(1)
    #puts "Current FDWR is #{fdwr}, must be less than #{fdwr_lim}."
    #puts "Current subsurf area is #{total_subsurface_m2} and gross surface area is #{total_wall_m2}"
    # Stop here unless windows / doors need reducing
    return true unless fdwr > fdwr_lim
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all windows (by raising sill height) to reduce window area down to the limit of #{wwr_lim.round}%.")
    # Determine the factors by which to reduce the window / door area
    mult = fdwr_lim / fdwr
    # Reduce the window area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'Wall'
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          # Reduce the size of the window
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_raising_sill(ss, red)
        end
      end
    end

    return true
  end

  # Reduces the SRR to the values specified by the PRM. SRR reduction
  # will be done by shrinking vertices toward the centroid.
  #
  # @todo support semiheated spaces as a separate SRR category
  # @todo add skylight frame area to calculation of SRR
  def model_apply_prm_baseline_skylight_to_roof_ratio(model)
    # Loop through all spaces in the model, and
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_sky_m2 = 0
    res_wall_m2 = 0.001
    res_sky_m2 = 0
    sh_wall_m2 = 0.001
    sh_sky_m2 = 0
    total_roof_m2 = 0.001
    total_subsurface_m2 = 0
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      sky_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'
        # This wall's gross area (including skylight area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          sky_area_m2 += ss.netArea * space.multiplier
        end
      end

      # Determine the space category
      cat = 'NonRes'
      if space_residential?(space)
        cat = 'Res'
      end
      # if space.is_semiheated
      # cat = 'Semiheated'
      # end

      # Add to the correct category
      case cat
        when 'NonRes'
          nr_wall_m2 += wall_area_m2
          nr_sky_m2 += sky_area_m2
        when 'Res'
          res_wall_m2 += wall_area_m2
          res_sky_m2 += sky_area_m2
        when 'Semiheated'
          sh_wall_m2 += wall_area_m2
          sh_sky_m2 += sky_area_m2
      end
      total_roof_m2 += wall_area_m2
      total_subsurface_m2 += sky_area_m2
    end

    # Calculate the SRR of each category
    srr_nr = ((nr_sky_m2 / nr_wall_m2) * 100).round(1)
    srr_res = ((res_sky_m2 / res_wall_m2) * 100).round(1)
    srr_sh = ((sh_sky_m2 / sh_wall_m2) * 100).round(1)
    srr = ((total_subsurface_m2 / total_roof_m2) * 100.0).round(1)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The skylight to roof ratios (SRRs) are: NonRes: #{srr_nr.round}%, Res: #{srr_res.round}%.")

    # SRR limit
    srr_lim = 5.0

    # Check against SRR limit
    red_nr = srr_nr > srr_lim ? true : false
    red_res = srr_res > srr_lim ? true : false
    red_sh = srr_sh > srr_lim ? true : false

    # Stop here unless windows need reducing
    return true unless srr > srr_lim
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all windows (by raising sill height) to reduce window area down to the limit of #{srr_lim.round}%.")
    # Determine the factors by which to reduce the window / door area
    mult = srr_lim / srr

    # Reduce the subsurface areas
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          # Reduce the size of the subsurface
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end

    return true
  end

  # Helper method to find out which climate zone set contains a specific climate zone.
  # Returns climate zone set name as String if success, nil if not found.
  def model_find_climate_zone_set(model, clim)
    result = nil

    possible_climate_zones = []
    $os_standards['climate_zone_sets'].each do |climate_zone_set|
      if climate_zone_set['climate_zones'].include?(clim)
        possible_climate_zones << climate_zone_set['name']
      end
    end

    # Check the results
    if possible_climate_zones.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set containing #{clim}")
    elsif possible_climate_zones.size > 2
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Found more than 2 climate zone sets containing #{clim}; will return last matching cliimate zone set.")
    end
    result = possible_climate_zones.sort.first

    # Check that a climate zone set was found
    if result.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set when #{instvartemplate}")
    end

    return result
  end

end
