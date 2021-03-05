class ASHRAE9012010 < ASHRAE901
  # @!group Pump

  # Determine type of pump part load control type
  #
  # @code_sections [90.1-2010_6.5.4.1]
  # @param pump [OpenStudio::Model::PumpVariableSpeed] OpenStudio pump object
  # @param plant_loop_type [String] Type of plant loop
  # @param pump_nominal_hp [Float] Pump nominal horsepower
  # @return [String] Pump part load control type
  def pump_variable_speed_get_control_type(pump, plant_loop_type, pump_nominal_hp)
    threshold = 5 # hp

    # Sizing factor to take into account that pumps
    # are typically sized to handle a ~10% pressure
    # increase and ~10% flow increase.
    design_sizing_factor = 1.25

    if plant_loop_type == 'Heating'
      return 'Riding Curve'
    else
      if pump_nominal_hp * design_sizing_factor > threshold
        return 'VSD DP Reset' # Requirement only applies to CHW pumps
      else
        return 'Riding Curve'
      end
    end
  end
  end
