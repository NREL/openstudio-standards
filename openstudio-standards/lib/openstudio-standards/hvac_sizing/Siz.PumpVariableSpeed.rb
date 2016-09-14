
# open the class to add methods to return sizing values
class OpenStudio::Model::PumpVariableSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.PumpVariableSpeed", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
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

    # In E+ 8.5, (OS 1.10.5 onward) the column name changed
    col_name = nil
    if self.model.version < OpenStudio::VersionString.new('1.10.5')
      col_name = 'Rated Flow Rate'
    else
      col_name = 'Design Flow Rate'
    end  
   
    return self.model.getAutosizedValue(self, col_name, 'm3/s')
    
  end

  # returns the autosized rated power consumption as an optional double
  def autosizedRatedPowerConsumption

    # In E+ 8.5, (OS 1.10.5 onward) the column name changed
    col_name = nil
    if self.model.version < OpenStudio::VersionString.new('1.10.5')
      col_name = 'Rated Power Consumption'
    else
      col_name = 'Design Power Consumption'
    end  
   
    return self.model.getAutosizedValue(self, col_name, 'W')
    
  end  
  
  
end
