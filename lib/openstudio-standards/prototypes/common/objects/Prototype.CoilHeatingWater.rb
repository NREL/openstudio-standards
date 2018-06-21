class Standard
  # @!group CoilHeatingWater

  # Prototype CoilHeatingWater object
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [<OpenStudio::Model::PlantLoop>] the coil will be placed on the demand side of this plant loop
  # @param schedule [String] name of the availability schedule, or [<OpenStudio::Model::Schedule>] Schedule object, or nil in which case default to always on
  # @param rated_inlet_water_temperature [Double] rated inlet water temperature in deg C, default is 180F
  # @param rated_outlet_water_temperature [Double] rated outlet water temperature in deg C, default is 160F
  # @param rated_inlet_air_temperature [Double] rated inlet air temperature in deg C, default is 62F
  # @param rated_outlet_air_temperature [Double] rated outlet air temperature in deg C, default is 90F
  def create_coil_heating_water(model, hot_water_loop, name: "Htg Coil", schedule: nil,
                                rated_inlet_water_temperature: 82.2, rated_outlet_water_temperature: 71.1,
                                rated_inlet_air_temperature: 16.6, rated_outlet_air_temperature: 32.2,
                                controller_convergence_tolerance: 0.1)

    htg_coil = OpenStudio::Model::CoilHeatingWater.new(model)

    # add to hot water loop
    hot_water_loop.addDemandBranchForComponent(htg_coil)

    # set coil name
    htg_coil.setName(name)

    # set coil availability schedule
    coil_availability_schedule = nil
    if schedule.nil?
      # default always on
      coil_availability_schedule = model.alwaysOnDiscreteSchedule
    elsif schedule.class == String
      coil_availability_schedule = model_add_schedule(model, schedule)

      if coil_availability_schedule.nil? && schedule == "alwaysOffDiscreteSchedule"
        coil_availability_schedule = model.alwaysOffDiscreteSchedule
      elsif coil_availability_schedule.nil?
        coil_availability_schedule = model.alwaysOnDiscreteSchedule
      end
    elsif !schedule.to_Schedule.empty?
      coil_availability_schedule = schedule
    else
      coil_availability_schedule = model.alwaysOnDiscreteSchedule
    end
    htg_coil.setAvailabilitySchedule(coil_availability_schedule)

    # rated temperatures
    htg_coil.setRatedInletWaterTemperature(rated_inlet_water_temperature) if !rated_inlet_water_temperature.nil?
    htg_coil.setRatedOutletWaterTemperature(rated_outlet_water_temperature) if !rated_outlet_water_temperature.nil?
    htg_coil.setRatedInletAirTemperature(rated_inlet_air_temperature) if !rated_inlet_air_temperature.nil?
    htg_coil.setRatedOutletAirTemperature(rated_outlet_air_temperature) if !rated_outlet_air_temperature.nil?

    # coil controller properties
    htg_coil_controller = htg_coil.controllerWaterCoil.get
    htg_coil_controller.setName("#{name} Controller")
    htg_coil_controller.setMinimumActuatedFlow(0)
    htg_coil_controller.setControllerConvergenceTolerance(controller_convergence_tolerance)

    return htg_coil
  end
end