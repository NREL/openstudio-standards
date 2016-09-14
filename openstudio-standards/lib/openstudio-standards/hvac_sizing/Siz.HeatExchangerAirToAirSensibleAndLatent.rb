
# open the class to add methods to return sizing values
class OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.HeatExchangerAirToAirSensibleAndLatent", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    nominal_supply_air_flow_rate = self.autosizedNominalSupplyAirFlowRate
    if nominal_supply_air_flow_rate.is_initialized
      self.setNominalSupplyAirFlowRate(nominal_supply_air_flow_rate.get) 
    end
    
  end

  # returns the autosized nominal supply air flow rate as an optional double
  def autosizedNominalSupplyAirFlowRate

    # In E+ 8.4, (OS 1.9.3 onward) the variable name changed
    supply_air_flow_rate_name = nil
    if self.model.version < OpenStudio::VersionString.new('1.9.3')
      supply_air_flow_rate_name = 'Nominal Supply Air Flow Rate'
    else
      supply_air_flow_rate_name = 'Design Size Nominal Supply Air Flow Rate'
    end  

    return self.model.getAutosizedValue(self, supply_air_flow_rate_name, 'm3/s')
    
  end
   
end

