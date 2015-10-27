
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingWater

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoilHeatingWater", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    maximum_water_flow_rate = self.autosizedMaximumWaterFlowRate
    if maximum_water_flow_rate.is_initialized
      self.setMaximumWaterFlowRate(maximum_water_flow_rate.get) 
    end
    
    u_factor_times_area_value = self.autosizedUFactorTimesAreaValue
    if u_factor_times_area_value.is_initialized
      self.setUFactorTimesAreaValue(u_factor_times_area_value.get)
    end
    
    rated_capacity = self.autosizedRatedCapacity
    if rated_capacity.is_initialized
      self.setRatedCapacity(rated_capacity.get) 
    end
        
  end

  # returns the autosized maximum water flow rate as an optional double
  def autosizedMaximumWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Water Flow Rate', 'm3/s')
    
  end

  # returns the autosized u-factor times area value as an optional double
  def autosizedUFactorTimesAreaValue

    return self.model.getAutosizedValue(self, 'Design Size U-Factor Times Area Value', 'W/K')
    
  end  
  
 # returns the autosized rated capacity as an optional double
  def autosizedRatedCapacity

    return self.model.getAutosizedValue(self, 'Design Size Design Coil Load', 'W')
    
  end  
  
  
end
