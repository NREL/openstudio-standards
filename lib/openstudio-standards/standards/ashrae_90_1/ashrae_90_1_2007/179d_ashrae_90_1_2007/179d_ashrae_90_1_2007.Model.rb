class ACM179dASHRAE9012007
  def __model_get_primary_building_type(model)
    building_types = {}

    building = model.getBuilding
    building_level_bt = nil
    if building.standardsBuildingType.is_initialized
      building_level_bt = building.standardsBuildingType.get
      # Turns "SmallOffice" in "Office"
      building_level_bt = model_get_lookup_name(building_level_bt)
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "found Building level standardsBuildingType = '#{building_level_bt}'")
    end

    model.getSpaceTypes.sort.each do |space_type|
      # populate hash of building types
      if !space_type.standardsBuildingType.is_initialized
        next
      end

      bldg_type_ori = space_type.standardsBuildingType.get
      # Turns "SmallOffice" in "Office". To ensure we aggregate properly
      bldg_type = model_get_lookup_name(bldg_type_ori)
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "found building type for Space Type '#{space_type.name}' = '#{bldg_type}'")
      if bldg_type_ori != bldg_type
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Space Type '#{space_type.name}' has actual Building Type '#{bldg_type_ori}' but sanitizing as '#{bldg_type}' for aggregation")
      end
      if building_types.key?(bldg_type)
        building_types[bldg_type] += space_type.floorArea
      else
        building_types[bldg_type] = space_type.floorArea
      end
    end

    if building_types.empty?
      if building_level_bt.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot identify a single building type in model, none of your #{model.getSpaceTypes.size} SpaceTypes have a standardsBuildingType assigned and neither does the Building")
        raise 'No Primary Building Type found'
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "No area determination based on space types found, using Building level standardsBuildingType = '#{building_level_bt}'")
        return building_level_bt
      end
    end

    space_type_level_bt = building_types.max_by { |_, v| v }.first
    if !building_level_bt.nil?
      if building_level_bt != space_type_level_bt
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "The Building has standardsBuildingType '#{building_level_bt}' while the area determination based on space types has '#{space_type_level_bt}'. Preferring the Space Type one")
      end
      return space_type_level_bt
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Building doesn't have a standardsBuildingType, using the area determination based on space types = '#{space_type_level_bt}'")
    return space_type_level_bt
  end

  # This starts by always using model_get_lookup_name to sanitize the names
  # Meaning 'RetailStripmall' is changed to 'StripMall' for eg
  # If remap_office is false, even if you have 'SmallOffice' it returns
  # 'Office'
  # It remap_office is true, it returns 'SmallOffice', 'MediumOffice' or 'LargeOffice'
  def model_get_primary_building_type(model, remap_office: false, remap_retail: false)
    # Maybe this is a premature optimization, but memoize the computation
    @primary_building_types_memoized ||= {}
    # TODO: this will work if you pass the same model. But if you do sp.model
    # then it changes everytime. Need to figure out a way to check if it points
    # to the same model or not, or remove the memoization
    @primary_building_types_memoized[model] ||= __model_get_primary_building_type(model)

    building_type = @primary_building_types_memoized[model]
    if remap_office && building_type == 'Office'
      floor_area_m2 = model.getBuilding.floorArea
      building_type = model_remap_office(model, floor_area_m2)
    end
    if remap_retail
      if building_type == 'StripMall'
        return 'RetailStripmall'
      elsif building_type == 'Retail'
        return 'RetailStandalone'
      end
    end
    return building_type
  end

  # **NOTE**: Patched to check also number of floors
  # remap office to one of the prototype buildings
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param floor_area [Double] floor area (m^2)
  # @return [String] SmallOffice, MediumOffice, LargeOffice
  def model_remap_office(model, floor_area)
    floor_area_sqft = OpenStudio.convert(floor_area, 'm^2', 'ft^2').get
    num_floors = model.getBuilding.buildingStories.size
    if floor_area_sqft < 25_000
      if num_floors <= 3
        return 'SmallOffice'
      else
        return 'MediumOffice'
      end
    elsif floor_area_sqft < 150_000
      if num_floors <= 5
        return 'MediumOffice'
      else
        return 'LargeOffice'
      end
    else
      return 'LargeOffice'
    end
  end

  # Patched to prefer the space area method above instead of just relying on
  # Building object
  def model_get_building_properties(model, remap_office = true)
    # get climate zone from model
    climate_zone = model_standards_climate_zone(model)

    # get building type from model
    building_type = model_get_primary_building_type(model, remap_office: remap_office)

    # get standards template
    if model.getBuilding.standardsTemplate.is_initialized
      standards_template = model.getBuilding.standardsTemplate.get
    end

    results = {}
    results['climate_zone'] = climate_zone
    results['building_type'] = building_type
    results['standards_template'] = standards_template

    return results
  end

  def model_prm_baseline_system_number(_model, _climate_zone, area_type, _fuel_type, area_ft2, num_stories, custom)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.prm', '179d: Heat Storage area applied as 90.1-2007 with addenda dn')
    sys_num = nil

    # Set the area limit
    limit_ft2 = 25_000

    # Customization for Xcel EDA.
    # No special retail category
    # for regular 90.1-2010.
    if custom != 'Xcel Energy CO EDA' && (area_type == 'retail')
      area_type = 'nonresidential'
    end

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

    return sys_num
  end

  # Returns standards data for selected model
  # This will check the building primary type instead
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [hash] hash of internal loads for different load types
  def model_get_standards_data(model, throw_if_not_found: false)
    # This returns 'Office' for eg
    standards_building_type = model_get_primary_building_type(model, remap_office: false)

    # populate search hash
    search_criteria = {
      'template' => template,
      'building_type' => standards_building_type,
      'space_type' => whole_building_space_type_name(model, standards_building_type)
    }

    # lookup space type properties
    space_type_properties = model_find_object(standards_data['space_types'], search_criteria)

    if space_type_properties.nil?
      msg = "Space type properties lookup failed: #{search_criteria}."
      if throw_if_not_found
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SpaceType', msg)
        raise msg
      end
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.SpaceType', msg)
      space_type_properties = {}
    end

    return space_type_properties
  end

  HVAC_AVAILABILITY_SCHEDULE_MAP = {
    # This is a map of HVAC Type to An array of methods
    # Type => [[:getter, :setter], [:getter, :setter]]
    'AirLoopHVAC' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardConvectiveElectric' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardConvectiveWater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardRadiantConvectiveElectric' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardRadiantConvectiveWater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACCoolingPanelRadiantConvectiveWater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACDehumidifierDX' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACEnergyRecoveryVentilator' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACFourPipeFanCoil' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACHighTemperatureRadiant' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACIdealLoadsAirSystem' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACLowTemperatureRadiantElectric' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACLowTempRadiantConstFlow' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACLowTempRadiantVarFlow' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACPackagedTerminalAirConditioner' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACPackagedTerminalHeatPump' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACUnitHeater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACUnitVentilator' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACWaterToAirHeatPump' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'AirLoopHVACUnitarySystem' => [
      # TODO
      # [:availabilitySchedule, :setAvailabilitySchedule],
      [:supplyAirFanOperatingModeSchedule, :setSupplyAirFanOperatingModeSchedule]
    ]
  }.freeze

  def model_apply_acm_hvac_availability_schedule(model)
    data = model_get_standards_data(model, throw_if_not_found: true)
    acm_fan_sch_name = data['hvac_operation_schedule']
    acm_fan_sch = nil

    count_availability = 0
    HVAC_AVAILABILITY_SCHEDULE_MAP.each do |hvac_type, methods|
      objects = model.send("get#{hvac_type}s")
      next if objects.empty?

      if acm_fan_sch.nil?
        acm_fan_sch = model_add_schedule(model, acm_fan_sch_name)
        model.getBuilding.additionalProperties.setFeature('acm_fan_sch', acm_fan_sch_name)
      end

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model_apply_acm_hvac_availability_schedule', "HVAC - found #{objects.size} #{hvac_type} object(s)")
      objects.each do |obj|
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model_apply_acm_hvac_availability_schedule', "HVAC - overriding availability schedule in '#{obj.nameString}' to #{acm_fan_sch.nameString}")
        methods.each do |_getter, setter|
          raise "HVAC_AVAILABILITY_SCHEDULE_MAP is out of date, #{obj.briefDescription} does not respond to #{setter}" unless obj.respond_to?(setter)

          ret = obj.send(setter, acm_fan_sch)
          if !ret
            OpenStudio.logFree(OpenStudio::Warning, 'openstudio.model_apply_acm_hvac_availability_schedule', "Failed to apply availability schedule via #{setter} for #{obj.briefDescription}")
          end
        end
        count_availability += 1
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model_apply_acm_hvac_availability_schedule', "Applied availablity schedule '#{acm_fan_sch_name}' to #{count_availability} objects.")
    return count_availability > 0
  end
end
