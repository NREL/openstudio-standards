
# open the class to add methods to return sizing values
class OpenStudio::Model::CoolingTowerVariableSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    
    self.autosizeDesignWaterFlowRate
    self.autosizeDesignAirFlowRate
    self.autosizeDesignFanPower

  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    rated_water_flow_rate = self.autosizedDesignWaterFlowRate
    if rated_water_flow_rate.is_initialized
      self.setDesignWaterFlowRate(rated_water_flow_rate.get) 
    end 

    rated_air_flow_rate = self.autosizedDesignAirFlowRate
    if rated_air_flow_rate.is_initialized
      self.setDesignAirFlowRate(rated_air_flow_rate.get) 
    end

    rated_fan_power = self.autosizedDesignFanPower
    if rated_fan_power.is_initialized
      self.setDesignFanPower(rated_fan_power.get) 
    end
    
  end

  # returns the autosized design water flow rate as an optional double
  def autosizedDesignWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Water Flow Rate', 'm3/s')
    
  end

  # returns the autosized air flow rate as an optional double
  def autosizedDesignAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized design fan power as an optional double
  def autosizedDesignFanPower

    return self.model.getAutosizedValue(self, 'Fan Power at Design Air Flow Rate', 'W')
    
  end
  
end
