
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::AirLoopHVAC

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeDesignSupplyAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    design_supply_air_flow_rate = self.autosizedDesignSupplyAirFlowRate
    if design_supply_air_flow_rate.is_initialized
      self.setDesignSupplyAirFlowRate(design_supply_air_flow_rate.get) 
    end
        
  end

  # returns the autosized design supply air flow rate as an optional double
  def autosizedDesignSupplyAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Supply Air Flow Rate', 'm3/s')
    
  end
  
  # Retrieves an airloop sum of air terminal minimum heating flow rates: sum(Vpz_min)
  def autosizeSumMinimumHeatingAirFlowRates
    result = OpenStudio::OptionalDouble.new
    name = self.name.get.upcase
    sql = self.model.sqlFile
    if sql.is_initialized
      sql = sql.get    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='ComponentSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='AirLoopHVAC'
              AND ColumnName='Sum of Air Terminal Minimum Heating Flow Rates'
              AND RowName='#{name}'
              AND Units='m3/s'"
      val = sql.execAndReturnFirstDouble(query)
      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result.to_f

  end

  # Retrieve an airloop's design outdoor air intake (Vot)
  # Ideally, this would only be used to retrieve Vot when 
  # calculated by EnergyPlus' built-in design VRP calculations
  def autosize621OutdoorAirIntakeFlow
    flow_types = ['Heating', 'Cooling']
    flow_rates = []
    flow_types.each do |flow_type|
      result = OpenStudio::OptionalDouble.new
      name = self.name.get.upcase
      sql = self.model.sqlFile
      if sql.is_initialized
        sql = sql.get    
        query = "SELECT Value 
                FROM tabulardatawithstrings
                WHERE ReportName='Standard62.1Summary' 
                AND ReportForString='Entire Facility' 
                AND TableName='System Ventilation Requirements for #{flow_type}'
                AND ColumnName='Outdoor Air Intake Flow Vot'
                AND RowName='#{name}'
                AND Units='m3/s'"
        val = sql.execAndReturnFirstDouble(query)
        if val.is_initialized
          result = OpenStudio::OptionalDouble.new(val.get)
        end
        # Inconsistency in column name in EnergyPlus 9.0: 
        # "Outdoor Air Intake Flow - Vot" vs "Outdoor Air Intake Flow Vot"
        # The following could be deleted if the inconsistency was ever fixed
        if result.to_f == 0.0
          query = "SELECT Value 
          FROM tabulardatawithstrings
          WHERE ReportName='Standard62.1Summary' 
          AND ReportForString='Entire Facility' 
          AND TableName='System Ventilation Requirements for #{flow_type}'
          AND ColumnName='Outdoor Air Intake Flow - Vot'
          AND RowName='#{name}'
          AND Units='m3/s'"
          val = sql.execAndReturnFirstDouble(query)
          if val.is_initialized
            result = OpenStudio::OptionalDouble.new(val.get)
          end
        end
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
      end
      flow_rates << result.to_f
    end

    return flow_rates.max

  end

  # Retrieve an airloop's sum of air terminal maximum flow rates: sum(Vpz)
  def autosizeSumAirTerminalMaxAirFlowRate
    result = OpenStudio::OptionalDouble.new
    name = self.name.get.upcase
    sql = self.model.sqlFile
    if sql.is_initialized
      sql = sql.get    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='ComponentSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='AirLoopHVAC'
              AND ColumnName='Sum of Air Terminal Maximum Flow Rates'
              AND RowName='#{name}'
              AND Units='m3/s'"
      val = sql.execAndReturnFirstDouble(query)
      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result.to_f

  end

end
