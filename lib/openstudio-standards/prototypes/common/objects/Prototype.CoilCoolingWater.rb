class Standard
  # @!group CoilCoolingWater

  # Prototype CoilCoolingWater object
  # @param coil_name [String] the name of the coil, or nil in which case it will be defaulted
  # @param chilled_water_loop [<OpenStudio::Model::PlantLoop>] the coil will be placed on the demand side of this plant loop
  # @param schedule [String] name of the availability schedule, or [<OpenStudio::Model::Schedule>] Schedule object, or nil in which case default to always on
  # @param design_inlet_water_temperature [Double] design inlet water temperature in degrees Celsius, default is nil
  # @param design_inlet_air_temperature [Double] design inlet air temperature in degrees Celsius, default is nil
  # @param design_outlet_air_temperature [Double] design outlet air temperature in degrees Celsius, default is nil
  def create_coil_cooling_water(model,
                                chilled_water_loop,
                                coil_name: "Clg Coil",
                                schedule: nil,
                                design_inlet_water_temperature: nil,
                                design_inlet_air_temperature: nil,
                                design_outlet_air_temperature: nil)

    clg_coil = OpenStudio::Model::CoilCoolingWater.new(model)

    # add to chilled water loop
    chilled_water_loop.addDemandBranchForComponent(clg_coil)

    # set coil name
    if coil_name.nil?
      clg_coil.setName("Clg Coil")
    else
      clg_coil.setName(coil_name)
    end

    # set coil availability schedule
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
    clg_coil.setAvailabilitySchedule(coil_availability_schedule)

    # rated temperatures
    clg_coil.setDesignInletWaterTemperature(design_inlet_water_temperature) if !design_inlet_water_temperature.nil?
    clg_coil.setDesignInletAirTemperature(design_inlet_air_temperature) if !design_inlet_air_temperature.nil?
    clg_coil.setDesignOutletAirTemperature(design_outlet_air_temperature) if !design_outlet_air_temperature.nil?

    # defaults
    clg_coil.setHeatExchangerConfiguration('CrossFlow')

    # coil controller properties
    clg_coil_controller = clg_coil.controllerWaterCoil.get
    clg_coil_controller.setName("#{clg_coil.name.to_s} Controller")
    clg_coil_controller.setAction("Reverse")
    clg_coil_controller.setMinimumActuatedFlow(0.0)

    return clg_coil
  end
end