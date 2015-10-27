
# open the class to add methods to return sizing values
class OpenStudio::Model::BoilerHotWater

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.BoilerHotWater", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    nominal_capacity = self.autosizedNominalCapacity
    if nominal_capacity.is_initialized
      self.setNominalCapacity(nominal_capacity.get) 
    end

    design_water_flow_rate = self.autosizedDesignWaterFlowRate
    if design_water_flow_rate.is_initialized
      self.setDesignWaterFlowRate(design_water_flow_rate.get) 
    end
    
  end

  # returns the autosized nominal capacity as an optional double
  def autosizedNominalCapacity

    return self.model.getAutosizedValue(self, 'Design Size Nominal Capacity', 'W')
    
  end
  
  # returns the autosized design water flow rate as an optional double
  def autosizedDesignWaterFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Design Water Flow Rate', 'm3/s')
    
  end
  
  
end
