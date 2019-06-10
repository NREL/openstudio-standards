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

  # Gets the annual occupied unmet hours from the sql file
  # @todo candidate for C++
  def model_annual_occupied_unmet_hours(model)
    sql = model_sql_file(model)

    # setup the queries
    heating_setpoint_unmet_query = "SELECT Value
                                    FROM TabularDataWithStrings
                                    WHERE ReportName='SystemSummary'
                                    AND ReportForString='Entire Facility'
                                    AND TableName='Time Setpoint Not Met'
                                    AND RowName = 'Facility'
                                    AND ColumnName='During Occupied Heating'"

    cooling_setpoint_unmet_query = "SELECT Value
                                    FROM TabularDataWithStrings
                                    WHERE ReportName='SystemSummary'
                                    AND ReportForString='Entire Facility'
                                    AND TableName='Time Setpoint Not Met'
                                    AND RowName = 'Facility'
                                    AND ColumnName='During Occupied Cooling'"

    # get the info
    heating_setpoint_unmet = sql.execAndReturnFirstDouble(heating_setpoint_unmet_query)
    cooling_setpoint_unmet = sql.execAndReturnFirstDouble(cooling_setpoint_unmet_query)

    # make sure all the data are availalbe
    if heating_setpoint_unmet.empty? || cooling_setpoint_unmet.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet hours information.')
      return false
    end

    # aggregate heating and cooling hrs
    heating_or_cooling_setpoint_unmet = heating_setpoint_unmet.get + cooling_setpoint_unmet.get

    return heating_or_cooling_setpoint_unmet
  end

  # Gets the annual occupied unmet heating hours from the sql file
  # @todo candidate for C++
  def model_annual_occupied_unmet_heating_hours(model)
    sql = model_sql_file(model)

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

    # make sure all the data are availalbe
    if heating_setpoint_unmet.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet heating hours information.')
      return false
    end

    return heating_setpoint_unmet.get
  end

  # Gets the annual occupied unmet cooling hours from the sql file
  # @todo candidate for C++
  def model_annual_occupied_unmet_cooling_hours(model)
    sql = model_sql_file(model)

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

    # make sure all the data are availalbe
    if cooling_setpoint_unmet.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet cooling hours information.')
      return false
    end

    return cooling_setpoint_unmet.get
  end

  # Gets the annual EUI from the sql file
  # @todo candidate for C++
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
  # @todo candidate for C++
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
  # @todo candidate for C++
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
    fuel_types = ['Electricity', 'Gas', 'Gasoline', 'Diesel', 'Coal', 'FuelOil#1', 'FuelOil#2', 'Propane', 'OtherFuel1', 'OtherFuel2', 'Water', 'Steam', 'DistrictCooling',
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

  def model_annual_eui_kbtu_per_ft2_by_fuel_and_enduse(model, fuel_type, end_use)

    energy_gj = model_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
    energy_kbtu = OpenStudio.convert(energy_gj, 'GJ', 'kBtu').get

    building = model.getBuilding

    floor_area_ft2 = OpenStudio.convert(building.floorArea, 'm^2', 'ft^2').get

    eui_kbtu_per_ft2 = energy_kbtu / floor_area_ft2

    return eui_kbtu_per_ft2
  end
end
