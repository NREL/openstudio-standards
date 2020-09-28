
# open the class to add methods to return sizing values
class OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeSupplyAirFlowRateDuringCoolingOperation
    self.autosizeSupplyAirFlowRateDuringHeatingOperation
    self.autosizeSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded
    self.autosizeSpeed1SupplyAirFlowRateDuringCoolingOperation
    self.autosizeSpeed1SupplyAirFlowRateDuringHeatingOperation
    self.autosizeSpeed2SupplyAirFlowRateDuringCoolingOperation
    self.autosizeSpeed2SupplyAirFlowRateDuringHeatingOperation
    self.autosizeSpeed3SupplyAirFlowRateDuringCoolingOperation
    self.autosizeSpeed3SupplyAirFlowRateDuringHeatingOperation
    self.autosizeSpeed4SupplyAirFlowRateDuringCoolingOperation
    self.autosizeSpeed4SupplyAirFlowRateDuringHeatingOperation
    self.autosizeMaximumSupplyAirTemperaturefromSupplementalHeater
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    sup_air_flow_cooling = self.autosizedSupplyAirFlowRateDuringCoolingOperation
    if sup_air_flow_cooling.is_initialized
      self.setSupplyAirFlowRateDuringCoolingOperation(sup_air_flow_cooling.get)
    end

    sup_air_flow_heating = self.autosizedsSupplyAirFlowRateDuringHeatingOperation
    if sup_air_flow_heating.is_initialized
      self.setSupplyAirFlowRateDuringHeatingOperation(sup_air_flow_heating.get)
    end

    sup_air_flow_no_htg_clg = self.autosizedSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded
    if sup_air_flow_no_htg_clg.is_initialized
      self.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(sup_air_flow_no_htg_clg.get)
    end

    speed1_sup_air_flow_cooling = self.autosizedSpeed1SupplyAirFlowRateDuringCoolingOperation
    if speed1_sup_air_flow_cooling.is_initialized
      self.setSpeed1SupplyAirFlowRateDuringCoolingOperation(speed1_sup_air_flow_cooling.get)
    end

    speed1_sup_air_flow_heating = self.autosizedsSpeed1SupplyAirFlowRateDuringHeatingOperation
    if speed1_sup_air_flow_heating.is_initialized
      self.setSpeed1SupplyAirFlowRateDuringHeatingOperation(speed1_sup_air_flow_heating.get)
    end

    speed2_sup_air_flow_cooling = self.autosizedSpeed2SupplyAirFlowRateDuringCoolingOperation
    if speed2_sup_air_flow_cooling.is_initialized
      self.setSpeed2SupplyAirFlowRateDuringCoolingOperation(speed2_sup_air_flow_cooling.get)
    end

    speed2_sup_air_flow_heating = self.autosizedsSpeed2SupplyAirFlowRateDuringHeatingOperation
    if speed2_sup_air_flow_heating.is_initialized
      self.setSpeed2SupplyAirFlowRateDuringHeatingOperation(speed2_sup_air_flow_heating.get)
    end

    speed3_sup_air_flow_cooling = self.autosizedSpeed3SupplyAirFlowRateDuringCoolingOperation
    if speed1_sup_air_flow_cooling.is_initialized
      self.setSpeed3SupplyAirFlowRateDuringCoolingOperation(speed3_sup_air_flow_cooling.get)
    end

    speed3_sup_air_flow_heating = self.autosizedsSpeed3SupplyAirFlowRateDuringHeatingOperation
    if speed3_sup_air_flow_heating.is_initialized
      self.setSpeed3SupplyAirFlowRateDuringHeatingOperation(speed3_sup_air_flow_heating.get)
    end

    speed3_sup_air_flow_no_htg_clg = self.autosizedSpeed3SupplyAirFlowRateWhenNoCoolingorHeatingisNeeded
    if speed3_sup_air_flow_no_htg_clg.is_initialized
      self.setSpeed3SupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(speed3_sup_air_flow_no_htg_clg.get)
    end

    speed4_sup_air_flow_cooling = self.autosizedSpeed4SupplyAirFlowRateDuringCoolingOperation
    if speed4_sup_air_flow_cooling.is_initialized
      self.setSpeed4SupplyAirFlowRateDuringCoolingOperation(speed4_sup_air_flow_cooling.get)
    end

    speed4_sup_air_flow_heating = self.autosizedsSpeed4SupplyAirFlowRateDuringHeatingOperation
    if speed4_sup_air_flow_heating.is_initialized
      self.setSpeed4SupplyAirFlowRateDuringHeatingOperation(speed4_sup_air_flow_heating.get)
    end

    max_sup_htg_temp = self.autosizedMaximumSupplyAirTemperaturefromSupplementalHeater
    if max_sup_htg_temp.is_initialized
      self.setMaximumSupplyAirTemperaturefromSupplementalHeater(max_sup_htg_temp.get)
    end

  end

  # returns the autosized supply air flow rate during cooling operation as an optional double
  def autosizedSupplyAirFlowRateDuringCoolingOperation

    return self.model.getAutosizedValue(self, 'Supply Air Flow Rate During Heating Operation', 'm3/s')

  end

    # returns the autosized supply air flow rate during heating operation as an optional double
  def autosizedSupplyAirFlowRateDuringHeatingOperation

    return self.model.getAutosizedValue(self, 'Supply Air Flow Rate During Cooling Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate when no heating or cooling is needed as an optional double
  def autosizedSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded

    return self.model.getAutosizedValue(self, 'Supply Air Flow Rate', 'm3/s')

  end

  # returns the autosized supply air flow rate during cooling operation as an optional double
  def autosizedSpeed1SupplyAirFlowRateDuringCoolingOperation

    return self.model.getAutosizedValue(self, 'Speed 1 Supply Air Flow Rate During Heating Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during heating operation as an optional double
  def autosizedSpeed1SupplyAirFlowRateDuringHeatingOperation

    return self.model.getAutosizedValue(self, 'Speed 1 Supply Air Flow Rate During Cooling Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during cooling operation as an optional double
  def autosizedSpeed2SupplyAirFlowRateDuringCoolingOperation

    return self.model.getAutosizedValue(self, 'Speed 2 Supply Air Flow Rate During Heating Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during heating operation as an optional double
  def autosizedSpeed2SupplyAirFlowRateDuringHeatingOperation

    return self.model.getAutosizedValue(self, 'Speed 2 Supply Air Flow Rate During Cooling Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during cooling operation as an optional double
  def autosizedSpeed3SupplyAirFlowRateDuringCoolingOperation

    return self.model.getAutosizedValue(self, 'Speed 3 Supply Air Flow Rate During Heating Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during heating operation as an optional double
  def autosizedSpeed3SupplyAirFlowRateDuringHeatingOperation

    return self.model.getAutosizedValue(self, 'Speed 3 Supply Air Flow Rate During Cooling Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during cooling operation as an optional double
  def autosizedSpeed4SupplyAirFlowRateDuringCoolingOperation

    return self.model.getAutosizedValue(self, 'Speed 4 Supply Air Flow Rate During Heating Operation', 'm3/s')

  end

  # returns the autosized supply air flow rate during heating operation as an optional double
  def autosizedSpeed4SupplyAirFlowRateDuringHeatingOperation

    return self.model.getAutosizedValue(self, 'Speed 4 Supply Air Flow Rate During Cooling Operation', 'm3/s')

  end

  # returns the autosized maximum supply air temperature from supplemental heater as an optional double
  def autosizedMaximumSupplyAirTemperaturefromSupplementalHeater

    return self.model.getAutosizedValue(self, 'Maximum Supply Air Temperature from Supplemental Heater', 'C')   
    
  end 

 
end
