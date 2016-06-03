
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::AirLoopHVAC

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeDesignSupplyAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    design_supply_air_flow_rate = self.autosizedDesignSupplyAirFlowRate
    if design_supply_air_flow_rate.is_initialized
      self.setDesignSupplyAirFlowRate(design_supply_air_flow_rate.get) 
    end
        
  end

  # returns the autosized design supply air flow rate as an optional double
  def autosizedDesignSupplyAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Supply Air Flow Rate', 'm3/s')
    
  end
  
  
end
