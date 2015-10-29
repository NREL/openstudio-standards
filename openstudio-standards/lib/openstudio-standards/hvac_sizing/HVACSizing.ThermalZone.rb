
# open the class to add methods to return sizing values
class OpenStudio::Model::ThermalZone

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeDesignOutdoorAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    # In OpenStudio, the design OA flow rates are calculated by the
    # Controller:OutdoorAir object associated with this system.
    # Therefore, this property will be retrieved from that object's sizing values
    air_loop = self.airLoopHVAC
    if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
      controller_oa = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir
      # get the max oa flow rate from the controller:outdoor air sizing
      maximum_outdoor_air_flow_rate = controller_oa.autosizedMaximumOutdoorAirFlowRate
      if maximum_outdoor_air_flow_rate.is_initialized
        self.setDesignOutdoorAirFlowRate(maximum_outdoor_air_flow_rate.get)
        # Set the OA flow method to "ZoneSum" to avoid severe errors
        # in the fully hard-sized model.
        self.setSystemOutdoorAirMethod("ZoneSum")
      end
    end
    
  end

  # returns the autosized maximum outdoor air flow rate as an optional double
  def autosizedMaximumOutdoorAirFlowRate

    return self.model.getAutosizedValue(self, 'Maximum Outdoor Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized minimum outdoor air flow rate as an optional double
  def autosizedMinimumOutdoorAirFlowRate

    return self.model.getAutosizedValue(self, 'Minimum Outdoor Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized cooling design air flow rate as an optional double
  def autosizedCoolingDesignAirFlowRate

    result = OpenStudio::OptionalDouble.new

    name = self.name.get.upcase

    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='HVACSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='Zone Cooling'
              AND ColumnName='User Design Air Flow'
              AND RowName='#{name}'
              AND Units='m3/s'"

      val = sql.execAndReturnFirstDouble(query)
      
      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        #OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "Data not found for query: #{query}")
      end

    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result

  end

  # returns the autosized heating design air flow rate as an optional double
  def autosizedHeatingDesignAirFlowRate

    result = OpenStudio::OptionalDouble.new

    name = self.name.get.upcase

    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='HVACSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='Zone Heating'
              AND ColumnName='User Design Air Flow'
              AND RowName='#{name}'
              AND Units='m3/s'"

      val = sql.execAndReturnFirstDouble(query)
      
      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        #OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "Data not found for query: #{query}")
      end

    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result

  end
  
end
