StandardsModel.class_eval do

  def sql_file

    # Ensure that the model has a sql file associated with it
    if self.sqlFile.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Failed to retrieve data because the sql file containing results is missing.')
      return false
    end

    return self.sqlFile.get
  end

  def annual_occupied_unmet_hours

    sql = self.sql_file

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
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet hours information.')
      return false
    end
    
    #aggregate heating and cooling hrs
    heating_or_cooling_setpoint_unmet = heating_setpoint_unmet.get + cooling_setpoint_unmet.get    
 
    return heating_or_cooling_setpoint_unmet
  end

  def annual_occupied_unmet_heating_hours

    sql = self.sql_file

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
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet heating hours information.')
      return false
    end

    return heating_setpoint_unmet.get
  end

  def annual_occupied_unmet_cooling_hours

    sql = self.sql_file

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
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get unmet cooling hours information.')
      return false
    end

    return cooling_setpoint_unmet.get
  end

  def annual_eui_kbtu_per_ft2

    sql = self.sql_file

    building = self.getBuilding
    
    # make sure all required data are available
    if sql.totalSiteEnergy.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Site energy data unavailable.')
      return false
    end
    
    total_site_energy_kBtu = OpenStudio::convert(sql.totalSiteEnergy.get, "GJ", "kBtu").get
  
    floor_area_ft2 = OpenStudio::convert(building.floorArea, "m^2", "ft^2").get
    
    site_eui_kbtu_per_ft2 = total_site_energy_kBtu / floor_area_ft2

    return site_eui_kbtu_per_ft2
  end

  def net_conditioned_floor_area

    sql = self.sql_file

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
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not get conditioned area information.')
      return false
    end

    return area_m2.get
  end

  def annual_energy_by_fuel_and_enduse(fuel_type, end_use)

    sql = self.sql_file

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
    
    # make sure all the data are availalbe
    if energy_gj.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not get energy for #{fuel_type} #{end_use}.")
      return 0.0
    end

    return energy_gj.get

  end

end
