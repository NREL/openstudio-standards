
# open the class to add methods to return sizing values
class OpenStudio::Model::AirTerminalSingleDuctVAVReheat

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.AirTerminalSingleDuctVAVReheat", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues
       
    rated_flow_rate = self.autosizedMaximumAirFlowRate
    if rated_flow_rate.is_initialized
      self.setMaximumAirFlowRate(rated_flow_rate.get) 
    end
    
    maximum_hot_water_or_steam_flow_rate = self.autosizedMaximumHotWaterOrSteamFlowRate
    if maximum_hot_water_or_steam_flow_rate.is_initialized
      self.setMaximumHotWaterOrSteamFlowRate(maximum_hot_water_or_steam_flow_rate.get)
    end
    
    maximum_flow_per_zone_floor_area_during_reheat = self.autosizedMaximumFlowPerZoneFloorAreaDuringReheat
    if maximum_flow_per_zone_floor_area_during_reheat.is_initialized
      self.setMaximumFlowPerZoneFloorAreaDuringReheat(maximum_flow_per_zone_floor_area_during_reheat.get) 
    end
    
    maximum_flow_fraction_during_reheat = self.autosizedMaximumFlowFractionDuringReheat
    if maximum_flow_fraction_during_reheat.is_initialized
      self.setMaximumFlowFractionDuringReheat(maximum_flow_fraction_during_reheat.get)
    end

  end

  # returns the autosized maximum air flow rate as an optional double
  def autosizedMaximumAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Air Flow Rate', 'm3/s')
    
  end

  # returns the autosized rated power consumption as an optional double
  def autosizedMaximumHotWaterOrSteamFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Reheat Water Flow Rate', 'm3/s')
    
  end  
  
 # returns the autosized maximum flow per zone floor area during reheat as an optional double
  def autosizedMaximumFlowPerZoneFloorAreaDuringReheat

    return self.model.getAutosizedValue(self, 'Design Size Maximum Flow per Zone Floor Area during Reheat', 'm3/s-m2')
       
  end  
  
 # returns the autosized maximum flow fraction during reheat as an optional double
  def autosizedMaximumFlowFractionDuringReheat

    return self.model.getAutosizedValue(self, 'Design Size Maximum Flow Fraction during Reheat', '')
    
  end    
  
  

  
end
