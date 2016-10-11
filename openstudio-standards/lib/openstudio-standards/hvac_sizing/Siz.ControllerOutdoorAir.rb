
# open the class to add methods to return sizing values
class OpenStudio::Model::ControllerOutdoorAir

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeMaximumOutdoorAirFlowRate
    self.autosizeMinimumOutdoorAirFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    maximum_outdoor_air_flow_rate = self.autosizedMaximumOutdoorAirFlowRate
    if maximum_outdoor_air_flow_rate.is_initialized
      self.setMaximumOutdoorAirFlowRate(maximum_outdoor_air_flow_rate.get) 
    end

    minimum_outdoor_air_flow_rate = self.autosizedMinimumOutdoorAirFlowRate
    if minimum_outdoor_air_flow_rate.is_initialized
      self.setMinimumOutdoorAirFlowRate(minimum_outdoor_air_flow_rate.get) 
    end
    
  end

  # returns the autosized maximum outdoor air flow rate as an optional double
  def autosizedMaximumOutdoorAirFlowRate

    return self.model.getAutosizedValue(self, 'Maximum Outdoor Air Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized minimum outdoor air flow rate as an optional double
  # EnergyPlus has a "bug" where if the system is a multizone system,
  # the Minimum Outdoor Air Flow Rate reported in the Component Sizing
  # summary does not include zone multipliers.
  # @todo determine what to do when the airloop has multiple zones
  # with different multipliers
  def autosizedMinimumOutdoorAirFlowRate

    oa = self.model.getAutosizedValue(self, 'Minimum Outdoor Air Flow Rate', 'm3/s')

    # Get the airloop connected to this controller
    if airLoopHVACOutdoorAirSystem.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Siz.ControllerOutdoorAir', "#{name} is not connected to an airLoopHVACOutdoorAirSystem, cannot determine autosizedMinimumOutdoorAirFlowRate accuractely.")
      return oa
    end
    oa_sys = airLoopHVACOutdoorAirSystem.get
    if oa_sys.airLoop.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Siz.ControllerOutdoorAir', "#{name}'s airLoopHVACOutdoorAirSystem is not assigned to an AirLoop, cannot determine autosizedMinimumOutdoorAirFlowRate accuractely.")
      return oa
    end
    air_loop = oa_sys.airLoop.get

    # If it is a multizone system, get the system multiplier
    # to work around the bug in EnergyPlus.
    if air_loop.multizone_vav_system?
      if oa.is_initialized
        oa_val = oa.get
        oa_val *= air_loop.system_multiplier
        oa = OpenStudio::OptionalDouble.new(oa_val)
      end
    end

    return oa
  end
end
