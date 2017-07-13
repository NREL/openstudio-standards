
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingDXVariableRefrigerantFlow

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeRatedTotalHeatingCapacity
    self.autosizeRatedAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    rated_air_flow_rate = self.autosizedRatedAirFlowRate
    if rated_air_flow_rate.is_initialized
      self.setRatedAirFlowRate(rated_air_flow_rate.get)
    end

    rated_total_heating_capacity = self.autosizedRatedTotalHeatingCapacity
    if rated_total_heating_capacity.is_initialized
      self.setRatedTotalHeatingCapacity(rated_total_heating_capacity.get)
    end


  end

  # Design Size Rated Air Flow Rate as an optional double
  def autosizedRatedAirFlowRate
    return self.model.getAutosizedValue(self, 'Design Size Rated Air Flow Rate', 'm3/s')
  end

  # Design Size Gross Rated Total Heating Capacity as an optional double
  def autosizedRatedTotalHeatingCapacity
    return self.model.getAutosizedValue(self, 'Design Size Gross Rated Heating Capacity', 'W')
  end

  
  
end
