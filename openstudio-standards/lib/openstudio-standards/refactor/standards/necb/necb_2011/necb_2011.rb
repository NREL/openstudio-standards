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
    @standards_data["fan_constant_volume_pressure_rise"] = 640.00
    # NECB Infiltration rate information for standard.
    @standards_data["infiltration"] = {}
    @standards_data["infiltration"]["rate_m3_per_s_per_m2"]               = 0.25 * 0.001 # m3/s/m2
    @standards_data["infiltration"]["constant_term_coefficient"]          = 0.0
    @standards_data["infiltration"]["temperature_term_coefficient"]       = 0.0
    @standards_data["infiltration"]["velocity_term_coefficient"]          = 0.224
    @standards_data["infiltration"]["velocity_squared_term_coefficient"]  = 0.0
    @standards_data["skylight_to_roof_ratio"] = 0.05
    @standards_data["space_types"] = model_find_objects( $os_standards['space_types'],{'template' => @instvartemplate })
  end


  def model_create_prototype_model(climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false)
    building_type = @instvarbuilding_type
    raise ("no building_type!") if @instvarbuilding_type.nil?
    model = nil
    #prototype generation.
    model = load_initial_osm(@geometry_file) #standard candidate
    model.yearDescription.get.setDayofWeekforStartDay('Sunday')
    model.add_design_days_and_weather_file(climate_zone, epw_file) #Standards
    model.add_ground_temperatures(@instvarbuilding_type, climate_zone, instvartemplate) #prototype candidate
    model.getBuilding.setName(self.class.to_s)
    model_assign_space_type_stubs(model, 'Space Function', @space_type_map) #Standards candidate
    #save new basefile to new geometry folder as class name.
    BTAP::FileIO::save_osm(model, "#{Folders.instance.data_geometry_folder}/new/#{self.class.to_s}.osm")
    model.getBuilding.setName("#{}-#{@instvarbuilding_type}-#{climate_zone}-#{epw_file} created: #{Time.new}")
    model_add_loads(model) #standards candidate
    model_apply_infiltration_standard(model) #standards candidate
    model_modify_surface_convection_algorithm(model) #standards
    model_add_constructions(model, @instvarbuilding_type, climate_zone) #prototype candidate
    apply_standard_construction_properties(model) #standards candidate
    apply_standard_window_to_wall_ratio(model) #standards candidate
    apply_standard_skylight_to_roof_ratio(model) #standards candidate
    model_create_thermal_zones(model, @space_multiplier_map) #standards candidate
    # For some building types, stories are defined explicitly

    return false if model.runSizingRun("#{sizing_run_dir}/SR0") == false
    #Create Reference HVAC Systems.
    model_add_hvac(model, @instvarbuilding_type, climate_zone, @prototype_input, epw_file) #standards for NECB Prototype for NREL candidate
    model_add_swh(model, @instvarbuilding_type, climate_zone, @prototype_input, epw_file)
    model_apply_sizing_parameters(model)


    #set a larger tolerance for unmet hours from default 0.2 to 1.0C
    model.getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
    model.getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)
    return false if model.runSizingRun("#{sizing_run_dir}/SR1") == false
    # This is needed for NECB 2011 as a workaround for sizing the reheat boxes
    model.getAirTerminalSingleDuctVAVReheats.each {|iobj| air_terminal_single_duct_vav_reheat_set_heating_cap(iobj)}
    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
    # AHU1 doesn't have economizer
    model_modify_oa_controller(model)
    # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
    model_reset_or_room_vav_minimum_damper(@prototype_input, model)
    model_modify_oa_controller(model)
    # Apply the HVAC efficiency standard
    model_apply_hvac_efficiency_standard(model, climate_zone)
    # Fix EMS references.
    # Temporary workaround for OS issue #2598
    model_temp_fix_ems_references(model)
    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    model_add_daylighting_controls(model) # to be removed after refactor.
    # Add output variables for debugging
    model_request_timeseries_outputs(model) if debug
    return model
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
        self.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
      end
      system_zone_array.each_with_index do |zones, system_index|
        #skip if no thermal zones for this system.
        next if zones.size == 0
        case system_index
          when 0, nil
            #Do nothing no system assigned to zone. Used for Unconditioned spaces
          when 1

            self.add_sys1_unitary_ac_baseboard_heating(model, zones, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, hw_loop)
          when 2
            self.add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype, chiller_type, "FPFC", mua_cooling_type, hw_loop)
          when 3
            self.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model, zones, boiler_fueltype, heating_coil_types_sys3, baseboard_type, hw_loop)
          when 4
            self.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model, zones, boiler_fueltype, heating_coil_types_sys4, baseboard_type, hw_loop)
          when 5
            self.add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype, chiller_type, "TPFC", mua_cooling_type, hw_loop)
          when 6
            self.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model, zones, boiler_fueltype, heating_coil_types_sys6, baseboard_type, chiller_type, fan_type, hw_loop)
          when 7
            self.add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype, chiller_type, "FPFC", mua_cooling_type, hw_loop)
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


  def add_sys1_unitary_ac_baseboard_heating(model, zones, boiler_fueltype, mau, mau_heating_coil_type, baseboard_type, hw_loop)

    # System Type 1: PTAC with no heating (unitary AC)
    # Zone baseboards, electric or hot water depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # PSZ to represent make-up air unit (if present)
    # This measure creates:
    # a PTAC  unit for each zone in the building; DX cooling coil
    # and heating coil that is always off
    # Baseboards ("Hot Water or "Electric") in zones connected to hot water loop
    # MAU is present if argument mau == true, not present if argument mau == false
    # MAU is PSZ; DX cooling
    # MAU heating coil: hot water coil or electric, depending on argument mau_heating_coil_type
    # mau_heating_coil_type choices are "Hot Water", "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    # Some system parameters are set after system is set up; by applying method 'apply_hvac_efficiency_standard'

    always_on = model.alwaysOnDiscreteSchedule

    # define always off schedule for ptac heating coil
    always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF::always_off(model)

    #Create MAU
    # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)

    if (mau == true) then

      mau_air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      mau_air_loop.setName("Make-up air unit")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = mau_air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn("VentilationRequirement")
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43)
      air_loop_sizing.setSizingOption("NonCoincident")
      air_loop_sizing.setAllOutdoorAirinCooling(true)
      air_loop_sizing.setAllOutdoorAirinHeating(true)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

      mau_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      if (mau_heating_coil_type == "Electric") then # electric coil
        mau_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      end

      if (mau_heating_coil_type == "Hot Water") then
        mau_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
        hw_loop.addDemandBranchForComponent(mau_htg_coil)
      end

      # Set up DX coil with default curves (set to NECB);

      mau_clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model, always_on)

      #oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      #oa_controller.setEconomizerControlType("DifferentialEnthalpy")

      #oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = mau_air_loop.supplyInletNode
      mau_fan.addToNode(supply_inlet_node)
      mau_htg_coil.addToNode(supply_inlet_node)
      mau_clg_coil.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager to control the supply air temperature
      sat = 20.0
      sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      sat_sch.setName("Makeup-Air Unit Supply Air Temp")
      sat_sch.defaultDaySchedule().setName("Makeup Air Unit Supply Air Temp Default")
      sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0, 24, 0, 0), sat)
      setpoint_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
      setpoint_mgr.addToNode(mau_air_loop.supplyOutletNode)

    end # Create MAU

    # Create a PTAC for each zone:
    # PTAC DX Cooling with electric heating coil; electric heating coil is always off

    # TO DO: need to apply this system to space types:
    #(1) data processing area: control room, data centre
    # when cooling capacity <= 20kW and
    #(2) residential/accommodation: murb, hotel/motel guest room
    # when building/space heated only (this as per NECB; apply to
    # all for initial work? CAN-QUEST limitation)

    #TO DO: PTAC characteristics: sizing, fan schedules, temperature setpoints, interaction with MAU

    zones.each do |zone|

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # Set up PTAC heating coil; apply always off schedule

      # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_off)


      # Set up PTAC DX coil with NECB performance curve characteristics;
      clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model, always_on)

      # Set up PTAC constant volume supply fan
      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)
      fan.setPressureRise(640)

      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                           always_on,
                                                                           fan,
                                                                           htg_coil,
                                                                           clg_coil)
      ptac.setName("#{zone.name} PTAC")
      ptac.addToThermalZone(zone)

      # add zone baseboards
      if (baseboard_type == "Electric") then

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if (baseboard_type == "Hot Water") then
        baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
        #Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)


        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        #add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)

      end

      #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
      if (mau == true) then

        diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
        mau_air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      end #components for MAU

    end # of zone loop

    return true

  end

  #sys1_unitary_ac_baseboard_heating

  def add_sys1_unitary_ac_baseboard_heating_multi_speed(model, zones, boiler_fueltype, mau, mau_heating_coil_type, baseboard_type, hw_loop)

    # System Type 1: PTAC with no heating (unitary AC)
    # Zone baseboards, electric or hot water depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # PSZ to represent make-up air unit (if present)
    # This measure creates:
    # a PTAC  unit for each zone in the building; DX cooling coil
    # and heating coil that is always off
    # Baseboards ("Hot Water or "Electric") in zones connected to hot water loop
    # MAU is present if argument mau == true, not present if argument mau == false
    # MAU is PSZ; DX cooling
    # MAU heating coil: hot water coil or electric, depending on argument mau_heating_coil_type
    # mau_heating_coil_type choices are "Hot Water", "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    # Some system parameters are set after system is set up; by applying method 'apply_hvac_efficiency_standard'


    always_on = model.alwaysOnDiscreteSchedule

    # define always off schedule for ptac heating coil
    always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF::always_off(model)

    #TODO: Heating and cooling temperature set point schedules are set somewhere else
    #TODO: For now fetch the schedules and use them in setting up the heat pump system
    #TODO: Later on these schedules need to be passed on to this method
    htg_temp_sch, clg_temp_sch = nil, nil
    zones.each do |izone|
      if (izone.thermostat.is_initialized)
        zone_thermostat = izone.thermostat.get
        if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
          dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
          htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
          clg_temp_sch = dual_thermostat.coolingSetpointTemperatureSchedule.get
          break
        end
      end
    end

    #Create MAU
    # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)

    if (mau == true) then

      staged_thermostat = OpenStudio::Model::ZoneControlThermostatStagedDualSetpoint.new(model)
      staged_thermostat.setHeatingTemperatureSetpointSchedule(htg_temp_sch)
      staged_thermostat.setNumberofHeatingStages(4)
      staged_thermostat.setCoolingTemperatureSetpointBaseSchedule(clg_temp_sch)
      staged_thermostat.setNumberofCoolingStages(4)

      mau_air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      mau_air_loop.setName("Make-up air unit")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = mau_air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(12.8)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption("NonCoincident")
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

      mau_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      # Multi-stage gas heating coil
      if (mau_heating_coil_type == "Electric" || mau_heating_coil_type == "Hot Water")

        mau_htg_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
        mau_htg_stage_1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_3 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_4 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)

        if (mau_heating_coil_type == "Electric")

          mau_supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)

        elsif (mau_heating_coil_type == "Hot Water")

          mau_supplemental_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(mau_supplemental_htg_coil)

        end

        mau_htg_stage_1.setNominalCapacity(0.1)
        mau_htg_stage_2.setNominalCapacity(0.2)
        mau_htg_stage_3.setNominalCapacity(0.3)
        mau_htg_stage_4.setNominalCapacity(0.4)

      end

      # Add stages to heating coil
      mau_htg_coil.addStage(mau_htg_stage_1)
      mau_htg_coil.addStage(mau_htg_stage_2)
      mau_htg_coil.addStage(mau_htg_stage_3)
      mau_htg_coil.addStage(mau_htg_stage_4)

      #TODO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX cooling coil
      mau_clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      mau_clg_coil.setFuelType('Electricity')
      mau_clg_stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_2 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_3 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_4 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_coil.addStage(mau_clg_stage_1)
      mau_clg_coil.addStage(mau_clg_stage_2)
      mau_clg_coil.addStage(mau_clg_stage_3)
      mau_clg_coil.addStage(mau_clg_stage_4)

      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.new(model, mau_fan, mau_htg_coil, mau_clg_coil, mau_supplemental_htg_coil)
      #              air_to_air_heatpump.setName("#{zone.name} ASHP")
      air_to_air_heatpump.setControllingZoneorThermostatLocation(zones[1])
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.setNumberofSpeedsforHeating(4)
      air_to_air_heatpump.setNumberofSpeedsforCooling(4)

      #oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      #oa_controller.setEconomizerControlType("DifferentialEnthalpy")

      #oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = mau_air_loop.supplyInletNode
      air_to_air_heatpump.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

    end # Create MAU

    # Create a PTAC for each zone:
    # PTAC DX Cooling with electric heating coil; electric heating coil is always off


    # TO DO: need to apply this system to space types:
    #(1) data processing area: control room, data centre
    # when cooling capacity <= 20kW and
    #(2) residential/accommodation: murb, hotel/motel guest room
    # when building/space heated only (this as per NECB; apply to
    # all for initial work? CAN-QUEST limitation)

    #TO DO: PTAC characteristics: sizing, fan schedules, temperature setpoints, interaction with MAU


    zones.each do |zone|

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # Set up PTAC heating coil; apply always off schedule

      # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_off)


      # Set up PTAC DX coil with NECB performance curve characteristics;
      clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model, always_on)


      # Set up PTAC constant volume supply fan
      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)
      fan.setPressureRise(640)


      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                           always_on,
                                                                           fan,
                                                                           htg_coil,
                                                                           clg_coil)
      ptac.setName("#{zone.name} PTAC")
      ptac.addToThermalZone(zone)

      # add zone baseboards
      if (baseboard_type == "Electric") then

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if (baseboard_type == "Hot Water") then
        baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
        #Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)


        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        #add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)

      end


      #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
      if (mau == true) then

        diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
        mau_air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      end #components for MAU

    end # of zone loop


    return true

  end

  #sys1_unitary_ac_baseboard_heating

  def add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype, chiller_type, fan_coil_type, mua_cooling_type, hw_loop)

    # System Type 2: FPFC or System 5: TPFC
    # This measure creates:
    # -a four pipe or a two pipe fan coil unit for each zone in the building;
    # -a make up air-unit to provide ventilation to each zone;
    # -a heating loop, cooling loop and condenser loop to serve four pipe fan coil units
    # Arguments:
    #   boiler_fueltype: "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    #   chiller_type: "Scroll";"Centrifugal";"Rotary Screw";"Reciprocating"
    #   mua_cooling_type: make-up air unit cooling type "DX";"Hydronic"
    #   fan_coil_type options are "TPFC" or "FPFC"

    # TODO: Add arguments as needed when the sizing routine is finalized. For example we will need to know the
    # required size of the boilers to decide on how many units are needed based on NECB rules.

    always_on = model.alwaysOnDiscreteSchedule

    # schedule for two-pipe fan coil operation

    twenty_four_hrs = OpenStudio::Time.new(0, 24, 0, 0)

    # Heating coil availability schedule for tpfc
    tpfc_htg_availability_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    tpfc_htg_availability_sch.setName("tpfc_htg_availability")
    # Cooling coil availability schedule for tpfc
    tpfc_clg_availability_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    tpfc_clg_availability_sch.setName("tpfc_clg_availability")
    istart_month = [1, 7, 11]
    istart_day = [1, 1, 1]
    iend_month = [6, 10, 12]
    iend_day = [30, 31, 31]
    sch_htg_value = [1, 0, 1]
    sch_clg_value = [0, 1, 0]
    for i in 0..2
      tpfc_htg_availability_sch_rule = OpenStudio::Model::ScheduleRule.new(tpfc_htg_availability_sch)
      tpfc_htg_availability_sch_rule.setName("tpfc_htg_availability_sch_rule")
      tpfc_htg_availability_sch_rule.setStartDate(model.getYearDescription.makeDate(istart_month[i], istart_day[i]))
      tpfc_htg_availability_sch_rule.setEndDate(model.getYearDescription.makeDate(iend_month[i], iend_day[i]))
      tpfc_htg_availability_sch_rule.setApplySunday(true)
      tpfc_htg_availability_sch_rule.setApplyMonday(true)
      tpfc_htg_availability_sch_rule.setApplyTuesday(true)
      tpfc_htg_availability_sch_rule.setApplyWednesday(true)
      tpfc_htg_availability_sch_rule.setApplyThursday(true)
      tpfc_htg_availability_sch_rule.setApplyFriday(true)
      tpfc_htg_availability_sch_rule.setApplySaturday(true)
      day_schedule = tpfc_htg_availability_sch_rule.daySchedule
      day_schedule.setName("tpfc_htg_availability_sch_rule_day")
      day_schedule.addValue(twenty_four_hrs, sch_htg_value[i])

      tpfc_clg_availability_sch_rule = OpenStudio::Model::ScheduleRule.new(tpfc_clg_availability_sch)
      tpfc_clg_availability_sch_rule.setName("tpfc_clg_availability_sch_rule")
      tpfc_clg_availability_sch_rule.setStartDate(model.getYearDescription.makeDate(istart_month[i], istart_day[i]))
      tpfc_clg_availability_sch_rule.setEndDate(model.getYearDescription.makeDate(iend_month[i], iend_day[i]))
      tpfc_clg_availability_sch_rule.setApplySunday(true)
      tpfc_clg_availability_sch_rule.setApplyMonday(true)
      tpfc_clg_availability_sch_rule.setApplyTuesday(true)
      tpfc_clg_availability_sch_rule.setApplyWednesday(true)
      tpfc_clg_availability_sch_rule.setApplyThursday(true)
      tpfc_clg_availability_sch_rule.setApplyFriday(true)
      tpfc_clg_availability_sch_rule.setApplySaturday(true)
      day_schedule = tpfc_clg_availability_sch_rule.daySchedule
      day_schedule.setName("tpfc_clg_availability_sch_rule_day")
      day_schedule.addValue(twenty_four_hrs, sch_clg_value[i])

    end

    # Create a chilled water loop

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Create a condenser Loop

    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Set up make-up air unit for ventilation
    # TO DO: Need to investigate characteristics of make-up air unit for NECB reference
    # and define them here

    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

    air_loop.setName("Make-up air unit")

    # When an air_loop is contructed, its constructor creates a sizing:system object
    # the default sizing:system constructor makes a system:sizing object
    # appropriate for a multizone VAV system
    # this systems is a constant volume system with no VAV terminals,
    # and therfore needs different default settings
    air_loop_sizing = air_loop.sizingSystem # TODO units
    air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
    air_loop_sizing.autosizeDesignOutdoorAirFlowRate
    air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
    air_loop_sizing.setPreheatDesignTemperature(7.0)
    air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
    air_loop_sizing.setPrecoolDesignTemperature(13.0)
    air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
    air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
    air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(13.1)
    air_loop_sizing.setSizingOption("NonCoincident")
    air_loop_sizing.setAllOutdoorAirinCooling(false)
    air_loop_sizing.setAllOutdoorAirinHeating(false)
    air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.008)
    air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.008)
    air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
    air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
    air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
    air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
    air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

    fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

    # Assume direct-fired gas heating coil for now; need to add logic
    # to set up hydronic or electric coil depending on proposed?

    htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)

    # Add DX or hydronic cooling coil
    if (mua_cooling_type == "DX")
      clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model, tpfc_clg_availability_sch)
    elsif (mua_cooling_type == "Hydronic")
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, tpfc_clg_availability_sch)
      chw_loop.addDemandBranchForComponent(clg_coil)
    end

    # does MAU have an economizer?
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

    #oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

    # Add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = air_loop.supplyInletNode
    fan.addToNode(supply_inlet_node)
    htg_coil.addToNode(supply_inlet_node)
    clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)

    # Add a setpoint manager single zone reheat to control the
    # supply air temperature based on the needs of default zone (OpenStudio picks one)
    # TO DO: need to have method to pick appropriate control zone?

    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(13.1)
    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

    # Set up FC (ZoneHVAC,cooling coil, heating coil, fan) in each zone

    zones.each do |zone|

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # fc supply fan
      fc_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      if (fan_coil_type == "FPFC")
        # heating coil
        fc_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)

        # cooling coil
        fc_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
      elsif (fan_coil_type == "TPFC")
        # heating coil
        fc_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, tpfc_htg_availability_sch)

        # cooling coil
        fc_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, tpfc_clg_availability_sch)
      end

      # connect heating coil to hot water loop
      hw_loop.addDemandBranchForComponent(fc_htg_coil)
      # connect cooling coil to chilled water loop
      chw_loop.addDemandBranchForComponent(fc_clg_coil)

      zone_fc = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, always_on, fc_fan, fc_clg_coil, fc_htg_coil)
      zone_fc.addToThermalZone(zone)

      # Create a diffuser and attach the zone/diffuser pair to the air loop (make-up air unit)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

    end #zone loop

  end

  # add_sys2_FPFC_sys5_TPFC

  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, hw_loop)
    # System Type 3: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas", "DX"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    always_on = model.alwaysOnDiscreteSchedule

    zones.each do |zone|

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      air_loop.setName("#{zone.name} NECB System 3 PSZ")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43)
      air_loop_sizing.setSizingOption("NonCoincident")
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      case heating_coil_type
        when "Electric" # electric coil
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)

        when "Gas"
          htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)

        when "DX"
          htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-10.0)
          sizing_zone.setZoneHeatingSizingFactor(1.3)
          sizing_zone.setZoneCoolingSizingFactor(1.0)
        else
          raise("#{heating_coil_type} is not a valid heating coil type.)")
      end

      #TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX coil with NECB performance curve characteristics;
      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)

      #oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

      #oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode
      #              fan.addToNode(supply_inlet_node)
      #              supplemental_htg_coil.addToNode(supply_inlet_node) if heating_coil_type == "DX"
      #              htg_coil.addToNode(supply_inlet_node)
      #              clg_coil.addToNode(supply_inlet_node)
      #              oa_system.addToNode(supply_inlet_node)
      if (heating_coil_type == 'DX')
        air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(model, always_on, fan, htg_coil, clg_coil, supplemental_htg_coil)
        air_to_air_heatpump.setName("#{zone.name} ASHP")
        air_to_air_heatpump.setControllingZone(zone)
        air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
        air_to_air_heatpump.addToNode(supply_inlet_node)
      else
        fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
      end
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13)
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(43)
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      #diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      if (baseboard_type == "Electric") then

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if (baseboard_type == "Hot Water") then
        baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
        #Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        #add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)
      end
    end #zone loop

    return true
  end

  #end add_sys3_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed

  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, hw_loop)
    # System Type 3: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas", "DX"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    always_on = model.alwaysOnDiscreteSchedule

    #TODO: Heating and cooling temperature set point schedules are set somewhere else
    #TODO: For now fetch the schedules and use them in setting up the heat pump system
    #TODO: Later on these schedules need to be passed on to this method
    htg_temp_sch, clg_temp_sch = nil, nil
    zones.each do |izone|
      if (izone.thermostat.is_initialized)
        zone_thermostat = izone.thermostat.get
        if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
          dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
          htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
          clg_temp_sch = dual_thermostat.coolingSetpointTemperatureSchedule.get
          break
        end
      end
    end

    zones.each do |zone|

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      air_loop.setName("#{zone.name} NECB System 3 PSZ")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption("NonCoincident")
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      staged_thermostat = OpenStudio::Model::ZoneControlThermostatStagedDualSetpoint.new(model)
      staged_thermostat.setHeatingTemperatureSetpointSchedule(htg_temp_sch)
      staged_thermostat.setNumberofHeatingStages(4)
      staged_thermostat.setCoolingTemperatureSetpointBaseSchedule(clg_temp_sch)
      staged_thermostat.setNumberofCoolingStages(4)
      zone.setThermostat(staged_thermostat)

      # Multi-stage gas heating coil
      if (heating_coil_type == "Gas" || heating_coil_type == "Electric")
        htg_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
        htg_stage_1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_3 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_4 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        if (heating_coil_type == "Gas")
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
        elsif (heating_coil_type == "Electric")
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          htg_stage_1.setNominalCapacity(0.1)
          htg_stage_2.setNominalCapacity(0.2)
          htg_stage_3.setNominalCapacity(0.3)
          htg_stage_4.setNominalCapacity(0.4)
        end

        # Multi-Stage DX or Electric heating coil
      elsif (heating_coil_type == "DX")
        htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
        htg_stage_1 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_2 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_3 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_4 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        sizing_zone.setZoneHeatingSizingFactor(1.3)
        sizing_zone.setZoneCoolingSizingFactor(1.0)
      else
        raise("#{heating_coil_type} is not a valid heating coil type.)")
      end

      # Add stages to heating coil
      htg_coil.addStage(htg_stage_1)
      htg_coil.addStage(htg_stage_2)
      htg_coil.addStage(htg_stage_3)
      htg_coil.addStage(htg_stage_4)

      #TODO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX cooling coil
      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setFuelType('Electricity')
      clg_stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_2 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_3 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_4 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_coil.addStage(clg_stage_1)
      clg_coil.addStage(clg_stage_2)
      clg_coil.addStage(clg_stage_3)
      clg_coil.addStage(clg_stage_4)

      #oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

      #oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.new(model, fan, htg_coil, clg_coil, supplemental_htg_coil)
      air_to_air_heatpump.setName("#{zone.name} ASHP")
      air_to_air_heatpump.setControllingZoneorThermostatLocation(zone)
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.addToNode(supply_inlet_node)
      air_to_air_heatpump.setNumberofSpeedsforHeating(4)
      air_to_air_heatpump.setNumberofSpeedsforCooling(4)

      oa_system.addToNode(supply_inlet_node)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      #diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      if (baseboard_type == "Electric") then

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if (baseboard_type == "Hot Water") then
        baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
        #Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        #add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)
      end

    end #zone loop

    return true
  end

  #end add_sys3_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed

  def add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, hw_loop)
    # System Type 4: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    # NOTE: This is the same as system type 3 (single zone make-up air unit and single zone rooftop unit are both PSZ systems)
    # SHOULD WE COMBINE sys3 and sys4 into one script?


    always_on = model.alwaysOnDiscreteSchedule

    # Create a PSZ for each zone
    # TO DO: need to apply this system to space types:
    #(1) automotive area: repair/parking garage, fire engine room, indoor truck bay
    #(2) supermarket/food service: food preparation with kitchen hood/vented appliance
    #(3) warehouse area (non-refrigerated spaces)


    zones.each do |zone|

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)


      air_loop.setName("#{zone.name} NECB System 4 PSZ")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption("NonCoincident")
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)


      if (heating_coil_type == "Electric") then # electric coil
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      end

      if (heating_coil_type == "Gas") then
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
      end

      #TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)


      # Set up DX coil with NECB performance curve characteristics;

      clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model, always_on)

      #oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)


      #oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode
      fan.addToNode(supply_inlet_node)
      htg_coil.addToNode(supply_inlet_node)
      clg_coil.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(43.0)
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)


      #Create sensible heat exchanger
      #              heat_exchanger = BTAP::Resources::HVAC::Plant::add_hrv(model)
      #              heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.5)
      #              heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.5)
      #              heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.5)
      #              heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.5)
      #              heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.0)
      #              heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.0)
      #              heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.0)
      #              heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.0)
      #              heat_exchanger.setSupplyAirOutletTemperatureControl(false)
      #
      #              Connect heat exchanger
      #              oa_node = oa_system.outboardOANode
      #              heat_exchanger.addToNode(oa_node.get)


      # Create a diffuser and attach the zone/diffuser pair to the air loop
      #diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      if (baseboard_type == "Electric") then

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if (baseboard_type == "Hot Water") then
        baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
        #Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)


        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        #add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)
      end

    end #zone loop


    return true
  end

  #end add_sys4_single_zone_make_up_air_unit_with_baseboard_heating

  def add_sys6_multi_zone_built_up_system_with_baseboard_heating(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, chiller_type, fan_type, hw_loop)

    # System Type 6: VAV w/ Reheat
    # This measure creates:
    # a single hot water loop with a natural gas or electric boiler or for the building
    # a single chilled water loop with water cooled chiller for the building
    # a single condenser water loop for heat rejection from the chiller
    # a VAV system w/ hot water or electric heating, chilled water cooling, and
    # hot water or electric reheat for each story of the building
    # Arguments:
    # "boiler_fueltype" choices match OS choices for boiler fuel type:
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    # "heating_coil_type": "Electric" or "Hot Water"
    # "baseboard_type": "Electric" and "Hot Water"
    # "chiller_type": "Scroll";"Centrifugal";""Screw";"Reciprocating"
    # "fan_type": "AF_or_BI_rdg_fancurve";"AF_or_BI_inletvanes";"fc_inletvanes";"var_speed_drive"

    always_on = model.alwaysOnDiscreteSchedule

    # Chilled Water Plant

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Condenser System

    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Make a Packaged VAV w/ PFP Boxes for each story of the building
    model.getBuildingStorys.sort.each do |story|
      if not (BTAP::Geometry::BuildingStoreys::get_zones_from_storey(story) & zones).empty?

        air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
        air_loop.setName("VAV with Reheat")
        sizingSystem = air_loop.sizingSystem
        sizingSystem.setCentralCoolingDesignSupplyAirTemperature(13.0)
        sizingSystem.setCentralHeatingDesignSupplyAirTemperature(13.1)
        sizingSystem.autosizeDesignOutdoorAirFlowRate
        sizingSystem.setMinimumSystemAirFlowRatio(0.3)
        sizingSystem.setPreheatDesignTemperature(7.0)
        sizingSystem.setPreheatDesignHumidityRatio(0.008)
        sizingSystem.setPrecoolDesignTemperature(13.0)
        sizingSystem.setPrecoolDesignHumidityRatio(0.008)
        sizingSystem.setSizingOption("NonCoincident")
        sizingSystem.setAllOutdoorAirinCooling(false)
        sizingSystem.setAllOutdoorAirinHeating(false)
        sizingSystem.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
        sizingSystem.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
        sizingSystem.setCoolingDesignAirFlowMethod("DesignDay")
        sizingSystem.setCoolingDesignAirFlowRate(0.0)
        sizingSystem.setHeatingDesignAirFlowMethod("DesignDay")
        sizingSystem.setHeatingDesignAirFlowRate(0.0)
        sizingSystem.setSystemOutdoorAirMethod("ZoneSum")

        fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)

        if (heating_coil_type == "Hot Water")
          htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(htg_coil)
        end
        if (heating_coil_type == "Electric")
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        end

        clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
        chw_loop.addDemandBranchForComponent(clg_coil)

        oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

        oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

        # Add the components to the air loop
        # in order from closest to zone to furthest from zone
        # TODO: still need to define the return fan (tried to access the air loop "returnAirNode" without success)
        # TODO: The OS sdk indicates that this keyword should be active but I get a "Not implemented" error when I
        # TODO: try to access it through "air_loop.returnAirNode"
        supply_inlet_node = air_loop.supplyInletNode
        supply_outlet_node = air_loop.supplyOutletNode
        fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
        oa_system.addToNode(supply_inlet_node)

        #return_inlet_node = air_loop.returnAirNode

        # Add a setpoint manager to control the
        # supply air to a constant temperature
        sat_c = 13.0
        sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        sat_sch.setName("Supply Air Temp")
        sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
        sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0, 24, 0, 0), sat_c)
        sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
        sat_stpt_manager.addToNode(supply_outlet_node)

        # TO-do ask Kamel about zonal assignments per storey.

        # Make a VAV terminal with HW reheat for each zone on this story that is in intersection with the zones array.
        # and hook the reheat coil to the HW loop
        (BTAP::Geometry::BuildingStoreys::get_zones_from_storey(story) & zones).each do |zone|

          # Zone sizing parameters
          sizing_zone = zone.sizingZone
          sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
          sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
          sizing_zone.setZoneCoolingSizingFactor(1.1)
          sizing_zone.setZoneHeatingSizingFactor(1.3)

          if (heating_coil_type == "Hot Water")
            reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
            hw_loop.addDemandBranchForComponent(reheat_coil)
          elsif (heating_coil_type == "Electric")
            reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          end

          vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
          air_loop.addBranchForZone(zone, vav_terminal.to_StraightComponent)
          # NECB 2011 minimum zone airflow setting
          min_flow_rate = 0.002 * zone.floorArea
          vav_terminal.setFixedMinimumAirFlowRate(min_flow_rate)
          vav_terminal.setMaximumReheatAirTemperature(43.0)
          vav_terminal.setDamperHeatingAction("Normal")

          #Set zone baseboards
          if (baseboard_type == "Electric") then
            zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
            zone_elec_baseboard.addToThermalZone(zone)
          end
          if (baseboard_type == "Hot Water") then
            baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
            #Connect baseboard coil to hot water loop
            hw_loop.addDemandBranchForComponent(baseboard_coil)
            zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
            #add zone_baseboard to zone
            zone_baseboard.addToThermalZone(zone)
          end

        end
      end
    end # next story

    #for debugging
    #puts "end add_sys6_multi_zone_built_up_with_baseboard_heating"

    return true

  end

  def setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, pump_flow_sch)

    hw_loop.setName("Hot Water Loop")
    sizing_plant = hw_loop.sizingPlant
    sizing_plant.setLoopType("Heating")
    sizing_plant.setDesignLoopExitTemperature(82.0) #TODO units
    sizing_plant.setLoopDesignTemperatureDifference(16.0)

    #pump (set to variable speed for now till fix to run away plant temperature is found)
    #pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    #TODO: the keyword "setPumpFlowRateSchedule" does not seem to work. A message
    #was sent to NREL to let them know about this. Once there is a fix for this,
    #use the proper pump schedule depending on whether we have two-pipe or four-pipe
    #fan coils.
    #            pump.resetPumpFlowRateSchedule()
    #            pump.setPumpFlowRateSchedule(pump_flow_sch)

    #boiler
    boiler1 = OpenStudio::Model::BoilerHotWater.new(model)
    boiler2 = OpenStudio::Model::BoilerHotWater.new(model)
    boiler1.setFuelType(boiler_fueltype)
    boiler2.setFuelType(boiler_fueltype)
    boiler1.setName("Primary Boiler")
    boiler2.setName("Secondary Boiler")

    #boiler_bypass_pipe
    boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    #supply_outlet_pipe
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the hot water loop
    hw_supply_inlet_node = hw_loop.supplyInletNode
    hw_supply_outlet_node = hw_loop.supplyOutletNode
    pump.addToNode(hw_supply_inlet_node)

    hw_loop.addSupplyBranchForComponent(boiler1)
    hw_loop.addSupplyBranchForComponent(boiler2)
    hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
    supply_outlet_pipe.addToNode(hw_supply_outlet_node)

    # Add a setpoint manager to control the
    # hot water based on outdoor temperature
    hw_oareset_stpt_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    hw_oareset_stpt_manager.setControlVariable("Temperature")
    hw_oareset_stpt_manager.setSetpointatOutdoorLowTemperature(82.0)
    hw_oareset_stpt_manager.setOutdoorLowTemperature(-16.0)
    hw_oareset_stpt_manager.setSetpointatOutdoorHighTemperature(60.0)
    hw_oareset_stpt_manager.setOutdoorHighTemperature(0.0)
    hw_oareset_stpt_manager.addToNode(hw_supply_outlet_node)

  end

  #of setup_hw_loop_with_components

  def setup_chw_loop_with_components(model, chw_loop, chiller_type)

    chw_loop.setName("Chilled Water Loop")
    sizing_plant = chw_loop.sizingPlant
    sizing_plant.setLoopType("Cooling")
    sizing_plant.setDesignLoopExitTemperature(7.0)
    sizing_plant.setLoopDesignTemperatureDifference(6.0)

    #pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)

    chiller1 = OpenStudio::Model::ChillerElectricEIR.new(model)
    chiller2 = OpenStudio::Model::ChillerElectricEIR.new(model)
    chiller1.setCondenserType("WaterCooled")
    chiller2.setCondenserType("WaterCooled")
    chiller1_name = "Primary Chiller WaterCooled #{chiller_type}"
    chiller1.setName(chiller1_name)
    chiller2_name = "Secondary Chiller WaterCooled #{chiller_type}"
    chiller2.setName(chiller2_name)

    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the chilled water loop
    chw_supply_inlet_node = chw_loop.supplyInletNode
    chw_supply_outlet_node = chw_loop.supplyOutletNode
    chw_pump.addToNode(chw_supply_inlet_node)
    chw_loop.addSupplyBranchForComponent(chiller1)
    chw_loop.addSupplyBranchForComponent(chiller2)
    chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

    # Add a setpoint manager to control the
    # chilled water to a constant temperature
    chw_t_c = 7.0
    chw_t_sch = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model, "CHW Temp", "Temperature", chw_t_c)
    chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_t_sch)
    chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

    return chiller1, chiller2

  end

  #of setup_chw_loop_with_components

  def setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    cw_loop.setName("Condenser Water Loop")
    cw_sizing_plant = cw_loop.sizingPlant
    cw_sizing_plant.setLoopType("Condenser")
    cw_sizing_plant.setDesignLoopExitTemperature(29.0)
    cw_sizing_plant.setLoopDesignTemperatureDifference(6.0)

    cw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)

    clg_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)

    # TO DO: Need to define and set cooling tower curves

    clg_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    cw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the condenser water loop
    cw_supply_inlet_node = cw_loop.supplyInletNode
    cw_supply_outlet_node = cw_loop.supplyOutletNode
    cw_pump.addToNode(cw_supply_inlet_node)
    cw_loop.addSupplyBranchForComponent(clg_tower)
    cw_loop.addSupplyBranchForComponent(clg_tower_bypass_pipe)
    cw_supply_outlet_pipe.addToNode(cw_supply_outlet_node)
    cw_loop.addDemandBranchForComponent(chiller1)
    cw_loop.addDemandBranchForComponent(chiller2)

    # Add a setpoint manager to control the
    # condenser water to constant temperature
    cw_t_c = 29.0
    cw_t_sch = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model, "CW Temp", "Temperature", cw_t_c)
    cw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, cw_t_sch)
    cw_t_stpt_manager.addToNode(cw_supply_outlet_node)

    return clg_tower

  end
  # Set the infiltration rate for this space to include
  # the impact of air leakage requirements in the standard.
  #
  # @return [Double] true if successful, false if not
  # @todo handle doors and vestibules
  def space_apply_infiltration_rate(space)
    # Remove infiltration rates set at the space type.
    infiltration_data = @standards_data["infiltration"]
    unless space.spaceType.empty?
      space.spaceType.get.spaceInfiltrationDesignFlowRates.each(&:remove)
    end
    # Remove infiltration rates set at the space object.
    space.spaceInfiltrationDesignFlowRates.each(&:remove)


    exterior_wall_and_roof_and_subsurface_area = space_exterior_wall_and_roof_and_subsurface_area(space) # To do
    # Don't create an object if there is no exterior wall area
    if exterior_wall_and_roof_and_subsurface_area <= 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "For #{instvartemplate}, no exterior wall area was found, no infiltration will be added.")
      return true
    end
    # Calculate the total infiltration, assuming
    # that it only occurs through exterior walls and roofs (not floors as
    # explicit stated in the NECB 2011 so overhang/cantilevered floors will
    # have no effective infiltration)
    tot_infil_m3_per_s = infiltration_data["rate_m3_per_s_per_m2"] * exterior_wall_and_roof_and_subsurface_area
    # Now spread the total infiltration rate over all
    # exterior surface area (for the E+ input field) this will include the exterior floor if present.
    all_ext_infil_m3_per_s_per_m2 = tot_infil_m3_per_s / space.exteriorArea

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Space', "For #{space.name}, adj infil = #{all_ext_infil_m3_per_s_per_m2.round(8)} m^3/s*m^2.")

    # Get any infiltration schedule already assigned to this space or its space type
    # If not, the always on schedule will be applied.
    infil_sch = nil
    unless space.spaceInfiltrationDesignFlowRates.empty?
      old_infil = space.spaceInfiltrationDesignFlowRates[0]
      if old_infil.schedule.is_initialized
        infil_sch = old_infil.schedule.get
      end
    end

    if infil_sch.nil? && space.spaceType.is_initialized
      space_type = space.spaceType.get
      unless space_type.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
        if old_infil.schedule.is_initialized
          infil_sch = old_infil.schedule.get
        end
      end
    end

    if infil_sch.nil?
      infil_sch = space.model.alwaysOnDiscreteSchedule
    end

    # Create an infiltration rate object for this space
    infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
    infiltration.setName("#{space.name} Infiltration")
    infiltration.setFlowperExteriorSurfaceArea(all_ext_infil_m3_per_s_per_m2)
    infiltration.setSchedule(infil_sch)
    infiltration.setConstantTermCoefficient(infiltration_data["constant_term_coefficient"] )
    infiltration.setTemperatureTermCoefficient(infiltration_data["constant_term_coefficient"])
    infiltration.setVelocityTermCoefficient(infiltration_data["velocity_term_coefficient"])
    infiltration.setVelocitySquaredTermCoefficient(infiltration_data["velocity_squared_term_coefficient"])
    infiltration.setSpace(space)


    return true
  end

end
