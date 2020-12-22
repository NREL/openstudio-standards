class Standard
  # @!group FanConstantVolume

  include PrototypeFan
  # Sets the fan pressure rise based on the Prototype buildings inputs
  # which are governed by the flow rate coming through the fan
  # and whether the fan lives inside a unit heater, PTAC, etc.
  def fan_constant_volume_apply_prototype_fan_pressure_rise(fan_constant_volume)
    # Don't modify unit heater fans
    return true if fan_constant_volume.name.to_s.include?('UnitHeater Fan')

    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if fan_constant_volume.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_constant_volume.maximumFlowRate.get
    elsif fan_constant_volume.autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_constant_volume.autosizedMaximumFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.FanConstantVolume', "For #{fan_constant_volume.name} max flow rate is not available, cannot apply prototype assumptions.")
      return false
    end

    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get

    # Pressure rise will be determined based on the
    # following logic.
    pressure_rise_in_h2o = 0.0

    # If the fan lives inside of a zone hvac equipment
    if fan_constant_volume.containingZoneHVACComponent.is_initialized
      zone_hvac = fan_constant_volume.containingZoneHVACComponent.get
      if zone_hvac.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
        pressure_rise_in_h2o = 1.33
      elsif zone_hvac.to_ZoneHVACFourPipeFanCoil.is_initialized
        pressure_rise_in_h2o = 1.33
      elsif zone_hvac.to_ZoneHVACUnitHeater.is_initialized
        pressure_rise_in_h2o = 0.2
      else # This type of fan should not exist in the prototype models
        return false
      end
    # If the fan lives on an airloop
    elsif fan_constant_volume.airLoopHVAC.is_initialized
      pressure_rise_in_h2o = fan_constant_volume_airloop_fan_pressure_rise(fan_constant_volume)
    end

    # Set the fan pressure rise
    pressure_rise_pa = OpenStudio.convert(pressure_rise_in_h2o, 'inH_{2}O', 'Pa').get
    fan_constant_volume.setPressureRise(pressure_rise_pa)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.FanConstantVolume', "For Prototype: #{fan_constant_volume.name}: #{maximum_flow_rate_cfm.round}cfm; Pressure Rise = #{pressure_rise_in_h2o}in w.c.")

    return true
  end

  # Determine the prototype fan pressure rise for a constant volume
  # fan on an AirLoopHVAC based on the airflow of the system.
  # @return [Double] the pressure rise (in H2O).  Defaults
  # to the logic from ASHRAE 90.1-2004 prototypes.
  def fan_constant_volume_airloop_fan_pressure_rise(fan_constant_volume)
    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if fan_constant_volume.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_constant_volume.maximumFlowRate.get
    elsif fan_constant_volume.autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan_constant_volume.autosizedMaximumFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.FanConstantVolume', "For #{fan_constant_volume.name} max flow rate is not available, cannot apply prototype assumptions.")
      return false
    end

    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get

    # Determine the pressure rise
    pressure_rise_in_h2o = if maximum_flow_rate_cfm < 7437
                             2.5
                           elsif maximum_flow_rate_cfm >= 7437 && maximum_flow_rate_cfm < 20_000
                             4.46
                           else # Over 20,000 cfm
                             4.09
                           end

    return pressure_rise_in_h2o
  end

  def create_fan_constant_volume(model,
                                 fan_name: nil,
                                 fan_efficiency: nil,
                                 pressure_rise: nil,
                                 motor_efficiency: nil,
                                 motor_in_airstream_fraction: nil,
                                 end_use_subcategory: nil)
    fan = OpenStudio::Model::FanConstantVolume.new(model)
    PrototypeFan.apply_base_fan_variables(fan,
                                          fan_name: fan_name,
                                          fan_efficiency: fan_efficiency,
                                          pressure_rise: pressure_rise,
                                          end_use_subcategory: end_use_subcategory)
    fan.setMotorEfficiency(motor_efficiency) unless motor_efficiency.nil?
    fan.setMotorInAirstreamFraction(motor_in_airstream_fraction) unless motor_in_airstream_fraction.nil?
    return fan
  end

  def create_fan_constant_volume_from_json(model,
                                           fan_json,
                                           fan_name: nil,
                                           fan_efficiency: nil,
                                           pressure_rise: nil,
                                           motor_efficiency: nil,
                                           motor_in_airstream_fraction: nil,
                                           end_use_subcategory: nil)
    # check values to use
    fan_efficiency ||= fan_json['fan_efficiency']
    pressure_rise ||= fan_json['pressure_rise']
    motor_efficiency ||= fan_json['motor_efficiency']
    motor_in_airstream_fraction ||= fan_json['motor_in_airstream_fraction']
    end_use_subcategory ||= fan_json['end_use_subcategory']

    # convert values
    pressure_rise = pressure_rise ? OpenStudio.convert(pressure_rise, 'inH_{2}O', 'Pa').get : nil

    # create fan
    fan = create_fan_constant_volume(model,
                                     fan_name: fan_name,
                                     fan_efficiency: fan_efficiency,
                                     pressure_rise: pressure_rise,
                                     motor_efficiency: motor_efficiency,
                                     motor_in_airstream_fraction: motor_in_airstream_fraction,
                                     end_use_subcategory: end_use_subcategory)
    return fan
  end
end
