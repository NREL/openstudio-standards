
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeRatedAirFlowRate
    self.autosizeRatedTotalCoolingCapacity
    self.autosizeRatedSensibleCoolingCapacity
    self.autosizeRatedWaterFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    rated_air_flow_rate = self.autosizedRatedAirFlowRate
    if rated_air_flow_rate.is_initialized
      self.setRatedAirFlowRate(rated_air_flow_rate.get) 
    end

    rated_total_cooling_capacity = self.autosizedRatedTotalCoolingCapacity
    if rated_total_cooling_capacity.is_initialized
      self.setRatedTotalCoolingCapacity(rated_total_cooling_capacity.get) 
    end    

    rated_sensible_cooling_capacity = self.autosizedRatedSensibleCoolingCapacity
    if rated_sensible_cooling_capacity.is_initialized
      self.setRatedSensibleCoolingCapacity(rated_sensible_cooling_capacity.get) 
    end 
 
    rated_water_flow_rate = self.autosizedRatedWaterFlowRate
    if rated_water_flow_rate.is_initialized
      self.setRatedWaterFlowRate(rated_water_flow_rate.get) 
    end 
      
  end

  # returns the autosized rated air flow rate as an optional double
  def autosizedRatedAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Rated Air Flow Rate', 'm3/s')

  end

  # returns the autosized rated total cooling capacity as an optional double
  def autosizedRatedTotalCoolingCapacity

    return self.model.getAutosizedValue(self, 'Design Size Rated Total Cooling Capacity', 'W')
    
  end

  # returns the autosized rated sensible cooling capacity as an optional double
  def autosizedRatedSensibleCoolingCapacity

    return self.model.getAutosizedValue(self, 'Design Size Rated Sensible Cooling Capacity', 'W')
    
  end
  
  # returns the autosized rated water flow rate as an optional double
  def autosizedRatedWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Rated Water Flow Rate', 'm3/s')   
    
  end

  
end
