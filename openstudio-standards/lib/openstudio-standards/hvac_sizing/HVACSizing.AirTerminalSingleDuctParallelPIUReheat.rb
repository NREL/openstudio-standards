
# open the class to add methods to return sizing values
class OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.AirTerminalSingleDuctParallelPIUReheat", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    maximum_primary_air_flow_rate = self.autosizedMaximumPrimaryAirFlowRate
    if maximum_primary_air_flow_rate.is_initialized
      self.setMaximumPrimaryAirFlowRate(maximum_primary_air_flow_rate.get) 
    end
    
    maximum_secondary_air_flow_rate = self.autosizedMaximumSecondaryAirFlowRate
    if maximum_secondary_air_flow_rate.is_initialized
      self.setMaximumSecondaryAirFlowRate(maximum_secondary_air_flow_rate.get)
    end
    
    minimum_primary_air_flow_fraction = self.autosizedMinimumPrimaryAirFlowFraction
    if minimum_primary_air_flow_fraction.is_initialized
      self.setMinimumPrimaryAirFlowFraction(minimum_primary_air_flow_fraction.get) 
    end
    
    fan_on_flow_fraction = self.autosizedFanOnFlowFraction
    if fan_on_flow_fraction.is_initialized
      self.setFanOnFlowFraction(fan_on_flow_fraction.get)
    end

    
  end

  # returns the autosized maximum primary air flow rate as an optional double
  def autosizedMaximumPrimaryAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Primary Air Flow Rate', 'm3/s')
    
  end

  # returns the autosized maximum secondary air flow rate as an optional double
  def autosizedMaximumSecondaryAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Secondary Air Flow Rate', 'm3/s')
    
  end  
  
 # returns the autosized minimum primary air flow fraction as an optional double
  def autosizedMinimumPrimaryAirFlowFraction

    return self.model.getAutosizedValue(self, 'Design Size Minimum Primary Air Flow Fraction', '')
      
  end  
  
 # returns the autosized fan on flow fraction as an optional double
  def autosizedFanOnFlowFraction

    return self.model.getAutosizedValue(self, 'Design Size Fan On Flow Fraction', '')
       
  end    
  
    
end
