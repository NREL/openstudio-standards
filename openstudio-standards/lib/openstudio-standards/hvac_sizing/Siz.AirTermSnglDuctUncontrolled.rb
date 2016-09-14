
# open the class to add methods to return sizing values
class OpenStudio::Model::AirTerminalSingleDuctUncontrolled

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeMaximumAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    maximum_air_flow_rate = self.autosizedMaximumAirFlowRate
    if maximum_air_flow_rate.is_initialized
      self.setMaximumAirFlowRate(maximum_air_flow_rate.get) 
    end
        
  end
 
  # returns the autosized maximum air flow rate as optional double
  def autosizedMaximumAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Air Flow Rate', 'm3/s')
    
  end  
  
  
end
