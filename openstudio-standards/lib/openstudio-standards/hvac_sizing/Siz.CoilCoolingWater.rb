
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilCoolingWater

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoilCoolingWater", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    design_water_flow_rate = self.autosizedDesignWaterFlowRate
    if design_water_flow_rate.is_initialized
      self.setDesignWaterFlowRate(design_water_flow_rate.get) 
    end

    design_air_flow_rate = self.autosizedDesignAirFlowRate
    if design_air_flow_rate.is_initialized
      self.setDesignAirFlowRate(design_air_flow_rate.get) 
    end    

    design_inlet_water_temperature = self.autosizedDesignInletWaterTemperature
    if design_inlet_water_temperature.is_initialized
      self.setDesignInletWaterTemperature(design_inlet_water_temperature.get) 
    end  
    
    design_inlet_air_temperature = self.autosizedDesignInletAirTemperature
    if design_inlet_air_temperature.is_initialized
      self.setDesignInletAirTemperature(design_inlet_air_temperature.get) 
    end  

    design_outlet_air_temperature = self.autosizedDesignOutletAirTemperature
    if design_outlet_air_temperature.is_initialized
      self.setDesignOutletAirTemperature(design_outlet_air_temperature.get) 
    end  
    
    design_inlet_air_humidity_ratio = self.autosizedDesignInletAirHumidityRatio
    if design_inlet_air_humidity_ratio.is_initialized
      self.setDesignInletAirHumidityRatio(design_inlet_air_humidity_ratio.get) 
    end      
    
    design_outlet_air_humidity_ratio = self.autosizedDesignOutletAirHumidityRatio
    if design_outlet_air_humidity_ratio.is_initialized
      self.setDesignOutletAirHumidityRatio(design_outlet_air_humidity_ratio.get) 
    end 
            
  end

  # returns the autosized design water flow rate as an optional double
  def autosizedDesignWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Design Water Flow Rate', 'm3/s')
 
  end

  # returns the autosized design air flow rate as an optional double
  def autosizedDesignAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Design Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized design inlet water temperature as an optional double
  def autosizedDesignInletWaterTemperature
    
    return self.model.getAutosizedValue(self, 'Design Size Design Inlet Water Temperature', 'C')
    
  end

  # returns the autosized design inlet air temperatureas an optional double
  def autosizedDesignInletAirTemperature

    return self.model.getAutosizedValue(self, 'Design Size Design Inlet Air Temperature', 'C')

  end

  # returns the autosized design outlet air temperature as an optional double
  def autosizedDesignOutletAirTemperature

    return self.model.getAutosizedValue(self, 'Design Size Design Outlet Air Temperature', 'C')
    
  end

  # returns the autosized inlet air humidity ratio as an optional double
  def autosizedDesignInletAirHumidityRatio

    return self.model.getAutosizedValue(self, 'Design Size Design Inlet Air Humidity Ratio', '')
    
  end

  # returns the autosized outlet air humidity ratio as an optional double
  def autosizedDesignOutletAirHumidityRatio

    return self.model.getAutosizedValue(self, 'Design Size Design Outlet Air Humidity Ratio', '')
    
  end

  # returns the autosized design coil load
  def autosizedDesignCoilLoad

    return self.model.getAutosizedValue(self, 'Design Size Design Coil Load', 'W')
    
  end  
  

end
