
# open the class to add methods to return sizing values
class OpenStudio::Model::SizingSystem

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeDesignOutdoorAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    # In OpenStudio, the design OA flow rates are calculated by the
    # Controller:OutdoorAir object associated with this system.
    # Therefore, this property will be retrieved from that object's sizing values
    air_loop = self.airLoopHVAC
    if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
      controller_oa = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir
      # get the max oa flow rate from the controller:outdoor air sizing
      maximum_outdoor_air_flow_rate = controller_oa.autosizedMaximumOutdoorAirFlowRate
      if maximum_outdoor_air_flow_rate.is_initialized
        self.setDesignOutdoorAirFlowRate(maximum_outdoor_air_flow_rate.get)
        # Set the OA flow method to "ZoneSum" to avoid severe errors
        # in the fully hard-sized model.
        self.setSystemOutdoorAirMethod("ZoneSum")
      end
    end
    
  end

  # returns the autosized maximum outdoor air flow rate as an optional double
  def autosizedMaximumOutdoorAirFlowRate

    return self.model.getAutosizedValue(self, 'Maximum Outdoor Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized minimum outdoor air flow rate as an optional double
  def autosizedMinimumOutdoorAirFlowRate

    return self.model.getAutosizedValue(self, 'Minimum Outdoor Air Flow Rate', 'm3/s')
    
  end
  
  
end
