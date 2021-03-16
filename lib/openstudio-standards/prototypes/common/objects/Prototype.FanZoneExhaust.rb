class Standard
  # @!group FanZoneExhaust

  include PrototypeFan

  # Sets the fan pressure rise based on the Prototype buildings inputs
  def fan_zone_exhaust_apply_prototype_fan_pressure_rise(fan_zone_exhaust)
    # Do not modify dummy exhaust fans
    return true if fan_zone_exhaust.name.to_s.downcase.include? 'dummy'

    # All exhaust fans are assumed to have a pressure rise of
    # 0.5 in w.c. in the prototype building models.
    pressure_rise_in_h2o = 0.5

    # Set the pressure rise
    pressure_rise_pa = OpenStudio.convert(pressure_rise_in_h2o, 'inH_{2}O', 'Pa').get
    fan_zone_exhaust.setPressureRise(pressure_rise_pa)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.FanZoneExhaust', "For Prototype: #{fan_zone_exhaust.name}: Pressure Rise = #{pressure_rise_in_h2o}in w.c.")

    return true
  end

  def create_fan_zone_exhaust_from_json(model,
                                        fan_json,
                                        fan_name: nil,
                                        fan_efficiency: nil,
                                        pressure_rise: nil,
                                        system_availability_manager_coupling_mode: nil,
                                        end_use_subcategory: nil)

    # check values to use
    fan_efficiency ||= fan_json['fan_efficiency']
    pressure_rise ||= fan_json['pressure_rise']
    system_availability_manager_coupling_mode ||= fan_json['system_availability_manager_coupling_mode']

    # convert values
    pressure_rise = pressure_rise ? OpenStudio.convert(pressure_rise, 'inH_{2}O', 'Pa').get : nil

    # create fan
    fan = create_fan_zone_exhaust(model,
                                  fan_name: fan_name,
                                  fan_efficiency: fan_efficiency,
                                  pressure_rise: pressure_rise,
                                  system_availability_manager_coupling_mode: system_availability_manager_coupling_mode,
                                  end_use_subcategory: end_use_subcategory)
    return fan
  end

  def create_fan_zone_exhaust(model,
                              fan_name: nil,
                              fan_efficiency: nil,
                              pressure_rise: nil,
                              system_availability_manager_coupling_mode: nil,
                              end_use_subcategory: nil)
    fan = OpenStudio::Model::FanZoneExhaust.new(model)
    PrototypeFan.apply_base_fan_variables(fan,
                                          fan_name: fan_name,
                                          fan_efficiency: fan_efficiency,
                                          pressure_rise: pressure_rise,
                                          end_use_subcategory: end_use_subcategory)
    fan.setSystemAvailabilityManagerCouplingMode(system_availability_manager_coupling_mode) unless system_availability_manager_coupling_mode.nil?
    return fan
  end
end
