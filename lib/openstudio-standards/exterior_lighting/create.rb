module OpenstudioStandards
  # The Exterior Lighting module provides methods create, modify, and get information about model exterior lighting
  module ExteriorLighting
    # @!group Create

    # create an ExtertiorLights object from inputs
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param name [String] the name of the exterior lights
    # @param power [Double] the watts value, can be watts or watts per area or length
    # @param units [String] units for the power, either 'W', 'W/ft' or 'W/ft^2'
    # @param multiplier [Double] the multiplier for the lighting, representing ft or ft^2
    # @param schedule [OpenStudio::Model::Schedule] OpenStudio Schedule object. If nil, will default to always on.
    # @param control_option [String] Options are 'ScheduleNameOnly' and 'AstronomicalClock'.
    #   'ScheduleNameOnly' will follow the schedule. 'AstronomicalClock' will follow the schedule, but turn off lights when the sun is up.
    # @return [OpenStudio::Model::ExteriorLights] OpenStudio ExteriorLights object
    def self.model_create_exterior_lights(model,
                                          name: nil,
                                          power: 1.0,
                                          units: 'W',
                                          multiplier: 1.0,
                                          schedule: nil,
                                          control_option: 'AstronomicalClock')
      # default name
      name = "Exterior Lights #{power.round(0)}" if name.nil?

      # default schedule
      schedule = model.alwaysOnDiscreteSchedule if schedule.nil?

      # create exterior light definition
      exterior_lights_definition = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      exterior_lights_definition.setName("#{name} Def (#{units})")
      exterior_lights_definition.setDesignLevel(power)

      # creating exterior lights object
      exterior_lights = OpenStudio::Model::ExteriorLights.new(exterior_lights_definition, schedule)
      exterior_lights.setMultiplier(multiplier)
      exterior_lights.setName(name)
      exterior_lights.setControlOption(control_option)
      exterior_lights.setEndUseSubcategory(name)

      return exterior_lights
    end
  end
end
