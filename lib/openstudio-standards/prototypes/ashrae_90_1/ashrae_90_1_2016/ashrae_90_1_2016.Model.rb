class ASHRAE9012016 < ASHRAE901
  # @!group Model

  # Determine the prototypical economizer type for the model.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param climate_zone [String] the climate zone
  # @return [String] the economizer type.  Possible values are:
  # 'NoEconomizer'
  # 'FixedDryBulb'
  # 'FixedEnthalpy'
  # 'DifferentialDryBulb'
  # 'DifferentialEnthalpy'
  # 'FixedDewPointAndDryBulb'
  # 'ElectronicEnthalpy'
  # 'DifferentialDryBulbAndEnthalpy'
  def model_economizer_type(model, climate_zone)
    economizer_type = case climate_zone
                      when 'ASHRAE 169-2006-0A',
                          'ASHRAE 169-2006-1A',
                          'ASHRAE 169-2006-2A',
                          'ASHRAE 169-2006-3A',
                          'ASHRAE 169-2006-4A',
                          'ASHRAE 169-2013-0A',
                          'ASHRAE 169-2013-1A',
                          'ASHRAE 169-2013-2A',
                          'ASHRAE 169-2013-3A',
                          'ASHRAE 169-2013-4A'
                        'DifferentialEnthalpy'
                      else
                        'DifferentialDryBulb'
                      end
    return economizer_type
  end

  # Implement occupancy based lighting level threshold (0.02 W/sqft). This is only for ASHRAE 90.1 2016 onwards.
  #
  # @code_sections [90.1-2016_9.4.1.1.h/i]
  # @author Xuechen (Jerry) Lei, PNNL
  # @param model [OpenStudio::Model::Model] OpenStudio Model
  #
  def model_add_lights_shutoff(model)
    zones = model.getThermalZones
    num_zones = 0
    business_sch_name = prototype_input['business_schedule']
    return if business_sch_name.nil? # This is only for 10 prototypes that do not have continuous operation.

    # Add business schedule
    model_add_schedule(model, business_sch_name)

    # Add EMS object for business schedule variable
    business_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    business_sensor.setKeyName(business_sch_name)
    business_sensor.setName('Business_Sensor')
    business_sensor_name = business_sensor.name.to_s

    zones.each do |zone|
      spaces = zone.spaces
      if spaces.length != 1
        puts 'warning, there are more than one spaces in the zone, need to confirm the implementation'
      end
      space = spaces[0]
      space_lights = space.lights
      if space_lights.empty?
        space_lights = space.spaceType.get.lights
      end
      space_people = space.people
      if space_people.empty?
        space_people = space.spaceType.get.people
      end

      next if space_lights.empty? # skip space with no lights

      zone_name = zone.name.to_s
      next if zone_name =~ /data\s*center/i # skip data centers

      light_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Lights Electric Power')
      light_sensor.setKeyName(zone_name)
      light_sensor.setName("#{zone_name}_LSr".gsub(/[\s-]/, ''))
      light_sensor_name = light_sensor.name.to_s

      floor_area = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, 'Zone Floor Area')
      floor_area.setInternalDataIndexKeyName(zone_name)
      floor_area.setName("#{zone_name}_Area".gsub(/[\s-]/, ''))
      floor_area_name = floor_area.name.to_s

      # account for multiple lights (also work for single light)
      big_light = space_lights[0] # find the light with highest power (assuming specified by watts/area)
      space_lights.each do |light_x|
        big_light_power = big_light.definition.to_LightsDefinition.get.wattsperSpaceFloorArea.to_f
        light_x_power = light_x.definition.to_LightsDefinition.get.wattsperSpaceFloorArea.to_f
        if light_x_power > big_light_power
          big_light = light_x
        end
      end

      add_lights_prog_0 = ""
      add_lights_prog_null = ""
      light_id = 0
      space_lights.each do |light_x|
        light_id += 1
        light_x_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(light_x, 'Lights', 'Electric Power Level')
        light_x_actuator.setName("#{zone_name}_Light#{light_id.to_s}_Actuator".gsub(/[\s-]/, ''))
        light_x_actuator_name = light_x_actuator.name.to_s
        add_lights_prog_null += "\n      SET #{light_x_actuator_name} = NULL,"
        if light_x == big_light
          add_lights_prog_0 += "\n      SET #{light_x_actuator_name} = 0.02*#{floor_area_name}/0.09290304,"
          next
        end
        add_lights_prog_0 += "\n      SET #{light_x_actuator_name} = 0,"
      end

      light_ems_prog = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      light_ems_prog.setName("SET_#{zone_name}_Light_EMS_Program".gsub(/[\s-]/, ''))
      light_ems_prog_body = <<-EMS
      SET #{light_sensor_name}_IP=0.093*#{light_sensor_name}/#{floor_area_name},
      IF (#{business_sensor_name} <= 0) && (#{light_sensor_name}_IP >= 0.02),#{add_lights_prog_0}
      ELSE,#{add_lights_prog_null}
      ENDIF
      EMS
      light_ems_prog.setBody(light_ems_prog_body)

      light_ems_prog_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      light_ems_prog_manager.setName("SET_#{zone_name}_Light_EMS_Program_Manager")
      light_ems_prog_manager.setCallingPoint('AfterPredictorAfterHVACManagers')
      light_ems_prog_manager.addProgram(light_ems_prog)
    end
    return true
  end
end
