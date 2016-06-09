
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingGas

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeNominalCapacity
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    nominal_capacity = self.autosizedNominalCapacity
    if nominal_capacity.is_initialized
      self.setNominalCapacity(nominal_capacity.get) 
    end
        
  end
 
  # returns the autosized rated capacity as an optional double
  def autosizedNominalCapacity

    return self.model.getAutosizedValue(self, 'Design Size Nominal Capacity', 'W')
    
  end  
  
  
end
