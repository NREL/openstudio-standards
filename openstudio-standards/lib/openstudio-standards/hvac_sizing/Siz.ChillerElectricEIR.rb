
# open the class to add methods to return sizing values
class OpenStudio::Model::ChillerElectricEIR

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.ChillerElectricEIR", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    reference_chilled_water_flow_rate = self.autosizedReferenceChilledWaterFlowRate
    if reference_chilled_water_flow_rate.is_initialized
      self.setReferenceChilledWaterFlowRate(reference_chilled_water_flow_rate.get) 
    end

    reference_capacity = self.autosizedReferenceCapacity
    if reference_capacity.is_initialized
      self.setReferenceCapacity(reference_capacity.get) 
    end

    # Only try to find the condenser water flow rate if this chiller
    # is a water cooled chiller connected to a condenser loop.
    if self.secondaryPlantLoop.is_initialized
      reference_condenser_fluid_flow_rate = self.autosizedReferenceCondenserFluidFlowRate
      if reference_condenser_fluid_flow_rate.is_initialized
        self.setReferenceCondenserFluidFlowRate(reference_condenser_fluid_flow_rate.get) 
      end
    end
    
  end

  # returns the autosized chilled water flow rate as an optional double
  def autosizedReferenceChilledWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Reference Chilled Water Flow Rate', 'm3/s')
    
  end
  
  # returns the autosized reference capacity as an optional double
  def autosizedReferenceCapacity

    return self.model.getAutosizedValue(self, 'Design Size Reference Capacity', 'W')

  end
  
  # returns the autosized reference condenser fluid flow rate as an optional double
  def autosizedReferenceCondenserFluidFlowRate

    return self.model.getAutosizedValue(self, 'User-Specified Reference Condenser Water Flow Rate', 'm3/s')
    
  end
  
  
end
