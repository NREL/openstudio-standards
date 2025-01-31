class Standard
  # @!group FanVariableVolume

  include PrototypeFan

  # Sets the fan pressure rise based on the Prototype buildings inputs
  # which are governed by the flow rate coming through the fan
  # and whether the fan lives inside a unit heater, PTAC, etc.
  #
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] variable volume fan object
  # @return [Boolean] returns true if successful, false if not
  def fan_variable_volume_apply_prototype_fan_pressure_rise(fan_variable_volume)
    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if fan_variable_volume.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_variable_volume.maximumFlowRate.get
    elsif fan_variable_volume.autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_variable_volume.autosizedMaximumFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.FanVariableVolume', "For #{fan_variable_volume.name} max flow rate is not available, cannot apply prototype assumptions.")
      return false
    end

    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get

    # Pressure rise will be determined based on the
    # following logic.
    pressure_rise_in_h2o = 0.0

    # If the fan lives inside of a zone hvac equipment
    if fan_variable_volume.containingZoneHVACComponent.is_initialized
      zone_hvac = fan_variable_volume.ZoneHVACComponent.get
      if zone_hvac.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized || zone_hvac.to_ZoneHVACFourPipeFanCoil.is_initialized
        pressure_rise_in_h2o = 1.33
      elsif zone_hvac.to_ZoneHVACUnitHeater.is_initialized
        pressure_rise_in_h2o = 0.2
      else # This type of fan should not exist in the prototype models
        return false
      end
    # If the fan lives on an airloop
    elsif fan_variable_volume.airLoopHVAC.is_initialized
      pressure_rise_in_h2o = fan_variable_volume_airloop_fan_pressure_rise(fan_variable_volume)
    end

    # Set the fan pressure rise
    pressure_rise_pa = OpenStudio.convert(pressure_rise_in_h2o, 'inH_{2}O', 'Pa').get
    fan_variable_volume.setPressureRise(pressure_rise_pa)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.FanVariableVolume', "For Prototype: #{fan_variable_volume.name}: #{maximum_flow_rate_cfm.round}cfm; Pressure Rise = #{pressure_rise_in_h2o}in w.c.")

    return true
  end

  # Determine the prototype fan pressure rise for a variable volume fan on an AirLoopHVAC based on system airflow.
  # Defaults to the logic from ASHRAE 90.1-2004 prototypes.
  #
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] variable volume fan object
  # @return [Double] pressure rise in inches H20
  def fan_variable_volume_airloop_fan_pressure_rise(fan_variable_volume)
    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if fan_variable_volume.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_variable_volume.maximumFlowRate.get
    elsif fan_variable_volume.autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_variable_volume.autosizedMaximumFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.FanVariableVolume', "For #{fan_variable_volume.name} max flow rate is not available, cannot apply prototype assumptions.")
      return false
    end

    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get

    # Determine the pressure rise
    pressure_rise_in_h2o = if maximum_flow_rate_cfm < 4648
                             4.0
                           elsif maximum_flow_rate_cfm >= 4648 && maximum_flow_rate_cfm < 20_000
                             6.32
                           else # Over 20,000 cfm
                             5.58
                           end

    return pressure_rise_in_h2o
  end

  # creates a variable volume fan
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param fan_name [String] fan name
  # @param fan_efficiency [Double] fan efficiency
  # @param pressure_rise [Double] fan pressure rise in Pa
  # @param motor_efficiency [Double] fan motor efficiency
  # @param motor_in_airstream_fraction [Double] fraction of motor heat in airstream
  # @param fan_power_minimum_flow_rate_input_method [String] options are Fraction, FixedFlowRate
  # @param fan_power_minimum_flow_rate_fraction [Double] minimum flow rate fraction
  # @param end_use_subcategory [String] end use subcategory name
  # @param fan_power_coefficient_1 [Double] fan power coefficient 1
  # @param fan_power_coefficient_2 [Double] fan power coefficient 2
  # @param fan_power_coefficient_3 [Double] fan power coefficient 3
  # @param fan_power_coefficient_4 [Double] fan power coefficient 4
  # @param fan_power_coefficient_5 [Double] fan power coefficient 5
  # @return [OpenStudio::Model::FanVariableVolume] variable volume fan object
  def create_fan_variable_volume(model,
                                 fan_name: nil,
                                 fan_efficiency: nil,
                                 pressure_rise: nil,
                                 motor_efficiency: nil,
                                 motor_in_airstream_fraction: nil,
                                 fan_power_minimum_flow_rate_input_method: nil,
                                 fan_power_minimum_flow_rate_fraction: nil,
                                 fan_power_coefficient_1: nil,
                                 fan_power_coefficient_2: nil,
                                 fan_power_coefficient_3: nil,
                                 fan_power_coefficient_4: nil,
                                 fan_power_coefficient_5: nil,
                                 end_use_subcategory: nil)
    fan = OpenStudio::Model::FanVariableVolume.new(model)
    PrototypeFan.apply_base_fan_variables(fan,
                                          fan_name: fan_name,
                                          fan_efficiency: fan_efficiency,
                                          pressure_rise: pressure_rise,
                                          end_use_subcategory: end_use_subcategory)
    fan.setMotorEfficiency(motor_efficiency) unless motor_efficiency.nil?
    fan.setMotorInAirstreamFraction(motor_in_airstream_fraction) unless motor_in_airstream_fraction.nil?
    fan.setFanPowerMinimumFlowRateInputMethod(fan_power_minimum_flow_rate_input_method) unless fan_power_minimum_flow_rate_input_method.nil?
    fan.setFanPowerMinimumFlowFraction(fan_power_minimum_flow_rate_fraction) unless fan_power_minimum_flow_rate_fraction.nil?
    fan.setFanPowerCoefficient1(fan_power_coefficient_1) unless fan_power_coefficient_1.nil?
    fan.setFanPowerCoefficient2(fan_power_coefficient_2) unless fan_power_coefficient_2.nil?
    fan.setFanPowerCoefficient3(fan_power_coefficient_3) unless fan_power_coefficient_3.nil?
    fan.setFanPowerCoefficient4(fan_power_coefficient_4) unless fan_power_coefficient_4.nil?
    fan.setFanPowerCoefficient5(fan_power_coefficient_5) unless fan_power_coefficient_5.nil?
    return fan
  end

  # creates a variable volume fan from a json
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param fan_json [Hash] hash of fan properties
  # @param fan_name [String] fan name
  # @param fan_efficiency [Double] fan efficiency
  # @param pressure_rise [Double] fan pressure rise in Pa
  # @param motor_efficiency [Double] fan motor efficiency
  # @param motor_in_airstream_fraction [Double] fraction of motor heat in airstream
  # @param fan_power_minimum_flow_rate_input_method [String] options are Fraction, FixedFlowRate
  # @param fan_power_minimum_flow_rate_fraction [Double] minimum flow rate fraction
  # @param end_use_subcategory [String] end use subcategory name
  # @param fan_power_coefficient_1 [Double] fan power coefficient 1
  # @param fan_power_coefficient_2 [Double] fan power coefficient 2
  # @param fan_power_coefficient_3 [Double] fan power coefficient 3
  # @param fan_power_coefficient_4 [Double] fan power coefficient 4
  # @param fan_power_coefficient_5 [Double] fan power coefficient 5
  # @return [OpenStudio::Model::FanVariableVolume] variable volume fan object
  def create_fan_variable_volume_from_json(model,
                                           fan_json,
                                           fan_name: nil,
                                           fan_efficiency: nil,
                                           pressure_rise: nil,
                                           motor_efficiency: nil,
                                           motor_in_airstream_fraction: nil,
                                           fan_power_minimum_flow_rate_input_method: nil,
                                           fan_power_minimum_flow_rate_fraction: nil,
                                           end_use_subcategory: nil,
                                           fan_power_coefficient_1: nil,
                                           fan_power_coefficient_2: nil,
                                           fan_power_coefficient_3: nil,
                                           fan_power_coefficient_4: nil,
                                           fan_power_coefficient_5: nil)
    # check values to use
    fan_efficiency ||= fan_json['fan_efficiency']
    pressure_rise ||= fan_json['pressure_rise']
    motor_efficiency ||= fan_json['motor_efficiency']
    motor_in_airstream_fraction ||= fan_json['motor_in_airstream_fraction']
    fan_power_minimum_flow_rate_input_method ||= fan_json['fan_power_minimum_flow_rate_input_method']
    fan_power_minimum_flow_rate_fraction ||= fan_json['fan_power_minimum_flow_rate_fraction']
    fan_power_coefficient_1 ||= fan_json['fan_power_coefficient_1']
    fan_power_coefficient_2 ||= fan_json['fan_power_coefficient_2']
    fan_power_coefficient_3 ||= fan_json['fan_power_coefficient_3']
    fan_power_coefficient_4 ||= fan_json['fan_power_coefficient_4']
    fan_power_coefficient_5 ||= fan_json['fan_power_coefficient_5']

    # convert values
    pressure_rise_pa = OpenStudio.convert(pressure_rise, 'inH_{2}O', 'Pa').get unless pressure_rise.nil?

    # create fan
    fan = create_fan_variable_volume(model,
                                     fan_name: fan_name,
                                     fan_efficiency: fan_efficiency,
                                     pressure_rise: pressure_rise_pa,
                                     motor_efficiency: motor_efficiency,
                                     motor_in_airstream_fraction: motor_in_airstream_fraction,
                                     fan_power_minimum_flow_rate_input_method: fan_power_minimum_flow_rate_input_method,
                                     fan_power_minimum_flow_rate_fraction: fan_power_minimum_flow_rate_fraction,
                                     end_use_subcategory: end_use_subcategory,
                                     fan_power_coefficient_1: fan_power_coefficient_1,
                                     fan_power_coefficient_2: fan_power_coefficient_2,
                                     fan_power_coefficient_3: fan_power_coefficient_3,
                                     fan_power_coefficient_4: fan_power_coefficient_4,
                                     fan_power_coefficient_5: fan_power_coefficient_5)
    return fan
  end
end
