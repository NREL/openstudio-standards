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

  # Determines the skylight to roof ratio limit for a given standard
  # 3% for 90.1-PRM-2019
  # @return [Double] the skylight to roof ratio, as a percent: 5.0 = 5%
  def model_prm_skylight_to_roof_ratio_limit(model)
    srr_lim = 3.0
    return srr_lim
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

  # Modify the existing service water heating loops to match the baseline required heating type.
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type (For consistency with the standard class, not used in the method)
  # @param swh_building_type [String] the swh building are type
  # @return [Boolean] returns true if successful, false if not

  def model_apply_baseline_swh_loops(model,
                                     building_type,
                                     swh_building_type = 'All others')
    # Get the original water heater information
    original_water_heater_info_hash = {}
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      original_water_heater_info_hash = {water_heater.name.get.to_s => model_get_object_hash(water_heater)}
    end

    # Get the building area type from the additional properties of wateruse_equipment
    wateruse_equipment_hash = {}
    model.getWaterUseEquipments.each do |wateruse_equipment|
      wateruse_equipment_hash[wateruse_equipment.name.get.to_s] = get_additional_property_as_string(wateruse_equipment, 'building_type_swh')
    end

    building_type_list = []
    # If there is additional properties, get the uniq building area type numbers.
    if wateruse_equipment_hash
      wateruse_equipment_hash.each do |name, sub_hash|
        sub_hash.each do|key, value|
          building_type_list << value
        end
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "No water use equipments are found in the model. Cannot apply baseline swh loops.")
    end
    if building_type_list
      building_area_type_number = building_type_list.uniq.size
    else
      building_area_type_number = 1
    end


    # Apply baseline swh loops
    if building_area_type_number == 1
      # One building area type
      # Modify the service water heater
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      model_apply_water_heater_prm_parameter(water_heater,
                                             swh_building_type)
    end
    else
    # Todo: service water heater with multiple building area type
    # Assume only one water heater in the model
    water_heaters = []
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      water_heaters.push(water_heater)
    end
    water_heater_thermal_zone = water_heaters[0].ambientTemperatureThermalZone.get
    service_water_temperature = water_heaters[0].maximumTemperatureLimit.get
    water_heater_capacity = water_heaters[0].heaterMaximumCapacity.get
    water_heater_volume = water_heaters[0].tankVolume.get
    parasitic_fuel_consumption_rate = water_heaters[0].offCycleParasiticFuelConsumptionRate

    model.getWaterUseEquipments.each do |wateruse_equipment|
      wateruse_equipment_def = wateruse_equipment.waterUseEquipmentDefinition
      wateruse_target_temp_schedule = wateruse_equipment_def.targetTemperatureSchedule.get.to_ScheduleRuleset.get.defaultDaySchedule()
      wateruse_temperature_array = []
      wateruse_target_temp_schedule.times().each do |time|
        wateruse_temperature_array << wateruse_target_temp_schedule.getValue(time)
      end
      wateruse_equipment_hash[wateruse_equipment.name.get.to_s] = {peak_flowrate: wateruse_equipment_def.peakFlowRate,
                                                                   flowrate_schedule: wateruse_equipment.flowRateFractionSchedule.get,
                                                                   water_use_temperature: wateruse_temperature_array.max}
    end

    # 1. Remove current swh loop
    # model.getPlantLoops.sort.each do |loop|
    #   # Don't remove loops except service water heating loops
    #   next unless plant_loop_swh_loop?(loop)
    #   loop.remove
    # end
    # 2. Create new swh loops based on building area type
    # building_type_swh_unique = wateruse_equipment_hash.values.uniq

    # building_type_swh_unique.each do |building_type_swh|
    #   system_name = 'Service Water Loop ' + building_type_swh
    #   # todo: Hard coded now, implement in the future, may have multiple pumps in a building
    #   service_water_pump_head = 29891
    #   service_water_pump_motor_efficiency = 0.7
    #   water_heater_fuel = water_heater_mixed_apply_prm_baseline_fuel_type(building_type_swh)
    #   model_add_swh_loop(model,
    #          system_name,
    #          water_heater_thermal_zone,
    #          service_water_temperature,
    #          service_water_pump_head,
    #          service_water_pump_motor_efficiency,
    #          water_heater_capacity,
    #          water_heater_volume,
    #          water_heater_fuel,
    #          parasitic_fuel_consumption_rate,
    #          add_pipe_losses = false,
    #          floor_area_served = 465,
    #          number_of_stories = 1,
    #          pipe_insulation_thickness = 0.0127, # 1/2in
    #          number_water_heaters = 1)
    # end
    end
    return true
  end
end

