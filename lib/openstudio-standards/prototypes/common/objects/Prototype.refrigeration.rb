class Standard
  # @!group refrigeration


  # Add refrigerated case to the model.
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # case is located, and which will be impacted by the case's thermal load.
  # @param case_type [String] the case type/name. For valid choices
  # This parameter is used also by the "Refrigeration System Lineup"
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
    # puts 'in add cases'
    # puts search_criteria
    # puts "these were the search criteria"

    props = model_find_object(standards_data['refrigerated_cases'], search_criteria)
    if props.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigerated case properties for: #{search_criteria}.")
      return nil
    end

    # Capacity, defrost, anti-sweat
    if props['latent_heat_ratio']
      latent_heat_ratio = props['latent_heat_ratio']
    end
    if props['rated_runtime_fraction']
      rated_runtime_fraction = props['rated_runtime_fraction']
    end
    case_length = OpenStudio::convert(props['case_length'],"ft","m").get
    case_temp = OpenStudio::convert(props['case_temp'],"F","C").get
    cooling_capacity_per_length = OpenStudio::convert(OpenStudio::convert(props['cooling_capacity_per_length'],"Btu/h","W").get,"W/ft","W/m").get
    evap_fan_power_per_length = OpenStudio::convert(props['evap_fan_power_per_length'],"W/ft","W/m").get
    if props['evap_temp']
      evap_temp = OpenStudio::convert(props['evap_temp'],"F","C").get
    end
    lighting_per_ft = OpenStudio::convert(props['lighting_per_ft'],"W/ft","W/m").get
    fraction_of_lighting_energy_to_case = props['fraction_of_lighting_energy_to_case']
    if props['latent_case_credit_curve_name']
      latent_case_credit_curve_name = model_add_curve(model, props['latent_case_credit_curve_name'])
    end
    defrost_power_per_length = OpenStudio::convert(props['defrost_power_per_length'],"W/ft","W/m").get
    defrost_type = props['defrost_type']
    if props['defrost_correction_type']
      defrost_correction_type = props['defrost_correction_type']
    end
    if props['defrost_correction_curve_name']
      defrost_correction_curve_name = model_add_curve(model, props['defrost_correction_curve_name'])
    end
    if props['anti_sweat_power']
      anti_sweat_power = OpenStudio::convert(props['anti_sweat_power'],"W/ft","W/m").get
    end
    if props['minimum_anti_sweat_heater_power_per_unit_length']
      minimum_anti_sweat_heater_power_per_unit_length = OpenStudio::convert(props['minimum_anti_sweat_heater_power_per_unit_length'],"W/ft","W/m").get
      anti_sweat_heater_control = props['anti_sweat_heater_control']
    end
    restocking_sch_name = 'Always Off'
    fractionofantisweatheaterenergytocase = props['fractionofantisweatheaterenergytocase']



    # Case
    ref_case = OpenStudio::Model::RefrigerationCase.new(model, model.alwaysOnDiscreteSchedule)
    ref_case.setName(case_type)
    ref_case.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_case.setThermalZone(thermal_zone)
    ref_case.setRatedAmbientTemperature(OpenStudio.convert(75, 'F', 'C').get)
    if props['latent_heat_ratio']
      ref_case.setRatedLatentHeatRatio(latent_heat_ratio)
    end
    if props['rated_runtime_fraction']
      ref_case.setRatedRuntimeFraction(rated_runtime_fraction)
    end
    ref_case.setCaseLength(case_length)
    ref_case.setCaseOperatingTemperature(case_temp)
    ref_case.setRatedTotalCoolingCapacityperUnitLength(cooling_capacity_per_length)
    ref_case.setStandardCaseFanPowerperUnitLength(evap_fan_power_per_length)
    ref_case.setOperatingCaseFanPowerperUnitLength(evap_fan_power_per_length)
    if props['evap_temp']
      ref_case.setDesignEvaporatorTemperatureorBrineInletTemperature(evap_temp)
    end
    ref_case.setStandardCaseLightingPowerperUnitLength(lighting_per_ft)
    ref_case.setInstalledCaseLightingPowerperUnitLength(lighting_per_ft)
    ref_case.setCaseLightingSchedule(model.alwaysOnDiscreteSchedule)
    puts '++++++++++++++++++'
    puts case_type
    puts props['latent_case_credit_curve_name']
    puts '++++++++++'
    # puts model_add_curve(model, latent_case_credit_curve_name)
    puts '-----------='
    if props['latent_case_credit_curve_name']
      # ref_case.setLatentCaseCreditCurve(model_add_curve(model, latent_case_credit_curve_name))
    end
    ref_case.setCaseDefrostPowerperUnitLength(defrost_power_per_length)
    if
    ref_case.setCaseDefrostType(defrost_type)
    end
    ref_case.setDefrostEnergyCorrectionCurveType(defrost_correction_type)
    if props['defrost_correction_curve_name']
      # ref_case.setDefrostEnergyCorrectionCurve(model_add_curve(model, defrost_correction_curve_name))
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
    ref_case.setUnderCaseHVACReturnAirFraction(0)
    ref_case.setRefrigeratedCaseRestockingSchedule(model_add_schedule(model, restocking_sch_name))


    length_ft = OpenStudio.convert(case_length, 'm', 'ft').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{length_ft.round} ft  called #{case_type} to #{thermal_zone.name}.")

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
  # @param walkin_type [String] the walkin type/name. For valid choices
  # refer to the ""Refrigerated Walkins" tab on the OpenStudio_Standards spreadsheet.
  # This parameter is used also by the "Refrigeration System Lineup"
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone where the
  # walkin is located, and which will be impacted by the walkin's thermal load.
  # @param walkin_name [String] the name of the walkin
  # @param insulated_floor_area [Double] the floor area of the walkin, in m^2

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
    # props = model_find_object(standards_data['refrigerationtest'], search_criteria)
    # if props.nil?
    #   OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find walkin refrigeration properties for: #{search_criteria}.")
    #   return nil
    # end


    # Capacity, defrost, lighting
    walkin_type = props['walkin_type']
    if props['rated_cooling_capacity']
      rated_cooling_capacity = OpenStudio::convert(props['rated_cooling_capacity'],"Btu/h","W").get
    end
    if props['cooling_capacity_c0']
      cooling_capacity_c0 = OpenStudio::convert(OpenStudio::convert(props['cooling_capacity_c0'],"Btu/h","W").get,"W/ft","W/m").get
    end
    if props['cooling_capacity_c1']
      cooling_capacity_c1 = OpenStudio::convert(OpenStudio::convert(props['cooling_capacity_c1'],"Btu/h","W").get,"W/ft","W/m").get
    end
    if props['cooling_capacity_c2']
      cooling_capacity_c2 = OpenStudio::convert(OpenStudio::convert(props['cooling_capacity_c2'],"Btu/h","W").get,"W/ft","W/m").get
    end
    if props['fan_power_mult']
      fan_power_mult = props['fan_power_mult']
    end
    if props['lighting_power_mult']
      lighting_power_mult = props['lighting_power_mult']
    end
    if props['reachin_door_area_mult']
      reachin_door_area_mult = OpenStudio::convert(props['reachin_door_area_mult'],"ft^2","m^2").get
    end
    operating_temp = OpenStudio::convert(props['operating_temp'],"F","C").get
    if props['source_temp']
      source_temp = OpenStudio::convert(props['source_temp'],"F","C").get
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
    # lighting_power_mult = props['lighting_power_mult']
    if props['insulated_floor_u']
      insulated_floor_u = OpenStudio::convert(props['insulated_floor_u'],"Btu/ft^2*h*R","W/m^2*K").get
    end
    if props['insulated_surface_u']
      insulated_surface_u = OpenStudio::convert(props['insulated_surface_u'],"Btu/ft^2*h*R","W/m^2*K").get
    end
    if props['stocking_door_u']
      insulated_door_u = OpenStudio::convert(props['stocking_door_u'],"Btu/ft^2*h*R","W/m^2*K").get
    end
    if props['glass_reachin_door_u_value']
      glass_reachin_door_u_value = OpenStudio::convert(props['glass_reachin_door_u_value'],"Btu/ft^2*h*R","W/m^2*K").get
    end
    if props['reachin_door_area']
      reachin_door_area = OpenStudio::convert(props['reachin_door_area'],"ft^2","m^2").get
    end
    if props['total_insulated_surface_area']
      total_insulated_surface_area = OpenStudio::convert(props['total_insulated_surface_area'],"ft^2","m^2").get
    end
    if props['height_of_glass_reachin_doors']
      height_of_glass_reachin_doors = OpenStudio::convert(props['height_of_glass_reachin_doors'],"ft","m").get
    end
    if props['area_of_stocking_doors']
      area_of_stocking_doors = OpenStudio::convert(props['area_of_stocking_doors'],"ft^2","m^2").get
    end
    if props['floor_surface_area']
      floor_surface_area = OpenStudio::convert(props['floor_surface_area'],"ft^2","m^2").get
    end
    if props['height_of_stocking_doors']
      height_of_stocking_doors = OpenStudio::convert(props['height_of_stocking_doors'],"ft","m").get
    end
    availabilityschedule = props['availabilityschedule']
    lightingschedule = props['lighting_schedule']
    defrostschedule = props['defrostschedule']
    defrostdripdownschedule = props['defrostdripdownschedule']
    restockingschedule = props['restocking_schedule']
    zoneboundarystockingdooropeningschedulefacingzone = props['zoneboundarystockingdooropeningschedulefacingzone']
    temperatureterminationdefrostfractiontoice = props['temperatureterminationdefrostfractiontoice']


    # Calculated properties
    if rated_cooling_capacity == nil
      rated_cooling_capacity = cooling_capacity_c2 * (floor_surface_area ^ 2) + cooling_capacity_c1 * floor_surface_area + cooling_capacity_c0
    end
    if defrost_power == nil
      defrost_power = defrost_power_mult * rated_cooling_capacity
    end
    if total_insulated_surface_area == nil
      total_insulated_surface_area = 1.7226 * floor_surface_area + 28.653
    end
    if reachin_door_area == nil
      reachin_door_area = reachin_door_area_mult * floor_surface_area
    end
    if fan_power == nil
      fan_power = fan_power_mult * rated_cooling_capacity
    end
    if lighting_power == nil
      lighting_power = lighting_power_mult * floor_surface_area
    end

    # Walk-In
    ref_walkin = OpenStudio::Model::RefrigerationWalkIn.new(model, model.alwaysOnDiscreteSchedule)
    ref_walkin.setName(walkin_type.to_s)
    ref_walkin.setZoneBoundaryThermalZone(thermal_zone)
    ref_walkin.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    ref_walkin.setRatedCoilCoolingCapacity(rated_cooling_capacity)
    ref_walkin.setOperatingTemperature(operating_temp)
    if props['source_temp']
      ref_walkin.setRatedCoolingSourceTemperature(source_temp)
    end
    if props['defrost_control_type']
      ref_walkin.setDefrostControlType(defrost_control_type)
    end
    ref_walkin.setDefrostType(defrost_type)
    ref_walkin.setDefrostPower(defrost_power)
    ref_walkin.setRatedTotalHeatingPower(ratedtotalheatingpower)
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
    ref_walkin.setRestockingSchedule(model_add_schedule(model, restockingschedule))
    ref_walkin.setLightingSchedule(model_add_schedule(model, lightingschedule))
    ref_walkin.setZoneBoundaryStockingDoorOpeningScheduleFacingZone(model_add_schedule(model, 'door_wi_sched'))




    # ref_walkin.setDefrostSchedule(defrost_sch)
    # ref_walkin.setDefrostDripDownSchedule(defrost_dripdown_sch)



    insulated_floor_area_ft2 = OpenStudio.convert(floor_surface_area, 'm^2', 'ft^2').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{insulated_floor_area_ft2.round} ft2 called #{walkin_type} to #{thermal_zone.name}.")

    return ref_walkin
  end

  # Adds a refrigeration compressor to the model.
  #
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



  def model_add_typical_refrigeration(model, climate_zone, thermal_zone_case, thermal_zone_walkin)

    floor_area = model.getBuilding.floorArea
    # puts floor_area
    # Define Size and System Category
    # floor_area = OpenStudio::convert(floor_area,"ft^2","m^2").get
    if floor_area < 3251.6064     # this is in m2
      size_category = '<35k ft2'
      system_category = 'cat_A'
      floor_area_scaling_factor = floor_area/3251.6064
    elsif floor_area < 4645.152
      size_category = '35k - 50k ft2'
      if template== 'DEER Pre-1975' or template== 'DEER 1985' or template== 'DEER 1996' or template== 'DEER 2003' or template== 'DEER 2007'
        system_category = 'cat_B'
      else
        system_category = 'cat_C'
      end
      floor_area_scaling_factor = floor_area/4645.152
    else
      size_category = '>50k ft2'
      if template== 'DEER Pre-1975' or template== 'DEER 1985' or template== 'DEER 1996'
        system_category = 'cat_B'
      else
        system_category = 'cat_C'
      end
      floor_area_scaling_factor = floor_area/4645.152
    end


    # puts size_category
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Floor area is: #{(OpenStudio::convert(floor_area,"m^2","ft^2").get).to_s} ft^2")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Therefore the size category is:  #{size_category.to_s}")
    # puts "***********************************************************"



    #For small stores, one compressor and one condenser per case is employed
    if floor_area < 3251.6064     # this is in m2

      t = 0
      while t < 2
        ##############################
        # Add refrigeration system
        ##############################
        #
        if t < 1
          system_type = "Medium Temperature"
        else
          system_type = "Low Temperature"
        end

        search_criteria = {
            'template' => template,
            'size_category' => size_category,
            'climate_zone' => climate_zone,
            'system_type' => system_type
        }


        props_lineup = model_find_object(standards_data['refrigeration_system_lineup'], search_criteria)
        if props_lineup.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration system lineup properties for: #{search_criteria}.")
          return nil
        end

        number_of_display_cases = props_lineup['number_of_display_cases']
        number_of_walkins = props_lineup['number_of_walkins']
        compressor_name = props_lineup['compressor_name']


        # puts number_of_display_cases
        hh = 0
        h_0 = 0
        j = 1
        while j <= number_of_display_cases
          #######################################
          # Add Small stores refrigeration systems
          #######################################
          # #
          # if j < 1
          #   system_type = "Medium Temperature"
          # else
          #   system_type = "Low Temperature"
          # end

          # Add system
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding #{system_type} System")
          # puts "***********************************************************"
          search_criteria = {
              'template' => template,
              'size_category' => size_category,
              'system_type' => system_type
          }
          #
          props = model_find_object(standards_data['refrigeration_system'], search_criteria)
          if props.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration system properties for: #{search_criteria}.")
            return nil
          end
          #
          # puts props_lineup
          # puts j
          system_name = (props_lineup["case_type_#{j}"]) + " Refrigeration System"
          ref_system = OpenStudio::Model::RefrigerationSystem.new(model)
          ref_system.setName(system_name)
          ref_system.setRefrigerationSystemWorkingFluidType(props['refrigerant'])
          ref_system.setSuctionTemperatureControlType(props['refrigerant'])


          # Add cases
          case_type = props_lineup["case_type_#{j}"]
          ref_case = model_add_refrigeration_case(model, thermal_zone_case, case_type, size_category)

          # Add Defrost and Dripdown Schedule
          search_criteria = {
              'template' => template,
              'case_type' => case_type,
              'size_category' => size_category
          }
          props_case = model_find_object(standards_data['refrigerated_cases'], search_criteria)
          if props_case.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigerated case properties for: #{search_criteria}.")
            return nil
          end
          numb_defrosts_per_day = props_case['defrost_per_day']
          minutes_defrost = props_case['minutes_defrost']
          numb_dripdown_per_day = props_case['dripdown_per_day']
          minutes_dripdown = props_case['minutes_dripdown']
          if minutes_defrost > 59   #Just to make sure to remain in the same hour
            minutes_defrost = 59
          end
          if minutes_dripdown > 59   #Just to make sure to remain in the same hour
            minutes_dripdown = 59
          end
          defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          defrost_sch.setName('Refrigeration Defrost Schedule')
          defrost_sch.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{case_type}")
          dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          dripdown_sch.setName('Refrigeration Dripdown Schedule')
          dripdown_sch.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{case_type}")
          #
          interval_defrost = (24/numb_defrosts_per_day).floor      #Hour interval between each defrost period
          if (hh + interval_defrost * numb_defrosts_per_day) > 23
            h_0 = 0
          else
            h_0 = hh
          end
          i = 1
          while i <= numb_defrosts_per_day
            defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)
            defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_defrost.to_int, 0), 0)
            dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)    #Dripdown is synced with defrost
            dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_dripdown.to_int, 0), 0)
            h_0 = h_0 + interval_defrost
            i += 1
          end
          defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          #
          ref_case.setCaseDefrostSchedule(defrost_sch)
          ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)
          # End of Defrost and Dripdown Schedule
          # Scale on the base of floor area
          ref_case.setCaseLength(ref_case.caseLength * floor_area_scaling_factor)
          # End of scaling
          rated_cooling_capacity = ref_case.ratedTotalCoolingCapacityperUnitLength * ref_case.caseLength  * floor_area_scaling_factor
          ref_system.addCase(ref_case)
          hh = hh + 1
          k += 1
          #
          # add compressors
          # compressor_type = system_type
          search_criteria = {
              'template' => template,
              'compressor_name' => compressor_name
          }
          props_compressor = model_find_object(standards_data['refrigeration_compressors'], search_criteria)
          if props_compressor.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration compressor properties for: #{search_criteria}.")
            return nil
          end
          number_of_compressors = (rated_cooling_capacity.to_f/ (OpenStudio::convert(props_compressor["rated_capacity"],"Btu/h","W").get).to_f).ceil
          i = 1
          while i < number_of_compressors
            # compressor_name = props_compressor["compressor_name"]
            compressor_i = model_add_refrigeration_compressor(model, compressor_name)
            # variation_walkin_area = props["variation_walkin_area_#{i}"]
            ref_system.addCompressor(compressor_i)
            i += 1
          end


          # Add condenser
          search_criteria = {
              'template' => template,
              'system_type' => system_type,
              'size_category' => size_category
          }
          #
          props_condenser = model_find_object(standards_data['refrigeration_condenser'], search_criteria)
          if props_condenser.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration condenser properties for: #{search_criteria}.")
            return nil
          end

          heat_rejection = OpenStudio::Model::CurveLinear.new(model)
          heat_rejection.setCoefficient1Constant(0)
          heat_rejection.setCoefficient2x(props_condenser['heatrejectioncurve_c1'])
          heat_rejection.setMinimumValueofx(-50)
          heat_rejection.setMaximumValueofx(50)
          #
          condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
          condenser.setRatedEffectiveTotalHeatRejectionRateCurve(heat_rejection)
          condenser.setRatedSubcoolingTemperatureDifference(OpenStudio::convert(props_condenser['subcool_t'],"Btu/h","W").get)
          condenser.setMinimumFanAirFlowRatio(props_condenser['min_airflow'])
          condenser.setRatedFanPower(props_condenser['fan_power_per_q_rejected'].to_f * rated_cooling_capacity.to_f)
          condenser.setCondenserFanSpeedControlType(props_condenser['fan_speed_control'])
          ref_system.setRefrigerationCondenser(condenser)

          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Finished adding #{system_name}")
          j = j + 1

          #
        end

        # add walkin cases
        #
        #
        hh = 0
        h_0 = 0
        j = 1
        while j <= number_of_walkins
          # Add system
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding #{system_type} walkins System")
          # puts "***********************************************************"
          search_criteria = {
              'template' => template,
              'size_category' => size_category,
              'system_type' => system_type
          }
          #
          props = model_find_object(standards_data['refrigeration_system'], search_criteria)
          if props.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration system properties for: #{search_criteria}.")
            return nil
          end

          system_name = (props_lineup["walkin_type_#{j}"]) + " Refrigeration System"
          ref_system = OpenStudio::Model::RefrigerationSystem.new(model)
          ref_system.setName(system_name)
          ref_system.setRefrigerationSystemWorkingFluidType(props['refrigerant'])
          ref_system.setSuctionTemperatureControlType(props['refrigerant'])

          # Add walkins
          walkin_type = props_lineup["walkin_type_#{j}"]
          ref_walkin = model_add_refrigeration_walkin(model, thermal_zone_walkin, size_category, walkin_type)

          # Add Defrost and Dripdown Schedule
          search_criteria = {
              'template' => template,
              'walkin_type' => walkin_type,
              'size_category' => size_category
          }
          props_walkin = model_find_object(standards_data['refrigeration_walkins'], search_criteria)
          if props_walkin.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find walkin properties for: #{search_criteria}.")
            return nil
          end
          numb_defrosts_per_day = props_walkin['defrost_per_day']
          minutes_defrost = props_walkin['minutes_defrost']
          numb_dripdown_per_day = props_walkin['dripdown_per_day']
          minutes_dripdown = props_walkin['minutes_dripdown']
          if minutes_defrost > 59   #Just to make sure to remain in the same hour
            minutes_defrost = 59
          end
          if minutes_dripdown > 59   #Just to make sure to remain in the same hour
            minutes_dripdown = 59
          end
          defrost_sch_walkin = OpenStudio::Model::ScheduleRuleset.new(model)
          defrost_sch_walkin.setName('Refrigeration Defrost Schedule')
          defrost_sch_walkin.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{walkin_type}")
          dripdown_sch_walkin = OpenStudio::Model::ScheduleRuleset.new(model)
          dripdown_sch_walkin.setName('Refrigeration Dripdown Schedule')
          dripdown_sch_walkin.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{walkin_type}")
          #
          interval_defrost = (24/numb_defrosts_per_day).floor      #Hour interval between each defrost period
          if (hh + interval_defrost * numb_defrosts_per_day) > 23
            h_0 = 0
          else
            h_0 = hh
          end
          i = 1
          while i <= numb_defrosts_per_day
            defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)
            defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_defrost.to_int, 0), 0)
            dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)    #Dripdown is synced with defrost
            dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_dripdown.to_int, 0), 0)
            h_0 = h_0 + interval_defrost
            i += 1
          end
          defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          #
          ref_walkin.setDefrostSchedule(defrost_sch_walkin)
          ref_walkin.setDefrostDripDownSchedule(dripdown_sch_walkin)
          # End of Defrost and Dripdown Schedule
          # Scale on the base of floor area
          ref_walkin.setRatedTotalLightingPower(ref_walkin.ratedTotalLightingPower.to_f * floor_area_scaling_factor)
          ref_walkin.setRatedCoolingCoilFanPower(ref_walkin.ratedCoolingCoilFanPower.to_f  * floor_area_scaling_factor)
          ref_walkin.setDefrostPower(ref_walkin.defrostPower.to_f  * floor_area_scaling_factor)
          ref_walkin.setRatedCoilCoolingCapacity(ref_walkin.ratedCoilCoolingCapacity.to_f  * floor_area_scaling_factor)
          ref_walkin.setZoneBoundaryTotalInsulatedSurfaceAreaFacingZone(ref_walkin.zoneBoundaryTotalInsulatedSurfaceAreaFacingZone.to_f  * floor_area_scaling_factor)
          ref_walkin.setInsulatedFloorSurfaceArea(ref_walkin.insulatedFloorSurfaceArea.to_f  * floor_area_scaling_factor)
          # End of scaling
          rated_cooling_capacity = ref_walkin.ratedCoilCoolingCapacity.to_f * floor_area_scaling_factor
          ref_system.addWalkin(ref_walkin)
          hh = hh + 1
          k += 1


          # add compressors
          # compressor_type = system_type
          search_criteria = {
              'template' => template,
              'compressor_name' => compressor_name
          }
          props_compressor = model_find_object(standards_data['refrigeration_compressors'], search_criteria)
          if props_compressor.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration compressor properties for: #{search_criteria}.")
            return nil
          end
          number_of_compressors = (rated_cooling_capacity.to_f/ (OpenStudio::convert(props_compressor["rated_capacity"],"Btu/h","W").get).to_f).ceil
          i = 1
          while i <= number_of_compressors
            # compressor_name = props_compressor["compressor_name"]
            compressor_i = model_add_refrigeration_compressor(model, compressor_name)
            # variation_walkin_area = props["variation_walkin_area_#{i}"]
            ref_system.addCompressor(compressor_i)
            i += 1
          end


          # Add condenser
          search_criteria = {
              'template' => template,
              'system_type' => system_type,
              'size_category' => size_category
          }
          #
          props_condenser = model_find_object(standards_data['refrigeration_condenser'], search_criteria)
          if props_condenser.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration condenser properties for: #{search_criteria}.")
            return nil
          end

          heat_rejection = OpenStudio::Model::CurveLinear.new(model)
          heat_rejection.setCoefficient1Constant(0)
          heat_rejection.setCoefficient2x(props_condenser['heatrejectioncurve_c1'])
          heat_rejection.setMinimumValueofx(-50)
          heat_rejection.setMaximumValueofx(50)
          #
          condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
          condenser.setRatedEffectiveTotalHeatRejectionRateCurve(heat_rejection)
          condenser.setRatedSubcoolingTemperatureDifference(OpenStudio::convert(props_condenser['subcool_t'],"Btu/h","W").get)
          condenser.setMinimumFanAirFlowRatio(props_condenser['min_airflow'])
          condenser.setRatedFanPower(props_condenser['fan_power_per_q_rejected'].to_f * rated_cooling_capacity.to_f)
          condenser.setCondenserFanSpeedControlType(props_condenser['fan_speed_control'])
          ref_system.setRefrigerationCondenser(condenser)

          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Finished adding #{system_name}")
          j = j + 1
        end
        #
        t = t + 1
      end
    else

      j = 0
      while j < 2
        ##############################
        # Add refrigeration system
        ##############################
        #
        if j < 1
          system_type = "Medium Temperature"
        else
          system_type = "Low Temperature"
        end

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding #{system_type} System")
        # puts "***********************************************************"


        search_criteria = {
            'template' => template,
            'size_category' => size_category,
            'system_type' => system_type
        }
        #
        puts search_criteria
        props = model_find_object(standards_data['refrigeration_system'], search_criteria)
        puts props
        if props.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration system properties for: #{search_criteria}.")
          return nil
        end
        #
        ref_system = OpenStudio::Model::RefrigerationSystem.new(model)
        ref_system.setName(system_type)
        ref_system.setRefrigerationSystemWorkingFluidType(props['refrigerant'])
        ref_system.setSuctionTemperatureControlType(props['refrigerant'])


        # Add cases
        search_criteria = {
            'template' => template,
            'size_category' => size_category,
            'climate_zone' => climate_zone,
            'system_type' => system_type
        }


        props_lineup = model_find_object(standards_data['refrigeration_system_lineup'], search_criteria)
        if props_lineup.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration system lineup properties for: #{search_criteria}.")
          return nil
        end

        # puts props_lineup

        number_of_display_cases = props_lineup['number_of_display_cases']
        number_of_walkins = props_lineup['number_of_walkins']
        compressor_name = props_lineup['compressor_name']

        rated_cooling_capacity = 0
        # add display cases
        k = 1
        hh = 0
        h_0 = 0
        while k <= number_of_display_cases
          case_type = props_lineup["case_type_#{k}"]
          # puts props_lineup
          # puts k
          # puts number_of_display_cases
          # puts "here is case_type"
          # puts case_type
          # puts "now we call add_case"
          ref_case = model_add_refrigeration_case(model, thermal_zone_case, case_type, size_category)
          # puts ref_case

          # Add Defrost and Dripdown Schedule
          search_criteria = {
              'template' => template,
              'case_type' => case_type,
              'size_category' => size_category
          }
          props_case = model_find_object(standards_data['refrigerated_cases'], search_criteria)
          if props_case.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigerated case properties for: #{search_criteria}.")
            return nil
          end
          numb_defrosts_per_day = props_case['defrost_per_day']
          minutes_defrost = props_case['minutes_defrost']
          numb_dripdown_per_day = props_case['dripdown_per_day']
          minutes_dripdown = props_case['minutes_dripdown']
          if minutes_defrost > 59   #Just to make sure to remain in the same hour
            minutes_defrost = 59
          end
          if minutes_dripdown > 59   #Just to make sure to remain in the same hour
            minutes_dripdown = 59
          end
          defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          defrost_sch.setName('Refrigeration Defrost Schedule')
          defrost_sch.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{case_type}")
          dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          dripdown_sch.setName('Refrigeration Dripdown Schedule')
          dripdown_sch.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{case_type}")
          #
          interval_defrost = (24/numb_defrosts_per_day).floor      #Hour interval between each defrost period
          if (hh + interval_defrost * numb_defrosts_per_day) > 23
            h_0 = 0
          else
            h_0 = hh
          end
          i = 1
          while i <= numb_defrosts_per_day
            defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)
            defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_defrost.to_int, 0), 0)
            dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)    #Dripdown is synced with defrost
            dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_dripdown.to_int, 0), 0)
            h_0 = h_0 + interval_defrost
            i += 1
          end
          defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          #
          ref_case.setCaseDefrostSchedule(defrost_sch)
          ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)
          # End of Defrost and Dripdown Schedule
          # Scale on the base of floor area
          ref_case.setCaseLength(ref_case.caseLength * floor_area_scaling_factor)
          # End of scaling
          rated_cooling_capacity = rated_cooling_capacity + ref_case.ratedTotalCoolingCapacityperUnitLength * ref_case.caseLength  * floor_area_scaling_factor
          ref_system.addCase(ref_case)
          hh = hh + 1
          k += 1
        end

        # add walkin cases
        #
        #
        k = 1
        hh = 0
        h_0 = 0
        while k <= number_of_walkins
          walkin_type = props_lineup["walkin_type_#{k}"]
          # puts 'here the walkin type'
          # puts walkin_type
          ref_walkin = model_add_refrigeration_walkin(model, thermal_zone_walkin, size_category, walkin_type)
          # puts 'after ref_walkin'
          # puts ref_walkin
          # Add Defrost and Dripdown Schedule
          search_criteria = {
              'template' => template,
              'walkin_type' => walkin_type,
              'size_category' => size_category
          }
          # puts k
          # puts 'these are search criteria'
          # puts search_criteria

          props_walkin = model_find_object(standards_data['refrigeration_walkins'], search_criteria)
          if props_walkin.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find walkin properties for: #{search_criteria}.")
            return nil
          end
          numb_defrosts_per_day = props_walkin['defrost_per_day']
          minutes_defrost = props_walkin['minutes_defrost']
          numb_dripdown_per_day = props_walkin['dripdown_per_day']
          minutes_dripdown = props_walkin['minutes_dripdown']
          if minutes_defrost > 59   #Just to make sure to remain in the same hour
            minutes_defrost = 59
          end
          if minutes_dripdown > 59   #Just to make sure to remain in the same hour
            minutes_dripdown = 59
          end
          defrost_sch_walkin = OpenStudio::Model::ScheduleRuleset.new(model)
          defrost_sch_walkin.setName('Refrigeration Defrost Schedule')
          defrost_sch_walkin.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default - #{walkin_type}")
          dripdown_sch_walkin = OpenStudio::Model::ScheduleRuleset.new(model)
          dripdown_sch_walkin.setName('Refrigeration Dripdown Schedule')
          dripdown_sch_walkin.defaultDaySchedule.setName("Refrigeration Dripdown Schedule Default - #{walkin_type}")
          #
          interval_defrost = (24/numb_defrosts_per_day).floor      #Hour interval between each defrost period
          if (hh + interval_defrost * numb_defrosts_per_day) > 23
            h_0 = 0
          else
            h_0 = hh
          end
          i = 1
          while i <= numb_defrosts_per_day
            defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)
            defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_defrost.to_int, 0), 0)
            dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, 0, 0), 0)    #Dripdown is synced with defrost
            dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,h_0, minutes_dripdown.to_int, 0), 0)
            h_0 = h_0 + interval_defrost
            i += 1
          end
          defrost_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          dripdown_sch_walkin.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
          #
          ref_walkin.setDefrostSchedule(defrost_sch_walkin)
          ref_walkin.setDefrostDripDownSchedule(dripdown_sch_walkin)
          # End of Defrost and Dripdown Schedule
          # Scale on the base of floor area
          ref_walkin.setRatedTotalLightingPower(ref_walkin.ratedTotalLightingPower.to_f * floor_area_scaling_factor)
          ref_walkin.setRatedCoolingCoilFanPower(ref_walkin.ratedCoolingCoilFanPower.to_f  * floor_area_scaling_factor)
          ref_walkin.setDefrostPower(ref_walkin.defrostPower.to_f  * floor_area_scaling_factor)
          ref_walkin.setRatedCoilCoolingCapacity(ref_walkin.ratedCoilCoolingCapacity.to_f  * floor_area_scaling_factor)
          ref_walkin.setZoneBoundaryTotalInsulatedSurfaceAreaFacingZone(ref_walkin.zoneBoundaryTotalInsulatedSurfaceAreaFacingZone.to_f  * floor_area_scaling_factor)
          ref_walkin.setInsulatedFloorSurfaceArea(ref_walkin.insulatedFloorSurfaceArea.to_f  * floor_area_scaling_factor)
          # End of scaling
          rated_cooling_capacity = rated_cooling_capacity + ref_walkin.ratedCoilCoolingCapacity.to_f * floor_area_scaling_factor
          ref_system.addWalkin(ref_walkin)
          hh = hh + 1
          k += 1
        end
        #

        # add compressors
        # compressor_type = system_type
        search_criteria = {
            'template' => template,
            'compressor_name' => compressor_name
        }
        props_compressor = model_find_object(standards_data['refrigeration_compressors'], search_criteria)
        if props_compressor.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration compressor properties for: #{search_criteria}.")
          return nil
        end
        # if floor_area >= 3251.6064
        number_of_compressors = (rated_cooling_capacity.to_f/ (OpenStudio::convert(props_compressor["rated_capacity"],"Btu/h","W").get).to_f).ceil
        # end
        i = 1
        while i <= number_of_compressors
          # puts i
          # compressor_name = props_compressor["compressor_name"]
          compressor_i = model_add_refrigeration_compressor(model, compressor_name)
          # variation_walkin_area = props["variation_walkin_area_#{i}"]
          ref_system.addCompressor(compressor_i)
          i += 1
        end


        # Add condenser
        search_criteria = {
            'template' => template,
            'system_type' => system_type,
            'size_category' => size_category
        }
        #
        props_condenser = model_find_object(standards_data['refrigeration_condenser'], search_criteria)
        if props_condenser.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find refrigeration condenser properties for: #{search_criteria}.")
          return nil
        end

        heat_rejection = OpenStudio::Model::CurveLinear.new(model)
        heat_rejection.setCoefficient1Constant(0)
        heat_rejection.setCoefficient2x(props_condenser['heatrejectioncurve_c1'])
        heat_rejection.setMinimumValueofx(-50)
        heat_rejection.setMaximumValueofx(50)
        #
        condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(model)
        condenser.setRatedEffectiveTotalHeatRejectionRateCurve(heat_rejection)
        condenser.setRatedSubcoolingTemperatureDifference(OpenStudio::convert(props_condenser['subcool_t'],"Btu/h","W").get)
        condenser.setMinimumFanAirFlowRatio(props_condenser['min_airflow'])
        condenser.setRatedFanPower(props_condenser['fan_power_per_q_rejected'].to_f * rated_cooling_capacity.to_f)
        condenser.setCondenserFanSpeedControlType(props_condenser['fan_speed_control'])
        ref_system.setRefrigerationCondenser(condenser)

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Finished adding #{system_type}")
        j = j + 1
      end

    end

    return true
  end



