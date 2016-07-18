
# open the class to add methods to return sizing values
class OpenStudio::Model::ControllerOutdoorAir

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeMaximumOutdoorAirFlowRate
    self.autosizeMinimumOutdoorAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    maximum_outdoor_air_flow_rate = self.autosizedMaximumOutdoorAirFlowRate
    if maximum_outdoor_air_flow_rate.is_initialized
      self.setMaximumOutdoorAirFlowRate(maximum_outdoor_air_flow_rate.get) 
    end

    minimum_outdoor_air_flow_rate = self.autosizedMinimumOutdoorAirFlowRate
    if minimum_outdoor_air_flow_rate.is_initialized
      self.setMinimumOutdoorAirFlowRate(minimum_outdoor_air_flow_rate.get) 
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
  
  
end
