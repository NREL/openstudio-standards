
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingDXMultiSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    autosizeSpeed1GrossRatedHeatingCapacity
    autosizeSpeed2GrossRatedHeatingCapacity
    autosizeSpeed3GrossRatedHeatingCapacity
    autosizeSpeed4GrossRatedHeatingCapacity
    autosizeSpeed1RatedAirFlowRate
    autosizeSpeed2RatedAirFlowRate
    autosizeSpeed3RatedAirFlowRate
    autosizeSpeed4RatedAirFlowRate 
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    speed1_rated_heating_capacity = self.autosizedSpeed1GrossRatedHeatingCapacity
    if speed1_rated_heating_capacity.is_initialized
      self.setSpeed1GrossRatedHeatingCapacity(speed1_rated_heating_capacity.get) 
    end
   
    speed2_rated_total_cooling_capacity = self.autosizedSpeed2GrossRatedHeatingCapacity
    if speed2_rated_total_cooling_capacity.is_initialized
      self.setSpeed2GrossRatedTotalCoolingCapacity(speed2_rated_total_cooling_capacity.get) 
    end

    speed3_rated_total_heating_capacity = self.autosizedSpeed3GrossRatedHeatingCapacity
    if speed3_rated_total_heating_capacity.is_initialized
      self.setSpeed3GrossRatedTotalCoolingCapacity(speed3_rated_total_heating_capacity.get) 
    end
    
    speed4_rated_total_heating_capacity = self.autosizedSpeed4GrossRatedHeatingCapacity
    if speed4_rated_total_heating_capacity.is_initialized
      self.setSpeed4GrossRatedTotalCoolingCapacity(speed4_rated_total_heating_capacity.get) 
    end
   
    speed1_rated_air_flow_rate = self.autosizedSpeed1RatedAirFlowRate
    if speed1_rated_air_flow_rate.is_initialized
      self.setSpeed1RatedAirFlowRate(speed1_rated_air_flow_rate.get) 
    end
 
    speed2_rated_air_flow_rate = self.autosizedSpeed2RatedAirFlowRate
    if speed2_rated_air_flow_rate.is_initialized
      self.setSpeed2RatedAirFlowRate(speed2_rated_air_flow_rate.get) 
    end
  
    speed3_rated_air_flow_rate = self.autosizedSpeed3RatedAirFlowRate
    if speed3_rated_air_flow_rate.is_initialized
      self.setSpeed3RatedAirFlowRate(speed3_rated_air_flow_rate.get) 
    end
    
    speed4_rated_air_flow_rate = self.autosizedSpeed4RatedAirFlowRate
    if speed4_rated_air_flow_rate.is_initialized
      self.setSpeed4RatedAirFlowRate(speed4_rated_air_flow_rate.get) 
    end
 
  end

  # returns the autosized rated total cooling capacity for stage 1 as an optional double
  def autosizedSpeed1GrossRatedHeatingCapacity

    return self.model.getAutosizedValue(self,'Speed 1 Design Size Rated Total Heating Capacity', 'W')
    
  end
  
  # returns the autosized rated total cooling capacity for stage 2 as an optional double
  def autosizedSpeed2GrossRatedHeatingCapacity

    return self.model.getAutosizedValue(self,'Speed 2 Design Size Rated Total Heating Capacity', 'W')
    
  end
  
  # returns the autosized rated total cooling capacity for stage 3 as an optional double
  def autosizedSpeed3GrossRatedHeatingCapacity

    return self.model.getAutosizedValue(self,'Speed 3 Design Size Rated Total Heating Capacity', 'W')
    
  end
  
  # returns the autosized rated total cooling capacity for stage 4 as an optional double
  def autosizedSpeed4GrossRatedHeatingCapacity

    return self.model.getAutosizedValue(self,'Speed 4 Design Size Rated Total Heating Capacity', 'W')
    
  end

  # returns the autosized rated air flow rate for stage 1 as an optional double
  def autosizedSpeed1RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Speed 1 Design Size Rated Air Flow Rate', 'm3/s')
    
  end

  # returns the autosized rated air flow rate for stage 2 as an optional double
  def autosizedSpeed2RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Speed 2 Design Size Rated Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized rated air flow rate for stage 3 as an optional double
  def autosizedSpeed3RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Speed 3 Design Size Rated Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized rated air flow rate for stage 4 as an optional double
  def autosizedSpeed4RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Speed 4 Design Size Rated Air Flow Rate', 'm3/s')
    
  end
  
end
