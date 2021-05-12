
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilCoolingDXMultiSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    autosizeSpeed1GrossRatedTotalCoolingCapacity
    autosizeSpeed2GrossRatedTotalCoolingCapacity
    autosizeSpeed3GrossRatedTotalCoolingCapacity
    autosizeSpeed4GrossRatedTotalCoolingCapacity
    autosizeSpeed1GrossRatedSensibleHeatRatio
    autosizeSpeed2GrossRatedSensibleHeatRatio
    autosizeSpeed3GrossRatedSensibleHeatRatio
    autosizeSpeed4GrossRatedSensibleHeatRatio  
    autosizeSpeed1RatedAirFlowRate
    autosizeSpeed2RatedAirFlowRate
    autosizeSpeed3RatedAirFlowRate
    autosizeSpeed4RatedAirFlowRate 
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    rated_speed1_rated_total_cooling_capacity = self.autosizedSpeed1GrossRatedTotalCoolingCapacity
    if rated_speed1_rated_total_cooling_capacity.is_initialized
      self.setSpeed1GrossRatedTotalCoolingCapacity(rated_speed1_rated_total_cooling_capacity.get) 
    end

    rated_speed2_rated_total_cooling_capacity = self.autosizedSpeed2GrossRatedTotalCoolingCapacity
    if rated_speed2_rated_total_cooling_capacity.is_initialized
      self.setSpeed2GrossRatedTotalCoolingCapacity(rated_speed2_rated_total_cooling_capacity.get) 
    end

    rated_speed3_rated_total_cooling_capacity = self.autosizedSpeed3GrossRatedTotalCoolingCapacity
    if rated_speed3_rated_total_cooling_capacity.is_initialized
      self.setSpeed3GrossRatedTotalCoolingCapacity(rated_speed3_rated_total_cooling_capacity.get) 
    end
    
    rated_speed4_rated_total_cooling_capacity = self.autosizedSpeed4GrossRatedTotalCoolingCapacity
    if rated_speed4_rated_total_cooling_capacity.is_initialized
      self.setSpeed4GrossRatedTotalCoolingCapacity(rated_speed4_rated_total_cooling_capacity.get) 
    end
    
    rated_speed1_rated_sensible_heat_ratio = self.autosizedSpeed1RatedSensibleHeatRatio
    if rated_speed1_rated_sensible_heat_ratio.is_initialized
      self.setSpeed1RatedSensibleHeatRatio(rated_speed1_rated_sensible_heat_ratio.get) 
    end

    rated_speed2_rated_sensible_heat_ratio = self.autosizedSpeed2RatedSensibleHeatRatio
    if rated_speed2_rated_sensible_heat_ratio.is_initialized
      self.setSpeed2RatedSensibleHeatRatio(rated_speed2_rated_sensible_heat_ratio.get) 
    end

    rated_speed3_rated_sensible_heat_ratio = self.autosizedSpeed3RatedSensibleHeatRatio
    if rated_speed3_rated_sensible_heat_ratio.is_initialized
      self.setSpeed3RatedSensibleHeatRatio(rated_speed3_rated_sensible_heat_ratio.get) 
    end

    rated_speed4_rated_sensible_heat_ratio = self.autosizedSpeed4RatedSensibleHeatRatio
    if rated_speed4_rated_sensible_heat_ratio.is_initialized
      self.setSpeed4RatedSensibleHeatRatio(rated_speed4_rated_sensible_heat_ratio.get) 
    end

    rated_speed1_rated_air_flow_rate = self.autosizedSpeed1RatedAirFlowRate
    if rated_speed1_rated_air_flow_rate.is_initialized
      self.setSpeed1RatedAirFlowRate(rated_speed1_rated_air_flow_rate.get) 
    end
 
    rated_speed2_rated_air_flow_rate = self.autosizedSpeed2RatedAirFlowRate
    if rated_speed2_rated_air_flow_rate.is_initialized
      self.setSpeed2RatedAirFlowRate(rated_speed2_rated_air_flow_rate.get) 
    end
  
    rated_speed3_rated_air_flow_rate = self.autosizedSpeed3RatedAirFlowRate
    if rated_speed3_rated_air_flow_rate.is_initialized
      self.setSpeed3RatedAirFlowRate(rated_speed3_rated_air_flow_rate.get) 
    end
    
    rated_speed4_rated_air_flow_rate = self.autosizedSpeed4RatedAirFlowRate
    if rated_speed4_rated_air_flow_rate.is_initialized
      self.setSpeed4RatedAirFlowRate(rated_speed4_rated_air_flow_rate.get) 
    end
 
  end

  # returns the autosized rated total cooling capacity for stage 1 as an optional double
  def autosizedSpeed1GrossRatedTotalCoolingCapacity

    return self.model.getAutosizedValue(self,'Design Size Speed 1 Gross Rated Total Cooling Capacity', 'W')
    
  end
  
  # returns the autosized rated total cooling capacity for stage 2 as an optional double
  def autosizedSpeed2GrossRatedTotalCoolingCapacity

    return self.model.getAutosizedValue(self,'Design Size Speed 2 Gross Rated Total Cooling Capacity', 'W')
    
  end
  
  # returns the autosized rated total cooling capacity for stage 3 as an optional double
  def autosizedSpeed3GrossRatedTotalCoolingCapacity

    return self.model.getAutosizedValue(self,'Design Size Speed 3 Gross Rated Total Cooling Capacity', 'W')
    
  end
  
  # returns the autosized rated total cooling capacity for stage 4 as an optional double
  def autosizedSpeed4GrossRatedTotalCoolingCapacity

    return self.model.getAutosizedValue(self,'Design Size Speed 4 Gross Rated Total Cooling Capacity', 'W')
    
  end

  # returns the autosized rated sensible heat ratio for stage 1 as an optional double
  def autosizedSpeed1RatedSensibleHeatRatio

    return self.model.getAutosizedValue(self,'Design Size Speed 1 Rated Sensible Heat Ratio', '')
    
  end
  
  # returns the autosized rated sensible heat ratio for stage 2 as an optional double
  def autosizedSpeed2RatedSensibleHeatRatio

    return self.model.getAutosizedValue(self,'Design Size Speed 2 Rated Sensible Heat Ratio', '')
    
  end
  
  # returns the autosized rated sensible heat ratio for stage 3 as an optional double
  def autosizedSpeed3RatedSensibleHeatRatio

    return self.model.getAutosizedValue(self,'Design Size Speed 3 Rated Sensible Heat Ratio', '')
    
  end
  
  # returns the autosized rated sensible heat ratio for stage 4 as an optional double
  def autosizedSpeed4RatedSensibleHeatRatio

    return self.model.getAutosizedValue(self,'Design Size Speed 4 Rated Sensible Heat Ratio', '')
    
  end
  
  # returns the autosized rated air flow rate for stage 1 as an optional double
  def autosizedSpeed1RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Design Size Speed 1 Rated Air Flow Rate', 'm3/s')
    
  end

  # returns the autosized rated air flow rate for stage 2 as an optional double
  def autosizedSpeed2RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Design Size Speed 2 Rated Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized rated air flow rate for stage 3 as an optional double
  def autosizedSpeed3RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Design Size Speed 3 Rated Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized rated air flow rate for stage 4 as an optional double
  def autosizedSpeed4RatedAirFlowRate

    return self.model.getAutosizedValue(self,'Design Size Speed 4 Rated Air Flow Rate', 'm3/s')
    
  end
end
