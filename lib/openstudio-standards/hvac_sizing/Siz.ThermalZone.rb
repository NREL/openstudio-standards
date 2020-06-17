
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
    
      # In E+ 8.4, (OS 1.9.3 onward) the table name changed
      table_name = nil
      if self.model.version < OpenStudio::VersionString.new('1.9.3')
        table_name = 'Zone Cooling'
      else
        table_name = 'Zone Sensible Cooling'
      end  
    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='HVACSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='#{table_name}'
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
    
      # In E+ 8.4, (OS 1.9.3 onward) the table name changed
      table_name = nil
      if self.model.version < OpenStudio::VersionString.new('1.9.3')
        table_name = 'Zone Heating'
      else
        table_name = 'Zone Sensible Heating'
      end    
    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='HVACSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='#{table_name}'
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

  # returns the calculated cooling design load as an optional double
  def coolingDesignLoad
  
    result = OpenStudio::OptionalDouble.new

    name = self.name.get.upcase

    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      # In E+ 8.4, (OS 1.9.3 onward) the table name changed
      table_name = nil
      if self.model.version < OpenStudio::VersionString.new('1.9.3')
        table_name = 'Zone Cooling'
      else
        table_name = 'Zone Sensible Cooling'
      end    
    
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='HVACSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='#{table_name}'
              AND ColumnName='User Design Load'
              AND RowName='#{name}'
              AND Units='W'"

      val = sql.execAndReturnFirstDouble(query)
      
      if val.is_initialized
        floor_area_no_multiplier_m2 = self.floorArea
        floor_area_m2 = floor_area_no_multiplier_m2 * self.multiplier
        w_per_m2 = val.get/floor_area_m2
        result = OpenStudio::OptionalDouble.new(w_per_m2)
      else
        #OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "Data not found for query: #{query}")
      end

    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result  
  
  end
  
  # returns the calculated heating design load as an optional double
  def heatingDesignLoad
  
    result = OpenStudio::OptionalDouble.new

    name = self.name.get.upcase

    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
      
      # In E+ 8.4, (OS 1.9.3 onward) the table name changed
      table_name = nil
      if self.model.version < OpenStudio::VersionString.new('1.9.3')
        table_name = 'Zone Heating'
      else
        table_name = 'Zone Sensible Heating'
      end
      
      query = "SELECT Value 
              FROM tabulardatawithstrings
              WHERE ReportName='HVACSizingSummary' 
              AND ReportForString='Entire Facility' 
              AND TableName='#{table_name}'
              AND ColumnName='User Design Load'
              AND RowName='#{name}'
              AND Units='W'"

      val = sql.execAndReturnFirstDouble(query)
      
      if val.is_initialized
        floor_area_no_multiplier_m2 = self.floorArea
        floor_area_m2 = floor_area_no_multiplier_m2 * self.multiplier
        w_per_m2 = val.get/floor_area_m2
        result = OpenStudio::OptionalDouble.new(w_per_m2)
      else
        #OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "Data not found for query: #{query}")
      end

    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result  
  
  end

  # Determine the zone heating fuels, including
  # any fuels used by zone equipment, reheat terminals,
  # the air loops serving the zone, and any plant loops
  # serving those air loops.
  #
  # return [Array<String>] An array. Possible values are 
  # Electricity, NaturalGas, PropaneGas, FuelOilNo1, FuelOilNo2,
  # Coal, Diesel, Gasoline, DistrictCooling, DistrictHeating, 
  # and SolarEnergy.
  def heating_fuels
  
    fuels = []
    
    # Special logic for models imported from Sefaira.
    # In this case, the fuels are listed as a comment
    # above the Zone object.
    if !self.comment == ''
      m = self.comment.match /! *(.*)/
      if m
        all_fuels = m[1].split(',')
        all_fuels.each do |fuel|
          fuels += fuel.strip
        end
      end
      if fuels.size > 0
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{self.name}, fuel type #{fuels.join(', ')} pulled from Zone comment.")
        fuels.uniq.sort
      end
    end
    
    # Check the zone hvac heating fuels
    fuels += self.model.zone_equipment_heating_fuels(self)

    # Check the zone airloop heating fuels
    fuels += self.model.zone_airloop_heating_fuels(self)

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.model.Model', "For #{name}, heating fuels = #{fuels.uniq.sort.join(', ')}.")

    return fuels.uniq.sort
    
  end
 
  # Determine the zone cooling fuels, including
  # any fuels used by zone equipment, reheat terminals,
  # the air loops serving the zone, and any plant loops
  # serving those air loops.
  #
  # return [Array<String>] An array. Possible values are
  # Electricity, NaturalGas, PropaneGas, FuelOilNo1, FuelOilNo2,
  # Coal, Diesel, Gasoline, DistrictCooling, DistrictHeating, 
  # and SolarEnergy.
  def cooling_fuels
  
    fuels = []
    
    # Check the zone hvac cooling fuels
    fuels += self.model.zone_equipment_cooling_fuels(self)

    # Check the zone airloop cooling fuels
    fuels += self.model.zone_airloop_cooling_fuels(self)

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.model.Model', "For #{name}, cooling fuels = #{fuels.uniq.sort.join(', ')}.")

    return fuels.uniq.sort
    
  end  
  
end
