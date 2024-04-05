module OpenstudioStandards
  # The SqlFile module provides methods to get information from the EnergyPlus .sql file after a run
  module SqlFile
    # @!group Energy Use

    # Gets the model annual energy consumption by fuel and enduse in GJ from the sql file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param fuel_type [String] the fuel type, e.g. 'Electricity'
    # @param end_use [String] the end use, e.g. 'InteriorEquipment'
    # @return [Double] the model energy fuel type end use in Gigajoules
    def self.model_get_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
      # get model sql file
      sql_file = OpenstudioStandards::SqlFile.model_get_sql_file(model)

      # setup the queries
      query = "SELECT Value
              FROM TabularDataWithStrings
              WHERE ReportName='AnnualBuildingUtilityPerformanceSummary'
              AND ReportForString='Entire Facility'
              AND TableName='End Uses'
              AND RowName = '#{end_use}'
              AND ColumnName='#{fuel_type}'"

      # get the info
      energy_gj = sql_file.execAndReturnFirstDouble(query)

      # make sure all the data are available
      if energy_gj.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SqlFile', "Could not get energy for #{fuel_type} #{end_use}.")
        return 0.0
      end

      return energy_gj.get
    end

    # Gets the model design day energy consumption by fuel and enduse in J from the sql file
    # Uses the meter data dictionary instead of annual building utility performance summary
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param fuel_type [String] the fuel type, e.g. 'Electricity'
    # @param end_use [String] the end use, e.g. 'InteriorEquipment'
    # @return [Double] the model energy fuel type end use in Joules
    def self.model_get_dd_energy_by_fuel_and_enduse(model, fuel_type, end_use)
      # get model sql file
      sql_file = OpenstudioStandards::SqlFile.model_get_sql_file(model)

      # setup the end use index query
      get_rpt_mtr_data_dic_idx = "SELECT ReportMeterDataDictionaryIndex
                                  FROM ReportMeterDataDictionary
                                  WHERE VariableName='#{end_use}:#{fuel_type}'"

      # get the end use index
      idx = sql_file.execAndReturnFirstDouble(get_rpt_mtr_data_dic_idx)

      # if no index it means that the end use isn't used in the model
      if idx.empty?
        return 0.0
      end

      # setup the energy use retrieval queries for the design days
      get_energy_j = "SELECT SUM (VariableValue)
                      FROM ReportMeterData
                      WHERE ReportMeterDataDictionaryIndex='#{idx}'"

      # get the end use energy value
      energy_j = sql_file.execAndReturnFirstDouble(get_energy_j)

      # no energy value, means that something isn't right, set it to 0 as a safeguard
      if energy_j.empty?
        return 0.0
      end

      return energy_j.get
    end

    # Gets all annual energy consumption by enduse and fuel type from the sql file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Hash] a hash of results for each fuel, where the keys are in the form 'End Use|Fuel Type',
    # e.g. Heating|Electricity, Exterior Equipment|Water.  All end use/fuel type combos are present, with
    # values of 0.0 if none of this end use/fuel type combo was used by the simulation.
    # @todo update for fuel type changes
    def self.model_get_annual_results_by_end_use_and_fuel_type(model)
      energy_values = {}

      # List of all fuel types
      fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

      # List of all end uses
      end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection', 'Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

      # Get the value for each end use/ fuel type combination
      end_uses.each do |end_use|
        fuel_types.each do |fuel_type|
          energy_values["#{end_use}|#{fuel_type}"] = OpenstudioStandards::SqlFile.model_get_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
        end
      end

      return energy_values
    end

    # Gets all design day energy consumption by enduse and fuel type from the sql file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Hash] a hash of results for each fuel, where the keys are in the form 'EndUse|FuelType',
    #   # e.g. Heating|Electricity, ExteriorEquipment|Water.  All end use/fuel type combos are present, with
    #   # values of 0.0 if none of this end use/fuel type combo was used by the simulation.
    def self.model_get_dd_results_by_end_use_and_fuel_type(model)
      energy_values = {}

      # List of all fuel types, based on Table 5.1 of EnergyPlus' Input Output Reference manual
      if model.version < OpenStudio::VersionString.new('3.7.0')
        fuel_types = ['Electricity', 'Gas', 'Gasoline', 'Diesel', 'Coal', 'FuelOilNo1', 'FuelOilNo2', 'Propane', 'OtherFuel1', 'OtherFuel2', 'Water', 'Steam', 'DistrictCooling',
                      'DistrictHeating', 'ElectricityPurchased', 'ElectricitySurplusSold', 'ElectricityNet']
      else
        fuel_types = ['Electricity', 'Gas', 'Gasoline', 'Diesel', 'Coal', 'FuelOilNo1', 'FuelOilNo2', 'Propane', 'OtherFuel1', 'OtherFuel2', 'Water', 'DistrictCooling',
                      'DistrictHeatingWater', 'DistrictHeatingSteam', 'ElectricityPurchased', 'ElectricitySurplusSold', 'ElectricityNet']
      end

      # List of all end uses, based on Table 5.3 of EnergyPlus' Input Output Reference manual
      end_uses = ['InteriorLights', 'ExteriorLights', 'InteriorEquipment', 'ExteriorEquipment', 'Fans', 'Pumps', 'Heating', 'Cooling', 'HeatRejection', 'Humidifier',
                  'HeatRecovery', 'DHW', 'Cogeneration', 'Refrigeration', 'WaterSystems']

      # Get the value for each end use/ fuel type combination
      end_uses.each do |end_use|
        fuel_types.each do |fuel_type|
          energy_values["#{end_use}|#{fuel_type}"] = OpenstudioStandards::SqlFile.model_get_dd_energy_by_fuel_and_enduse(model, fuel_type, end_use)
        end
      end

      return energy_values
    end

    # Gets annual energy use intensity by fuel and end use in kBtu/ft^2 from the sql file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Double] a hash of annual energy use intensity by each fuel and end use in kBtu/ft^2, inclusive of all spaces
    def self.model_get_annual_eui_kbtu_per_ft2_by_fuel_and_enduse(model, fuel_type, end_use)
      energy_gj = OpenstudioStandards::SqlFile.model_get_annual_energy_by_fuel_and_enduse(model, fuel_type, end_use)
      energy_kbtu = OpenStudio.convert(energy_gj, 'GJ', 'kBtu').get
      floor_area_ft2 = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get
      eui_kbtu_per_ft2 = energy_kbtu / floor_area_ft2

      return eui_kbtu_per_ft2
    end

    # Gets the model total annual energy use intensity in kBtu/ft^2 from the sql file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Double] the model total annual site energy use intensity in kBtu/ft^2, inclusive of all spaces
    def self.model_get_annual_eui_kbtu_per_ft2(model)
      # get model sql file
      sql_file = OpenstudioStandards::SqlFile.model_get_sql_file(model)

      # make sure all required data are available
      if sql_file.totalSiteEnergy.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SqlFile', 'Site energy data unavailable.')
        return false
      end

      total_site_energy_kbtu = OpenStudio.convert(sql_file.totalSiteEnergy.get, 'GJ', 'kBtu').get
      floor_area_ft2 = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get
      site_eui_kbtu_per_ft2 = total_site_energy_kbtu / floor_area_ft2

      return site_eui_kbtu_per_ft2
    end

    # @!endgroup Energy Use
  end
end
