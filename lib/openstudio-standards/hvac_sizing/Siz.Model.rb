
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  # Ensure that the version of OpenStudio is 2.4.1 or greater
  # because this is when the .autosizedFoo methods were added to C++.
  min_os_version = "2.4.1"
  if OpenStudio::Model::Model.new.version < OpenStudio::VersionString.new(min_os_version)
    OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "This measure requires a minimum OpenStudio version of #{min_os_version} because this is when the .autosizedFoo methods were added to C++.")
  end

  # Load the helper libraries for getting additional autosized
  # values that aren't included in the C++ API.
  require_relative 'Siz.AirLoopHVAC'
  require_relative 'Siz.CoilCoolingWater'
  require_relative 'Siz.ThermalZone'

  # Heating and cooling fuel methods
  require_relative 'Siz.HeatingCoolingFuels'

  # Component quantity methods
  require_relative 'Siz.HVACComponent'

  # A helper method to get component sizes from the Equipment Summary of the TabularDataWithStrings Report
  # returns the autosized value as an optional double
  def getAutosizedValueFromEquipmentSummary(object, table_name, value_name, units)

    result = OpenStudio::OptionalDouble.new

    name = object.name.get.upcase

    sql = self.sqlFile

    if sql.is_initialized
      sql = sql.get

      #SELECT * FROM ComponentSizes WHERE CompType = 'Coil:Heating:Gas' AND CompName = "COIL HEATING GAS 3" AND Description = "Design Size Nominal Capacity"
      query = "Select Value FROM TabularDataWithStrings WHERE
      ReportName = 'EquipmentSummary' AND
      TableName = '#{table_name}' AND
      RowName = '#{name}' AND
      ColumnName = '#{value_name}' AND
      Units = '#{units}'"

      val = sql.execAndReturnFirstDouble(query)

      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        # @todo comment following line (debugging new HVACsizing objects right now)
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "QUERY ERROR: Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end


  # Helper function to output the fan power for each fan in the model
  # @param [String] csv_path: if given, will output a csv file
  # @return [Array of Hash] each row is a fan, with its name, type, rated watts per cfm, and the airloop or hvac component or zonehvac component it serves
  # @todo output actual bhp and allowable bhp for systems 3-4 and 5-8
  # @todo remove maybe later?
  def output_fan_report(csv_path = nil)

    table = []

    # Deal with all the constant volume fans
    self.getFanConstantVolumes.each do |fan|
      row = {:name=>fan.name.to_s, :type=>'Constant Volume', :rated_w_per_cfm=>fan.rated_w_per_cfm.round(2), :air_loop=>'', :hvac_component=>'', :zone_hvac_component=>''}
      if fan.airLoopHVAC.is_initialized
        row[:air_loop] = fan.airLoopHVAC.get.name.to_s
      elsif fan.containingHVACComponent.is_initialized
        row[:hvac_component] = fan.containingHVACComponent.get.name.to_s
      elsif fan.containingZoneHVACComponent.is_initialized
        row[:zone_hvac_component] = fan.containingZoneHVACComponent.get.name.to_s
      end
      # Add to table
      table << row
    end

    # Deal with all the constant volume fans
    self.getFanVariableVolumes.each do |fan|
      row = {:name=>fan.name.to_s, :type=>'Variable Volume', :rated_w_per_cfm=>fan.rated_w_per_cfm.round(2), :air_loop=>'', :hvac_component=>'', :zone_hvac_component=>''}
      if fan.airLoopHVAC.is_initialized
        row[:air_loop] = fan.airLoopHVAC.get.name.to_s
      elsif fan.containingHVACComponent.is_initialized
        row[:hvac_component] = fan.containingHVACComponent.get.name.to_s
      elsif fan.containingZoneHVACComponent.is_initialized
        row[:zone_hvac_component] = fan.containingZoneHVACComponent.get.name.to_s
      end
      # Add to table
      table << row
    end

    # Deal with all the constant volume fans
    self.getFanOnOffs.each do |fan|
      row = {:name=>fan.name.to_s, :type=>'On Off', :rated_w_per_cfm=>fan.rated_w_per_cfm.round(2), :air_loop=>'', :hvac_component=>'', :zone_hvac_component=>''}
      if fan.airLoopHVAC.is_initialized
        row[:air_loop] = fan.airLoopHVAC.get.name.to_s
      elsif fan.containingHVACComponent.is_initialized
        row[:hvac_component] = fan.containingHVACComponent.get.name.to_s
      elsif fan.containingZoneHVACComponent.is_initialized
        row[:zone_hvac_component] = fan.containingZoneHVACComponent.get.name.to_s
      end
      # Add to table
      table << row
    end

    # If a csv path is given, output
    if !csv_path.nil? && !table.first.nil?
      CSV.open(csv_path, "wb") do |csv|
        csv << table.first.keys # adds the attributes name on the first line
        table.each do |hash|
          csv << hash.values
        end
      end
    end

    return table

  end

end
