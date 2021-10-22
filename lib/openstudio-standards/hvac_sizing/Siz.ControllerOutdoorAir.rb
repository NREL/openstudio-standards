
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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Siz.ControllerOutdoorAir', "#{name} is not connected to an airLoopHVACOutdoorAirSystem, cannot determine autosizedMinimumOutdoorAirFlowRate accurately.")
      return oa
    end
    oa_sys = airLoopHVACOutdoorAirSystem.get
    if oa_sys.airLoop.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Siz.ControllerOutdoorAir', "#{name}'s airLoopHVACOutdoorAirSystem is not assigned to an AirLoop, cannot determine autosizedMinimumOutdoorAirFlowRate accurately.")
      return oa
    end
    air_loop = oa_sys.airLoop.get

    # Determine if the system is multizone
    multizone = false
    if air_loop.thermalZones.size > 1
      multizone = true
    end

    # Determine if the system is variable volume
    vav = false
    air_loop.supplyComponents.reverse.each do |comp|
      if comp.to_FanVariableVolume.is_initialized
        vav = true
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanVariableVolume.is_initialized
          vav = true
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.is_initialized
          if fan.get.to_FanVariableVolume.is_initialized
            vav = true
          end
        end
      end
    end
    
    # If it is a multizone VAV system, get the system multiplier
    # to work around the bug in EnergyPlus.
    if multizone && vav
      if oa.is_initialized
        oa_val = oa.get
        
        # Get the system multiplier
        mult = 1

        # Get all the zone multipliers
        zn_mults = []
        air_loop.thermalZones.each do |zone|
          zn_mults << zone.multiplier
        end
     
        # Warn if there are different multipliers
        uniq_mults = zn_mults.uniq
        if uniq_mults.size > 1
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop.name}: not all zones on the system have an identical zone multiplier.  Multipliers are: #{uniq_mults.join(', ')}.")
        else
          mult = uniq_mults[0]
        end

        oa_val = oa_val * mult
        oa = OpenStudio::OptionalDouble.new(oa_val)
      end
    end

    return oa
  end
end
