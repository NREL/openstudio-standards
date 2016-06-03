
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilCoolingDXVariableRefrigerantFlow

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizedRatedTotalCoolingCapacity
    self.autosizeRatedAirFlowRate
    self.autosizeRatedSensibleHeatRatio
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

    rated_sensible_heat_ratio = self.autosizedRatedSensibleHeatRatio
    if rated_sensible_heat_ratio.is_initialized
      self.setRatedSensibleHeatRatio(rated_sensible_heat_ratio.get)
    end
        
  end

  # Design Size Rated Air Flow Rate as an optional double
  def autosizedRatedTotalCoolingCapacity
    return self.model.getAutosizedValue(self, 'Design Size Rated Air Flow Rate', 'm3/s')
  end

  # Design Size Gross Rated Total Cooling Capacity as an optional double
  def autosizedRatedAirFlowRate
    return self.model.getAutosizedValue(self, 'Design Size Gross Rated Total Cooling Capacity', 'W')
  end

  # Design Size Gross Rated Sensible Heat Ratio as an optional double
  def autosizedRatedSensibleHeatRatio
    return self.model.getAutosizedValue(self, 'Design Size Gross Rated Sensible Heat Ratio', '')
  end
  
end
