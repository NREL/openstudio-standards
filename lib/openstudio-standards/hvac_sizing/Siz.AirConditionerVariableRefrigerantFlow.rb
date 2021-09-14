
# open the class to add methods to return sizing values
class OpenStudio::Model::AirConditionerVariableRefrigerantFlow

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeRatedTotalCoolingCapacity
    self.autosizeRatedTotalHeatingCapacity
    self.autosizeResistiveDefrostHeaterCapacity
    self.autosizeWaterCondenserVolumeFlowRate
    self.autosizeEvaporativeCondenserAirFlowRate
    self.autosizeEvaporativeCondenserPumpRatedPowerConsumption
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    # Rated Total Cooling Capacity (gross)
    rated_cool_cap = self.autosizedRatedTotalCoolingCapacity
    if rated_cool_cap.is_initialized
      self.setRatedTotalCoolingCapacity(rated_cool_cap.get)
    end
    
    # Rated Total Heating Capacity
    rated_heat_cap = self.autosizedRatedTotalHeatingCapacity
    if rated_heat_cap.is_initialized
      self.setRatedTotalHeatingCapacity(rated_heat_cap.get)
    end
    
    # Resistive Defrost Heater Capacity
    defrost_heat_cap = self.autosizedResistiveDefrostHeaterCapacity
    if defrost_heat_cap.is_initialized
      self.setResistiveDefrostHeaterCapacity(defrost_heat_cap.get)
    end
    
    # Evaporative Condenser Air Flow Rate
    evap_cnd_airflow_rate = self.autosizedEvaporativeCondenserAirFlowRate
    if evap_cnd_airflow_rate.is_initialized
      self.setEvaporativeCondenserAirFlowRate(evap_cnd_airflow_rate.get)
    end
    
    # Evaporative Condenser Pump Rated Power Consumption
    evap_cnd_pump_power = self.autosizedEvaporativeCondenserPumpRatedPowerConsumption
    if evap_cnd_pump_power.is_initialized
      self.setEvaporativeCondenserPumpRatedPowerConsumption(evap_cnd_pump_power.get)
    end
    
    # @todo autosizeWaterCondenserVolumeFlowRate
      #self.setWaterCondenserVolumeFlowRate

  end

  
  # Rated Total Cooling Capacity (gross)
  def autosizedRatedTotalCoolingCapacity
    return self.model.getAutosizedValue(self, 'Design Size Rated Total Cooling Capacity (gross)', 'W')
  end

  # Rated Total Heating Capacity
  def autosizedRatedTotalHeatingCapacity
    return self.model.getAutosizedValue(self, 'Design Size Rated Total Heating Capacity', 'W')
  end
  
  # Resistive Defrost Heater Capacity (unit is empty as of right now in 8.4...)
  def autosizedResistiveDefrostHeaterCapacity
    return self.model.getAutosizedValue(self, 'Design Size Resistive Defrost Heater Capacity', '')
  end
  
  # Evaporative Condenser Air Flow Rate
  def autosizedEvaporativeCondenserAirFlowRate
    return self.model.getAutosizedValue(self, 'Design Size Evaporative Condenser Air Flow Rate', 'm3/s')
  end
  
  # Evaporative Condenser Pump Rated Power Consumption
  def autosizedEvaporativeCondenserPumpRatedPowerConsumption
    return self.model.getAutosizedValue(self, 'Design Size Evaporative Condenser Pump Rated Power Consumption', 'W')
  end
  
end
