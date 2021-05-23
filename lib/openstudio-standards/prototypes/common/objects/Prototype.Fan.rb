# Prototype fan calculation methods that are the same regardless of fan type.
# These methods are available to FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
module PrototypeFan
  # @!group Fan

  # Sets the fan motor efficiency using the Prototype
  # model assumptions for fan impeller efficiency,
  # motor type, and a 10% safety factor on brake horsepower.
  #
  # @return [Bool] true if successful, false if not
  def prototype_fan_apply_prototype_fan_efficiency(fan)
    # Do not modify dummy exhaust fans
    return true unless !fan.name.to_s.downcase.include? 'dummy'

    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if fan.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan.maximumFlowRate.get
    elsif fan.autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = fan.autosizedMaximumFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Fan', "For #{fan.name} max flow rate is not hard sized, cannot apply efficiency standard.")
      return false
    end

    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get

    # Get the pressure rise from the fan
    pressure_rise_pa = fan.pressureRise
    pressure_rise_in_h2o = OpenStudio.convert(pressure_rise_pa, 'Pa', 'inH_{2}O').get

    # Get the default impeller efficiency
    fan_impeller_eff = fan_baseline_impeller_efficiency(fan)

    # Calculate the Brake Horsepower
    brake_hp = (pressure_rise_in_h2o * maximum_flow_rate_cfm) / (fan_impeller_eff * 6356)
    allowed_hp = brake_hp * 1.1 # Per PNNL document #TODO add reference
    if allowed_hp > 0.1
      allowed_hp = allowed_hp.round(2) + 0.0001
    elsif allowed_hp < 0.01
      allowed_hp = 0.01
    end

    # Minimum motor size for efficiency lookup
    # is 1 HP unless the motor serves an exhaust fan,
    # a powered VAV terminal, or a fan coil unit.
    unless fan_small_fan?(fan)
      if allowed_hp < 1.0
        allowed_hp = 1.01
      end
    end

    # Find the motor efficiency
    motor_eff, nominal_hp = fan_standard_minimum_motor_efficiency_and_size(fan, allowed_hp)

    # Calculate the total fan efficiency
    total_fan_eff = fan_impeller_eff * motor_eff

    # Set the total fan efficiency and the motor efficiency
    if fan.to_FanZoneExhaust.is_initialized
      fan.setFanEfficiency(total_fan_eff)
    else
      fan.setFanEfficiency(total_fan_eff)
      fan.setMotorEfficiency(motor_eff)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Fan', "For #{fan.name}: allowed_hp = #{allowed_hp.round(2)}HP; motor eff = #{(motor_eff * 100).round(2)}%; total fan eff = #{(total_fan_eff * 100).round}% based on #{maximum_flow_rate_cfm.round} cfm.")

    return true
  end

  def self.apply_base_fan_variables(fan,
                                    fan_name: nil,
                                    fan_efficiency: nil,
                                    pressure_rise: nil,
                                    end_use_subcategory: nil)
    fan.setName(fan_name) unless fan_name.nil?
    fan.setFanEfficiency(fan_efficiency) unless fan_efficiency.nil?
    fan.setPressureRise(pressure_rise) unless pressure_rise.nil?
    fan.setEndUseSubcategory(end_use_subcategory) unless end_use_subcategory.nil?
    return fan
  end

  def get_fan_from_standards(standards_name: nil,
                             type: nil,
                             fan_efficiency: nil,
                             pressure_rise: nil,
                             motor_efficiency: nil,
                             motor_in_airstream_fraction: nil,
                             fan_power_minimum_flow_rate_input_method: nil,
                             fan_power_coefficient_1: nil,
                             fan_power_coefficient_2: nil,
                             fan_power_coefficient_3: nil,
                             fan_power_coefficient_4: nil,
                             fan_power_coefficient_5: nil,
                             system_availability_manager_coupling_mode: nil,
                             end_use_subcategory: nil)
    search_criteria = {}
    standards_name ? search_criteria['name'] = standards_name : search_criteria['name'] = 'default'
    if type then search_criteria['type'] = type end
    if fan_efficiency then search_criteria['fan_efficiency'] = fan_efficiency end
    if pressure_rise then search_criteria['pressure_rise'] = pressure_rise end
    if motor_efficiency then search_criteria['motor_efficiency'] = motor_efficiency end
    if motor_in_airstream_fraction then search_criteria['motor_in_airstream_fraction'] = motor_in_airstream_fraction end
    if fan_power_minimum_flow_rate_input_method then search_criteria['fan_power_minimum_flow_rate_input_method'] = fan_power_minimum_flow_rate_input_method end
    if fan_power_coefficient_1 then search_criteria['fan_power_coefficient_1'] = fan_power_coefficient_1 end
    if fan_power_coefficient_2 then search_criteria['fan_power_coefficient_2'] = fan_power_coefficient_2 end
    if fan_power_coefficient_3 then search_criteria['fan_power_coefficient_3'] = fan_power_coefficient_3 end
    if fan_power_coefficient_4 then search_criteria['fan_power_coefficient_4'] = fan_power_coefficient_4 end
    if fan_power_coefficient_5 then search_criteria['fan_power_coefficient_5'] = fan_power_coefficient_5 end
    if system_availability_manager_coupling_mode then search_criteria['system_availability_manager_coupling_mode'] = system_availability_manager_coupling_mode end
    if end_use_subcategory then search_criteria['end_use_subcategory'] = end_use_subcategory end

    model_find_object(@standards_data['fans'], search_criteria)
  end

  def create_fan_by_name(model,
                         standards_name,
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
                         system_availability_manager_coupling_mode: nil,
                         end_use_subcategory: nil)

    fan_json = get_fan_from_standards(standards_name: standards_name)

    if fan_json['type'] == 'ConstantVolume'
      create_fan_constant_volume_from_json(model,
                                           fan_json,
                                           fan_name: fan_name,
                                           fan_efficiency: fan_efficiency,
                                           pressure_rise: pressure_rise,
                                           motor_efficiency: motor_efficiency,
                                           motor_in_airstream_fraction: motor_in_airstream_fraction,
                                           end_use_subcategory: end_use_subcategory)
    elsif fan_json['type'] == 'OnOff'
      create_fan_on_off_from_json(model,
                                  fan_json,
                                  fan_name: fan_name,
                                  fan_efficiency: fan_efficiency,
                                  pressure_rise: pressure_rise,
                                  motor_efficiency: motor_efficiency,
                                  motor_in_airstream_fraction: motor_in_airstream_fraction,
                                  end_use_subcategory: end_use_subcategory)
    elsif fan_json['type'] == 'VariableVolume'
      create_fan_variable_volume_from_json(model,
                                           fan_json,
                                           fan_name: fan_name,
                                           fan_efficiency: fan_efficiency,
                                           pressure_rise: pressure_rise,
                                           motor_efficiency: motor_efficiency,
                                           motor_in_airstream_fraction: motor_in_airstream_fraction,
                                           fan_power_minimum_flow_rate_input_method: fan_power_minimum_flow_rate_input_method,
                                           fan_power_minimum_flow_rate_fraction: fan_power_minimum_flow_rate_fraction,
                                           fan_power_coefficient_1: fan_power_coefficient_1,
                                           fan_power_coefficient_2: fan_power_coefficient_2,
                                           fan_power_coefficient_3: fan_power_coefficient_3,
                                           fan_power_coefficient_4: fan_power_coefficient_4,
                                           fan_power_coefficient_5: fan_power_coefficient_5,
                                           end_use_subcategory: end_use_subcategory)
    elsif fan_json['type'] == 'ZoneExhaust'
      create_fan_zone_exhaust_from_json(model,
                                        fan_json,
                                        fan_name: fan_name,
                                        fan_efficiency: fan_efficiency,
                                        pressure_rise: pressure_rise,
                                        system_availability_manager_coupling_mode: system_availability_manager_coupling_mode,
                                        end_use_subcategory: end_use_subcategory)
    end
  end
end
