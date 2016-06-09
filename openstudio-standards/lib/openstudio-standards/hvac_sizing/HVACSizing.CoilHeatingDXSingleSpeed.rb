
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingDXSingleSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeRatedTotalHeatingCapacity
    self.autosizeRatedAirFlowRate
    self.autosizeResistiveDefrostHeaterCapacity
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

    rated_resistive_defrost_heater_capacity = self.autosizedResistiveDefrostHeaterCapacity
    if rated_resistive_defrost_heater_capacity.is_initialized
      self.setResistiveDefrostHeaterCapacity(rated_resistive_defrost_heater_capacity.get) 
    end     
      
  end

  # returns the autosized rated air flow rate as an optional double
  def autosizedRatedAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Rated Air Flow Rate', 'm3/s')

  end

  # returns the autosized rated total cooling capacity as an optional double
  def autosizedRatedTotalHeatingCapacity

    return self.model.getAutosizedValue(self, 'Design Size Gross Rated Heating Capacity', 'W')
    
  end
  
  # returns the autosized rated sensible heat ratio as an optional double
  def autosizedResistiveDefrostHeaterCapacity

    return self.model.getAutosizedValue(self, 'Design Size Resistive Defrost Heater Capacity', 'W')   
    
  end

  
end
