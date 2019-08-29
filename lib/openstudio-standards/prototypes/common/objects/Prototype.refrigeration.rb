class Standard
  # @!group refrigeration

  # Adds a refrigerated case to the model.
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # case is located, and which will be impacted by the case's thermal load.
  # @param case_type [String] the case type/name. For valid choices
  # This parameter is used also by the "Refrigeration System Lineup" tab.
  # refer to the ""Refrigerated Cases" tab on the OpenStudio_Standards spreadsheet.
  # @param size_category [String] size category of the building area. Valid choices
  # are: "<35k ft2", "35k - 50k ft2", ">50k ft2"
  def model_add_refrigeration_case(model, thermal_zone, case_type, size_category)
    # Get the case properties
    #

    search_criteria = {
      'template' => template,
      'case_type' => case_type,
      'size_category' => size_category
    }

    props = model_find_object(standards_data['refrigerated_cases'], search_criteria)
    if props.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigerated case properties for: #{search_criteria}.")
      return nil
    end

    # Capacity, defrost, anti-sweat
    case_length = OpenStudio.convert(props['case_length'], 'ft', 'm').get
    case_temp = OpenStudio.convert(props['case_temp'], 'F', 'C').get
    cooling_capacity_per_length = OpenStudio.convert(props['cooling_capacity_per_length'], 'Btu/hr*ft', 'W/m').get
    evap_fan_power_per_length = OpenStudio.convert(props['evap_fan_power_per_length'], 'W/ft', 'W/m').get
    if props['evap_temp']
      evap_temp_c = OpenStudio.convert(props['evap_temp'], 'F', 'C').get
    end
    lighting_w_per_m = OpenStudio.convert(props['lighting_per_ft'], 'W/ft', 'W/m').get
    if props['lighting_schedule']
      case_lighting_schedule = model_add_schedule(model, props['lighting_schedule'])
    else
      case_lighting_schedule = model.alwaysOnDiscreteSchedule
    end
    fraction_of_lighting_energy_to_case = props['fraction_of_lighting_energy_to_case']
    if props['latent_case_credit_curve_name']
      latent_case_credit_curve = model_add_curve(model, props['latent_case_credit_curve_name'])
    end
    defrost_power_per_length = OpenStudio.convert(props['defrost_power_per_length'], 'W/ft', 'W/m').get
    defrost_type = props['defrost_type']
    if props['defrost_correction_type']
      defrost_correction_type = props['defrost_correction_type']
    end
    if props['defrost_correction_curve_name']
      defrost_correction_curve_name = model_add_curve(model, props['defrost_correction_curve_name'])
    end
    if props['anti_sweat_power']
      anti_sweat_power = OpenStudio.convert(props['anti_sweat_power'], 'W/ft', 'W/m').get
    end
    if props['minimum_anti_sweat_heater_power_per_unit_length']
      minimum_anti_sweat_heater_power_per_unit_length = OpenStudio.convert(props['minimum_anti_sweat_heater_power_per_unit_length'], 'W/ft', 'W/m').get
    end
    if props['anti_sweat_heater_control']
      if props['anti_sweat_heater_control'] == 'RelativeHumidity'
        anti_sweat_heater_control = 'Linear'
      else
        anti_sweat_heater_control = props['anti_sweat_heater_control']
      end
    end
    if props['restocking_schedule']
      if props['restocking_schedule'].downcase == 'always off'
        restocking_sch = model.alwaysOffDiscreteSchedule
      else
        restocking_sch = model_add_schedule(model, props['restocking_schedule'])
      end
    else
      restocking_sch = model.alwaysOffDiscreteSchedule
    end
    if props['fractionofantisweatheaterenergytocase']
      fractionofantisweatheaterenergytocase = props['fractionofantisweatheaterenergytocase']
    end

    # Case
    ref_case = OpenStudio::Model::RefrigerationCase.new(model, model.alwaysOnDiscreteSchedule)
    ref_case.setName(case_type)
    ref_case.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_case.setThermalZone(thermal_zone)
    ref_case.setRatedAmbientTemperature(OpenStudio.convert(75, 'F', 'C').get)
    ref_case.setRatedLatentHeatRatio(props['latent_heat_ratio']) if props['latent_heat_ratio']
    ref_case.setRatedRuntimeFraction(props['rated_runtime_fraction']) if props['rated_runtime_fraction']
    ref_case.setCaseLength(case_length)
    ref_case.setCaseOperatingTemperature(case_temp)
    ref_case.setRatedTotalCoolingCapacityperUnitLength(cooling_capacity_per_length)
    cooling_capacity_w = ref_case.caseLength * ref_case.ratedTotalCoolingCapacityperUnitLength
    cooling_capacity_btu_per_hr = OpenStudio.convert(cooling_capacity_w, 'W', 'Btu/hr').get
    ref_case.setStandardCaseFanPowerperUnitLength(evap_fan_power_per_length)
    ref_case.setOperatingCaseFanPowerperUnitLength(evap_fan_power_per_length)
    if props['evap_temp']
      ref_case.setDesignEvaporatorTemperatureorBrineInletTemperature(evap_temp_c)
    end
    ref_case.setStandardCaseLightingPowerperUnitLength(lighting_w_per_m)
    ref_case.setInstalledCaseLightingPowerperUnitLength(lighting_w_per_m)
    ref_case.setCaseLightingSchedule(case_lighting_schedule)

    if props['latent_case_credit_curve_name']
      ref_case.setLatentCaseCreditCurve(latent_case_credit_curve)
    end
    ref_case.setCaseDefrostPowerperUnitLength(defrost_power_per_length)
    if props['defrost_type']
      ref_case.setCaseDefrostType(defrost_type)
    end
    ref_case.setDefrostEnergyCorrectionCurveType(defrost_correction_type)
    if props['defrost_correction_curve_name']
      ref_case.setDefrostEnergyCorrectionCurve(defrost_correction_curve_name)
    end
    if props['anti_sweat_power']
      ref_case.setCaseAntiSweatHeaterPowerperUnitLength(anti_sweat_power)
    end
    ref_case.setFractionofAntiSweatHeaterEnergytoCase(fractionofantisweatheaterenergytocase)
    ref_case.setFractionofLightingEnergytoCase(fraction_of_lighting_energy_to_case)
    if props['minimum_anti_sweat_heater_power_per_unit_length']
      ref_case.setMinimumAntiSweatHeaterPowerperUnitLength(minimum_anti_sweat_heater_power_per_unit_length)
    end
    if props['anti_sweat_heater_control']
      ref_case.setAntiSweatHeaterControlType(anti_sweat_heater_control)
    end
    ref_case.setHumidityatZeroAntiSweatHeaterEnergy(0)
    if props['under_case_hvac_return_air_fraction']
      ref_case.setUnderCaseHVACReturnAirFraction(props['under_case_hvac_return_air_fraction'])
    else
      ref_case.setUnderCaseHVACReturnAirFraction(0)
    end
    ref_case.setRefrigeratedCaseRestockingSchedule(restocking_sch)

    if props['case_category']
      ref_case_addprops = ref_case.additionalProperties
      ref_case_addprops.setFeature('case_category', props['case_category'])
    end

    length_ft = OpenStudio.convert(case_length, 'm', 'ft').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{length_ft.round} ft display case called #{case_type} with a cooling capacity of #{cooling_capacity_btu_per_hr.round} Btu/hr to #{thermal_zone.name}.")

    return ref_case
  end

  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # walkin is located, and which will be impacted by the walkin's thermal load.
  # @param size_category [String] size category of the building area. Valid choices
  # are: "<35k ft2", "35k - 50k ft2", ">50k ft2"
  # @param walkin_type [String] the walkin type/name. For valid choices
  # refer to the "Refrigerated Walkins" tab on the OpenStudio_Standards spreadsheet.
  # This parameter is used also by the "Refrigeration System Lineup" tab.
  def model_add_refrigeration_walkin(model, thermal_zone, size_category, walkin_type)
    # Get the walkin properties
    search_criteria = {
      'template' => template,
      'size_category' => size_category,
      'walkin_type' => walkin_type
    }

    props = model_find_object(standards_data['refrigeration_walkins'], search_criteria)
    if props.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find walkin properties for: #{search_criteria}.")
      return nil
    end

    # Capacity, defrost, lighting
    walkin_type = props['walkin_type']
    if props['rated_cooling_capacity']
      rated_cooling_capacity = OpenStudio.convert(props['rated_cooling_capacity'], 'Btu/h', 'W').get
    end
    if props['cooling_capacity_c0']
      cooling_capacity_c0 = OpenStudio.convert(OpenStudio.convert(props['cooling_capacity_c0'], 'Btu/h', 'W').get, 'W/ft', 'W/m').get
    end
    if props['cooling_capacity_c1']
      cooling_capacity_c1 = OpenStudio.convert(OpenStudio.convert(props['cooling_capacity_c1'], 'Btu/h', 'W').get, 'W/ft', 'W/m').get
    end
    if props['cooling_capacity_c2']
      cooling_capacity_c2 = OpenStudio.convert(OpenStudio.convert(props['cooling_capacity_c2'], 'Btu/h', 'W').get, 'W/ft', 'W/m').get
    end
    if props['fan_power_mult']
      fan_power_mult = props['fan_power_mult']
    end
    if props['lighting_power_mult']
      lighting_power_mult = props['lighting_power_mult']
    end
    if props['reachin_door_area_mult']
      reachin_door_area_mult = OpenStudio.convert(props['reachin_door_area_mult'], 'ft^2', 'm^2').get
    end
    operating_temp = OpenStudio.convert(props['operating_temp'], 'F', 'C').get
    if props['source_temp']
      source_temp = OpenStudio.convert(props['source_temp'], 'F', 'C').get
    end
    if props['defrost_control_type']
      defrost_control_type = props['defrost_control_type']
    end
    defrost_type = props['defrost_type']
    defrost_power_mult = props['defrost_power_mult']
    defrost_power = props['defrost_power']
    ratedtotalheatingpower = props['ratedtotalheatingpower']
    ratedcirculationfanpower = props['ratedcirculationfanpower']
    fan_power = props['fan_power']
    lighting_power = props['lighting_power']
    # lighting_power_mult = props_ref_system['lighting_power_mult']
    if props['insulated_floor_u']
      insulated_floor_u = OpenStudio.convert(props['insulated_floor_u'], 'Btu/ft^2*h*R', 'W/m^2*K').get
    end
    if props['insulated_surface_u']
      insulated_surface_u = OpenStudio.convert(props['insulated_surface_u'], 'Btu/ft^2*h*R', 'W/m^2*K').get
    end
    if props['stocking_door_u']
      insulated_door_u = OpenStudio.convert(props['stocking_door_u'], 'Btu/ft^2*h*R', 'W/m^2*K').get
    end
    if props['glass_reachin_door_u_value']
      glass_reachin_door_u_value = OpenStudio.convert(props['glass_reachin_door_u_value'], 'Btu/ft^2*h*R', 'W/m^2*K').get
    end
    if props['reachin_door_area']
      reachin_door_area = OpenStudio.convert(props['reachin_door_area'], 'ft^2', 'm^2').get
    end
    if props['total_insulated_surface_area']
      total_insulated_surface_area = OpenStudio.convert(props['total_insulated_surface_area'], 'ft^2', 'm^2').get
    end
    if props['height_of_glass_reachin_doors']
      height_of_glass_reachin_doors = OpenStudio.convert(props['height_of_glass_reachin_doors'], 'ft', 'm').get
    end
    if props['area_of_stocking_doors']
      area_of_stocking_doors = OpenStudio.convert(props['area_of_stocking_doors'], 'ft^2', 'm^2').get
    end
    if props['floor_surface_area']
      floor_surface_area = OpenStudio.convert(props['floor_surface_area'], 'ft^2', 'm^2').get
    end
    if props['height_of_stocking_doors']
      height_of_stocking_doors = OpenStudio.convert(props['height_of_stocking_doors'], 'ft', 'm').get
    end
    lightingschedule = props['lighting_schedule']
    restockingschedule = props['restocking_schedule']
    temperatureterminationdefrostfractiontoice = props['temperatureterminationdefrostfractiontoice']

    # Calculated properties
    if rated_cooling_capacity.nil?
      rated_cooling_capacity = cooling_capacity_c2 * (floor_surface_area ^ 2) + cooling_capacity_c1 * floor_surface_area + cooling_capacity_c0
    end
    if defrost_power.nil?
      defrost_power = defrost_power_mult * rated_cooling_capacity
    end
    if total_insulated_surface_area.nil?
      total_insulated_surface_area = 1.7226 * floor_surface_area + 28.653
    end
    if reachin_door_area.nil?
      reachin_door_area = reachin_door_area_mult * floor_surface_area
    end
    if fan_power.nil?
      fan_power = fan_power_mult * rated_cooling_capacity
    end
    if lighting_power.nil?
      lighting_power = lighting_power_mult * floor_surface_area
    end

    # Walk-In
    ref_walkin = OpenStudio::Model::RefrigerationWalkIn.new(model, model.alwaysOnDiscreteSchedule)
    ref_walkin.setName(walkin_type.to_s)
    ref_walkin.setZoneBoundaryThermalZone(thermal_zone)
    ref_walkin.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_walkin.setRatedCoilCoolingCapacity(rated_cooling_capacity)
    rated_cooling_capacity_btu_per_hr = OpenStudio.convert(rated_cooling_capacity, 'W', 'Btu/hr').get
    ref_walkin.setOperatingTemperature(operating_temp)
    if props['source_temp']
      ref_walkin.setRatedCoolingSourceTemperature(source_temp)
    end
    if props['defrost_control_type']
      ref_walkin.setDefrostControlType(defrost_control_type)
    end
    ref_walkin.setDefrostType(defrost_type)
    ref_walkin.setDefrostPower(defrost_power)
    if props['ratedtotalheatingpower']
      ref_walkin.setRatedTotalHeatingPower(ratedtotalheatingpower)
    end
    if props['ratedcirculationfanpower']
      ref_walkin.setRatedCirculationFanPower(ratedcirculationfanpower)
    end
    ref_walkin.setRatedCoolingCoilFanPower(fan_power)
    ref_walkin.setRatedTotalLightingPower(lighting_power)
    if props['insulated_floor_u']
      ref_walkin.setInsulatedFloorUValue(insulated_floor_u)
    end
    if props['insulated_surface_u']
      ref_walkin.setZoneBoundaryInsulatedSurfaceUValueFacingZone(insulated_surface_u)
    end
    if props['stocking_door_u']
      ref_walkin.setZoneBoundaryStockingDoorUValueFacingZone(insulated_door_u)
    end
    if props['reachin_door_area']
      ref_walkin.setZoneBoundaryAreaofGlassReachInDoorsFacingZone(reachin_door_area)
    end
    if props['total_insulated_surface_area']
      ref_walkin.setZoneBoundaryTotalInsulatedSurfaceAreaFacingZone(total_insulated_surface_area)
    end
    if props['area_of_stocking_doors']
      ref_walkin.setZoneBoundaryAreaofStockingDoorsFacingZone(area_of_stocking_doors)
    end
    if props['floor_surface_area']
      ref_walkin.setInsulatedFloorSurfaceArea(floor_surface_area)
    end
    if props['height_of_glass_reachin_doors']
      ref_walkin.setZoneBoundaryHeightofGlassReachInDoorsFacingZone(height_of_glass_reachin_doors)
    end
    if props['height_of_stocking_doors']
      ref_walkin.setZoneBoundaryHeightofStockingDoorsFacingZone(height_of_stocking_doors)
    end
    if props['glass_reachin_door_u_value']
      ref_walkin.setZoneBoundaryGlassReachInDoorUValueFacingZone(glass_reachin_door_u_value)
    end
    if props['temperatureterminationdefrostfractiontoice']
      ref_walkin.setTemperatureTerminationDefrostFractiontoIce(temperatureterminationdefrostfractiontoice)
    end
    if props['restocking_schedule']
      ref_walkin.setRestockingSchedule(model_add_schedule(model, restockingschedule))
    end
    ref_walkin.setLightingSchedule(model_add_schedule(model, lightingschedule))
    ref_walkin.setZoneBoundaryStockingDoorOpeningScheduleFacingZone(model_add_schedule(model, 'door_wi_sched'))

    ref_walkin_addprops = ref_walkin.additionalProperties
    ref_walkin_addprops.setFeature("motor_category", props['motor_category'] )

    # Add doorway protection
    if props['doorway_protection_type']
      ref_walkin.zoneBoundaries.each do |zb|
        zb.setStockingDoorOpeningProtectionTypeFacingZone(props['doorway_protection_type'])
      end
    end

    insulated_floor_area_ft2 = OpenStudio.convert(floor_surface_area, 'm^2', 'ft^2').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{insulated_floor_area_ft2.round} ft2 walkin called #{walkin_type} with a capacity of #{rated_cooling_capacity_btu_per_hr.round} Btu/hr to #{thermal_zone.name}.")

    return ref_walkin
  end

  # Adds a refrigeration compressor to the model.
  def model_add_refrigeration_compressor(model, compressor_name)
    # Get the compressor properties
    search_criteria = {
      'template' => template,
      'compressor_name' => compressor_name
    }

    props = model_find_object(standards_data['refrigeration_compressors'], search_criteria)
    if props.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration compressor properties for: #{search_criteria}.")
      return nil
    end

    # Performance curves
    pwr_curve_name = props['power_curve']
    cap_curve_name = props['capacity_curve']

    # Make the compressor
    compressor = OpenStudio::Model::RefrigerationCompressor.new(model)
    compressor.setRefrigerationCompressorPowerCurve(model_add_curve(model, pwr_curve_name))
    compressor.setRefrigerationCompressorCapacityCurve(model_add_curve(model, cap_curve_name))

    return compressor
  end

  # Find the thermal zone that is best for adding refrigerated display cases into.
  # First, check for space types that typically have refrigeration.
  # Fall back to largest zone in the model if no typical space types are found.
  #   # @param model [OpenStudio::Model::Model] the model
  #   # @return [OpenStudio::Model::ThermalZone] returns a thermal zone if found, nil if not.
  def model_typical_display_case_zone(model)
    # Ideally, look for one of the space types
    # that would typically have refrigeration.
    display_case_zone = nil
    display_case_zone_area_m2 = 0
    model.getThermalZones.each do |zone|
      space_type = thermal_zone_majority_space_type(zone)
      next if space_type.empty?
      space_type = space_type.get
      next if space_type.standardsSpaceType.empty?
      next if space_type.standardsBuildingType.empty?
      stds_spc_type = space_type.standardsSpaceType.get
      stds_bldg_type = space_type.standardsBuildingType.get
      case "#{stds_bldg_type} #{stds_spc_type}"
      when 'PrimarySchool Kitchen',
          'SecondarySchool Kitchen',
          'SuperMarket Sales',
          'QuickServiceRestaurant Kitchen',
          'FullServiceRestaurant Kitchen',
          'LargeHotel Kitchen',
          'Hospital Kitchen',
          'EPr Kitchen',
          'ESe Kitchen',
          'Gro GrocSales',
          'RFF StockRoom',
          'RSD StockRoom',
          'Htl Kitchen',
          'Hsp Kitchen'
        if zone.floorArea > display_case_zone_area_m2
          display_case_zone = zone
          display_case_zone_area_m2 = zone.floorArea
        end
      end
    end

    unless display_case_zone.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Display case zone is #{display_case_zone.name}, the largest zone with a space type typical for display cases.")
      return display_case_zone
    end

    # If no typical space type was found,
    # choose the largest zone in the model.
    display_case_zone = nil
    display_case_zone_area_m2 = 0
    model.getThermalZones.each do |zone|
      if zone.floorArea > display_case_zone_area_m2
        display_case_zone = zone
        display_case_zone_area_m2 = zone.floorArea
      end
    end

    unless display_case_zone.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "No space types typical for display cases were found, so the display cases will be placed in #{display_case_zone.name}, the largest zone.")
      return display_case_zone
    end

    return display_case_zone
  end

  # Find the thermal zone that is best for adding refrigerated walkins into.
  # First, check for space types that typically have refrigeration.
  # Fall back to largest zone in the model if no typical space types are found.
  # @param model [OpenStudio::Model::Model] the model
  # @return [OpenStudio::Model::ThermalZone] returns a thermal zone if found, nil if not.
  def model_typical_walkin_zone(model)
    # Ideally, look for one of the space types
    # that would typically have refrigeration walkins.
    walkin_zone = nil
    walkin_zone_area_m2 = 0
    model.getThermalZones.each do |zone|
      space_type = thermal_zone_majority_space_type(zone)
      next if space_type.empty?
      space_type = space_type.get
      next if space_type.standardsSpaceType.empty?
      next if space_type.standardsBuildingType.empty?
      stds_spc_type = space_type.standardsSpaceType.get
      stds_bldg_type = space_type.standardsBuildingType.get
      case "#{stds_bldg_type} #{stds_spc_type}"
      when 'PrimarySchool Kitchen',
          'SecondarySchool Kitchen',
          'SuperMarket DryStorage',
          'QuickServiceRestaurant	Kitchen',
          'FullServiceRestaurant Kitchen',
          'LargeHotel Kitchen',
          'Hospital Kitchen',
          'EPr Kitchen',
          'ESe Kitchen',
          'Gro RefWalkInCool',
          'Gro RefWalkInFreeze',
          'RFF StockRoom',
          'RSD StockRoom',
          'Htl Kitchen',
          'Hsp Kitchen'
        if zone.floorArea > walkin_zone_area_m2
          walkin_zone = zone
          walkin_zone_area_m2 = zone.floorArea
        end
      end
    end

    unless walkin_zone.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Walkin zone is #{walkin_zone.name}, the largest zone with a space type typical for walkins.")
      return walkin_zone
    end

    # If no typical space type was found,
    # choose the largest zone in the model.
    walkin_zone = nil
    walkin_zone_area_m2 = 0
    model.getThermalZones.each do |zone|
      if zone.floorArea > walkin_zone_area_m2
        walkin_zone = zone
        walkin_zone_area_m2 = zone.floorArea
      end
    end

    unless walkin_zone.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "No space types typical for walkins were found, so the walkins will be placed in #{walkin_zone.name}, the largest zone.")
      return walkin_zone
    end

    return walkin_zone
  end

  # Add a typical refrigeration system to the model, including cases, walkins,
  # compressors, and condensors.  For small stores, each case and walkin is served
  # by one compressor and one condenser.  For larger stores, all medium temp cases and walkins
  # are served by one multi-compressor rack, and all low temp cases and walkins another.
  def model_add_typical_refrigeration(model, building_type)
    # Define system category and scaling factor
    floor_area_ft2 = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get
    case building_type
    when 'SuperMarket', 'Gro'
      if floor_area_ft2 < 35_000 # this is in m2
        size_category = '<35k ft2'
        floor_area_scaling_factor = floor_area_ft2 / 35_000
      elsif floor_area_ft2 < 50_000
        size_category = '35k - 50k ft2'
        floor_area_scaling_factor = floor_area_ft2 / 50_000
      else
        size_category = '>50k ft2'
        floor_area_scaling_factor = floor_area_ft2 / 50_000
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Refrigeration size category is #{size_category}, with a scaling factor of #{floor_area_scaling_factor} because the floor area is #{floor_area_ft2.round} ft2.  All cases and walkins added later will subsequently be scaled by this factor.")
    else
      size_category = 'Kitchen'
      floor_area_scaling_factor = 1 # Do not scale kitchen systems
    end

    # Add a low and medium temperature system
    ['Medium Temperature', 'Low Temperature'].each do |system_type|
      # Find refrigeration system lineup
      search_criteria = {
        'template' => template,
        'building_type' => building_type,
        'size_category' => size_category,
        'system_type' => system_type
      }
      props_lineup = model_find_object(standards_data['refrigeration_system_lineup'], search_criteria)
      if props_lineup.nil?
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "No refrigeration system lineup found for #{search_criteria}, no system will be added.")
        next
      end
      number_of_display_cases = props_lineup['number_of_display_cases']
      number_of_walkins = props_lineup['number_of_walkins']
      compressor_name = props_lineup['compressor_name']

      # Find the thermal zones most suited for holding the display cases
      thermal_zone_case = nil
      if number_of_display_cases > 0
        thermal_zone_case = model_typical_display_case_zone(model)
        if thermal_zone_case.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model',"Attempted to add #{number_of_display_cases} display cases to the model, but could find no thermal zone to put them into.")
          return false
        end
      end

      # Add display cases
      display_cases = []
      (1..number_of_display_cases).each_with_index do |display_case_number, def_start_hr_iterator|
        case_type = props_lineup["case_type_#{display_case_number}"]

        # Add the basic case
        ref_case = model_add_refrigeration_case(model, thermal_zone_case, case_type, size_category)
        return false if ref_case.nil?

        # Scale based on floor area
        ref_case.setCaseLength(ref_case.caseLength * floor_area_scaling_factor)

        # Find defrost and dripdown properties
        search_criteria = {
          'template' => template,
          'case_type' => case_type,
          'size_category' => size_category
        }
        props_case = model_find_object(standards_data['refrigerated_cases'], search_criteria)
        if props_case.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigerated case properties for: #{search_criteria}.")
          next
        end
        numb_defrosts_per_day = props_case['defrost_per_day']
        minutes_defrost = props_case['minutes_defrost']
        minutes_dripdown = props_case['minutes_dripdown']
        minutes_defrost = 59 if minutes_defrost > 59 # Just to make sure to remain in the same hour
        minutes_dripdown = 59 if minutes_dripdown > 59 # Just to make sure to remain in the same hour

        # Add defrost and dripdown schedules
        defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        defrost_sch.setName('Refrigeration Defrost Schedule')
        defrost_sch.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{case_type}")
        dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        dripdown_sch.setName('Refrigeration Dripdown Schedule')
        dripdown_sch.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{case_type}")

        # Stagger the defrosts for cases by 1 hr
        interval_defrost = (24 / numb_defrosts_per_day).floor # Hour interval between each defrost period
        if (def_start_hr_iterator + interval_defrost * numb_defrosts_per_day) > 23
          first_def_start_hr = 0 # Start over again at midnight when time reaches 23hrs
        else
          first_def_start_hr = def_start_hr_iterator
        end

        # Add the specified number of defrost periods to the daily schedule
        (1..numb_defrosts_per_day).each do |defrost_of_day|
          def_start_hr = first_def_start_hr + ((1 - defrost_of_day) * interval_defrost)
          defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, 0, 0), 0)
          defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, minutes_defrost.to_int, 0), 0)
          dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, 0, 0), 0) # Dripdown is synced with defrost
          dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, minutes_dripdown.to_int, 0), 0)
        end
        defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

        # Assign the defrost and dripdown schedules
        ref_case.setCaseDefrostSchedule(defrost_sch)
        ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)

        display_cases << ref_case
      end

      # Find the thermal zones most suited for holding the walkins
      thermal_zone_walkin = nil
      if number_of_walkins > 0
        thermal_zone_walkin = model_typical_walkin_zone(model)
        if thermal_zone_walkin.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Attempted to add #{number_of_walkins} walkins to the model, but could find no thermal zone to put them into.")
          return false
        end
      end

      # Add walkin cases
      walkins = []
      (1..number_of_walkins).each_with_index do |walkin_number, def_start_hr_iterator|
        walkin_type = props_lineup["walkin_type_#{walkin_number}"]

        # Add the basic walkin
        ref_walkin = model_add_refrigeration_walkin(model, thermal_zone_walkin, size_category, walkin_type)
        return false if ref_walkin.nil?

        # Scale based on floor area
        ref_walkin.setRatedTotalLightingPower(ref_walkin.ratedTotalLightingPower * floor_area_scaling_factor)
        ref_walkin.setRatedCoolingCoilFanPower(ref_walkin.ratedCoolingCoilFanPower * floor_area_scaling_factor)
        ref_walkin.setDefrostPower(ref_walkin.defrostPower.get * floor_area_scaling_factor)
        ref_walkin.setRatedCoilCoolingCapacity(ref_walkin.ratedCoilCoolingCapacity * floor_area_scaling_factor)
        ref_walkin.setZoneBoundaryTotalInsulatedSurfaceAreaFacingZone(ref_walkin.zoneBoundaryTotalInsulatedSurfaceAreaFacingZone.get * floor_area_scaling_factor)
        ref_walkin.setInsulatedFloorSurfaceArea(ref_walkin.insulatedFloorSurfaceArea * floor_area_scaling_factor)

        # Check that walkin physically fits inside the thermal zone.
        # If not, remove the walkin and warn.
        walkin_floor_area_ft2 = OpenStudio.convert(ref_walkin.insulatedFloorSurfaceArea, 'm^2', 'ft^2').get.round
        walkin_zone_floor_area_ft2 = OpenStudio.convert(thermal_zone_walkin.floorArea, 'm^2', 'ft^2').get.round
        if walkin_floor_area_ft2 > walkin_zone_floor_area_ft2
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "Walkin #{ref_walkin.name} has an area of #{walkin_floor_area_ft2} ft^2, which is larger than the #{walkin_zone_floor_area_ft2} ft^2 zone.  Walkin will be removed from model.")
          ref_walkin.remove
          next
        end

        # Find defrost and dripdown properties
        search_criteria = {
          'template' => template,
          'walkin_type' => walkin_type,
          'size_category' => size_category
        }
        props_walkin = model_find_object(standards_data['refrigeration_walkins'], search_criteria)
        if props_walkin.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find walkin properties for: #{search_criteria}.")
          next
        end
        numb_defrosts_per_day = props_walkin['defrost_per_day']
        minutes_defrost = props_walkin['minutes_defrost']
        minutes_dripdown = props_walkin['minutes_dripdown']
        minutes_defrost = 59 if minutes_defrost > 59 # Just to make sure to remain in the same hour
        minutes_dripdown = 59 if minutes_dripdown > 59 # Just to make sure to remain in the same hour

        # Add defrost and dripdown schedules
        defrost_sch_walkin = OpenStudio::Model::ScheduleRuleset.new(model)
        defrost_sch_walkin.setName('Refrigeration Defrost Schedule')
        defrost_sch_walkin.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{walkin_type}")
        dripdown_sch_walkin = OpenStudio::Model::ScheduleRuleset.new(model)
        dripdown_sch_walkin.setName('Refrigeration Dripdown Schedule')
        dripdown_sch_walkin.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{walkin_type}")

        # Stagger the defrosts for cases by 1 hr
        interval_defrost = (24 / numb_defrosts_per_day).floor # Hour interval between each defrost period
        if (def_start_hr_iterator + interval_defrost * numb_defrosts_per_day) > 23
          first_def_start_hr = 0 # Start over again at midnight when time reaches 23hrs
        else
          first_def_start_hr = def_start_hr_iterator
        end

        # Add the specified number of defrost periods to the daily schedule
        (1..numb_defrosts_per_day).each do |defrost_of_day|
          def_start_hr = first_def_start_hr + ((1 - defrost_of_day) * interval_defrost)
          defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, 0, 0), 0)
          defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, minutes_defrost.to_int, 0), 0)
          dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, 0, 0), 0) # Dripdown is synced with defrost
          dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0, def_start_hr, minutes_dripdown.to_int, 0), 0)
        end
        defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

        # Assign the defrost and dripdown schedules
        ref_walkin.setDefrostSchedule(defrost_sch_walkin)
        ref_walkin.setDefrostDripDownSchedule(dripdown_sch_walkin)

        walkins << ref_walkin
      end

      # Divide cases and walkins into one or more refrigeration systems depending on store type
      # For small stores and kitchens one system with one compressor and one condenser per case is employed.
      # For larger stores, multiple cases and walkins are served by a rack with multiple compressors.
      ref_system_lineups = []
      case system_type
      when '<35k ft2', 'Kitchen'
        # Put each case on its own system
        display_cases.each do |ref_case|
          ref_system_lineups << { 'ref_cases' => [ref_case], 'walkins' => [] }
        end
        # Put each walkin on its own system
        walkins.each do |walkin|
          ref_system_lineups << { 'ref_cases' => [], 'walkins' => [walkin] }
        end
      else
        # Put all cases and walkins on one system
        ref_system_lineups << { 'ref_cases' => display_cases, 'walkins' => walkins }
      end

      # Find refrigeration system properties
      search_criteria = {
        'template' => template,
        'building_type' => building_type,
        'size_category' => size_category,
        'system_type' => system_type
      }
      props_ref_system = model_find_object(standards_data['refrigeration_system'], search_criteria)
      if props_ref_system.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration system properties for: #{search_criteria}.")
        next
      end

      # Add refrigeration systems
      ref_system_lineups.each do |ref_system_lineup|
        # Skip if no cases or walkins are attached to the system
        next if ref_system_lineup['ref_cases'].empty? && ref_system_lineup['walkins'].empty?

        # Add refrigeration system
        ref_system = OpenStudio::Model::RefrigerationSystem.new(model)
        ref_system.setName(system_type)
        ref_system.setRefrigerationSystemWorkingFluidType(props_ref_system['refrigerant'])
        ref_system.setSuctionTemperatureControlType(props_ref_system['refrigerant'])

        # Sum the capacity required by all cases and walkins
        # and attach the cases and walkins to the system.
        rated_case_capacity_w = 0
        ref_system_lineup['ref_cases'].each do |ref_case|
          rated_case_capacity_w += ref_case.ratedTotalCoolingCapacityperUnitLength * ref_case.caseLength
          ref_system.addCase(ref_case)
        end
        ref_system_lineup['walkins'].each do |walkin|
          rated_case_capacity_w += walkin.ratedCoilCoolingCapacity
          ref_system.addWalkin(walkin)
        end

        # Find the compressor properties
        search_criteria = {
          'template' => template,
          'compressor_name' => compressor_name
        }
        props_compressor = model_find_object(standards_data['refrigeration_compressors'], search_criteria)
        if props_compressor.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration compressor properties for: #{search_criteria}.")
          next
        end

        # Calculate the number of compressors required to meet the
        # combined rated capacity of all the cases
        # and add them to the system
        rated_compressor_capacity_btu_per_hr = props_compressor['rated_capacity']
        number_of_compressors = (rated_case_capacity_w / OpenStudio.convert(rated_compressor_capacity_btu_per_hr, 'Btu/h', 'W').get).ceil
        (1..number_of_compressors).each do |compressor_number|
          compressor = model_add_refrigeration_compressor(model, compressor_name)
          ref_system.addCompressor(compressor)
        end
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Added #{number_of_compressors} compressors, each with a capacity of #{rated_compressor_capacity_btu_per_hr.round} Btu/hr to serve #{OpenStudio.convert(rated_case_capacity_w, 'W', 'Btu/hr').get.round} Btu/hr of case and walkin load.")

        # Find the condenser properties
        search_criteria = {
          'template' => template,
          'building_type' => building_type,
          'system_type' => system_type,
          'size_category' => size_category
        }
        props_condenser = model_find_object(standards_data['refrigeration_condenser'], search_criteria)
        if props_condenser.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration condenser properties for: #{search_criteria}.")
          next
        end

        # Heat rejection as a function of temperature
        heat_rejection_curve = OpenStudio::Model::CurveLinear.new(model)
        heat_rejection_curve.setName('Condenser Heat Rejection Function of Temperature')
        heat_rejection_curve.setCoefficient1Constant(0)
        heat_rejection_curve.setCoefficient2x(props_condenser['heatrejectioncurve_c1'])
        heat_rejection_curve.setMinimumValueofx(-50)
        heat_rejection_curve.setMaximumValueofx(50)

        # Add condenser
        condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
        condenser.setRatedEffectiveTotalHeatRejectionRateCurve(heat_rejection_curve)
        condenser.setRatedSubcoolingTemperatureDifference(OpenStudio.convert(props_condenser['subcool_t'], 'F', 'C').get)
        condenser.setMinimumFanAirFlowRatio(props_condenser['min_airflow'])
        condenser.setRatedFanPower(props_condenser['fan_power_per_q_rejected'].to_f * rated_case_capacity_w)
        condenser.setCondenserFanSpeedControlType(props_condenser['fan_speed_control'])
        ref_system.setRefrigerationCondenser(condenser)

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{system_type} refrigeration system")
      end
    end

    return true
  end

  # Determine the latent case credit curve to use
  # for walkins. Defaults to values after 90.1-2007.
  # @todo Should probably use the model_add_refrigeration_walkin
  # and lookups from the spreadsheet instead of hard-coded values.
  def model_walkin_freezer_latent_case_credit_curve(model)
    latent_case_credit_curve_name = 'Single Shelf Horizontal Latent Energy Multiplier_After2004'
    return latent_case_credit_curve_name
  end

  # Adds a full commercial refrigeration rack, as would be found in a supermarket,
  # to the model.
  #
  # @param compressor_type [String] the system temperature range.  valid choices are:
  # Low Temp, Med Temp
  # @param system_name [String] the name of the refrigeration system
  # @param cases [Array<Hash>] an array of cases with keys:
  # case_type and space_names.
  # @param walkins [Array<Hashs>] an array of walkins with keys:
  # walkin_type, space_names, and number_of_walkins
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # refrigeration piping is located.
  # @todo Move refrigeration compressors to spreadsheet
  def model_add_refrigeration_system(model,
                                     compressor_type,
                                     system_name,
                                     cases,
                                     walkins,
                                     thermal_zone)

    # Refrigeration system
    ref_sys = OpenStudio::Model::RefrigerationSystem.new(model)
    ref_sys.setName(system_name.to_s)
    ref_sys.setSuctionPipingZone(thermal_zone)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model',
                       "Adding #{compressor_type} refrigeration system called #{system_name} with #{cases.size} cases and #{walkins.size} walkins.")

    # Compressors (20 for each system)
    for i in 0...20
      compressor = model_add_refrigeration_compressor(model, compressor_type)
      ref_sys.addCompressor(compressor)
    end

    size_category = 'Any'
    # Cases
    cooling_cap = 0
    i = 0
    cases.each do |case_|
      zone = model_get_zones_from_spaces_on_system(model, case_)[0]
      ref_case = model_add_refrigeration_case(model, zone, case_['case_type'], size_category)
      return false if ref_case.nil?
      ########################################
      # Defrost schedule
      defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      defrost_sch.setName('Refrigeration Defrost Schedule')
      defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
      # Dripdown schedule
      dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      dripdown_sch.setName('Refrigeration Defrost Schedule')
      dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
      # Case Credit Schedule
      case_credit_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      case_credit_sch.setName('Refrigeration Case Credit Schedule')
      case_credit_sch.defaultDaySchedule.setName('Refrigeration Case Credit Schedule Default')
      case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 7, 0, 0), 0.2)
      case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 21, 0, 0), 0.4)
      case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
      ref_case.setCaseDefrostSchedule(defrost_sch)
      ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)
      ref_case.setCaseCreditFractionSchedule(case_credit_sch)
      ########################################
      ref_sys.addCase(ref_case)
      i += 1
    end

    # Walkins
    walkins.each do |walkin|
      for i in 0...walkin['number_of_walkins']

        zone = model_get_zones_from_spaces_on_system(model, walkin)[0]
        ref_walkin = model_add_refrigeration_walkin(model, zone, size_category, walkin['walkin_type'])
        return false if ref_walkin.nil?
        ########################################
        # Defrost schedule
        defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        defrost_sch.setName('Refrigeration Defrost Schedule')
        defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
        defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
        defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 1)
        defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 0, 0), 0)
        defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 59, 0), 1)
        defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        # Dripdown schedule
        dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        dripdown_sch.setName('Refrigeration Defrost Schedule')
        dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
        dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
        dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 1)
        dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 0, 0), 0)
        dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 59, 0), 1)
        dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        ref_walkin.setDefrostSchedule(defrost_sch)
        ref_walkin.setDefrostDripDownSchedule(dripdown_sch)
        ref_sys.addWalkin(ref_walkin)
        ########################################
        cooling_cap += ref_walkin.ratedCoilCoolingCapacity # calculate total cooling capacity of the cases + walkins
      end
    end

    # Condenser capacity
    # The heat rejection rate from the condenser is equal to the rated capacity of all the display cases and walk-ins connected to the compressor rack
    # plus the power rating of the compressors making up the compressor rack.
    # Assuming a COP of 1.3 for low-temperature compressor racks and a COP of 2.0 for medium-temperature compressor racks,
    # the required condenser capacity is approximated as follows:
    # Note the factor 1.2 has been included to over-estimate the condenser size.  The total capacity of the display cases can be calculated
    # from their rated cooling capacity times the length of the cases.  The capacity of each of the walk-ins is specified directly.
    condensor_cap = if compressor_type == 'Low Temp'
                      1.2 * cooling_cap * (1 + 1 / 1.3)
                    else
                      1.2 * cooling_cap * (1 + 1 / 2.0)
                    end
    condenser_coefficient_2 = condensor_cap / 5.6
    condenser_curve = OpenStudio::Model::CurveLinear.new(model)
    condenser_curve.setCoefficient1Constant(0)
    condenser_curve.setCoefficient2x(condenser_coefficient_2)
    condenser_curve.setMinimumValueofx(1.4)
    condenser_curve.setMaximumValueofx(33.3)

    # Condenser fan power
    # The condenser fan power can be estimated from the heat rejection capacity of the condenser as follows:
    condenser_fan_pwr = 0.0441 * condensor_cap + 695

    # Condenser
    condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
    condenser.setRatedFanPower(condenser_fan_pwr)
    condenser.setRatedEffectiveTotalHeatRejectionRateCurve(condenser_curve)
    condenser.setCondenserFanSpeedControlType('Fixed')
    condenser.setMinimumFanAirFlowRatio(0.1)

    ref_sys.setRefrigerationCondenser(condenser)

    return true
  end
end
