
# open the class to add methods to return sizing values
class OpenStudio::Model::CoolingTowerTwoSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoolingTowerTwoSpeed", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoolingTowerTwoSpeed", ".applySizingValues not yet implemented for #{self.iddObject.type.valueDescription}.")
    
  end

  # returns the autosized design water flow rate as an optional double
  def autosizedDesignWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Water Flow Rate', 'm3/s')

  end
  
  # returns the autosized fan power at high speed as an optional double
  def autosizedHighFanSpeedFanPower

    return self.model.getAutosizedValue(self, 'Fan Power at High Fan Speed', 'W')
    
  end
  
  # returns the autosized reference design air flow rate as an optional double
  def autosizedHighFanSpeedAirFlowRate

    return self.model.getAutosizedValue(self, 'Air Flow Rate at High Fan Speed', 'm3/s')
    
  end
  
  # returns the autosized u-factor times area value at high speed as an optional double
  def autosizedHighFanSpeedUFactorTimesAreaValue

    return self.model.getAutosizedValue(self, 'U-Factor Times Area Value at High Fan Speed', 'W/C')

  end
  
  # returns the autosized reference low speed air flow rate as an optional double
  def autosizedLowFanSpeedAirFlowRate

    return self.model.getAutosizedValue(self, 'Low Fan Speed Air Flow Rate', 'm3/s')
    
  end  
  
  # returns the autosized fan power at low speed as an optional double
  def autosizedLowFanSpeedFanPower

    return self.model.getAutosizedValue(self, 'Fan Power at Low Fan Speed', 'W')
    
  end  
  
  # returns the autosized u-factor times area value at design air flow rate as an optional double
  def autosizedLowFanSpeedUFactorTimesAreaValue

    return self.model.getAutosizedValue(self, 'U-Factor Times Area Value at Low Fan Speed', 'W/K')

  end  
  
  # returns the autosized air flow rate in free convection regime as an optional double
  def autosizedFreeConvectionRegimeAirFlowRate

    return self.model.getAutosizedValue(self, 'Free Convection Regime Air Flow Rate', 'm3/s')

  end
  
  # returns the autosized u-factor times area value in free convection as an optional double
  def autosizedFreeConvectionRegimeUFactorTimesAreaValue

    return self.model.getAutosizedValue(self, 'Free Convection U-Factor Times Area Value', 'W/K')
    
  end
    
  
end
