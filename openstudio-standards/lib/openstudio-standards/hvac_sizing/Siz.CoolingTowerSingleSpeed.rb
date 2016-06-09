
# open the class to add methods to return sizing values
class OpenStudio::Model::CoolingTowerSingleSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoolingTowerSingleSpeed", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    design_water_flow_rate = self.autosizedDesignWaterFlowRate
    if design_water_flow_rate.is_initialized
      self.setDesignWaterFlowRate(design_water_flow_rate.get) 
    end

    fan_power_at_design_air_flow_rate = self.autosizedFanPoweratDesignAirFlowRate
    if fan_power_at_design_air_flow_rate.is_initialized
      self.setFanPoweratDesignAirFlowRate(fan_power_at_design_air_flow_rate.get) 
    end

    design_air_flow_rate = self.autosizedDesignAirFlowRate
    if design_air_flow_rate.is_initialized
      self.setDesignAirFlowRate(design_air_flow_rate.get) 
    end

    u_factor_times_area_value_at_design_air_flow_rate = self.autosizedUFactorTimesAreaValueatDesignAirFlowRate
    if u_factor_times_area_value_at_design_air_flow_rate.is_initialized
      self.setUFactorTimesAreaValueatDesignAirFlowRate(u_factor_times_area_value_at_design_air_flow_rate.get) 
    end

    air_flow_rate_in_free_convection_regime = self.autosizedAirFlowRateinFreeConvectionRegime
    if air_flow_rate_in_free_convection_regime.is_initialized
      self.setAirFlowRateinFreeConvectionRegime(air_flow_rate_in_free_convection_regime.get) 
    end

    u_factor_times_area_value_at_free_convection_air_flow_rate = self.autosizedUFactorTimesAreaValueatFreeConvectionAirFlowRate
    if u_factor_times_area_value_at_free_convection_air_flow_rate.is_initialized
      self.setUFactorTimesAreaValueatFreeConvectionAirFlowRate(u_factor_times_area_value_at_free_convection_air_flow_rate.get) 
    end
    
  end

  # returns the autosized design water flow rate as an optional double
  def autosizedDesignWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Water Flow Rate', 'm3/s')

  end
  
  # returns the autosized fan power at design air flow rate as an optional double
  def autosizedFanPoweratDesignAirFlowRate

    return self.model.getAutosizedValue(self, 'Fan Power at Design Air Flow Rate', 'W')
    
  end
  
  # returns the autosized reference design air flow rate as an optional double
  def autosizedDesignAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized u-factor times area value at design air flow rate as an optional double
  def autosizedUFactorTimesAreaValueatDesignAirFlowRate

    return self.model.getAutosizedValue(self, 'U-Factor Times Area Value at Design Air Flow Rate', 'W/C')

  end
  
  # returns the autosized air flow rate in free convection regime as an optional double
  def autosizedAirFlowRateinFreeConvectionRegime

    return self.model.getAutosizedValue(self, 'Free Convection Regime Air Flow Rate', 'm3/s')

  end
  
  # returns the autosized u-factor times area value in free convection as an optional double
  def autosizedUFactorTimesAreaValueatFreeConvectionAirFlowRate

    return self.model.getAutosizedValue(self, 'Free Convection U-Factor Times Area Value', 'W/K')
    
  end
    
  
end
