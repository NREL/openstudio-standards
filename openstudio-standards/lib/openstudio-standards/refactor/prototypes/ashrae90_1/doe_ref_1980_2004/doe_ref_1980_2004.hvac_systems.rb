class DOERef1980_2004_Model < A90_1_Model
  # Determine the type of SWH pump that
  # a model will have.
  # @return [String] the SWH pump type: ConstantSpeed, VariableSpeed
  def model_swh_pump_type(model, building_type)
    swh_pump_type = if building_type == 'Medium Office'
                   'ConstantSpeed'
                 else
                   'VariableSpeed'
                 end
    return swh_pump_type
  end
end
