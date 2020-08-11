Standard.class_eval do

  # Gets the sql file for the model, erroring if not found
  # @todo candidate for C++
  def model_sql_file(model)
    # Ensure that the model has a sql file associated with it
    if model.sqlFile.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Failed to retrieve data because the sql file containing results is missing.')
      return false
    end

    return model.sqlFile.get
  end

  # Get the weather run period for the model
  #
  # @return [<OpenStudio::EnvironmentType>] the weather run period environment type
  def model_weather_run_period(model)
    sql = model_sql_file(model)
    unless sql
      return false
    end

    # get the weather file run period
    ann_env_pd = nil
    sql.availableEnvPeriods.each do |env_pd|
      env_type = sql.environmentType(env_pd)
      next unless env_type.is_initialized
      if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
        ann_env_pd = env_pd
      end
    end

    # make sure the annual run exists
    unless ann_env_pd
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Cannot find the annual simulation run period.')
      return false
    end

    return ann_env_pd
  end

  # Gets the annual occupied unmet heating hours from zone temperature time series in the sql file
  #
  # @param tolerance [Double] tolerance in degrees Rankine to log an unmet hour
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  # @return [Hash] Hash with 'sum' of heating unmet hours and 'zone_temperature_differences' of all zone unmet hours data
  # @todo account for operative temperature thermostats
  def model_annual_occupied_unmet_heating_hours_detailed(model, tolerance: 1.0, occupied_percentage_threshold: 0.05)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Calculating zone heating occupied unmet hours with #{tolerance} R tolerance.  This may take some time.")
    sql = model_sql_file(model)

    # convert tolerance to Kelvin
    tolerance_K = OpenStudio.convert(tolerance, 'R', 'K').get

    ann_env_pd = model_weather_run_period(model)
    unless ann_env_pd
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get annual run period.')
      return false
    end

    # for each zone calculate unmet hours and store in array
    bldg_unmet_hours = []
    bldg_occ_unmet_hours = []
    zone_data = []
    model.getThermalZones.each do |zone|
      # skip zones that aren't heated
      next unless thermal_zone_heated?(zone)

      # get zone air temperatures
      zone_temp_timeseries = sql.timeSeries(ann_env_pd, 'Hourly', 'Zone Air Temperature', zone.name.get)
      if zone_temp_timeseries.empty?
        # try mean air temperature instead
        zone_temp_timeseries = sql.timeSeries(ann_env_pd, 'Hourly', 'Zone Mean Air Temperature', zone.name.get)
        if zone_temp_timeseries.empty?
          # no air temperature found
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not find zone air temperature timeseries for zone '#{zone.name.get}'")
          return false
        end
      end

      # convert to ruby array
      zone_temperatures = []
      zone_temp_vector = zone_temp_timeseries.get.values
      for i in (0..zone_temp_vector.size - 1)
        zone_temperatures << zone_temp_vector[i]
      end

      # get zone thermostat heating setpoint temperatures
      zone_setpoint_temp_timeseries = sql.timeSeries(ann_env_pd, 'Hourly', 'Zone Thermostat Heating Setpoint Temperature', zone.name.get)
      if zone_setpoint_temp_timeseries.empty?
        # no setpoint temperature found
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not find heating setpoint temperature timeseries for zone '#{zone.name.get}'")
        return false
      end

      # convert to ruby array
      zone_setpoint_temperatures = []
      zone_setpoint_temp_vector = zone_setpoint_temp_timeseries.get.values
      for i in (0..zone_setpoint_temp_vector.size - 1)
        zone_setpoint_temperatures << zone_setpoint_temp_vector[i]
      end

      # calculate zone occupancy by making a new ruleset schedule
      occ_schedule_ruleset = std.thermal_zone_get_occupancy_schedule(zone)
      occ_values = std.schedule_ruleset_annual_hourly_values(occ_schedule_ruleset)

      # calculate difference accounting for unmet hours tolerance
      zone_temperature_diff = zone_setpoint_temperatures.map.with_index { |x, i| (zone_temperatures[i] - x) }
      zone_unmet_hours = zone_temperature_diff.map { |x| (x + tolerance_K) < 0 ? 1 : 0 }
      zone_occ_unmet_hours = []
      for i in (0..zone_unmet_hours.size - 1)
        bldg_unmet_hours[i] = 0 if bldg_unmet_hours[i].nil?
        bldg_occ_unmet_hours[i] = 0 if bldg_occ_unmet_hours[i].nil?
        bldg_unmet_hours[i] += zone_unmet_hours[i]
        if occ_values[i] >= occupied_percentage_threshold
          zone_occ_unmet_hours[i] = zone_unmet_hours[i]
          bldg_occ_unmet_hours[i] += zone_unmet_hours[i]
        else
          zone_occ_unmet_hours[i] = 0
        end
      end

      # log information for zone
      # could reduce the number of returned variables if this poses a storage or data transfer problem
      zone_data << { 'zone_name' => zone.name,
                     'zone_area' => zone.floorArea,
                     'zone_air_temperatures' => zone_temperatures.round(3),
                     'zone_air_setpoint_temperatures' => zone_setpoint_temperatures.round(3),
                     'zone_air_temperature_differences' => zone_temperature_diff.round(3),
                     'zone_occupancy' => occ_values.map { |x| x.round(3) },
                     'zone_unmet_hours' => zone_unmet_hours,
                     'zone_occupied_unmet_hours' => zone_occ_unmet_hours,
                     'sum_zone_unmet_hours' => zone_unmet_hours.count { |x| x > 0 },
                     'sum_zone_occupied_unmet_hours' => zone_occ_unmet_hours.count { |x| x > 0 } }
    end

    occupied_unmet_heating_hours_detailed = { 'sum_bldg_unmet_hours' => bldg_unmet_hours.count { |x| x > 0 },
                                              'sum_bldg_occupied_unmet_hours' => bldg_occ_unmet_hours.count { |x| x > 0 },
                                              'bldg_unmet_hours' => bldg_unmet_hours,
                                              'bldg_occupied_unmet_hours' => bldg_occ_unmet_hours,
                                              'zone_data' => zone_data }
    return occupied_unmet_heating_hours_detailed
  end

  # Gets the annual occupied unmet cooling hours from zone temperature time series in the sql file
  #
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  # @param tolerance [Double] tolerance in degrees Rankine to log an unmet hour
  # @return [Hash] Hash with 'sum' of cooling unmet hours and 'zone_temperature_differences' of all zone unmet hours data
  # @todo account for operative temperature thermostats
  def model_annual_occupied_unmet_cooling_hours_detailed(model, tolerance: 1.0, occupied_percentage_threshold: 0.05)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Calculating zone cooling occupied unmet hours with #{tolerance} R tolerance. This may take some time.")
    sql = model_sql_file(model)

    # convert tolerance to Kelvin
    tolerance_K = OpenStudio.convert(tolerance, 'R', 'K').get

    ann_env_pd = model_weather_run_period(model)
    unless ann_env_pd
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get annual run period.')
      return false
    end

    # for each zone calculate unmet hours and store in array
    bldg_unmet_hours = []
    bldg_occ_unmet_hours = []
    zone_data = []
    model.getThermalZones.each do |zone|
      # skip zones that aren't cooled
      next unless thermal_zone_cooled?(zone)

      # get zone air temperatures
      zone_temp_timeseries = sql.timeSeries(ann_env_pd, 'Hourly', 'Zone Air Temperature', zone.name.get)
      if zone_temp_timeseries.empty?
        # try mean air temperature instead
        zone_temp_timeseries = sql.timeSeries(ann_env_pd, 'Hourly', 'Zone Mean Air Temperature', zone.name.get)
        if zone_temp_timeseries.empty?
          # no air temperature found
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not find zone air temperature timeseries for zone '#{zone.name.get}'")
          return false
        end
      end

      # convert to ruby array
      zone_temperatures = []
      zone_temp_vector = zone_temp_timeseries.get.values
      for i in (0..zone_temp_vector.size - 1)
        zone_temperatures << zone_temp_vector[i]
      end

      # get zone thermostat heating setpoint temperatures
      zone_setpoint_temp_timeseries = sql.timeSeries(ann_env_pd, 'Hourly', 'Zone Thermostat Cooling Setpoint Temperature', zone.name.get)
      if zone_setpoint_temp_timeseries.empty?
        # no setpoint temperature found
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not find cooling setpoint temperature timeseries for zone '#{zone.name.get}'")
        return false
      end

      # convert to ruby array
      zone_setpoint_temperatures = []
      zone_setpoint_temp_vector = zone_setpoint_temp_timeseries.get.values
      for i in (0..zone_setpoint_temp_vector.size - 1)
        zone_setpoint_temperatures << zone_setpoint_temp_vector[i]
      end

      # calculate zone occupancy by making a new ruleset schedule
      occ_schedule_ruleset = std.thermal_zone_get_occupancy_schedule(zone)
      occ_values = std.schedule_ruleset_annual_hourly_values(occ_schedule_ruleset)

      # calculate difference accounting for unmet hours tolerance
      zone_temperature_diff = zone_setpoint_temperatures.map.with_index { |x, i| (x - zone_temperatures[i]) }
      zone_unmet_hours = zone_temperature_diff.map { |x| (x - tolerance_K) > 0 ? 1 : 0 }
      zone_occ_unmet_hours = []
      for i in (0..zone_unmet_hours.size - 1)
        bldg_unmet_hours[i] = 0 if bldg_unmet_hours[i].nil?
        bldg_occ_unmet_hours[i] = 0 if bldg_occ_unmet_hours[i].nil?
        bldg_unmet_hours[i] += zone_unmet_hours[i]
        if occ_values[i] >= occupied_percentage_threshold
          zone_occ_unmet_hours[i] = zone_unmet_hours[i]
          bldg_occ_unmet_hours[i] += zone_unmet_hours[i]
        else
          zone_occ_unmet_hours[i] = 0
        end
      end

      # log information for zone
      # could reduce the number of returned variables if this poses a storage or data transfer problem
      zone_data << { 'zone_name' => zone.name,
                     'zone_area' => zone.floorArea,
                     'zone_air_temperatures' => zone_temperatures.round(3),
                     'zone_air_setpoint_temperatures' => zone_setpoint_temperatures.round(3),
                     'zone_air_temperature_differences' => zone_temperature_diff.round(3),
                     'zone_occupancy' => occ_values.map { |x| x.round(3) },
                     'zone_unmet_hours' => zone_unmet_hours,
                     'zone_occupied_unmet_hours' => zone_occ_unmet_hours,
                     'sum_zone_unmet_hours' => zone_unmet_hours.count { |x| x > 0 },
                     'sum_zone_occupied_unmet_hours' => zone_occ_unmet_hours.count { |x| x > 0 } }
    end

    occupied_unmet_cooling_hours_detailed = { 'sum_bldg_unmet_hours' => bldg_unmet_hours.count { |x| x > 0 },
                                              'sum_bldg_occupied_unmet_hours' => bldg_occ_unmet_hours.count { |x| x > 0 },
                                              'bldg_unmet_hours' => bldg_unmet_hours,
                                              'bldg_occupied_unmet_hours' => bldg_occ_unmet_hours,
                                              'zone_data' => zone_data }
    return occupied_unmet_cooling_hours_detailed
  end

  # Gets the annual occupied unmet heating hours from the sql file
  #
  # @param tolerance [Double] tolerance in degrees Rankine to log an unmet hour
  #   If this is unspecified, the tolerance will be the tolerance specified in OutputControl:ReportingTolerances.
  #   If there isn't an OutputControl:ReportingTolerances object, the EnergyPlus default is 0.2 degrees Kelvin.
  #   If a tolerance is defined and does not match the tolerance defined in OutputControl:ReportingTolerances,
  #   this method will compare the zone temperature and setpoint temperature timeseries for each zone.
  #   Generally, it is much faster to define tolerances with the OutputControl:ReportingTolerances object.
  # @return [Double] heating unmet hours
  def model_annual_occupied_unmet_heating_hours(model, tolerance: nil)
    sql = model_sql_file(model)

    reporting_tolerances = model.getOutputControlReportingTolerances
    model_tolerance = reporting_tolerances.toleranceforTimeHeatingSetpointNotMet
    model_tolerance_R = OpenStudio.convert(model_tolerance, 'K', 'R')

    use_detailed = false
    unless tolerance.nil?
      # check to see if input argument tolerance matches model tolerance
      tolerance_K = OpenStudio.convert(tolerance, 'R', 'K').get
      unless (model_tolerance - tolerance_K).abs < 1e-3
        # input argument tolerance does not match model tolerance; need to recalculate unmet hours
        use_detailed = true
      end
    end

    if use_detailed
      # calculate unmet hours for each zone using zone time series
      zones_unmet_hours = model_annual_occupied_unmet_heating_hours_detailed(model, tolerance)
      heating_unmet_hours = zones_unmet_hours['sum_bldg_occupied_unmet_hours']
    else
      # use default EnergyPlus unmet hours reporting
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Calculating heating unmet hours with #{model_tolerance_R} R tolerance")

      # setup the queries
      heating_setpoint_unmet_query = "SELECT Value
                                    FROM TabularDataWithStrings
                                    WHERE ReportName='SystemSummary'
                                    AND ReportForString='Entire Facility'
                                    AND TableName='Time Setpoint Not Met'
                                    AND RowName = 'Facility'
                                    AND ColumnName='During Occupied Heating'"
      # get the info
      heating_setpoint_unmet = sql.execAndReturnFirstDouble(heating_setpoint_unmet_query)

      # make sure all the data are available
      if heating_setpoint_unmet.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet heating hours information.')
        return false
      end

      heating_unmet_hours = heating_setpoint_unmet.get
    end

    return heating_unmet_hours
  end

  # Gets the annual occupied unmet cooling hours from the sql file
  #
  # @param tolerance [Double] tolerance in degrees Rankine to log an unmet hour
  #   If this is unspecified, the tolerance will be the tolerance specified in OutputControl:ReportingTolerances.
  #   If there isn't an OutputControl:ReportingTolerances object, the EnergyPlus default is 0.2 degrees Kelvin.
  #   If a tolerance is defined and does not match the tolerance defined in OutputControl:ReportingTolerances,
  #   this method will compare the zone temperature and setpoint temperature timeseries for each zone.
  #   Generally, it is much faster to define tolerances with the OutputControl:ReportingTolerances object.
  # @return [Double] heating unmet hours
  def model_annual_occupied_unmet_cooling_hours(model, tolerance: nil)
    sql = model_sql_file(model)

    reporting_tolerances = model.getOutputControlReportingTolerances
    model_tolerance = reporting_tolerances.toleranceforTimeHeatingSetpointNotMet
    model_tolerance_R = OpenStudio.convert(model_tolerance, 'K', 'R')

    use_detailed = false
    unless tolerance.nil?
      # check to see if input argument tolerance matches model tolerance
      tolerance_K = OpenStudio.convert(tolerance, 'R', 'K').get
      unless (model_tolerance - tolerance_K).abs < 1e-3
        # input argument tolerance does not match model tolerance; need to recalculate unmet hours
        use_detailed = true
      end
    end

    if use_detailed
      # calculate unmet hours for each zone using zone time series
      zones_unmet_hours = model_annual_occupied_unmet_cooling_hours_detailed(model, tolerance)
      cooling_unmet_hours = zones_unmet_hours['sum_bldg_occupied_unmet_hours']
    else
      # use default EnergyPlus unmet hours reporting
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Calculating cooling unmet hours with #{model_tolerance_R} R tolerance")

      # setup the queries
      cooling_setpoint_unmet_query = "SELECT Value
                                    FROM TabularDataWithStrings
                                    WHERE ReportName='SystemSummary'
                                    AND ReportForString='Entire Facility'
                                    AND TableName='Time Setpoint Not Met'
                                    AND RowName = 'Facility'
                                    AND ColumnName='During Occupied Cooling'"
      # get the info
      cooling_setpoint_unmet = sql.execAndReturnFirstDouble(cooling_setpoint_unmet_query)

      # make sure all the data are available
      if cooling_setpoint_unmet.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet cooling hours information.')
        return false
      end

      cooling_unmet_hours = cooling_setpoint_unmet.get
    end

    return cooling_unmet_hours
  end

  # Gets the annual occupied unmet hours from the sql file
  def model_annual_occupied_unmet_hours(model)

    heating_setpoint_unmet = model_annual_occupied_unmet_heating_hours(model)
    cooling_setpoint_unmet = model_annual_occupied_unmet_cooling_hours(model)

    # aggregate heating and cooling hrs
    heating_or_cooling_setpoint_unmet = heating_setpoint_unmet + cooling_setpoint_unmet

    return heating_or_cooling_setpoint_unmet
  end

  # Gets the annual EUI from the sql file
  def model_annual_eui_kbtu_per_ft2(model)
    sql = model_sql_file(model)

    building = model.getBuilding

    # make sure all required data are available
    if sql.totalSiteEnergy.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Site energy data unavailable.')
      return false
    end

    total_site_energy_kbtu = OpenStudio.convert(sql.totalSiteEnergy.get, 'GJ', 'kBtu').get

    floor_area_ft2 = OpenStudio.convert(building.floorArea, 'm^2', 'ft^2').get

    site_eui_kbtu_per_ft2 = total_site_energy_kbtu / floor_area_ft2

    return site_eui_kbtu_per_ft2
  end

  # Gets the net conditioned area from the sql file
  def model_net_conditioned_floor_area(model)
    sql = model_sql_file(model)

    # setup the queries
    area_query = "SELECT Value
                  FROM TabularDataWithStrings
                  WHERE ReportName='AnnualBuildingUtilityPerformanceSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Building Area'
                  AND RowName = 'Net Conditioned Building Area'
                  AND ColumnName='Area'"

    # get the info
    area_m2 = sql.execAndReturnFirstDouble(area_query)

    # make sure all the data are availalbe
    if area_m2.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get conditioned area information.')
      return false
    end

    return area_m2.get
  end

  # Gets the annual energy consumption by fuel and enduse from the sql file
  def model_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
    sql = model_sql_file(model)

    # setup the queries
    query = "SELECT Value
             FROM TabularDataWithStrings
             WHERE ReportName='AnnualBuildingUtilityPerformanceSummary'
             AND ReportForString='Entire Facility'
             AND TableName='End Uses'
             AND RowName = '#{end_use}'
             AND ColumnName='#{fuel_type}'"

    # get the info
    energy_gj = sql.execAndReturnFirstDouble(query)

    # make sure all the data are available
    if energy_gj.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not get energy for #{fuel_type} #{end_use}.")
      return 0.0
    end

    return energy_gj.get
  end

  def model_dd_energy_by_fuel_by_enduse(model, fuel_type, end_use)
    sql = model_sql_file(model)

    # setup the end use index query
    get_rpt_mtr_data_dic_idx = "SELECT ReportMeterDataDictionaryIndex
                                FROM ReportMeterDataDictionary
                                WHERE VariableName='#{end_use}:#{fuel_type}'"

    # get the end use index
    idx = sql.execAndReturnFirstDouble(get_rpt_mtr_data_dic_idx)

    # if no index it means that the end use isn't used in the model
    if idx.empty?
      return 0.0
    end

    # setup the energy use retrieval queries for the design days
    get_energy_j = "SELECT SUM (VariableValue)
                    FROM ReportMeterData
                    WHERE ReportMeterDataDictionaryIndex='#{idx}'"

    # get the end use energy value
    energy_j = sql.execAndReturnFirstDouble(get_energy_j)

    # no energy value, means that something isn't right, set it to 0 as a safeguard
    if energy_j.empty?
      return 0.0
    end

    return energy_j.get
  end

  # Gets all annual energy consumption by enduse and fuel type from the sql file
  #
  # @return [Hash] a hash of results for each fuel, where the keys are in the form 'End Use|Fuel Type',
  # e.g. Heating|Electricity, Exterior Equipment|Water.  All end use/fuel type combos are present, with
  # values of 0.0 if none of this end use/fuel type combo was used by the simulation.
  def model_results_by_end_use_and_fuel_type(model)
    energy_values = {}

    # List of all fuel types
    fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

    # List of all end uses
    end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection','Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

    # Get the value for each end use/ fuel type combination
    end_uses.each do |end_use|
      fuel_types.each do |fuel_type|
        energy_values["#{end_use}|#{fuel_type}"] = model_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
      end
    end

    return energy_values
  end
  
  def model_dd_results_by_end_use_and_fuel_type(model)
    energy_values = {}

    # List of all fuel types, based on Table 5.1 of EnergyPlus' Input Output Reference manual
    fuel_types = ['Electricity', 'Gas', 'Gasoline', 'Diesel', 'Coal', 'FuelOilNo1', 'FuelOilNo2', 'Propane', 'OtherFuel1', 'OtherFuel2', 'Water', 'Steam', 'DistrictCooling',
    'DistrictHeating', 'ElectricityPurchased', 'ElectricitySurplusSold', 'ElectricityNet']

    # List of all end uses, based on Table 5.3 of EnergyPlus' Input Output Reference manual
    end_uses = ['InteriorLights', 'ExteriorLights', 'InteriorEquipment', 'ExteriorEquipment', 'Fans', 'Pumps', 'Heating', 'Cooling', 'HeatRejection', 'Humidifier', 
    'HeatRecovery', 'DHW', 'Cogeneration', 'Refrigeration', 'WaterSystems']

    # Get the value for each end use/ fuel type combination
    end_uses.each do |end_use|
      fuel_types.each do |fuel_type|
        energy_values["#{end_use}|#{fuel_type}"] = model_dd_energy_by_fuel_by_enduse(model, fuel_type, end_use)
      end
    end

    return energy_values
  end

  # Gets annual eui by fuel and end use from the sql file
  def model_annual_eui_kbtu_per_ft2_by_fuel_and_enduse(model, fuel_type, end_use)

    energy_gj = model_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
    energy_kbtu = OpenStudio.convert(energy_gj, 'GJ', 'kBtu').get

    building = model.getBuilding

    floor_area_ft2 = OpenStudio.convert(building.floorArea, 'm^2', 'ft^2').get

    eui_kbtu_per_ft2 = energy_kbtu / floor_area_ft2

    return eui_kbtu_per_ft2
  end
end
