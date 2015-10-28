
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

    return self.model.getAutosizedValue(self, 'Nominal Supply Air Flow Rate', 'm3/s')
    
  end
   
end

