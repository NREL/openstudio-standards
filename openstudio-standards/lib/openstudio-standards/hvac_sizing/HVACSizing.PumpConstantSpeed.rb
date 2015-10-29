
# open the class to add methods to return sizing values
class OpenStudio::Model::PumpConstantSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.PumpConstantSpeed", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    rated_flow_rate = self.autosizedRatedFlowRate
    if rated_flow_rate.is_initialized
      self.setRatedFlowRate(rated_flow_rate.get) 
    end
    
    rated_power_consumption = self.autosizedRatedPowerConsumption
    if rated_power_consumption.is_initialized
      self.setRatedPowerConsumption(rated_power_consumption.get)
    end
    
    
  end

  # returns the autosized rated flow rate as an optional double
  def autosizedRatedFlowRate

    return self.model.getAutosizedValue(self, 'Rated Flow Rate', 'm3/s')
    
  end

  # returns the autosized rated power consumption as an optional double
  def autosizedRatedPowerConsumption

    return self.model.getAutosizedValue(self, 'Rated Power Consumption', 'W')
    
  end  
  
  
end