end

#######################################################################################################
# OLD
#######################################################################################################



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
  puts '---------------------------------------------'
  i = 0
  cases.each do |case_|
    zone = model_get_zones_from_spaces_on_system(model, case_)[0]
    ref_case = model_add_refrigeration_case(model, zone, case_['case_type'], size_category)
    ########################################
    # Defrost schedule
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    defrost_sch.setName('Refrigeration Defrost Schedule')
    defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 0, 0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 59, 0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
    # Dripdown schedule
    dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    dripdown_sch.setName('Refrigeration Defrost Schedule')
    dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
    dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 0, 0), 0)
    dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 59, 0), 0)
    dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
    # Case Credit Schedule
    case_credit_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    case_credit_sch.setName('Refrigeration Case Credit Schedule')
    case_credit_sch.defaultDaySchedule.setName('Refrigeration Case Credit Schedule Default')
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 7, 0, 0), 0.2)
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 21, 0, 0), 0.4)
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    #
    # ref_case.setCaseDefrostSchedule(defrost_sch)
    # ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)
    ########################################
    # puts ref_case
    ref_sys.addCase(ref_case)
    cooling_cap += (ref_case.ratedTotalCoolingCapacityperUnitLength * ref_case.caseLength) # calculate total cooling capacity of the cases
    i = i + 1
  end

  # Walkins
  walkins.each do |walkin|
    for i in 0...walkin['number_of_walkins']

      zone = model_get_zones_from_spaces_on_system(model, walkin)[0]
      ref_walkin = model_add_refrigeration_walkin(model, zone, size_category, walkin['walkin_type'])
      ########################################
      # Defrost schedule
      defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      defrost_sch.setName('Refrigeration Defrost Schedule')
      defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 59, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i+10, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i+10, 59, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
      # Dripdown schedule
      dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      dripdown_sch.setName('Refrigeration Defrost Schedule')
      dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 0, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i, 59, 0), 1)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i+10, 0, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,i+10, 59, 0), 1)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24, 0, 0), 0)
      #
      ref_walkin.setDefrostSchedule(defrost_sch)
      ref_walkin.setDefrostDripDownSchedule(dripdown_sch)
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




