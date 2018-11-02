class Standard
  # @!group refrigeration

  # Adds a single refrigerated case connected to a rack composed
  # of a single compressor and a single air-cooled condenser.
  #
  # @note The legacy prototype IDF files use the simplified
  # Refrigeration:CompressorRack object, but this object is
  # not included in OpenStudio.  Instead, a detailed rack
  # with similar performance is added.
  # @todo Set compressor properties since prototypes use simple
  # refrigeration rack instead of detailed
  # @todo fix latent case credit curve setter
  # @todo Should probably use the model_add_refrigeration_walkin
  # and lookups from the spreadsheet instead of hard-coded values.
  def model_add_refrigeration(model,
                              case_type,
                              cooling_capacity_per_length,
                              length,
                              evaporator_fan_pwr_per_length,
                              lighting_per_length,
                              lighting_sch_name,
                              defrost_pwr_per_length,
                              restocking_sch_name,
                              cop,
                              cop_f_of_t_curve_name,
                              condenser_fan_pwr,
                              condenser_fan_pwr_curve_name,
                              thermal_zone)

    # Default properties based on the case type
    # case_type = 'Walkin Freezer', 'Display Case'
    case_temp = nil
    latent_heat_ratio = nil
    runtime_fraction = nil
    fraction_antisweat_to_case = nil
    under_case_return_air_fraction = nil
    latent_case_credit_curve_name = nil
    defrost_type = nil
    if case_type == 'Walkin Freezer'
      case_temp = OpenStudio.convert(-9.4, 'F', 'C').get
      latent_heat_ratio = 0.1
      runtime_fraction = 0.4
      fraction_antisweat_to_case = 0.0
      under_case_return_air_fraction = 0.0
      latent_case_credit_curve_name = model_walkin_freezer_latent_case_credit_curve(model)
      defrost_type = 'Electric'
    elsif case_type == 'Display Case'
      case_temp = OpenStudio.convert(35.6, 'F', 'C').get
      latent_heat_ratio = 0.08
      runtime_fraction = 0.85
      fraction_antisweat_to_case = 0.2
      under_case_return_air_fraction = 0.05
      latent_case_credit_curve_name = 'Multi Shelf Vertical Latent Energy Multiplier'
      defrost_type = 'None'
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Refrigeration System')

    # Defrost schedule
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_sch.setName('Refrigeration Defrost Schedule')
    defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
    if case_type == 'Walkin Freezer'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 20, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 20, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    elsif case_type == 'Display Case'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 20, 0), 0)
    end

    # Dripdown schedule
    defrost_dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_dripdown_sch.setName('Refrigeration Defrost DripDown Schedule')
    defrost_dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost DripDown Schedule Default')
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 30, 0), 1)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 0, 0), 0)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 30, 0), 1)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

    # Case Credit Schedule
    case_credit_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    case_credit_sch.setName('Refrigeration Case Credit Schedule')
    case_credit_sch.defaultDaySchedule.setName('Refrigeration Case Credit Schedule Default')
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 7, 0, 0), 0.2)
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 21, 0, 0), 0.4)
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)

    # Case
    ref_case = OpenStudio::Model::RefrigerationCase.new(model, defrost_sch)
    ref_case.setName("#{thermal_zone.name} #{case_type}")
    ref_case.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_case.setThermalZone(thermal_zone)
    ref_case.setRatedTotalCoolingCapacityperUnitLength(cooling_capacity_per_length)
    ref_case.setCaseLength(length)
    ref_case.setCaseOperatingTemperature(case_temp)
    ref_case.setStandardCaseFanPowerperUnitLength(evaporator_fan_pwr_per_length)
    ref_case.setOperatingCaseFanPowerperUnitLength(evaporator_fan_pwr_per_length)
    ref_case.setStandardCaseLightingPowerperUnitLength(lighting_per_length)
    ref_case.resetInstalledCaseLightingPowerperUnitLength
    ref_case.setCaseLightingSchedule(model_add_schedule(model, lighting_sch_name))
    ref_case.setHumidityatZeroAntiSweatHeaterEnergy(0)
    unless defrost_type == 'None'
      ref_case.setCaseDefrostType('Electric')
      ref_case.setCaseDefrostPowerperUnitLength(defrost_pwr_per_length)
      ref_case.setCaseDefrostDripDownSchedule(defrost_dripdown_sch)
    end
    ref_case.setUnderCaseHVACReturnAirFraction(under_case_return_air_fraction)
    ref_case.setFractionofAntiSweatHeaterEnergytoCase(fraction_antisweat_to_case)
    ref_case.resetDesignEvaporatorTemperatureorBrineInletTemperature
    ref_case.setRatedAmbientTemperature(OpenStudio.convert(75, 'F', 'C').get)
    ref_case.setRatedLatentHeatRatio(latent_heat_ratio)
    ref_case.setRatedRuntimeFraction(runtime_fraction)
    # TODO: enable ref_case.setLatentCaseCreditCurve(model_add_curve(model, latent_case_credit_curve_name))
    ref_case.setLatentCaseCreditCurve(model_add_curve(model, latent_case_credit_curve_name))
    ref_case.setCaseHeight(0)
    # TODO: setRefrigeratedCaseRestockingSchedule is not working
    ref_case.setRefrigeratedCaseRestockingSchedule(model_add_schedule(model, restocking_sch_name))
    if case_type == 'Walkin Freezer'
      ref_case.setCaseCreditFractionSchedule(case_credit_sch)
    end

    # Compressor
    # TODO set compressor properties since prototypes use simple
    # refrigeration rack instead of detailed
    compressor = OpenStudio::Model::RefrigerationCompressor.new(model)

    # Condenser
    condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
    condenser.setRatedFanPower(condenser_fan_pwr)

    # Refrigeration system
    ref_sys = OpenStudio::Model::RefrigerationSystem.new(model)
    ref_sys.addCompressor(compressor)
    ref_sys.addCase(ref_case)
    ref_sys.setRefrigerationCondenser(condenser)
    ref_sys.setSuctionPipingZone(thermal_zone)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Refrigeration System')

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

  # Add refrigerated case to the model.
  #
  # @param case_type [String] the case type.  Valid choices include:
  # LT Coffin Ice Cream, LT Coffin Frozen Food, LT Reach-In Ice Cream, LT Reach-In Frozen Food,
  # MT Coffin, MT Vertical Open, MT Service, MT Reach-In
  # @param case_name [String] the name of the case
  # @param length [Double] the length of the case, in m
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # case is located, and which will be impacted by the case's thermal load.
  def model_add_refrigeration_case(model, case_type, case_name, length, thermal_zone)
    # Get the case properties
    search_criteria = {
      'template' => template,
      'case_type' => case_type
    }

    props = model_find_object(standards_data['refrigerated_cases'], search_criteria)
    if props.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigerated case properties for: #{search_criteria}.")
      return nil
    end

    # Capacity, defrost, anti-sweat
    case_temp = props['case_temp']
    latent_heat_ratio = props['latent_heat_ratio']
    cooling_capacity_per_length = props['cooling_capacity_per_length']
    evaporator_fan_pwr_per_length = props['evap_fan_power_per_length']
    evapo_temp = props['evap_temp']
    lighting_per_length = props['lighting_per_length']
    latent_case_credit_curve_name = props['latent_case_credit_curve_name']
    defrost_pwr_per_length = props['defrost_power_per_length']
    defrost_type = props['defrost_type']
    defrost_correction_type = props['defrost_correction_type']
    defrost_correction_curve_name = props['defrost_correction_curve_name']
    anti_power = props['anti_sweat_power']

    runtime_fraction = 0.85
    restocking_sch_name = 'Always Off'

    # Defrost schedule
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_sch.setName('Refrigeration Defrost Schedule')
    defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
    if case_type == 'MT Vertical Open'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 30, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 30, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 30, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 30, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    elsif case_type == 'MT Service'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 40, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 40, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 40, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 40, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    else # when 'LT Coffin Frozen Food','LT Coffin Ice Cream','LT Reach-In Ice Cream','LT Reach-In Frozen Food',
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 45, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    end

    # Dripdown schedule
    defrost_dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_dripdown_sch.setName('Refrigeration Case Defrost DripDown Schedule')
    defrost_dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost DripDown Schedule Default')
    if case_type == 'MT Vertical Open'
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 40, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 40, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 40, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 40, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    elsif case_type == 'MT Service'
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 50, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 6, 50, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 50, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 18, 50, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    else # when 'LT Coffin Frozen Food','LT Coffin Ice Cream','LT Reach-In Ice Cream','LT Reach-In Frozen Food',
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 55, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    end

    # Case
    ref_case = OpenStudio::Model::RefrigerationCase.new(model, defrost_sch)
    ref_case.setName(case_name.to_s)
    ref_case.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_case.setThermalZone(thermal_zone)
    ref_case.setRatedTotalCoolingCapacityperUnitLength(cooling_capacity_per_length)
    ref_case.setCaseLength(length)
    ref_case.setCaseOperatingTemperature(case_temp)
    ref_case.setStandardCaseFanPowerperUnitLength(evaporator_fan_pwr_per_length)
    ref_case.setOperatingCaseFanPowerperUnitLength(evaporator_fan_pwr_per_length)
    ref_case.setStandardCaseLightingPowerperUnitLength(lighting_per_length) unless lighting_per_length.nil?
    ref_case.resetInstalledCaseLightingPowerperUnitLength
    ref_case.setCaseLightingSchedule(model.alwaysOnDiscreteSchedule)
    ref_case.setHumidityatZeroAntiSweatHeaterEnergy(anti_power)
    ref_case.setCaseDefrostType(defrost_type)
    ref_case.setCaseDefrostPowerperUnitLength(defrost_pwr_per_length) unless defrost_pwr_per_length.nil?
    ref_case.setCaseDefrostDripDownSchedule(defrost_dripdown_sch)
    ref_case.setUnderCaseHVACReturnAirFraction(0)
    ref_case.setFractionofAntiSweatHeaterEnergytoCase(0.7)
    ref_case.setDesignEvaporatorTemperatureorBrineInletTemperature(evapo_temp)
    ref_case.setRatedAmbientTemperature(OpenStudio.convert(75, 'F', 'C').get)
    ref_case.setRatedLatentHeatRatio(latent_heat_ratio)
    ref_case.setRatedRuntimeFraction(runtime_fraction)
    ref_case.setLatentCaseCreditCurve(model_add_curve(model, latent_case_credit_curve_name))
    ref_case.setCaseHeight(0)
    ref_case.setRefrigeratedCaseRestockingSchedule(model_add_schedule(model, restocking_sch_name))
    ref_case.setDefrostEnergyCorrectionCurveType(defrost_correction_type)
    ref_case.setDefrostEnergyCorrectionCurve(model_add_curve(model, defrost_correction_curve_name))

    length_ft = OpenStudio.convert(length, 'm', 'ft').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{length_ft.round} ft #{case_type} called #{case_name} to #{thermal_zone.name}.")

    return ref_case
  end

  # Adds walkin to the model. The following characteristics are defaulted based on user input.
  #  - Rated coil cooling capacity (function of floor area)
  #  - Rated cooling coil fan power (function of cooling capacity)
  #  - Rated total lighting power (function of floor area)
  #  - Defrost power (function of cooling capacity)
  # Coil fan power and total lighting power are given for both old (2004, 2007, and 2010) and new (2013) walk-ins.
  # It is assumed that only walk-in freezers have electric defrost while walk-in coolers use off-cycle defrost.
  #
  # @param walkin_type [String] the walkin type.  valid choices are:
  # Walk-In Freezer, Walk-In Cooler, Walk-In Cooler Glass Door
  # @param walkin_name [String] the name of the walkin
  # @param insulated_floor_area [Double] the floor area of the walkin, in m^2
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # walkin is located, and which will be impacted by the walkin's thermal load.
  def model_add_refrigeration_walkin(model, walkin_type, walkin_name, insulated_floor_area, thermal_zone)
    # Get the walkin properties
    search_criteria = {
      'template' => template,
      'walkin_type' => walkin_type
    }

    props = model_find_object(standards_data['walkin_refrigeration'], search_criteria)
    if props.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find walkin refrigeration properties for: #{search_criteria}.")
      return nil
    end

    # Capacity, defrost, lighting
    cooling_capacity_c2 = props['cooling_capacity_c2']
    cooling_capacity_c1 = props['cooling_capacity_c1']
    cooling_capacity_c0 = props['cooling_capacity_c0']
    operating_temp = props['operating_temp']
    source_temp = props['source_temp']
    defrost_control_type = props['defrost_control_type']
    defrost_type = props['defrost_type']
    defrost_power_mult = props['defrost_power_mult']
    insulated_floor_u = props['insulated_floor_u']
    insulated_surface_u = props['insulated_surface_u']
    stocking_door_u = props['insulated_door_u']
    reachin_door_area_mult = props['reachin_door_area_mult']
    fan_power_mult = props['fan_power_mult']
    lighting_power_mult = props['lighting_power_mult']

    always_off_name = 'Always Off'

    # Calculated properties
    cooling_capacity = cooling_capacity_c2 * (insulated_floor_area ^ 2) + cooling_capacity_c1 * insulated_floor_area + cooling_capacity_c0
    defrost_power = defrost_power_mult * cooling_capacity
    insulated_surface_area = 1.7226 * insulated_floor_area + 28.653
    reachin_door_area = reachin_door_area_mult * insulated_floor_area
    fan_power = fan_power_mult * cooling_capacity
    lighting_power = lighting_power_mult * insulated_floor_area

    # Defrost schedule
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_sch.setName('Refrigeration WaklIn Defrost Schedule')
    defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
    if walkin_type == 'Walk-In Freezer'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 45, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 45, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    else
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 1, 0, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 13, 0, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    end

    # Dripdown schedule
    defrost_dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_dripdown_sch.setName('Refrigeration WalkIn Defrost DripDown Schedule')
    defrost_dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost DripDown Schedule Default')
    if walkin_type == 'Walk-In Freezer'
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 0, 55, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 55, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    else
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 1, 0, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 12, 0, 0), 0)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 13, 0, 0), 1)
      defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    end

    # Door schedule
    walkin_door_sch = 'SuperMarket Walk-In Door Sch'

    # Walk-In
    ref_walkin = OpenStudio::Model::RefrigerationWalkIn.new(model, defrost_sch)
    ref_walkin.setName(walkin_name.to_s)
    ref_walkin.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_walkin.setRatedCoilCoolingCapacity(cooling_capacity)
    ref_walkin.setOperatingTemperature(operating_temp)
    ref_walkin.setRatedCoolingSourceTemperature(source_temp)
    ref_walkin.setRatedTotalHeatingPower(0)
    ref_walkin.setHeatingPowerSchedule(model_add_schedule(model, always_off_name))
    ref_walkin.setRatedCoolingCoilFanPower(fan_power)
    ref_walkin.setRatedCirculationFanPower(0)
    ref_walkin.setRatedTotalLightingPower(lighting_power)
    ref_walkin.setLightingSchedule(model.alwaysOnDiscreteSchedule)
    ref_walkin.setDefrostType(defrost_type)
    ref_walkin.setDefrostControlType(defrost_control_type)
    ref_walkin.setDefrostSchedule(defrost_sch)
    ref_walkin.setDefrostDripDownSchedule(defrost_dripdown_sch)
    ref_walkin.setDefrostPower(defrost_power)
    ref_walkin.setTemperatureTerminationDefrostFractiontoIce(0.7)
    ref_walkin.setRestockingSchedule(model_add_schedule(model, always_off_name))
    ref_walkin.setInsulatedFloorSurfaceArea(insulated_floor_area)
    ref_walkin.setInsulatedFloorUValue(insulated_floor_u)
    ref_walkin.setZoneBoundaryThermalZone(thermal_zone)
    ref_walkin.setZoneBoundaryTotalInsulatedSurfaceAreaFacingZone(insulated_surface_area)
    ref_walkin.setZoneBoundaryInsulatedSurfaceUValueFacingZone(insulated_surface_u)
    ref_walkin.setZoneBoundaryAreaofGlassReachInDoorsFacingZone(reachin_door_area)
    ref_walkin.setZoneBoundaryHeightofGlassReachInDoorsFacingZone(1.83)
    ref_walkin.setZoneBoundaryGlassReachInDoorUValueFacingZone(2.27)
    ref_walkin.setZoneBoundaryAreaofStockingDoorsFacingZone(3.3)
    ref_walkin.setZoneBoundaryHeightofStockingDoorsFacingZone(2.1)
    ref_walkin.setZoneBoundaryStockingDoorUValueFacingZone(stocking_door_u)
    ref_walkin.setZoneBoundaryStockingDoorOpeningScheduleFacingZone(model_add_schedule(model, walkin_door_sch))

    insulated_floor_area_ft2 = OpenStudio.convert(insulated_floor_area, 'm^2', 'ft^2').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{insulated_floor_area_ft2.round} ft2 #{walkin_type} called #{walkin_name} to #{thermal_zone.name}.")

    return ref_walkin
  end

  # Adds a refrigeration compressor to the model.
  #
  def model_add_refrigeration_compressor(model, compressor_type)
    # Get the compressor properties
    search_criteria = {
      'template' => template,
      'compressor_type' => compressor_type
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

  # Adds a full commercial refrigeration rack, as would be found in a supermarket,
  # to the model.
  #
  # @param compressor_type [String] the system temperature range.  valid choices are:
  # Low Temp, Med Temp
  # @param system_name [String] the name of the refrigeration system
  # @param cases [Array<Hash>] an array of cases with keys:
  # case_type, case_name, length, number_of_cases, and space_names.
  # @param walkins [Array<Hashs>] an array of walkins with keys:
  # walkin_type, walkin_name, insulated_floor_area, space_names, and number_of_walkins
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

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding #{compressor_type} refrigeration system called #{system_name} with #{cases.size} cases and #{walkins.size} walkins.")

    # Compressors (20 for each system)
    for i in 0...20
      compressor = model_add_refrigeration_compressor(model, compressor_type)
      ref_sys.addCompressor(compressor)
    end

    # Cases
    cooling_cap = 0
    cases.each do |case_|
      for i in 0...case_['number_of_cases']
        zone = model_get_zones_from_spaces_on_system(model, case_)[0]
        ref_case = model_add_refrigeration_case(model,
                                                case_['case_type'],
                                                "#{case_['case_name']} #{i + 1}",
                                                case_['length'],
                                                zone)
        ref_sys.addCase(ref_case)
        cooling_cap += (ref_case.ratedTotalCoolingCapacityperUnitLength * ref_case.caseLength) # calculate total cooling capacity of the cases
      end
    end

    # Walkins
    walkins.each do |walkin|
      for i in 0...walkin['number_of_walkins']
        zone = model_get_zones_from_spaces_on_system(model, walkin)[0]
        ref_walkin = model_add_refrigeration_walkin(model,
                                                    walkin['walkin_type'],
                                                    "#{walkin['walkin_name']} #{i + 1}",
                                                    walkin['insulated_floor_area'],
                                                    zone)
        cooling_cap += ref_walkin.ratedCoilCoolingCapacity # calculate total cooling capacity of the cases + walkins
      end
    end

    # Condenser capacity
    # The heat rejection rate from the condenser is equal to the rated capacity of all the display cases and walk-ins connected to the compressor rack
    # plus the power rating of the compressors making up the compressor rack.
    # Assuming a COP of 1.3 for low-temperature compressor racks and a COP of 2.0 for medium-temperature compressor racks,
    # the required condenser capacity is approximated as follows:
    # Note the factor 1.2 has been included to over-estimate the condenser size.  The total capacity of the display cases can be calculated from their rated cooling capacity times the length of the cases.  The capacity of each of the walk-ins is specified directly.
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
