class NECB2011
  # This method will take a model that uses NECB2011 spacetypes , and..
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

  def necb_autozone_and_autosystem(model: nil, runner: nil, use_ideal_air_loads: false, system_fuel_defaults:)

    unique_schedule_types = [] # Array to store schedule objects
    space_zoning_data_array_json = []

    # First pass of spaces to collect information into the space_zoning_data_array .
    model.getSpaces.sort.each do |space|
      space_type_data = nil
      # this will get the spacetype system index 8.4.4.8A  from the SpaceTypeData and BuildingTypeData in  (1-12)
      space_system_index = nil
      if space.spaceType.empty?
        space_system_index = nil
      else
        # gets row information from standards spreadsheet.
        space_types_table = @standards_data['space_types']
        search_criteria = {'template' => self.class.name,
                           'space_type' => space.spaceType.get.standardsSpaceType.get,
                           'building_type' => space.spaceType.get.standardsBuildingType.get}
        space_type_data = model_find_object(space_types_table, search_criteria)
        raise("Could not find spacetype information in #{self.class.name} for space_type => #{space.spaceType.get.standardsSpaceType.get} - #{space.spaceType.get.standardsBuildingType.get}") if space_type_data.nil?
      end

      # Get the heating and cooling load for the space. Only Zones with a defined thermostat will have a load.
      # Make sure we don't have sideeffects by changing the argument variables.
      # Get the heating and cooling load for the space. Only Zones with a defined thermostat will have a load.
      # Make sure we don't have sideeffects by changing the argument variables.

      cooling_design_load = space.spaceType.get.standardsSpaceType.get == '- undefined -' ? 0.0 : space.thermalZone.get.coolingDesignLoad.get * space.floorArea * space.multiplier / 1000.0
      heating_design_load = space.spaceType.get.standardsSpaceType.get == '- undefined -' ? 0.0 : space.thermalZone.get.heatingDesignLoad.get * space.floorArea * space.multiplier / 1000.0

      # identify space-system_index and assign the right NECB system type 1-7.
      necb_hvac_system_selection_table = @standards_data['necb_hvac_system_selection_type']
      necb_hvac_system_select = necb_hvac_system_selection_table.select do |necb_hvac_system_select|
        necb_hvac_system_select['necb_hvac_system_selection_type'] == space_type_data['necb_hvac_system_selection_type'] &&
            necb_hvac_system_select['min_stories'] <= model.getBuilding.standardsNumberOfAboveGroundStories.get &&
            necb_hvac_system_select['max_stories'] >= model.getBuilding.standardsNumberOfAboveGroundStories.get &&
            necb_hvac_system_select['min_cooling_capacity_kw'] <= cooling_design_load &&
            necb_hvac_system_select['max_cooling_capacity_kw'] >= cooling_design_load
      end.first

      # get placement on floor, core or perimeter and if a top, bottom, middle or single story.
      horizontal_placement, vertical_placement = BTAP::Geometry::Spaces.get_space_placement(space)
      # dump all info into an array for debugging and iteration.
      unless space.spaceType.empty?
        space_zoning_data_array_json << {
            space: space,
            space_name: space.name,
            floor_area: space.floorArea,
            building_type_name: space.spaceType.get.standardsBuildingType.get, # space type name
            space_type_name: space.spaceType.get.standardsSpaceType.get, # space type name
            necb_hvac_system_selection_type: space_type_data['necb_hvac_system_selection_type'], #
            system_number: necb_hvac_system_select['system_type'].nil? ? nil : necb_hvac_system_select['system_type'], # the necb system type
            number_of_stories: model.getBuilding.standardsNumberOfAboveGroundStories.get, # number of stories
            heating_design_load: heating_design_load,
            cooling_design_load: cooling_design_load,
            is_dwelling_unit: necb_hvac_system_select['dwelling'], # Checks if it is a dwelling unit.
            is_wildcard: necb_hvac_system_select['necb_hvac_system_selection_type'] == 'Wildcard' ? true : nil,
            schedule_type: determine_necb_schedule_type(space).to_s,
            multiplier: (@space_multiplier_map[space.name.to_s].nil? ? 1 : @space_multiplier_map[space.name.to_s]),
        }.merge(BTAP::Geometry::Spaces.get_space_placement(space))

      end
    end

    File.write("#{File.dirname(__FILE__)}/newway.json", JSON.pretty_generate(space_zoning_data_array_json))

    # Deal with Wildcard spaces. Might wish to have logic to do coridors first.
    space_zoning_data_array_json.each do |space_zone_data|
      # If it is a wildcard space.
      if space_zone_data[:system_number].nil?
        # iterate through all adjacent spaces from largest shared wall area to smallest.
        # Set system type to match first space system that is not nil.
        adj_spaces = space_get_adjacent_spaces_with_shared_wall_areas(space_zone_data[:space], true)
        if adj_spaces.nil?
          puts "Warning: No adjacent spaces for #{space_zone_data[:space].name} on same floor, looking for others above and below to set system"
          adj_spaces = space_get_adjacent_spaces_with_shared_wall_areas(space_zone_data[:space], false)
        end
        adj_spaces.sort.each do |adj_space|
          # if there are no adjacent spaces. Raise an error.
          raise "Could not determine adj space to space #{space_zone_data[:space].name.get}" if adj_space.nil?

          adj_space_data = space_zoning_data_array_json.find {|data| data[:space] == adj_space[0]}
          if adj_space_data[:system_number].nil?
            next
          else
            space_zone_data[:system_number] = adj_space_data[:system_number]
            break
          end
        end
        raise "Could not determine adj space system to space #{space_zone_data[:space].name.get}" if space_zone_data[:system_number].nil?
      end
    end

    # remove any thermal zones used for sizing to start fresh. Should only do this after the above system selection method.
    model.getThermalZones.sort.each(&:remove)

    # now lets apply the rules.
    # Rule1 all zones must contain only the same schedule / occupancy schedule.
    # Rule2 zones must cater to similar solar gains (N,E,S,W)
    # Rule3 zones must not pass from floor to floor. They must be contained to a single floor or level.
    # Rule4 Wildcard spaces will be associated with the nearest zone of similar schedule type in which is shared most of it's internal surface with.
    # Rule5 NECB zones must contain spaces of similar system type only.
    # Rule6 Multiplier zone will be part of the floor and orientation of the base space.
    # Rule7 Residential / dwelling units must not share systems with other space types.
    # Array of system types of Array of Spaces
    system_zone_array = []
    # Lets iterate by system
    (0..7).each do |system_number|
      system_zone_array[system_number] = []
      # iterate by story
      model.getBuildingStorys.sort.each_with_index do |story, building_index|
        # iterate by unique schedule type.
        space_zoning_data_array_json.map {|item| item[:schedule_type]}.uniq.each do |schedule_type|
          # iterate by horizontal location
          ['north', 'east', 'west', 'south', 'core'].each do |horizontal_placement|
            # puts "horizontal_placement:#{horizontal_placement}"
            [true, false].each do |is_dwelling_unit|
              space_info_array = []
              space_zoning_data_array_json.each do |space_info|
                # puts "Spacename: #{space_info.space.name}:#{space_info.space.spaceType.get.name}"
                if (space_info[:system_number] == system_number) &&
                    (space_info[:space].buildingStory.get == story) &&
                    (determine_necb_schedule_type(space_info[:space]).to_s == schedule_type) &&
                    (space_info[:horizontal_placement] == horizontal_placement) &&
                    (space_info[:is_dwelling_unit] == is_dwelling_unit)
                  space_info_array << space_info
                end
              end

              # create Thermal Zone if space_array is not empty.
              unless space_info_array.empty?
                # Process spaces that have multipliers associated with them first.
                # This map define the multipliers for spaces with multipliers not equals to 1
                space_multiplier_map = @space_multiplier_map

                # create new zone and add the spaces to it.
                space_info_array.each do |space_info|
                  # Create thermalzone for each space.
                  thermal_zone = OpenStudio::Model::ThermalZone.new(model)
                  # Create a more informative space name.
                  thermal_zone.setName("Sp-#{space_info[:space].name} Sys-#{system_number} Flr-#{building_index + 1} Sch-#{schedule_type} HPlcmt-#{horizontal_placement} ZN")
                  # Add zone mulitplier if required.
                  thermal_zone.setMultiplier(space_info[:multiplier]) unless space_info[:multiplier] == 1
                  # Space to thermal zone. (for archetype work it is one to one)
                  space_info[:space].setThermalZone(thermal_zone)
                  # Get thermostat for space type if it already exists.
                  space_type_name = space_info[:space].spaceType.get.name.get
                  thermostat_name = space_type_name + ' Thermostat'
                  thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
                  if thermostat.empty?
                    OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space_info[:space].name} ZN")
                    raise " Thermostat #{thermostat_name} not found for space name: #{space_info[:space].name}"
                  else
                    thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
                    thermal_zone.setThermostatSetpointDualSetpoint(thermostat_clone)
                  end
                  # Add thermal to zone system number.
                  system_zone_array[system_number] << thermal_zone
                end
              end
            end
          end
        end
      end
    end
    # system iteration

    # Create and assign the zones to the systems.
    if use_ideal_air_loads == true
      # otherwise use ideal loads.
      model.getThermalZones.sort.each do |thermal_zone|
        thermal_zone_ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        thermal_zone_ideal_loads.addToThermalZone(thermal_zone)
      end
    else
      hw_loop_needed = false
      system_zone_array.each_with_index do |zones, system_index|
        next if zones.empty?

        if system_index == 1 && (system_fuel_defaults['mau_heating_coil_type'] == 'Hot Water' || system_fuel_defaults['baseboard_type'] == 'Hot Water')
          hw_loop_needed = true
        elsif system_index == 2 || system_index == 5 || system_index == 7
          hw_loop_needed = true
        elsif (system_index == 3 || system_index == 4) && system_fuel_defaults['baseboard_type'] == 'Hot Water'
          hw_loop_needed = true
        elsif system_index == 6 && (system_fuel_defaults['mau_heating_coil_type'] == 'Hot Water' || system_fuel_defaults['baseboard_type'] == 'Hot Water')
          hw_loop_needed = true
        end
        if hw_loop_needed
          break
        end
      end
      if hw_loop_needed
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        setup_hw_loop_with_components(model, hw_loop, system_fuel_defaults['boiler_fueltype'], always_on)
      end
      system_zone_array.each_with_index do |zones, system_index|
        # skip if no thermal zones for this system.
        next if zones.empty?

        case system_index
        when 0, nil
          # Do nothing no system assigned to zone. Used for Unconditioned spaces
        when 1
          add_sys1_unitary_ac_baseboard_heating(model: model,
                                                zones: zones,
                                                mau_type: system_fuel_defaults['mau_type'],
                                                mau_heating_coil_type: system_fuel_defaults['mau_heating_coil_type'],
                                                baseboard_type: system_fuel_defaults['baseboard_type'],
                                                hw_loop: hw_loop)
        when 2, 7
          add_sys2_FPFC_sys5_TPFC(model: model,
                                  zones: zones,
                                  chiller_type: system_fuel_defaults['chiller_type'],
                                  fan_coil_type: 'FPFC',
                                  mau_cooling_type: system_fuel_defaults['mau_cooling_type'],
                                  hw_loop: hw_loop)
        when 3
          zones.each do |zone|
            add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                               zones: [zone],
                                                                                               heating_coil_type: system_fuel_defaults['heating_coil_type_sys3'],
                                                                                               baseboard_type: system_fuel_defaults['baseboard_type'],
                                                                                               hw_loop: hw_loop,
                                                                                               new_auto_zoner: false)
          end
        when 4
          zones.each do |zone|
            add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                                                                         zones: [zone],
                                                                         heating_coil_type: system_fuel_defaults['heating_coil_type_sys4'],
                                                                         baseboard_type: system_fuel_defaults['baseboard_type'],
                                                                         hw_loop: hw_loop)
          end
        when 5
          add_sys2_FPFC_sys5_TPFC(model: model,
                                  zones: zones,
                                  chiller_type: system_fuel_defaults['chiller_type'],
                                  fan_coil_type: 'TPFC',
                                  mau_cooling_type: system_fuel_defaults['mau_cooling_type'],
                                  hw_loop: hw_loop)
        when 6
          add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                     zones: zones,
                                                                     heating_coil_type: system_fuel_defaults['heating_coil_type_sys6'],
                                                                     baseboard_type: system_fuel_defaults['baseboard_type'],
                                                                     chiller_type: system_fuel_defaults['chiller_type'],
                                                                     fan_type: system_fuel_defaults['fan_type'],
                                                                     hw_loop: hw_loop)
        end
      end
    end
    # Check to ensure that all spaces are assigned to zones except undefined ones.
    errors = []
    model.getSpaces.sort.each do |space|
      if space.thermalZone.empty? && (space.spaceType.get.name.get != 'Space Function - undefined -')
        errors << "space #{space.name} with spacetype #{space.spaceType.get.name.get} was not assigned a thermalzone."
      end
    end
    raise(" #{errors}") unless errors.empty?
  end

  # Creates thermal zones to contain each space, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  def model_create_thermal_zones(model, space_multiplier_map = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started creating thermal zones')
    space_multiplier_map = {} if space_multiplier_map.nil?

    # Remove any Thermal zones assigned
    model.getThermalZones.each(&:remove)

    # Create a thermal zone for each space in the self
    model.getSpaces.sort.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(model)
      zone.setName("#{space.name} ZN")
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      space.setThermalZone(zone)

      # Skip thermostat for spaces with no space type
      next if space.spaceType.empty?

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
        ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_loads.addToThermalZone(zone)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished creating thermal zones')
  end

  # Top level method that merges spaces into zones where possible. This requires a sizing run. This follows the spirit of
  # the EE4 modelling manual found here https://www.nrcan.gc.ca/energy/software-tools/7457 where the
  # A zone includes those areas in the building that meet three criteria:
  # * Served by the same HVAC system
  # * Similar operation and function
  # * Similar heating/cooling loads
  # Some expections are dwelling units wet zone and wild zones.  These spaces will have special considerations when autozoning a
  # building.

  def auto_zoning(model:, sizing_run_dir: Dir.pwd)
    # The first thing we need to do is get a sizing run to determine the heating loads of all the spaces. The default
    # btap geometry has a one to one relationship of zones to spaces.. So we simply create the thermal zones for all the spaces.
    # to do this we need to create thermals zone for each space.

    # Remove any Thermal zones assigned before
    model.getThermalZones.each(&:remove)
    # create new thermal zones one to one with spaces.
    model_create_thermal_zones(model)
    # do a sizing run.
    if model_run_sizing_run(model, "#{sizing_run_dir}/autozone") == false
      raise('autorun sizing run failed!')
    end

    # collect sizing information on each space.
    self.store_space_sizing_loads(model)

    # Remove any Thermal zones assigned again to start fresh.
    model.getThermalZones.each(&:remove)

    self.auto_zone_dwelling_units(model)
    self.auto_zone_wet_spaces(model)
    self.auto_zone_all_other_spaces(model)
    self.auto_zone_wild_spaces(model)
  end

  # Organizes Zones and assigns them to appropriate systems according to NECB 2011-17 systems spacetype rules in Sec 8.
  # requires requires fuel type to be assigned for each system aspect. Defaults to gas hydronic.
  def auto_system(model:,
                  boiler_fueltype: "NaturalGas",
                  baseboard_type: "Hot Water",
                  mau_type: true,
                  mau_heating_coil_type: "Hot Water",
                  mau_cooling_type: "DX",
                  chiller_type: "Scroll",
                  heating_coil_type_sys3: "Gas",
                  heating_coil_type_sys4: "Gas",
                  heating_coil_type_sys6: "Hot Water",
                  fan_type: "var_speed_drive",
                  swh_fueltype: "NaturalGas"
  )

    #remove idealair from zones if any.
    model.getZoneHVACIdealLoadsAirSystems.each(&:remove)
    @hw_loop = create_hw_loop_if_required(baseboard_type,
                                          boiler_fueltype,
                                          mau_heating_coil_type,
                                          model)
    #Rule that all dwelling units have their own zone and system.
    auto_system_dwelling_units(model: model,
                               baseboard_type: baseboard_type,
                               boiler_fueltype: boiler_fueltype,
                               chiller_type: chiller_type,
                               fan_type: fan_type,
                               heating_coil_type_sys3: heating_coil_type_sys3,
                               heating_coil_type_sys4: heating_coil_type_sys4,
                               hw_loop: @hw_loop,
                               heating_coil_type_sys6: heating_coil_type_sys6,
                               mau_cooling_type: mau_cooling_type,
                               mau_heating_coil_type: mau_heating_coil_type,
                               mau_type: mau_type
    )

    #Assign a single system 4 for all wet spaces.. and assign the control zone to the one with the largest load.
    auto_system_wet_spaces(baseboard_type: baseboard_type,
                           boiler_fueltype: boiler_fueltype,
                           heating_coil_type_sys4: heating_coil_type_sys4,
                           model: model)


    #Assign a single system 4 for all storage spaces.. and assign the control zone to the one with the largest load.
    auto_system_storage_spaces(baseboard_type: baseboard_type,
                               boiler_fueltype: boiler_fueltype,
                               heating_coil_type_sys4: heating_coil_type_sys4,
                               model: model)


    #Assign the wild spaces to a single system 4 system with a control zone with the largest load.
    auto_system_wild_spaces(baseboard_type: baseboard_type,
                            heating_coil_type_sys4: heating_coil_type_sys4,
                            model: model)
    # do the regular assignment for the rest and group where possible.
    auto_system_all_other_spaces(model: model,
                                 baseboard_type: baseboard_type,
                                 boiler_fueltype: boiler_fueltype,
                                 chiller_type: chiller_type,
                                 fan_type: fan_type,
                                 heating_coil_type_sys3: heating_coil_type_sys3,
                                 heating_coil_type_sys4: heating_coil_type_sys4,
                                 hw_loop: @hw_loop,
                                 heating_coil_type_sys6: heating_coil_type_sys6,
                                 mau_cooling_type: mau_cooling_type,
                                 mau_heating_coil_type: mau_heating_coil_type,
                                 mau_type: mau_type
    )
  end

  # Method to store space sizing loads. This is needed because later when the zones are destroyed this information will be lost.
  def store_space_sizing_loads(model)
    @stored_space_heating_sizing_loads = {}
    @stored_space_cooling_sizing_loads = {}
    model.getSpaces.each do |space|
      @stored_space_heating_sizing_loads[space] = space.spaceType.get.standardsSpaceType.get == '- undefined -' ? 0.0 : space.thermalZone.get.heatingDesignLoad.get
      @stored_space_cooling_sizing_loads[space] = space.spaceType.get.standardsSpaceType.get == '- undefined -' ? 0.0 : space.thermalZone.get.coolingDesignLoad.get
    end
  end

  # Returns heating load per area for space after sizing run has been done.
  def stored_space_heating_load(space)
    if @stored_space_heating_sizing_loads.nil?
      # do a sizing run.
      raise("autorun sizing run failed!") if model_run_sizing_run(space.model, "#{Dir.pwd}/autozone") == false
      #collect sizing information on each space.
      self.store_space_sizing_loads(space.model)
    end
    @stored_space_heating_sizing_loads[space]
  end

  # Returns the cooling load per area for space after sizing runs has been done.
  def stored_space_cooling_load(space)
    if @stored_space_cooling_sizing_loads.nil?
      # do a sizing run.
      raise("autorun sizing run failed!") if model_run_sizing_run(space.model, "#{Dir.pwd}/autozone") == false
      #collect sizing information on each space.
      self.store_space_sizing_loads(space.model)
    end
    @stored_space_cooling_sizing_loads[space]
  end

  # # Returns the heating load per area for zone after sizing runs has been done.
  def stored_zone_heating_load(zone)
    total = 0.0
    zone.spaces.each do |space|
      total += stored_space_heating_load(space)
    end
    return total
  end

  # Returns the cooling load per area for zone after sizing runs has been done.
  def stored_zone_cooling_load(zone)
    total = 0.0
    zone.spaces.each do |space|
      total += stored_space_cooling_load(space)
    end
    return total
  end

  # Dwelling unit spaces need to have their own HVAC system. Thankfully NECB defines what spacetypes are considering
  # dwelling units and have been defined as spaces that are
  # openstudio-standards/standards/necb/NECB2011/data/necb_hvac_system_selection_type.json as spaces that are Residential/Accomodation and Sleeping area'
  # this is determine by the is_a_necb_dwelling_unit? method. The thermostat is set by the space-type schedule. This will return an array of TZ.
  def auto_zone_dwelling_units(model)
    dwelling_tz_array = []
    # ----Dwelling units----------- will always have their own system per unit, so they should have their own thermal zone.
    model.getSpaces.select {|space| is_a_necb_dwelling_unit?(space)}.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(model)
      zone.setName("DU_BT=#{space.spaceType.get.standardsBuildingType.get}_ST=#{space.spaceType.get.standardsSpaceType.get}_FL=#{space.buildingStory().get.name}_SCH#{ determine_dominant_schedule([space])}")
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      space.setThermalZone(zone)

      # Add a thermostat based on the space type.
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        # The thermostat name for the spacetype should exist.
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
        OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model).addToThermalZone(zone)
      end
      dwelling_tz_array << zone
    end
    return dwelling_tz_array
  end

  # Something that the code is silent on are smelly humid areas that should not be on the same system as the rest of the
  #  building.. These are the 'wet' spaces and have been defined as locker and washroom areas.. These will be put under
  # their own single system 4 system. These will be set to the dominant floor schedule.
  def auto_zone_wet_spaces(model)
    wet_zone_array = Array.new
    model.getSpaces.select {|space| is_an_necb_wet_space?(space)}.each do |space|
      #if this space was already assigned to something skip it.
      next unless space.thermalZone.empty?
      # get space to dominant schedule
      dominant_schedule = determine_dominant_schedule(space.model.getSpaces)
      #create new TZ and set space to the zone.
      zone = OpenStudio::Model::ThermalZone.new(model)
      space.setThermalZone(zone)
      tz_name = "WET_ST=#{space.spaceType.get.standardsSpaceType.get}_FL=#{space.buildingStory().get.name}_SCH#{dominant_schedule}"
      zone.setName(tz_name)
      #Set multiplier from the original tz multiplier.
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end

      #this method will determine if the right schedule was used for this wet & wild space if not.. it will reset the space
      # to use the correct schedule version of the wet and wild space type.
      adjust_wildcard_spacetype_schedule(space, dominant_schedule)
      #Find spacetype thermostat and assign it to the zone.
      thermostat_name = space.spaceType.get.name.get + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        # The thermostat name for the spacetype should exist.
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}-")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
        ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_loads.addToThermalZone(zone)
      end
      # Go through other spaces to see if there are similar spaces with similar loads on the same floor that can be grouped.
      model.getSpaces.select {|s| is_an_necb_wet_space?(s)}.each do |space_target|
        if space_target.thermalZone.empty?
          if are_space_loads_similar?(space_1: space, space_2: space_target) && space.buildingStory().get == space_target.buildingStory().get # added since chris needs zones to not span floors for costing.
            adjust_wildcard_spacetype_schedule(space_target, dominant_schedule)
            space_target.setThermalZone(zone)
          end
        end
      end
      wet_zone_array << zone
    end
    return wet_zone_array
  end

  # This method will find all the spaces that are not wet, wild or dwelling units and zone them. It will try to determine
  # if the spaces are similar based on exposure and load and blend those spaces into the same zone.  It will not merge spaces
  # from different floors, since this will impact Chris Kirneys costing algorithms.
  def auto_zone_all_other_spaces(model)
    other_tz_array = Array.new
    #iterate through all non wildcard spaces.
    model.getSpaces.select {|space| not is_a_necb_dwelling_unit?(space) and not is_an_necb_wildcard_space?(space)}.each do |space|
      #skip if already assigned to a thermal zone.
      next unless space.thermalZone.empty?
      #create new zone for this space based on the space name.
      zone = OpenStudio::Model::ThermalZone.new(model)
      tz_name = "ALL_ST=#{space.spaceType.get.standardsSpaceType.get}_FL=#{space.buildingStory().get.name}_SCH=#{ determine_dominant_schedule([space])}"
      zone.setName(tz_name)
      #sets space mulitplier unless it is nil or 1.
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      #Assign space to the new zone.
      space.setThermalZone(zone)

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        # The thermostat name for the spacetype should exist.
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
        ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_loads.addToThermalZone(zone)
      end
      # Go through other spaces and if you find something with similar loads on the same floor, add it to the zone.
      model.getSpaces.select {|space| not is_a_necb_dwelling_unit?(space) and not is_an_necb_wildcard_space?(space)}.each do |space_target|
        if space_target.thermalZone.empty?
          if are_space_loads_similar?(space_1: space, space_2: space_target) and space.buildingStory().get == space_target.buildingStory().get # added since chris needs zones to not span floors for costing.
            space_target.setThermalZone(zone)
          end
        end
      end
      other_tz_array << zone
    end
    return other_tz_array
  end

  # This will take all the wildcard spaces and merge them to be supported by a system 4. The control zone will be the
  # zone that has the largest heating load per area.
  def auto_zone_wild_spaces(model)
    other_tz_array = Array.new
    #iterate through wildcard spaces.
    model.getSpaces.select {|space| is_an_necb_wildcard_space?(space) and not is_an_necb_wet_space?(space)}.each do |space|
      #skip if already assigned to a thermal zone.
      next unless space.thermalZone.empty?
      #create new zone for this space based on the space name.
      zone = OpenStudio::Model::ThermalZone.new(model)
      tz_name = "WILD_ST=#{space.spaceType.get.standardsSpaceType.get}_FL=#{space.buildingStory().get.name}_SCH=#{determine_dominant_schedule(space.model.getSpaces)}"
      zone.setName(tz_name)
      #sets space mulitplier unless it is nil or 1.
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      #Assign space to the new zone.
      space.setThermalZone(zone)

      #lets keep the wild schedules to be the same as what dominate the floor.
      dominant_floor_schedule = determine_dominant_schedule(space.model.getSpaces)

      adjust_wildcard_spacetype_schedule(space, dominant_floor_schedule)

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        # The thermostat name for the spacetype should exist.
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
        ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_loads.addToThermalZone(zone)
      end
      # Go through other spaces and if you find something with similar loads on the same floor, add it to the zone.
      model.getSpaces.select {|space| is_an_necb_wildcard_space?(space) and not is_an_necb_wet_space?(space)}.each do |space_target|
        if space_target.thermalZone.empty?
          if are_space_loads_similar?(space_1: space, space_2: space_target) and
              space.buildingStory().get == space_target.buildingStory().get # added since chris needs zones to not span floors for costing.
            space_target.setThermalZone(zone)
          end
        end
      end
      other_tz_array << zone
    end
    return other_tz_array

    wild_zone_array = []
    #Get a list of all the wild spaces.
    model.getSpaces.select {|space| is_an_necb_wildcard_space?(space) and not is_an_necb_wet_space?(space)}.each do |space|
      #if this space was already assigned to something skip it.
      next unless space.thermalZone.empty?
      #find adjacent spaces to the current space.
      adj_spaces = space_get_adjacent_spaces_with_shared_wall_areas(space, true)
      adj_spaces = adj_spaces.map {|key, value| key}

      # find unassigned adjacent wild spaces that have not been assigned that have the same multiplier these will be
      # lumped together in the same zone.
      wild_adjacent_spaces = adj_spaces.select {|adj_space|
        is_an_necb_wildcard_space?(adj_space) and
            not is_an_necb_wet_space?(adj_space) and
            adj_space.thermalZone.empty? and
            space_multiplier_map[space.name.to_s] == space_multiplier_map[adj_space.name.to_s]
      }
      #put them all together.
      wild_adjacent_spaces << space

      # Get adjacent candidate foster zones. Must not be a wildcard space and must not be linked to another space incase
      # it is part of a mirrored space.
      other_adjacent_spaces = adj_spaces.select do |adj_space|
        is_an_necb_wildcard_space?(adj_space) == false and
            adj_space.thermalZone.get.spaces.size == 1 and
            space_multiplier_map[space.name.to_s] == space_multiplier_map[adj_space.name.to_s]
      end

      #If there are adjacent spaces that fit the above criteria.
      # We will need to set each space to the dominant floor schedule by setting the spaces spacetypes to that
      # schedule version and eventually set it to a system 4
      unless other_adjacent_spaces.empty?
        #assign the space(s) to the adjacent thermal zone.
        schedule_type = determine_dominant_schedule(space.buildingStory.get.spaces)
        zone = other_adjacent_spaces.first.thermalZone.get
        wild_adjacent_spaces.each do |space|
          adjust_wildcard_spacetype_schedule(space, schedule_type)
          space.setThermalZone(zone)
        end
      end

      #create new TZ and set space to the zone.
      zone = OpenStudio::Model::ThermalZone.new(model)
      space.setThermalZone(zone)
      zone.setName("Wild-ZN:BT=#{space.spaceType.get.standardsBuildingType.get}:ST=#{space.spaceType.get.standardsSpaceType.get}:FL=#{space.buildingStory().get.name}:")
      #Set multiplier from the original tz multiplier.
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end

      # Set space to dominant

      dominant_floor_schedule = determine_dominant_schedule(space.buildingStory().get.spaces)
      #this method will determine if the right schedule was used for this wet & wild space if not.. it will reset the space
      # to use the correct schedule version of the wet and wild space type.
      adjust_wildcard_spacetype_schedule(space, dominant_floor_schedule)
      #Find spacetype thermostat and assign it to the zone.
      thermostat_name = space.spaceType.get.name.get + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        # The thermostat name for the spacetype should exist.
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
        ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        ideal_loads.addToThermalZone(zone)
      end
      # Go through other spaces to see if there are similar spaces with similar loads on the same floor that can be grouped.
      model.getSpaces.select {|s| is_an_necb_wildcard_space?(s) and not is_an_necb_wet_space?(s)}.each do |space_target|
        if space_target.thermalZone.empty?
          if are_space_loads_similar?(space_1: space, space_2: space_target) &&
              space.buildingStory().get == space_target.buildingStory().get # added since chris needs zones to not span floors for costing.
            adjust_wildcard_spacetype_schedule(space_target, dominant_floor_schedule)
            space_target.setThermalZone(zone)
          end
        end
      end
      wild_zone_array << zone
    end
    return wild_zone_array
  end

  # This method will determine if the loads on a zone are similar. (Exposure, space type, space loads, and schedules, etc)
  def are_zone_loads_similar?(zone_1:, zone_2:)
    #make sure they have the same number of spaces.
    truthes = []
    return false if zone_1.spaces.size != zone_2.spaces.size
    zone_1.spaces.each do |space_1|
      zone_2.spaces.each do |space_2|
        if are_space_loads_similar?(space_1: space_1, space_2: space_2)
          truthes << true
        end
      end
    end
    #truthes sizes should be the same as the # of spaces if all spaces are similar.
    return truthes.size == zone_1.spaces.size
  end

  # This method will determine if the loads on a space are similar. (Exposure, space type, space loads, and schedules, etc)
  def are_space_loads_similar?(space_1:,
                               space_2:,
                               surface_percent_difference_tolerance: 0.01,
                               angular_percent_difference_tolerance: 0.001,
                               heating_load_percent_difference_tolerance: 15.0)
    # Do they have the same space type?
    return false unless space_1.multiplier == space_2.multiplier
    # Ensure that they both have defined spacetypes
    return false if space_1.spaceType.empty?
    return false if space_2.spaceType.empty?
    # ensure that they have the same spacetype.
    return false unless space_1.spaceType.get == space_2.spaceType.get
    # Perform surface comparision. If ranges are within percent_difference_tolerance.. they can be considered the same.
    space_1_floor_area = space_1.floorArea
    space_2_floor_area = space_2.floorArea
    space_1_surface_report = space_surface_report(space_1)
    space_2_surface_report = space_surface_report(space_2)
    #Spaces should have the same number of surface orientations.
    return false unless space_1_surface_report.size == space_2_surface_report.size
    #spaces should have similar loads
    return false unless self.percentage_difference(stored_space_heating_load(space_1), stored_space_heating_load(space_2)) <= heating_load_percent_difference_tolerance
    #Each surface should match
    space_1_surface_report.each do |space_1_surface|
      surface_match = space_2_surface_report.detect do |space_2_surface|
        space_1_surface[:surface_type] == space_2_surface[:surface_type] &&
            space_1_surface[:boundary_condition] == space_2_surface[:boundary_condition] &&
            self.percentage_difference(space_1_surface[:tilt], space_2_surface[:tilt]) <= angular_percent_difference_tolerance &&
            self.percentage_difference(space_1_surface[:azimuth], space_2_surface[:azimuth]) <= angular_percent_difference_tolerance &&
            self.percentage_difference(space_1_surface[:surface_area_to_floor_ratio],
                                       space_2_surface[:surface_area_to_floor_ratio]) <= surface_percent_difference_tolerance &&
            self.percentage_difference(space_1_surface[:glazed_subsurface_area_to_floor_ratio],
                                       space_2_surface[:glazed_subsurface_area_to_floor_ratio]) <= surface_percent_difference_tolerance &&
            self.percentage_difference(space_1_surface[:opaque_subsurface_area_to_floor_ratio],
                                       space_2_surface[:opaque_subsurface_area_to_floor_ratio]) <= surface_percent_difference_tolerance

      end
      return false if surface_match.nil?
    end
    return true
  end

  #This method gathers the surface information for the space to determine if spaces are the same.
  def space_surface_report(space)
    surface_report = []
    space_floor_area = space.floorArea
    ['Outdoors', 'Ground'].each do |bc|
      surfaces = BTAP::Geometry::Surfaces.filter_by_boundary_condition(space.surfaces, [bc]).each do |surface|
        #sum wall area and subsurface area by direction. This is the old way so excluding top and bottom surfaces.
        #new way
        glazings = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(surface.subSurfaces, ["FixedWindow",
                                                                                               "OperableWindow",
                                                                                               "GlassDoor",
                                                                                               "Skylight",
                                                                                               "TubularDaylightDiffuser",
                                                                                               "TubularDaylightDome"])
        doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(surface.subSurfaces, ["Door",
                                                                                            "OverheadDoor"])
        azimuth = (surface.azimuth() * 180.0 / Math::PI)
        tilt = (surface.tilt() * 180.0 / Math::PI)
        surface_data = surface_report.detect do |surface_data|
          surface_data[:surface_type] == surface.surfaceType &&
              surface_data[:azimuth] == azimuth &&
              surface_data[:tilt] == tilt &&
              surface_data[:boundary_condition] == bc
        end

        if surface_data.nil?
          surface_data = {
              surface_type: surface.surfaceType,
              azimuth: azimuth,
              tilt: tilt,
              boundary_condition: bc,
              surface_area: 0,
              surface_area_to_floor_ratio: 0,
              glazed_subsurface_area: 0,
              glazed_subsurface_area_to_floor_ratio: 0,
              opaque_subsurface_area: 0,
              opaque_subsurface_area_to_floor_ratio: 0
          }
          surface_report << surface_data
        end
        surface_data[:surface_area] += surface.grossArea.to_i
        surface_data[:surface_area_to_floor_ratio] += surface.grossArea / space.floorArea

        surface_data[:glazed_subsurface_area] += glazings.map {|subsurface| subsurface.grossArea * subsurface.multiplier}.inject(0) {|sum, x| sum + x}.to_i
        surface_data[:glazed_subsurface_area_to_floor_ratio] += glazings.map {|subsurface| subsurface.grossArea * subsurface.multiplier}.inject(0) {|sum, x| sum + x} / space.floorArea

        surface_data[:surface_area] += doors.map {|subsurface| subsurface.grossArea * subsurface.multiplier}.inject(0) {|sum, x| sum + x}.to_i
        surface_data[:surface_area_to_floor_ratio] += doors.map {|subsurface| subsurface.grossArea * subsurface.multiplier}.inject(0) {|sum, x| sum + x} / space.floorArea
      end
    end
    surface_report.sort! {|a, b| [a[:surface_type], a[:azimuth], a[:tilt], a[:boundary_condition]] <=> [b[:surface_type], b[:azimuth], b[:tilt], b[:boundary_condition]]}

    return surface_report
  end

  #Check to see if this is a wildcard space that the NECB does not have a specified schedule or system for.
  def is_an_necb_wildcard_space?(space)
    space_type_table = @standards_data['space_types']
    space_type_data = model_find_object(space_type_table,
                                                   {'template' => self.class.name,
                                                                     'space_type' => space.spaceType.get.standardsSpaceType.get,
                                                                     'building_type' => space.spaceType.get.standardsBuildingType.get})
    raise("#{space}") if space_type_data.nil?
    return space_type_data["necb_hvac_system_selection_type"] == "Wildcard"
  end

  # Check to see if this is a wet space that the NECB does not have a specified schedule or system for. Currently hardcoded to
  # Locker room and washroom.
  def is_an_necb_wet_space?(space)
    #Hack! Should replace this with a proper table lookup.
    return space.spaceType.get.standardsSpaceType.get.include?('Locker room') || space.spaceType.get.standardsSpaceType.get.include?('Washroom')
  end

  # Check to see if this is a wet space that the NECB does not have a specified schedule or system for. Currently hardcoded to
  # Locker room and washroom.
  def is_an_necb_storage_space?(space)
    #Hack! Should replace this with a proper table lookup.
    return space.spaceType.get.standardsSpaceType.get.include?('Storage')
  end


  # Check if the space spactype is a dwelling unit as per NECB.
  def is_a_necb_dwelling_unit?(space)
    space_type_table = @standards_data['space_types']
    space_type_data = model_find_object(space_type_table,
                                                   {'template' => self.class.name,
                                                                     'space_type' => space.spaceType.get.standardsSpaceType.get,
                                                                     'building_type' => space.spaceType.get.standardsBuildingType.get})

    necb_hvac_system_selection_table = @standards_data['necb_hvac_system_selection_type']
    necb_hvac_system_select = necb_hvac_system_selection_table.detect do |necb_hvac_system_select|
      necb_hvac_system_select['necb_hvac_system_selection_type'] == space_type_data['necb_hvac_system_selection_type'] &&
          necb_hvac_system_select['min_stories'] <= space.model.getBuilding.standardsNumberOfAboveGroundStories.get &&
          necb_hvac_system_select['max_stories'] >= space.model.getBuilding.standardsNumberOfAboveGroundStories.get
    end
    return necb_hvac_system_select['dwelling'] == true
  end

  # Determines what system index number is required for the space's spacetype by NECB rules.
  def get_necb_spacetype_system_selection(space)
    space_type_table = @standards_data['space_types']
    space_type_data = model_find_object(space_type_table, {'template' => self.class.name,
                                                                                                'space_type' => space.spaceType.get.standardsSpaceType.get,
                                                                                                'building_type' => space.spaceType.get.standardsBuildingType.get})

    # identify space-system_index and assign the right NECB system type 1-7.
    necb_hvac_system_selection_table = @standards_data['necb_hvac_system_selection_type']
    necb_hvac_system_select = necb_hvac_system_selection_table.detect do |necb_hvac_system_select|
      necb_hvac_system_select['necb_hvac_system_selection_type'] == space_type_data['necb_hvac_system_selection_type'] &&
          necb_hvac_system_select['min_stories'] <= space.model.getBuilding.standardsNumberOfAboveGroundStories.get &&
          necb_hvac_system_select['max_stories'] >= space.model.getBuilding.standardsNumberOfAboveGroundStories.get &&
          necb_hvac_system_select['min_cooling_capacity_kw'] <= self.stored_space_cooling_load(space) &&
          necb_hvac_system_select['max_cooling_capacity_kw'] >= self.stored_space_cooling_load(space)
    end
    raise("could not find system for given spacetype") if necb_hvac_system_select.nil?
    return necb_hvac_system_select['system_type']
  end

  # Determines what system index number is required for the thermal zone based on the spacetypes it contains
  def get_necb_thermal_zone_system_selection(tz)
    systems = []
    tz.spaces.each do |space|
      systems << get_necb_spacetype_system_selection(space)
    end
    systems.uniq!
    systems.compact!
    raise("This thermal zone spaces require different systems.") if systems.size > 1
    return systems.first
  end

  # Math fundtion to determine percent difference.
  def percentage_difference(value_1, value_2)
    return 0.0 if value_1 == value_2
    return ((value_1 - value_2).abs / ((value_1 + value_2) / 2) * 100)
  end

  # Set wildcard spactype schedule to NECB letter index.
  def adjust_wildcard_spacetype_schedule(space, schedule)
    if space.spaceType.empty?
      OpenStudio.logFree(OpenStudio::Error, 'Error: No spacetype assigned for #{space.name.get}. This must be assigned. Aborting.')
    end
    # Get current spacetype name
    space_type_name = space.spaceType.get.standardsSpaceType.get.to_s
    # Determine new spacetype name.
    regex = /^(.*sch-)(\S)$/
    new_spacetype_name = "#{space_type_name.match(regex).captures.first}#{schedule}"
    new_spacetype = nil

    #if the new spacetype does not match the old space type. we gotta update the space with the new spacetype.
    if space_type_name != new_spacetype_name
      new_spacetype = space.model.getSpaceTypes.detect do |spacetype|
        (not spacetype.standardsBuildingType.empty?) and #need to do this to prevent an exception.
            spacetype.standardsBuildingType.get == space.spaceType.get.standardsBuildingType.get and
            (not spacetype.standardsSpaceType.empty?) and #need to do this to prevent an exception.
            spacetype.standardsSpaceType.get == new_spacetype_name
      end
      if new_spacetype.nil?
        # Space type is not in model. need to create from scratch.
        new_spacetype = OpenStudio::Model::SpaceType.new(space.model)
        new_spacetype.setStandardsBuildingType(space.spaceType.get.standardsBuildingType.get)
        new_spacetype.setStandardsSpaceType(new_spacetype_name)
        new_spacetype.setName("#{space.spaceType.get.standardsBuildingType.get} #{new_spacetype_name}")
        space_type_apply_internal_loads(new_spacetype, true, true, true, true, true, true)
        space_type_apply_internal_load_schedules(new_spacetype, true, true, true, true, true, true, true)
      end
      space.setSpaceType(new_spacetype)
      #sanity check.
      raise ("could not reassign space type schedule.") if schedule != space.spaceType.get.name.get.match(regex)[2]
    end
    return space
  end

  def set_wildcard_schedules_to_dominant_building_schedule(model, runner = nil)
    #Get rid of.
  end

  def determine_dominant_schedule(spaces)
    # lookup necb space type properties
    space_type_properties = @standards_data['space_types']
    # Here is a hash to keep track of the m2 running total of spacetypes for each
    # sched type.
    # 2018-04-11:  Not sure if this is still used but the list was expanded to incorporate additional existing or potential
    # future schedules.
    schedule_hash = Hash[
        'A', 0,
        'B', 0,
        'C', 0,
        'D', 0,
        'E', 0,
        'F', 0,
        'G', 0,
        'H', 0,
        'I', 0,
        'J', 0,
        'K', 0,
        'L', 0,
        'M', 0,
        'N', 0,
        'O', 0,
        'P', 0,
        'Q', 0
    ]
    # iterate through spaces in building.
    spaces.select {|space| not is_an_necb_wildcard_space?(space) and not space.spaceType.get.standardsSpaceType.get == '- undefined -'}.each do |space|

      # Ensure space floors are multiplied.
      mult = @space_multiplier_map[space.name.to_s].nil? ? 1.0 : @space_multiplier_map[space.name.to_s]
      # puts "this #{determine_necb_schedule_type(space)}"
      schedule_hash[determine_necb_schedule_type(space)] += space.floorArea * mult
    end
    # finds max value and returns NECB schedule letter.
    #determine dominant letter schedule.
    return schedule_hash.max_by(&:last).first
  end

  # This model determines the dominant NECB schedule type
  # @param model [OpenStudio::model::Model] A model object
  # return s.each [String]
  def determine_dominant_necb_schedule_type(model)
    return determine_dominant_schedule(model.getSpaces)
  end

  # This method determines the spacetype schedule type. This will re
  # @author phylroy.lopez@nrcan.gc.ca
  # @param space [String]
  # @return [String]:["A","B","C","D","E","F","G","H","I"] spacetype
  def determine_necb_schedule_type(space)
    spacetype_data = @standards_data['space_types']
    raise "Spacetype not defined for space #{space.get.name}) if space.spaceType.empty?" if space.spaceType.empty?
    raise "Undefined standardsSpaceType or StandardsBuildingType for space #{space.spaceType.get.name}) if space.spaceType.empty?" if space.spaceType.get.standardsSpaceType.empty? | space.spaceType.get.standardsBuildingType.empty?
    space_type_properties = spacetype_data.detect {|st| (st['space_type'] == space.spaceType.get.standardsSpaceType.get) && (st['building_type'] == space.spaceType.get.standardsBuildingType.get)}
    return space_type_properties['necb_schedule_type'].strip
  end

  ################################################# NECB Systems

  # Method will create a hot water loop if systems default fuel and medium sources require it.
  def create_hw_loop_if_required(baseboard_type, boiler_fueltype, mau_heating_coil_type, model)
    #get systems that will be used in the model based on the space types to determine if a hw_loop is required.
    systems_used = []
    model.getSpaces.each do |space|
      systems_used << get_necb_spacetype_system_selection(space)
      systems_used.uniq!
    end

    #See if we need to create a hot water loop based on fueltype and systems used.
    hw_loop_needed = false
    systems_used.each do |system|
      case system.to_s
      when '2', '5', '7'
        hw_loop_needed = true
      when '1', '6'
        if mau_heating_coil_type == 'Hot Water' or baseboard_type == 'Hot Water'
          hw_loop_needed = true
        end
      when '3', '4'
        if mau_heating_coil_type == 'Hot Water' or baseboard_type == 'Hot Water'
          hw_loop_needed = true if (baseboard_type == 'Hot Water')
        end
      end
      if hw_loop_needed
        # just need one true condition to need a boiler.
        break
      end
    end # each
    #create hw_loop as needed.. Assuming one loop per model.
    if hw_loop_needed
      @hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      setup_hw_loop_with_components(model, @hw_loop, boiler_fueltype, always_on)
    end
    return @hw_loop
  end

  # Default method to create a necb system and assign array of zones to be supported by it. It will try to bring zones with
  # similar loads on the same airloops and set control zones where possible for single zone systems and will create monolithic
  # system 6 multizones where possible.
  def create_necb_system(baseboard_type:,
                         boiler_fueltype:,
                         chiller_type:,
                         fan_type:,
                         heating_coil_type_sys3:,
                         heating_coil_type_sys4:,
                         heating_coil_type_sys6:,
                         hw_loop:,
                         mau_cooling_type:,
                         mau_heating_coil_type:,
                         mau_type:,
                         model:,
                         zones:)

    # The goal is to minimize the number of system when possible.
    system_zones_hash = {}
    zones.each do |zone|
      system_zones_hash[get_necb_thermal_zone_system_selection(zone)] = [] if system_zones_hash[get_necb_thermal_zone_system_selection(zone)].nil?
      system_zones_hash[get_necb_thermal_zone_system_selection(zone)] << zone
    end
    #puts JSON.pretty_generate(system_zones_hash)
    # go through each system and zones pairs to
    system_zones_hash.each_pair do |system, zones|
      case system
      when 0, nil
        # Do nothing no system assigned to zone. Used for Unconditioned spaces
      when 1
        group_similar_zones_together(zones).each do |zones|
          mau_air_loop = add_sys1_unitary_ac_baseboard_heating(model: model,
                                                               zones: zones,
                                                               mau_type: mau_type,
                                                               mau_heating_coil_type: mau_heating_coil_type,
                                                               baseboard_type: baseboard_type,
                                                               hw_loop: @hw_loop)
        end
      when 2
        group_similar_zones_together(zones).each do |zones|
          add_sys2_FPFC_sys5_TPFC(model: model,
                                  zones: zones,
                                  chiller_type: chiller_type,
                                  mau_cooling_type: mau_cooling_type,
                                  fan_coil_type: 'FPFC',
                                  hw_loop: @hw_loop)
        end
      when 3
        group_similar_zones_together(zones).each do |zones|
          add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                             zones: zones,
                                                                                             heating_coil_type: heating_coil_type_sys3,
                                                                                             baseboard_type: baseboard_type,
                                                                                             hw_loop: @hw_loop,
                                                                                             new_auto_zoner: true)
        end
      when 4
        group_similar_zones_together(zones).each do |zones|
          add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                                                                       zones: zones,
                                                                       heating_coil_type: heating_coil_type_sys4,
                                                                       baseboard_type: baseboard_type,
                                                                       hw_loop: @hw_loop)
        end
      when 5
        group_similar_zones_together(zones).each do |zones|
          add_sys2_FPFC_sys5_TPFC(model: model,
                                  zones: zones,
                                  chiller_type: chiller_type,
                                  mau_cooling_type: mau_cooling_type,
                                  fan_coil_type: 'TPFC',
                                  hw_loop: @hw_loop)
        end
      when 6
        add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                   zones: zones,
                                                                   heating_coil_type: heating_coil_type_sys6,
                                                                   baseboard_type: baseboard_type,
                                                                   chiller_type: chiller_type,
                                                                   fan_type: fan_type,
                                                                   hw_loop: @hw_loop)

      when 7
        group_similar_zones_together(zones).each do |zones|
          add_sys2_FPFC_sys5_TPFC(model: model,
                                  zones: zones,
                                  chiller_type: chiller_type,
                                  fan_coil_type: 'FPFC',
                                  mau_cooling_type: mau_cooling_type,
                                  hw_loop: @hw_loop)
        end
      end
    end
  end

  # This method will deal with all non wet, non-wild, and non-dwelling units thermal zones.
  def auto_system_all_other_spaces(baseboard_type:,
                                   boiler_fueltype:,
                                   chiller_type:,
                                   fan_type:,
                                   heating_coil_type_sys3:,
                                   heating_coil_type_sys4:,
                                   heating_coil_type_sys6:,
                                   hw_loop:,
                                   mau_cooling_type:,
                                   mau_heating_coil_type:,
                                   mau_type:,
                                   model:
  )

    zones = []
    other_spaces = model.getSpaces.select do |space|
      (not is_a_necb_dwelling_unit?(space)) and
          (not is_an_necb_wildcard_space?(space)) and
          (not is_an_necb_storage_space?(space))
    end
    other_spaces.each do |space|
      zones << space.thermalZone.get
    end
    zones.uniq!

    #since dwelling units are all zoned 1:1 to space:zone we simply add the zone to the appropriate btap system.
    create_necb_system(baseboard_type: baseboard_type,
                       boiler_fueltype: boiler_fueltype,
                       chiller_type: chiller_type,
                       fan_type: fan_type,
                       heating_coil_type_sys3: heating_coil_type_sys3,
                       heating_coil_type_sys4: heating_coil_type_sys4,
                       heating_coil_type_sys6: heating_coil_type_sys6,
                       hw_loop: @hw_loop,
                       mau_cooling_type: mau_cooling_type,
                       mau_heating_coil_type: mau_heating_coil_type,
                       mau_type: mau_type,
                       model: model,
                       zones: zones)
  end

  # This methos will ensure that all dwelling units are assigned to a system 1 or 3. There is an option to have a shared
  # AHU or not. Currently set to false. So by default all dwelling units will have their own AHU.

  def auto_system_dwelling_units(baseboard_type:,
                                 boiler_fueltype:,
                                 chiller_type:,
                                 fan_type:,
                                 heating_coil_type_sys3:,
                                 heating_coil_type_sys4:,
                                 heating_coil_type_sys6:,
                                 hw_loop:,
                                 mau_cooling_type:,
                                 mau_heating_coil_type:,
                                 mau_type:,
                                 model:
  )

    system_zones_hash = {}
    # Detemine if dwelling units have a shared AHU.  If user entered building stories > 4 then set to true.
    dwelling_shared_ahu = model.getBuilding.standardsNumberOfAboveGroundStories.get > 4
    # store dwelling zones into array
    zones = []
    model.getSpaces.select {|space| is_a_necb_dwelling_unit?(space)}.each do |space|
      zones << space.thermalZone.get
    end
    zones.uniq!

    #sort system 1 or 3 used for each dwelling unit as per T8.4.4.8.A NECB 2011-17
    zones.each do |zone|
      system_zones_hash[get_necb_thermal_zone_system_selection(zone)] = [] if system_zones_hash[get_necb_thermal_zone_system_selection(zone)].nil?
      system_zones_hash[get_necb_thermal_zone_system_selection(zone)] << zone
    end

    # go through each system and zones pairs to
    system_zones_hash.each_pair do |system, zones|
      case system
      when 1
        if dwelling_shared_ahu
          add_sys1_unitary_ac_baseboard_heating(model: model,
                                                zones: zones,
                                                mau_type: mau_type,
                                                mau_heating_coil_type: mau_heating_coil_type,
                                                baseboard_type: baseboard_type,
                                                hw_loop: @hw_loop)
        else
          #Create a separate air loop for each unit.
          zones.each do |zone|
            add_sys1_unitary_ac_baseboard_heating(model: model,
                                                  zones: [zone],
                                                  mau_type: mau_type,
                                                  mau_heating_coil_type: mau_heating_coil_type,
                                                  baseboard_type: baseboard_type,
                                                  hw_loop: @hw_loop)

          end
        end

      when 3
        if dwelling_shared_ahu
          add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                             zones: zones,
                                                                                             heating_coil_type: heating_coil_type_sys3,
                                                                                             baseboard_type: baseboard_type,
                                                                                             hw_loop: @hw_loop,
                                                                                             new_auto_zoner: true)
        else
          #Create a separate air loop for each unit.
          zones.each do |zone|
            add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                               zones: [zone],
                                                                                               heating_coil_type: heating_coil_type_sys3,
                                                                                               baseboard_type: baseboard_type,
                                                                                               hw_loop: @hw_loop,
                                                                                               new_auto_zoner: true)

          end
        end
      end
    end
  end

  # All wet spaces will be on their own system 4 AHU.
  def auto_system_wet_spaces(baseboard_type:,
                             boiler_fueltype:,
                             heating_coil_type_sys4:,
                             model:)
    #Determine what zones are wet zones.
    wet_tz = []
    model.getSpaces.select {|space|
      is_an_necb_wet_space?(space)}.each do |space|
      wet_tz << space.thermalZone.get
    end
    wet_tz.uniq!
    #create a system 4 for the wet zones.
    unless wet_tz.empty?
      add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                                                                   zones: wet_tz,
                                                                   heating_coil_type: heating_coil_type_sys4,
                                                                   baseboard_type: baseboard_type,
                                                                   hw_loop: @hw_loop)
    end
  end


  # All wet spaces will be on their own system 4 AHU.
  def auto_system_storage_spaces(baseboard_type:,
                                 boiler_fueltype:,
                                 heating_coil_type_sys4:,
                                 model:)
    #Determine what zones are wet zones.
    tz = []
    model.getSpaces.select {|space|
      is_an_necb_storage_space?(space)}.each do |space|
      tz << space.thermalZone.get
    end
    tz.uniq!
    #create a system 4 for the  zones.
    unless tz.empty?
      add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                                                                   zones: tz,
                                                                   heating_coil_type: heating_coil_type_sys4,
                                                                   baseboard_type: baseboard_type,
                                                                   hw_loop: @hw_loop)
    end
  end


  # All wild spaces will be on a single system 4 ahu with the largests heating load zone being the control zone.
  def auto_system_wild_spaces(baseboard_type:,
                              heating_coil_type_sys4:,
                              model:
  )

    zones = []
    model.getSpaces.select {|space|
      not is_an_necb_wet_space?(space) and is_an_necb_wildcard_space?(space)}.each do |space|
      zones << space.thermalZone.get
    end
    zones.uniq!
    unless zones.empty?
      #create a system 4 for the wild zones.
      add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                                                                   zones: zones,
                                                                   heating_coil_type: heating_coil_type_sys4,
                                                                   baseboard_type: baseboard_type,
                                                                   hw_loop: @hw_loop)
    end
  end

  #This method will determine the control zone from the last sizing run space loads.
  def determine_control_zone(zones)
    # In this case the control zone is the load with the largest heating loads. This may cause overheating of some zones.
    # but this is preferred to unmet heating.
    #Iterate through zones.
    zone_heating_load_hash = {}
    zones.each {|zone| zone_heating_load_hash[zone] = self.stored_zone_heating_load(zone)}
    return zone_heating_load_hash.max_by(&:last).first
  end

  # This method is used to determine if there are single zones that can be grouped with zones of similar loads.
  def group_similar_zones_together(zones)
    total_zones_input = zones.size
    array_of_array_of_zones = []
    accounted_for = []
    # Go through other zones to see if there are similar zones with similar loads on the same floor that can be grouped.
    zones.each do |zone|
      similar_array_of_zones = []
      next if accounted_for.include?(zone.name.to_s)
      similar_array_of_zones << zone
      accounted_for << zone.name.to_s
      zones.each do |zone_target|
        unless accounted_for.include?(zone_target.name.to_s)
          if are_zone_loads_similar?(zone_1: zone,
                                     zone_2: zone_target)
            similar_array_of_zones << zone_target
            accounted_for << zone_target.name.to_s
          end
        end
      end
      array_of_array_of_zones << similar_array_of_zones
    end
    total_zones_output = 0
    array_of_array_of_zones.each do |zones|
      total_zones_output += zones.size
    end
    #puts total_zones_output
    #puts accounted_for.sort
    #sanity check.
    if total_zones_output != total_zones_input
      #puts JSON.pretty_generate(array_of_array_of_zones)
      #puts JSON.pretty_generate(accounted_for.sort)
      raise("#{}")
    end
    return array_of_array_of_zones
  end

  # This method will create a color object used in SU, 3D Viewer and Floorspace.js
  def set_random_rendering_color(object, random)
    rendering_color = OpenStudio::Model::RenderingColor.new(object.model)
    rendering_color.setName(object.name.get)
    rendering_color.setRenderingRedValue(random.rand(255))
    rendering_color.setRenderingGreenValue(random.rand(255))
    rendering_color.setRenderingBlueValue(random.rand(255))
    return rendering_color
  end
end
