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
    # Create a data struct for the space to system to placement information.

    # system assignment.
    unless ['NaturalGas', 'Electricity', 'PropaneGas', 'FuelOil#1', 'FuelOil#2', 'Coal', 'Diesel', 'Gasoline', 'OtherFuel1'].include?(system_fuel_defaults['boiler_fueltype'])
      BTAP.runner_register('ERROR', "boiler_fueltype = #{system_fuel_defaults['boiler_fueltype']}", runner)
      return false
    end

    unless [true, false].include?(system_fuel_defaults['mau_type'])
      BTAP.runner_register('ERROR', "mau_type = #{system_fuel_defaults['mau_type']}", runner)
      return false
    end

    unless ['Hot Water', 'Electric'].include?(system_fuel_defaults['mau_heating_coil_type'])
      BTAP.runner_register('ERROR', "mau_heating_coil_type = #{system_fuel_defaults['mau_heating_coil_type']}", runner)
      return false
    end

    unless ['Hot Water', 'Electric'].include?(system_fuel_defaults['baseboard_type'])
      BTAP.runner_register('ERROR', "baseboard_type = #{system_fuel_defaults['baseboard_type']}", runner)
      return false
    end

    unless ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'].include?(system_fuel_defaults['chiller_type'])
      BTAP.runner_register('ERROR', "chiller_type = #{system_fuel_defaults['chiller_type']}", runner)
      return false
    end
    unless ['DX', 'Hydronic'].include?(system_fuel_defaults['mau_cooling_type'])
      BTAP.runner_register('ERROR', "mau_cooling_type = #{system_fuel_defaults['mau_cooling_type']}", runner)
      return false
    end

    unless ['Electric', 'Gas', 'DX'].include?(system_fuel_defaults['heating_coil_type_sys3'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys3 = #{system_fuel_defaults['heating_coil_type_sys3']}", runner)
      return false
    end

    unless ['Electric', 'Gas', 'DX'].include?(system_fuel_defaults['heating_coil_type_sys4'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys4 = #{system_fuel_defaults['heating_coil_type_sys4']}", runner)
      return false
    end

    unless ['Hot Water', 'Electric'].include?(system_fuel_defaults['heating_coil_type_sys6'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys6 = #{system_fuel_defaults['heating_coil_type_sys6']}", runner)
      return false
    end

    unless ['AF_or_BI_rdg_fancurve', 'AF_or_BI_inletvanes', 'fc_inletvanes', 'var_speed_drive'].include?(system_fuel_defaults['fan_type'])
      BTAP.runner_register('ERROR', "fan_type = #{system_fuel_defaults['fan_type']}", runner)
      return false
    end
    # REPEATED CODE!!
    unless ['Electric', 'Hot Water'].include?(system_fuel_defaults['heating_coil_type_sys6'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys6 = #{system_fuel_defaults['heating_coil_type_sys6']}", runner)
      return false
    end
    # REPEATED CODE!!
    unless ['Electric', 'Gas'].include?(system_fuel_defaults['heating_coil_type_sys4'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys4 = #{system_fuel_defaults['heating_coil_type_sys4']}", runner)
      return false
    end

    unique_schedule_types = [] # Array to store schedule objects
    space_zoning_data_array_json = []

    # First pass of spaces to collect information into the space_zoning_data_array .
    model.getSpaces.sort.each do |space|
      space_type_data = nil
      # this will get the spacetype system index 8.4.4.8A  from the SpaceTypeData and BuildingTypeData in  (1-12)
      space_system_index = nil
      unless space.spaceType.empty?
        # gets row information from standards spreadsheet.
        space_type_data = standards_lookup_table_first(table_name: 'space_types', search_criteria: {'template' => self.class.name,
                                                                                                    'space_type' => space.spaceType.get.standardsSpaceType.get,
                                                                                                    'building_type' => space.spaceType.get.standardsBuildingType.get})
        raise("Could not find spacetype information in #{self.class.name} for space_type => #{space.spaceType.get.standardsSpaceType.get} - #{space.spaceType.get.standardsBuildingType.get}") if space_type_data.nil?
      end

      #Get Heating and cooling loads
      cooling_design_load = space.spaceType.get.standardsSpaceType.get == '- undefined -' ? 0.0 : space.thermalZone.get.coolingDesignLoad.get * space.floorArea * space.multiplier / 1000.0
      heating_design_load = space.spaceType.get.standardsSpaceType.get == '- undefined -' ? 0.0 : space.thermalZone.get.heatingDesignLoad.get * space.floorArea * space.multiplier / 1000.0


      # identify space-system_index and assign the right NECB system type 1-7.
      necb_hvac_system_selection_table = standards_lookup_table_many(table_name: 'necb_hvac_system_selection_type')
      necb_hvac_system_select = necb_hvac_system_selection_table.detect do |necb_hvac_system_select|
        necb_hvac_system_select['necb_hvac_system_selection_type'] == space_type_data['necb_hvac_system_selection_type'] &&
            necb_hvac_system_select['min_stories'] <= model.getBuilding.standardsNumberOfAboveGroundStories.get &&
            necb_hvac_system_select['max_stories'] >= model.getBuilding.standardsNumberOfAboveGroundStories.get &&
            necb_hvac_system_select['min_cooling_capacity_kw'] <= cooling_design_load &&
            necb_hvac_system_select['max_cooling_capacity_kw'] >= cooling_design_load
      end

      #======

      horizontal_placement = nil
      vertical_placement = nil
      json_data = nil

      #get all exterior surfaces.
      surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces,
                                                                        ["Outdoors",
                                                                         "Ground",
                                                                         "GroundFCfactorMethod",
                                                                         "GroundSlabPreprocessorAverage",
                                                                         "GroundSlabPreprocessorCore",
                                                                         "GroundSlabPreprocessorPerimeter",
                                                                         "GroundBasementPreprocessorAverageWall",
                                                                         "GroundBasementPreprocessorAverageFloor",
                                                                         "GroundBasementPreprocessorUpperWall",
                                                                         "GroundBasementPreprocessorLowerWall"])

      #exterior Surfaces
      ext_wall_surfaces = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces, ["Wall"])
      ext_bottom_surface = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces, ["Floor"])
      ext_top_surface = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces, ["RoofCeiling"])

      #Interior Surfaces..if needed....
      internal_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, ["Surface"])
      int_wall_surfaces = BTAP::Geometry::Surfaces::filter_by_surface_types(internal_surfaces, ["Wall"])
      int_bottom_surface = BTAP::Geometry::Surfaces::filter_by_surface_types(internal_surfaces, ["Floor"])
      int_top_surface = BTAP::Geometry::Surfaces::filter_by_surface_types(internal_surfaces, ["RoofCeiling"])


      vertical_placement = "NA"
      #determine if space is a top or bottom, both or middle space.
      if ext_bottom_surface.size > 0 and ext_top_surface.size > 0 and int_bottom_surface.size == 0 and int_top_surface.size == 0
        vertical_placement = "single_story_space"
      elsif int_bottom_surface.size > 0 and ext_top_surface.size > 0 and int_bottom_surface.size > 0
        vertical_placement = "top"
      elsif ext_bottom_surface.size > 0 and ext_top_surface.size == 0
        vertical_placement = "bottom"
      elsif ext_bottom_surface.size == 0 and ext_top_surface.size == 0
        vertical_placement = "middle"
      end


      #determine if what cardinal direction has the majority of external
      #surface area of the space.
      #set this to 'core' by default and change it if it is found to be a space exposed to a cardinal direction.
      horizontal_placement = nil
      #set up summing hashes for each direction.
      json_data = Hash.new
      walls_area_array = Hash.new
      subsurface_area_array = Hash.new
      boundary_conditions = {}
      boundary_conditions[:outdoors] = ["Outdoors"]
      boundary_conditions[:ground] = [
          "Ground",
          "GroundFCfactorMethod",
          "GroundSlabPreprocessorAverage",
          "GroundSlabPreprocessorCore",
          "GroundSlabPreprocessorPerimeter",
          "GroundBasementPreprocessorAverageWall",
          "GroundBasementPreprocessorAverageFloor",
          "GroundBasementPreprocessorUpperWall",
          "GroundBasementPreprocessorLowerWall"]
      #go through all directions.. need to do north twice since that goes around zero degree mark.
      orientations = [
          {:surface_type => 'Wall', :direction => 'north', :azimuth_from => 0.00, :azimuth_to => 45.0, :tilt_from => 0.0, :tilt_to => 180.0},
          {:surface_type => 'Wall', :direction => 'north', :azimuth_from => 315.001, :azimuth_to => 360.0, :tilt_from => 0.0, :tilt_to => 180.0},
          {:surface_type => 'Wall', :direction => 'east', :azimuth_from => 45.001, :azimuth_to => 135.0, :tilt_from => 0.0, :tilt_to => 180.0},
          {:surface_type => 'Wall', :direction => 'south', :azimuth_from => 135.001, :azimuth_to => 225.0, :tilt_from => 0.0, :tilt_to => 180.0},
          {:surface_type => 'Wall', :direction => 'west', :azimuth_from => 225.001, :azimuth_to => 315.0, :tilt_from => 0.0, :tilt_to => 180.0},
          {:surface_type => 'RoofCeiling', :direction => 'top', :azimuth_from => 0.0, :azimuth_to => 360.0, :tilt_from => 0.0, :tilt_to => 180.0},
          {:surface_type => 'Floor', :direction => 'bottom', :azimuth_from => 0.0, :azimuth_to => 360.0, :tilt_from => 0.0, :tilt_to => 180.0}
      ]
      [:outdoors, :ground].each do |bc|
        orientations.each do |orientation|
          walls_area_array[orientation[:direction]] = 0.0
          subsurface_area_array[orientation[:direction]] = 0.0
          json_data[:surface_data] = []
        end
      end


      [:outdoors, :ground].each do |bc|
        orientations.each do |orientation|
          puts "bc= #{bc}"
          puts boundary_conditions[bc.to_sym]
          puts boundary_conditions
          surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, boundary_conditions[bc])
          selected_surfaces = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces, [orientation[:surface_type]])
          BTAP::Geometry::Surfaces::filter_by_azimuth_and_tilt(selected_surfaces, orientation[:azimuth_from], orientation[:azimuth_to], orientation[:tilt_from], orientation[:tilt_to]).each do |surface|
            #sum wall area and subsurface area by direction. This is the old way so excluding top and bottom surfaces.
            walls_area_array[orientation[:direction]] += surface.grossArea unless ['RoofCeiling', 'Floor'].include?(orientation[:surface_type])
            #new way
            glazings = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(surface.subSurfaces, ["FixedWindow", "OperableWindow", "GlassDoor", "Skylight", "TubularDaylightDiffuser", "TubularDaylightDome"])
            doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(surface.subSurfaces, ["Door", "OverheadDoor"])
            azimuth = (surface.azimuth() * 180.0 / Math::PI).to_i
            tilt = (surface.tilt() * 180.0 / Math::PI).to_i
            surface_data = json_data[:surface_data].detect {|surface_data| surface_data[:surface_type] == surface.surfaceType && surface.surfaceType && surface_data[:azimuth] == azimuth && surface_data[:tilt] == tilt && surface_data[:boundary_condition] == bc}
            if surface_data.nil?
              surface_data = {:surface_type => surface.surfaceType, :azimuth => azimuth, :tilt => tilt, :boundary_condition => bc, :surface_area => 0.0, :glazed_subsurface_area => 0.0, :opaque_subsurface_area => 0.0}
              json_data[:surface_data] << surface_data
            end
            surface_data[:surface_area] += surface.grossArea.to_i
            surface_data[:glazed_subsurface_area] += glazings.map {|subsurface| subsurface.grossArea}.inject(0) {|sum, x| sum + x}.to_i
            surface_data[:surface_area] += doors.map {|subsurface| subsurface.grossArea}.inject(0) {|sum, x| sum + x}.to_i
          end
        end
      end

      horizontal_placement = nil
      wall_surface_data = json_data[:surface_data].select {|surface| surface[:surface_type] == "Wall"}
      if wall_surface_data.empty?
        horizontal_placement = 'core' #should change to attic.
      else
        max_area_azimuth = wall_surface_data.max_by {|k| k[:surface_area]}[:azimuth]

        #if no surfaces ext or ground.. then set the space as a core space.
        if json_data[:surface_data].inject(0) {|sum, hash| sum + hash[:surface_area]} == 0.0
          horizontal_placement = 'core'
        elsif (max_area_azimuth >= 0.0 && max_area_azimuth <= 45.00) || (max_area_azimuth >= 315.01 && max_area_azimuth <= 360.00)
          horizontal_placement = 'north'
        elsif (max_area_azimuth >= 45.01 && max_area_azimuth <= 135.00)
          horizontal_placement = 'east'
        elsif (max_area_azimuth >= 135.01 && max_area_azimuth <= 225.00)
          horizontal_placement = 'south'
        elsif (max_area_azimuth >= 225.01 && max_area_azimuth <= 315.00)
          horizontal_placement = 'west'
        end
      end

      # dump all info into an array for debugging and iteration.
      unless space.spaceType.empty?
        space_zoning_data_array_json << {
            space: space,
            space_name: space.name,
            floor_area: space.floorArea,
            horizontal_placement: horizontal_placement,
            vertical_placement: vertical_placement,
            building_type_name: space.spaceType.get.standardsBuildingType.get, # space type name
            space_type_name: space.spaceType.get.standardsSpaceType.get, # space type name
            short_space_type_name: "#{space.spaceType.get.standardsBuildingType.get}-#{space.spaceType.get.standardsSpaceType.get}",
            necb_hvac_system_selection_type: space_type_data['necb_hvac_system_selection_type'], #
            system_number: necb_hvac_system_select['system_type'].nil? ? nil : necb_hvac_system_select['system_type'], # the necb system type
            number_of_stories: model.getBuilding.standardsNumberOfAboveGroundStories.get, # number of stories
            heating_design_load: heating_design_load,
            cooling_design_load: cooling_design_load,
            is_dwelling_unit: necb_hvac_system_select['dwelling'], # Checks if it is a dwelling unit.
            is_wildcard: necb_hvac_system_select['necb_hvac_system_selection_type'] == 'Wildcard' ? true : nil,
            schedule_type: determine_necb_schedule_type(space).to_s,
            multiplier: (@space_multiplier_map[space.name.to_s].nil? ? 1 : @space_multiplier_map[space.name.to_s]),
            surface_data: json_data[:surface_data]
        }
      end
    end
    File.write("#{File.dirname(__FILE__)}/newway.json", JSON.pretty_generate(space_zoning_data_array_json))
    # reduce the number of zones by first finding spaces with similar load profiles.. That means
    # 1. same space_type
    # 2. same envelope exposure
    # 3. same schedule (should be the same as #2)

    # Get all the spacetypes used in the spaces.
    dwelling_group_index = 0
    wildcard_group_index = 0
    regular_group_index = 0

    unique_spacetypes = space_zoning_data_array_json.map {|space_info| space_info[:short_space_type_name]}.uniq()
    unique_spacetypes.each do |unique_spacetype|
      spaces_of_a_spacetype = space_zoning_data_array_json.select {|space_info| space_info[:short_space_type_name] == unique_spacetype}
      spaces_of_a_spacetype.each do |space_info|
        if space_info[:is_dwelling_unit] == true
          # these units are regretablly on their own system. So they must be zone on their own for costing purposes.

        elsif space_info[:is_wildcard] == true
          # These spaces need to be added to nearby system or on their own system.
        else # all other spaces
          # find all spaces with same envelope loads.
          spaces_of_a_spacetype.each do |space_info_2|
            space_info[:surface_data] == space_info_2[:surface_data]
          end
        end
      end
    end


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
            puts space_zone_data[:space].name.get.to_s
            break
          end
        end
        raise "Could not determine adj space system to space #{space_zone_data.space.name.get}" if space_zone_data[:system_number].nil?
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
        space_zoning_data_array_json.map {|item| item[:schedule_type]}.uniq!.each do |schedule_type|
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
          add_sys1_unitary_ac_baseboard_heating(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['mau_type'], system_fuel_defaults['mau_heating_coil_type'], system_fuel_defaults['baseboard_type'], hw_loop)
        when 2
          add_sys2_FPFC_sys5_TPFC(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['chiller_type'], 'FPFC', system_fuel_defaults['mau_cooling_type'], hw_loop)
        when 3
          add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['heating_coil_type_sys3'], system_fuel_defaults['baseboard_type'], hw_loop)
        when 4
          add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['heating_coil_type_sys4'], system_fuel_defaults['baseboard_type'], hw_loop)
        when 5
          add_sys2_FPFC_sys5_TPFC(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['chiller_type'], 'TPFC', system_fuel_defaults['mau_cooling_type'], hw_loop)
        when 6
          add_sys6_multi_zone_built_up_system_with_baseboard_heating(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['heating_coil_type_sys6'], system_fuel_defaults['baseboard_type'], system_fuel_defaults['chiller_type'], system_fuel_defaults['fan_type'], hw_loop)
        when 7
          add_sys2_FPFC_sys5_TPFC(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['chiller_type'], 'FPFC', system_fuel_defaults['mau_cooling_type'], hw_loop)
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
end
