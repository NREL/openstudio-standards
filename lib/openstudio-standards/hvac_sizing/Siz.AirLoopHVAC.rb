
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::AirLoopHVAC

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
