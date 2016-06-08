
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingGasMultiStage

  # Sets all auto-sizeable fields to autosize
  def autosize
    autosizeStage1NominalCapacity
    autosizeStage2NominalCapacity
    autosizeStage3NominalCapacity
    autosizeStage4NominalCapacity
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    design_size_stage1_nominal_capacity = self.autosizedStage1NominalCapacity
    if design_size_stage1_nominal_capacity.is_initialized
      self.setStage1NominalCapacity(design_size_stage1_nominal_capacity.get) 
    end
 
    design_size_stage2_nominal_capacity = self.autosizedStage2NominalCapacity
    if design_size_stage2_nominal_capacity.is_initialized
      self.setStage2NominalCapacity(design_size_stage2_nominal_capacity.get) 
    end
    
    design_size_stage3_nominal_capacity = self.autosizedStage3NominalCapacity
    if design_size_stage3_nominal_capacity.is_initialized
      self.setStage3NominalCapacity(design_size_stage3_nominal_capacity.get) 
    end

    design_size_stage4_nominal_capacity = self.autosizedStage4NominalCapacity
    if design_size_stage4_nominal_capacity.is_initialized
      self.setStage4NominalCapacity(design_size_stage4_nominal_capacity.get) 
    end
    
  end

  # returns the autosized design stage 1 capacity
  def autosizedStage1NominalCapacity

    return self.model.getAutosizedValue(self,'Design Size Stage 1 Nominal Capacity', 'W')
    
  end
  
  # returns the autosized design stage 2 capacity
  def autosizedStage2NominalCapacity

    return self.model.getAutosizedValue(self,'Design Size Stage 2 Nominal Capacity', 'W')
    
  end
  
  # returns the autosized design stage 3 capacity
  def autosizedStage3NominalCapacity

    return self.model.getAutosizedValue(self,'Design Size Stage 3 Nominal Capacity', 'W')
    
  end
  
  # returns the autosized design stage 4 capacity
  def autosizedStage4NominalCapacity

    return self.model.getAutosizedValue(self,'Design Size Stage 4 Nominal Capacity', 'W')

  end

end
