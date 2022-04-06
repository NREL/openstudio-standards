class ASHRAE901PRM2019 < ASHRAE901PRM
  # @!group Model

  # Determine if there is a need for a proposed model sizing run.
  # A typical application of such sizing run is to determine space
  # conditioning type.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  #
  # @return [Boolean] Returns true if a sizing run is required
  def model_create_prm_baseline_building_requires_proposed_model_sizing_run(model)
    return true
  end

  # Determines the area of the building above which point
  # the non-dominant area type gets it's own HVAC system type.
  # @return [Double] the minimum area (m^2)
  def model_prm_baseline_system_group_minimum_area(model, custom)
    exception_min_area_ft2 = 20_000
    # Customization - Xcel EDA Program Manual 2014
    # 3.2.1 Mechanical System Selection ii
    if custom == 'Xcel Energy CO EDA'
      exception_min_area_ft2 = 5000
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Customization; per Xcel EDA Program Manual 2014 3.2.1 Mechanical System Selection ii, minimum area for non-predominant conditions reduced to #{exception_min_area_ft2} ft2.")
    end
    exception_min_area_m2 = OpenStudio.convert(exception_min_area_ft2, 'ft^2', 'm^2').get
    return exception_min_area_m2
  end

  # Determines which system number is used
  # for the baseline system.
  # @return [String] the system number: 1_or_2, 3_or_4,
  # 5_or_6, 7_or_8, 9_or_10
  def model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    sys_num = nil

    # Customization - Xcel EDA Program Manual 2014
    # Table 3.2.2 Baseline HVAC System Types
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 lookup for HVAC system types shall be used.')

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
          # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
          # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        # Should only be hit by Xcel EDA
        sys_num = '3_or_4'
      end

    else

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
        # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
        # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        sys_num = '3_or_4'
      end

    end

    return sys_num
  end

  # Change the fuel type based on climate zone, depending on the standard.
  # For 90.1-2013, fuel type is based on climate zone, not the proposed model.
  # @return [String] the revised fuel type
  def model_prm_baseline_system_change_fuel_type(model, fuel_type, climate_zone, custom = nil)
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 rules for heating fuel type (based on proposed model) rules apply.')
      return fuel_type
    end

    # For 90.1-2013 the fuel type is determined based on climate zone.
    # Don't change the fuel if it purchased heating or cooling.
    if fuel_type == 'electric' || fuel_type == 'fossil'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
           'ASHRAE 169-2006-2A',
           'ASHRAE 169-2006-3A',
           'ASHRAE 169-2013-1A',
           'ASHRAE 169-2013-2A',
           'ASHRAE 169-2013-3A'
        fuel_type = 'electric'
      else
        fuel_type = 'fossil'
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Heating fuel is #{fuel_type} for 90.1-2013, climate zone #{climate_zone}.  This is independent of the heating fuel type in the proposed building, per G3.1.1-3.  This is different than previous versions of 90.1.")
    end

    return fuel_type
  end

  # Determines the fan type used by VAV_Reheat and VAV_PFP_Boxes systems.
  # Variable speed fan for 90.1-2013
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_baseline_system_vav_fan_type(model)
    fan_type = 'Variable Speed Fan'
    return fan_type
  end

  # Determines the skylight to roof ratio limit for a given standard
  # 3% for 90.1-PRM-2019
  # @return [Double] the skylight to roof ratio, as a percent: 5.0 = 5%
  def model_prm_skylight_to_roof_ratio_limit(model)
    srr_lim = 3.0
    return srr_lim
  end

  # Analyze HVAC, window-to-wall ratio and SWH building (area) types from user data inputs in the @standard_data library
  # This function returns True, but the values are stored in the multi-building_data argument.
  # The hierarchy for process the building types
  # 1. Highest: PRM rules - if rules applied against user inputs, the function will use the calculated value to reset the building type
  # 2. Second: User defined building type in the csv file.
  # 3. Third: User defined userdata_building.csv file. If an object (e.g. space, thermalzone) are not defined in their correspondent userdata csv file, use the building csv file
  # 4. Fourth: Dropdown list in the measure GUI. If none presented, use the data from the dropdown list.
  # NOTE! This function will add building types to OpenStudio objects as an additional features for hierarchy 1-3
  # The object additional feature is empty when the function determined it uses fourth hierarchy.
  #
  # @param [OpenStudio::Model::Model] model
  # @param [String] climate_zone
  # @param [String] default_hvac_building_type (Fourth Hierarchy hvac building type)
  # @param [String] default_wwr_building_type (Fourth Hierarchy wwr building type)
  # @param [String] default_swh_building_type (Fourth Hierarchy swh building type)
  # @param [Hash] bldg_type_zone_hash An empty hash that maps building type for hvac to a list of thermal zones
  # @param [Hash] air_loop_thermal_zone_hash An empty hash that maps air loop with thermal zones
  # @return True
  def handle_multi_building_area_types(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash, air_loop_thermal_zone_hash)
    # Construct the user_building hashmap
    user_buildings = @standards_data.key?('userdata_building') ? @standards_data['userdata_building'] : nil

    # Build up a hvac_building_type : thermal zone hash map
    # =============================HVAC user data process===========================================
    user_thermal_zones = @standards_data.key?('userdata_thermal_zone') ? @standards_data['userdata_thermal_zone'] : nil
    # First construct hvac building type -> thermal Zone hash and hvac building type -> floor area
    bldg_type_zone_hash = {}
    bldg_type_zone_area_hash = {}
    model.getThermalZones.each do |thermal_zone|
      # get climate zone to check the conditioning category
      thermal_zone_condition_category = thermal_zone_conditioning_category(thermal_zone, climate_zone)
      if thermal_zone_condition_category == 'Semiheated' || thermal_zone_condition_category == 'Unconditioned'
        next
      end

      # Check for Second hierarchy
      hvac_building_type = nil
      if user_thermal_zones && user_thermal_zones.length >= 1
        user_thermal_zone_index = user_thermal_zones.index { |user_thermal_zone| user_thermal_zone['name'] == thermal_zone.name.get }
        # make sure the thermal zone has assigned a building_type_for_hvac
        unless user_thermal_zone_index.nil? || user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac'].nil?
          # Only thermal zone in the user data and have building_type_for_hvac data will be assigned.
          hvac_building_type = user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac']
        end
      end
      # Second hierarchy does not apply, check Third hierarchy
      if hvac_building_type.nil? && user_buildings && user_buildings.length >= 1
        building_name = thermal_zone.model.building.get.name.get
        user_building_index = user_buildings.index { |user_building| user_building['name'] == building_name }
        unless user_building_index.nil? || user_buildings[user_building_index]['building_type_for_hvac'].nil?
          # Only thermal zone in the buildings user data and have building_type_for_hvac data will be assigned.
          hvac_building_type = user_buildings[user_building_index]['building_type_for_hvac']
        end
      end
      # Third hierarchy does not apply, apply Fourth hierarchy
      if hvac_building_type.nil?
        hvac_building_type = default_hvac_building_type
      end
      # Add data to the hash map
      unless bldg_type_zone_hash.key?(hvac_building_type)
        bldg_type_zone_hash[hvac_building_type] = []
      end
      unless bldg_type_zone_area_hash.key?(hvac_building_type)
        bldg_type_zone_area_hash[hvac_building_type] = 0.0
      end
      # calculate floor area for the thermal zone
      part_of_floor_area = false
      thermal_zone.spaces.sort.each do |space|
        next unless space.partofTotalFloorArea

        # a space in thermal zone is part of floor area.
        part_of_floor_area = true
        bldg_type_zone_area_hash[hvac_building_type] += space.floorArea * space.multiplier
      end
      if part_of_floor_area
        # Only add the thermal_zone if it is part of the floor area
        bldg_type_zone_hash[hvac_building_type].append(thermal_zone)
      end
    end
    # Handle an edge case that all zones in the model are unconditioned.
    unless bldg_type_zone_hash.empty?
      # Calculate the total floor area.
      # If the max tie, this algorithm will pick the first encountered hvac building type as the maximum.
      total_floor_area = 0.0
      hvac_bldg_type_with_max_floor = nil
      hvac_bldg_type_max_floor_area = 0.0
      bldg_type_zone_area_hash.each do |key, value|
        if value > hvac_bldg_type_max_floor_area
          hvac_bldg_type_with_max_floor = key
          hvac_bldg_type_max_floor_area = value
        end
        total_floor_area += value
      end

      # Reset the thermal zones by going through the hierarchy 1 logics
      bldg_type_hvac_zone_hash.clear
      # Add the thermal zones for the maximum floor (primary system)
      bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor] = bldg_type_zone_hash[hvac_bldg_type_with_max_floor]
      bldg_type_zone_hash.each do |bldg_type, bldg_type_zone|
        # loop the rest bldg_types
        unless bldg_type.eql? hvac_bldg_type_with_max_floor
          if OpenStudio.convert(total_floor_area, 'm^2', 'ft^2').get <= 40000
            # Building is smaller than 40k sqft, it could only have one hvac_building_type, reset all the thermal zones.
            bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor].push(*bldg_type_zone)
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The building floor area is less than 40,000 square foot. Thermal zones under hvac building type #{bldg_type} is reset to #{hvac_bldg_type_with_max_floor}")
          else
            if OpenStudio.convert(bldg_type_zone_area_hash[bldg_type], 'm^2', 'ft^2').get < 20000
              # in this case, all thermal zones shall be categorized as the primary hvac_building_type
              bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor].push(*bldg_type_zone)
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The floor area in hvac building type #{bldg_type} is less than 20,000 square foot. Thermal zones under this hvac building type is reset to #{hvac_bldg_type_with_max_floor}")
            else
              bldg_type_hvac_zone_hash[bldg_type] = bldg_type_zone
            end
          end
        end
      end

      # Write in hvac building type thermal zones by thermal zone
      bldg_type_hvac_zone_hash.each do |h1_bldg_type, bldg_type_zone_array|
        bldg_type_zone_array.each do |thermal_zone|
          thermal_zone.additionalProperties.setFeature('building_type_for_hvac', h1_bldg_type)
        end
      end
    end

    # =============================SPACE user data process===========================================
    user_spaces = @standards_data.key?('userdata_space') ? @standards_data['userdata_space'] : nil
    model.getSpaces.each do |space|
      type_for_wwr = nil
      # Check for 2nd level hierarchy
      if user_spaces && user_spaces.length >= 1
        user_spaces.each do |user_space|
          unless user_space['building_type_for_wwr'].nil?
            if space.name.get == user_space['name']
              type_for_wwr = user_space['building_type_for_wwr']
            end
          end
        end
      end

      if type_for_wwr.nil?
        # 2nd Hierarchy does not apply, check for 3rd level hierarchy
        building_name = space.model.building.get.name.get
        if user_buildings && user_buildings.length >= 1
          user_buildings.each do |user_building|
            unless user_building['building_type_for_wwr'].nil?
              if user_building['name'] == building_name
                type_for_wwr = user_building['building_type_for_wwr']
              end
            end
          end
        end
      end

      if type_for_wwr.nil?
        # 3rd level hierarchy does not apply, Apply 4th level hierarchy
        type_for_wwr = default_wwr_building_type
      end
      # add wwr type to space:
      space.additionalProperties.setFeature('building_type_for_wwr', type_for_wwr)
    end
    # =============================SWH user data process===========================================
    user_wateruse_equipments = @standards_data.key?('userdata_wateruse_equipment') ? @standards_data['userdata_wateruse_equipment'] : nil
    model.getWaterUseEquipments.each do |wateruse_equipment|
      type_for_swh = nil
      # Check for 2nd hierarchy
      if user_wateruse_equipments && user_wateruse_equipments.length >= 1
        user_wateruse_equipments.each do |user_wateruse_equipment|
          unless user_wateruse_equipment['building_type_for_swh'].nil?
            if wateruse_equipment.name.get == user_wateruse_equipment['name']
              type_for_swh = user_wateruse_equipment['building_type_for_swh']
            end
          end
        end
      end

      if type_for_swh.nil?
        # 2nd hierarchy does not apply, check for 3rd hierarchy
        # get space building type
        building_name = wateruse_equipment.model.building.get.name.get
        if user_buildings && user_buildings.length >= 1
          user_buildings.each do |user_building|
            unless user_building['building_type_for_swh'].nil?
              if user_building['name'] == building_name
                type_for_swh = user_building['building_type_for_swh']
              end
            end
          end
        end
      end

      if type_for_swh.nil?
        # 3rd hierarchy does not apply, apply 4th hierarchy
        type_for_swh = default_swh_building_type
      end
      # add swh type to wateruse equipment:
      wateruse_equipment.additionalProperties.setFeature('building_type_for_swh', type_for_swh)
    end

    # ============================Process airloop info ============================================
    user_airloops = @standards_data.key?('userdata_airloop_hvac') ? @standards_data['userdata_airloop_hvac'] : nil
    # TODO: for now, it just work with economizer exceptions
    model.getAirLoopHVACs.each do |air_loop|
      air_loop_name = air_loop.name.get
      if user_airloops && user_airloops.length > 1
        user_airloops.each do |user_airloop|
          if air_loop_name == user_airloop['name']
            if user_airloop.key?('economizer_exception_for_gas_phase_air_cleaning') &&
               user_airloop['economizer_exception_for_gas_phase_air_cleaning'].downcase == 'yes'
              unless air_loop_thermal_zone_hash.key?('economizer_exception_for_gas_phase_air_cleaning')
                air_loop_thermal_zone_hash['economizer_exception_for_gas_phase_air_cleaning'] = []
              end
              air_loop_thermal_zone_hash['economizer_exception_for_gas_phase_air_cleaning'] | air_loop.thermalZones.get
            end

            if user_airloop.key?('economizer_exception_for_open_refrigerated_cases') &&
               user_airloop['economizer_exception_for_open_refrigerated_cases'].downcase == 'yes'
              unless air_loop_thermal_zone_hash.key?('economizer_exception_for_open_refrigerated_cases')
                air_loop_thermal_zone_hash['economizer_exception_for_open_refrigerated_cases'] = []
              end
              air_loop_thermal_zone_hash['economizer_exception_for_open_refrigerated_cases'] | air_loop.thermalZones.get
            end
          end
        end
      end
    end

    return true
  end

  # Determine the surface range of a baseline model.
  # The method calculates the window to wall ratio (assuming all spaces are conditioned)
  # and select the range based on the calculated window to wall ratio
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param wwr_parameter [Hash] parameters to choose min and max percent of surfaces,
  #            could be different set in different standard
  def model_get_percent_of_surface_range(model, wwr_parameter)
    wwr_range = { 'minimum_percent_of_surface' => nil, 'maximum_percent_of_surface' => nil }
    intended_surface_type = wwr_parameter['intended_surface_type']
    if intended_surface_type == 'ExteriorWindow' || intended_surface_type == 'GlassDoor'
      if wwr_parameter.key?('wwr_building_type')
        wwr_building_type = wwr_parameter['wwr_building_type']
        wwr_info = wwr_parameter['wwr_info']
        if wwr_info[wwr_building_type] <= 10
          wwr_range['minimum_percent_of_surface'] = 0
          wwr_range['maximum_percent_of_surface'] = 10
        elsif wwr_info[wwr_building_type] <= 20
          wwr_range['minimum_percent_of_surface'] = 10.1
          wwr_range['maximum_percent_of_surface'] = 20
        elsif wwr_info[wwr_building_type] <= 30
          wwr_range['minimum_percent_of_surface'] = 20.1
          wwr_range['maximum_percent_of_surface'] = 30
        elsif wwr_info[wwr_building_type] <= 40
          wwr_range['minimum_percent_of_surface'] = 30.1
          wwr_range['maximum_percent_of_surface'] = 40
        else
          wwr_range['minimum_percent_of_surface'] = nil
          wwr_range['maximum_percent_of_surface'] = nil
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No wwr_building_type found for ExteriorWindow or GlassDoor')
      end
    end
    return wwr_range
  end
end
