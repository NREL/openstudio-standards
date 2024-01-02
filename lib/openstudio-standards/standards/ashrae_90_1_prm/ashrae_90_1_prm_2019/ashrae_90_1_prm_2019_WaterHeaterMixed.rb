class ASHRAE901PRM2019 < ASHRAE901PRM


  def model_apply_water_heater_prm_parameter(water_heater_mixed, building_type_swh)

    # get number of water heaters
    if water_heater_mixed.additionalProperties.getFeatureAsInteger('component_quantity').is_initialized
      comp_qty = water_heater_mixed.additionalProperties.getFeatureAsInteger('component_quantity').get
    else
      comp_qty = 1
    end
    # Get the capacity of the water heater
    capacity_w = water_heater_mixed.heaterMaximumCapacity
    if capacity_w.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find capacity, standard will not be applied.")
      return false
    else
      capacity_w = capacity_w.get / comp_qty
    end
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    # Get the volumn of the water heater
    volumn_m3 = water_heater_mixed.tankVolume
    if volumn_m3.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find volumn, standard will not be applied.")
      return false
    else
      volumn_m3 = volumn_m3.get / comp_qty
    end
    volumn_gal = OpenStudio.convert(volumn_m3, 'm^3', 'gal').get
    # Get the fuel type data
    heater_prop = model_find_object(standards_data['prm_swh_bldg_type'], {'swh_building_type' => building_type_swh})
    new_fuel_data = heater_prop['baseline_heating_method']
    if new_fuel_data == "Gas Storage"
      new_fuel = "NaturalGas"
    else
      new_fuel = "Electricity"
    end
    # Get the water heater properties
    if (new_fuel == "Electricity") and (capacity_btu_per_hr > 40944.01)
      # The efficiency is based on PNNL-23269 Enhancements to ASHRAE Standard 90.1 Prototype Building Models A 1.2
      water_heater_eff = 1
      # The skin loss coefficient ua is based on 90.1-2019 Table 7.8 and PNNL-23269
      ua_btu_per_hr_per_f = (0.3 + 27.0/volumn_gal)/70
    else
      search_criteria = {}
      search_criteria['template'] = template
      search_criteria['fuel_type'] = new_fuel
      if new_fuel == "Electricity"
        search_criteria['product_class'] = "Water Heaters"
      else
        search_criteria['product_class'] = "Storage Water Heater"
      end

      # Todo: Use 'medium' as draw_profile for now. Add a warning
      search_criteria['draw_profile'] = "medium"
      # todo: delete later
      capacity_btu_per_hr = 74900
      wh_props = model_find_object(standards_data['water_heaters'], search_criteria, capacity = capacity_btu_per_hr, date = nil, area = nil, num_floors = nil, fan_motor_bhp = nil, volume = volumn_gal)
      puts wh_props
      unless wh_props
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find water heater properties, cannot apply efficiency standard.")
        return false
      end
      uniform_energy_factor_base = wh_props['uniform_energy_factor_base']
      uniform_energy_factor_volume_allowance = wh_props['uniform_energy_factor_volume_allowance']
      uef = uniform_energy_factor_base - uniform_energy_factor_volume_allowance * volumn_gal
      ef = water_heater_convert_uniform_energy_factor_to_energy_factor(fuel_type = new_fuel, uef = uef, capacity_btu_per_hr = capacity_btu_per_hr, volume_gal = volumn_gal)
      eff_ua = water_heater_convert_energy_factor_to_thermal_efficiency_and_ua(new_fuel, ef, capacity_btu_per_hr)
      water_heater_eff = eff_ua[0]
      ua_btu_per_hr_per_f = eff_ua[1]
    end

    # Ensure that efficiency and UA were both set
    if water_heater_eff.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot calculate efficiency, cannot apply efficiency standard.")
      return false
    end

    if ua_btu_per_hr_per_f.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot calculate UA, cannot apply efficiency standard.")
      return false
    end

    # Convert to SI
    ua_w_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, skin-loss UA = #{ua_w_per_k} W/K.")

    # Set the water heater prm properties
    # Efficiency
    water_heater_mixed.setHeaterThermalEfficiency(water_heater_eff)
    # Skin loss
    water_heater_mixed.setOffCycleLossCoefficienttoAmbientTemperature(ua_w_per_k)
    water_heater_mixed.setOnCycleLossCoefficienttoAmbientTemperature(ua_w_per_k)
    # Fuel type
    old_fuel = water_heater_mixed.heaterFuelType
    unless new_fuel == old_fuel
      water_heater_mixed.setHeaterFuelType(new_fuel)
      water_heater_mixed.setOnCycleParasiticFuelType(new_fuel)
      water_heater_mixed.setOffCycleParasiticFuelType(new_fuel)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, changed baseline water heater fuel from #{old_fuel} to #{new_fuel}.")
    end

    # Append the name with prm information
    water_heater_mixed.setName("#{water_heater_mixed.name} #{water_heater_eff.round(3)} Therm Eff")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.WaterHeaterMixed', "For #{template}: #{water_heater_mixed.name}; thermal efficiency = #{water_heater_eff.round(3)}, skin-loss UA = #{ua_btu_per_hr_per_f.round}Btu/hr-R")
    return true
  end


  def model_add_water_heater(model,
                             building_type_swh,
                             water_heater_capacity,
                             water_heater_volume,
                             water_heater_fuel,
                             service_water_temperature,
                             parasitic_fuel_consumption_rate,
                             swh_temp_sch,
                             set_peak_use_flowrate ,
                             peak_flowrate,
                             flowrate_schedule,
                             water_heater_thermal_zone,
                             number_water_heaters)
    # water heater volume in gallon
    water_heater_capacity_btu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'Btu/hr').get
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get

    # set service water heating loop control
    temp_sch_type_limits = model_add_schedule_type_limits(model,
                                                          name: 'Temperature Schedule Type Limits',
                                                          lower_limit_value: 0.0,
                                                          upper_limit_value: 100.0,
                                                          numeric_type: 'Continuous',
                                                          unit_type: 'Temperature')

    if swh_temp_sch.nil?
      # Service water heating loop controls
      swh_temp_c = service_water_temperature
      swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
      swh_delta_t_r = 9 # 9F delta-T
      swh_temp_c = OpenStudio.convert(swh_temp_f, 'F', 'C').get
      swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
      swh_temp_sch = model_add_constant_schedule_ruleset(model,
                                                         swh_temp_c,
                                                         name = "Service Water Loop Temp - #{swh_temp_f.round}F")
      swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    end

    # Water heater depends on the fuel type
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)

    # Assign a quantity to the water heater if it represents multiple water heaters
    if number_water_heaters > 1
      water_heater.setName("#{building_type_swh} - #{number_water_heaters}X #{(water_heater_vol_gal / number_water_heaters).round}gal #{water_heater_fuel} Water Heater - #{(water_heater_capacity_kbtu_per_hr / number_water_heaters).round}kBtu/hr")
      water_heater.additionalProperties.setFeature('component_quantity', number_water_heaters)
    else
      water_heater.setName("#{building_type_swh} - #{water_heater_vol_gal.round}gal #{water_heater_fuel} Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    end

    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)
    water_heater.setDeadbandTemperatureDifference(2.0)

    # set thermal zone info
    if water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F or 72F
      case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        indoor_temp = 71.6
      else
        indoor_temp = 70.0
      end
      default_water_heater_ambient_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                                  OpenStudio.convert(indoor_temp, 'F', 'C').get,
                                                                                  name = 'Water Heater Ambient Temp Schedule - ' + indoor_temp.to_s + 'f')
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
      water_heater.resetAmbientTemperatureThermalZone
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone(water_heater_thermal_zone)
      water_heater.resetAmbientTemperatureSchedule
    end

    # set parameters
    water_heater.setMaximumTemperatureLimit(service_water_temperature)
    water_heater.setDeadbandTemperatureDifference(OpenStudio.convert(3.6, 'R', 'K').get)
    water_heater.setHeaterControlType('Cycle')
    water_heater.setHeaterMaximumCapacity(OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'W').get)
    water_heater.setOffCycleParasiticHeatFractiontoTank(0.8)
    water_heater.setIndirectWaterHeatingRecoveryTime(1.5) # 1.5hrs
    if water_heater_fuel == 'Electricity'
      water_heater.setHeaterFuelType('Electricity')
      water_heater.setHeaterThermalEfficiency(1.0)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Electricity')
      water_heater.setOnCycleParasiticFuelType('Electricity')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053)
    elsif water_heater_fuel == 'Natural Gas' || water_heater_fuel == 'NaturalGas'
      water_heater.setHeaterFuelType('Gas')
      water_heater.setHeaterThermalEfficiency(0.78)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Gas')
      water_heater.setOnCycleParasiticFuelType('Gas')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "#{water_heater_fuel} is not a valid water heater fuel.  Valid choices are Electricity, NaturalGas, and HeatPump.")
    end

    if set_peak_use_flowrate
      rated_flow_rate_m3_per_s = peak_flowrate
      rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
      water_heater.setPeakUseFlowRate(rated_flow_rate_m3_per_s)

      schedule = model_add_schedule(model, flowrate_schedule)
      water_heater.setUseFlowRateFractionSchedule(schedule)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Added water heater called #{water_heater.name}")

    return water_heater

  end

  def model_add_swh_loop(model,
                         building_type_swh,
                         building_type_swh_hash,
                         service_water_temperature,
                         service_water_pump_head,
                         service_water_pump_motor_efficiency,
                         water_heater_capacity,
                         water_heater_volume)
    # Service water heating loop
    service_water_loop = OpenStudio::Model::PlantLoop.new(model)
    service_water_loop.setMinimumLoopTemperature(10.0)
    service_water_loop.setMaximumLoopTemperature(60.0)
    service_water_loop.setName('Service Water Loop - ' + building_type_swh)


    # Service water heating loop controls
    swh_temp_c = service_water_temperature
    swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
    # create swh temp schedule
    swh_temp_sch = model_add_constant_schedule_ruleset(model,
                                                       swh_temp_c,
                                                       name = "Service Water Loop Temp - #{swh_temp_f.round}F - " + building_type_swh)
    # create temperature schedule type limits
    temp_sch_type_limits = model_add_schedule_type_limits(model,
                                                          name: 'Temperature Schedule Type Limits - ' + building_type_swh,
                                                          lower_limit_value: 0.0,
                                                          upper_limit_value: 100.0,
                                                          numeric_type: 'Continuous',
                                                          unit_type: 'Temperature')
    swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)

    # create setpoint manager
    swh_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, swh_temp_sch)
    swh_stpt_manager.setName('Service hot water setpoint manager - ' + building_type_swh)
    swh_stpt_manager.addToNode(service_water_loop.supplyOutletNode)

    # sizing plant
    sizing_plant = service_water_loop.sizingPlant
    swh_delta_t_r = 9.0 # 9F delta-T
    swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(swh_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(swh_delta_t_k)

    # Determine if circulating or non-circulating based on supplied head pressure
    swh_pump_head_press_pa = service_water_pump_head
    circulating = true
    if swh_pump_head_press_pa.nil? || swh_pump_head_press_pa <= 1
      # As if there is no circulation pump
      swh_pump_head_press_pa = 0.001
      service_water_pump_motor_efficiency = 1
      circulating = false
    end

    # Service water heating pump
    if circulating
      swh_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      swh_pump.setName("#{service_water_loop.name} Circulator Pump")
      swh_pump.setPumpControlType('Intermittent')
    else
      swh_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      swh_pump.setName("#{service_water_loop.name} Water Mains Pressure Driven")
      swh_pump.setPumpControlType('Continuous')
    end
    swh_pump.setRatedPumpHead(swh_pump_head_press_pa.to_f)
    swh_pump.setMotorEfficiency(service_water_pump_motor_efficiency)
    swh_pump.addToNode(service_water_loop.supplyInletNode)

    # Get the fuel type data
    heater_prop = model_find_object(standards_data['prm_swh_bldg_type'], {'swh_building_type' => building_type_swh})
    new_fuel_data = heater_prop['baseline_heating_method']
    if new_fuel_data == "Gas Storage"
      water_heater_fuel = "NaturalGas"
    else
      water_heater_fuel = "Electricity"
    end

    water_heater = model_add_water_heater(model,
                                          building_type_swh,
                                          water_heater_capacity,
                                          water_heater_volume,
                                          water_heater_fuel,
                                          service_water_temperature,
                                          parasitic_fuel_consumption_rate = 0,
                                          swh_temp_sch,
                                          false,
                                          0.0,
                                          nil,
                                          water_heater_thermal_zone = nil,
                                          number_water_heaters = 1)

    service_water_loop.addSupplyBranchForComponent(water_heater)

    # create water use connections based on the space name and building area type
    building_type_swh_hash.keys.each do |key|
      # Water use connection
      swh_connection = OpenStudio::Model::WaterUseConnections.new(model)
      swh_connection.setName("#{building_type_swh} - #{key} - Water Use Connection")

      model.getWaterUseEquipments.each do |wateruse_equipment|
        if wateruse_equipment.name.get.to_s == key
          swh_connection.addWaterUseEquipment(wateruse_equipment)
        end
      end
      service_water_loop.addDemandBranchForComponent(swh_connection)
    end
  end
end