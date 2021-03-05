class Standard
  include Pump

  # Determine and set type of part load control type for heating and chilled
  # water variable speed pumps
  #
  # @param pump [OpenStudio::Model::PumpVariableSpeed] OpenStudio pump object
  # @return [Boolean] Returns true if applicable, false otherwise
  def pump_variable_speed_control_type(pump)
    # Get plant loop
    plant_loop = pump.plantLoop.get

    # Get plant loop type
    plant_loop_type = plant_loop.sizingPlant.loopType
    return false unless plant_loop_type == 'Heating' || plant_loop_type == 'Cooling'

    # Get rated pump power
    if pump.autosizedRatedPowerConsumption.is_initialized
      pump_rated_power_w = pump.autosizedRatedPowerConsumption.get
    elsif pump.ratedPowerConsumption.is_initialized
      pump_rated_power_w = pump.ratedPowerConsumption.get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Pump', "For #{pump.name}, could not find rated pump power consumption, cannot determine w per gpm correctly.")
      return false
    end

    # Get nominal nameplate HP
    pump_nominal_hp = pump_rated_power_w * pump.motorEfficiency / 745.7

    # Assign peformance curves
    control_type = pump_variable_speed_get_control_type(pump, plant_loop_type, pump_nominal_hp)

    # Set pump part load performance curve coefficients
    pump_variable_speed_set_control_type(pump, control_type) unless !control_type

    return true
  end

  # Determine type of pump part load control type
  #
  # @param pump [OpenStudio::Model::PumpVariableSpeed] OpenStudio pump object
  # @param plant_loop_type [String] Type of plant loop
  # @param pump_nominal_hp [Float] Pump nominal horsepower
  # @return [Boolean] Returns false (default behavior)
  def pump_variable_speed_get_control_type(pump, plant_loop_type, pump_nominal_hp)
    return false
  end
end
