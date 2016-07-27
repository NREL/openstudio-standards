
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::SpaceType
  # Returns standards data for selected space type and template
  #
  # @param [string] target template for lookup
  # @return [hash] hash of internal loads for different load types
  def get_standards_data(template)
    standards_building_type = if standardsBuildingType.is_initialized
                                standardsBuildingType.get
                              end
    standards_space_type = if standardsSpaceType.is_initialized
                             standardsSpaceType.get
                           end

    # populate search hash
    search_criteria = {
      'template' => template,
      'building_type' => standards_building_type,
      'space_type' => standards_space_type
    }

    # lookup space type properties

    space_type_properties = model.find_object($os_standards['space_types'], search_criteria)

    if space_type_properties.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Space type properties lookup failed: #{search_criteria}.")
      space_type_properties = {}
    end

    return space_type_properties
  end

  # Sets the color for the space types as shown
  # in the SketchUp plugin using render by space type.
  #
  # @param [string] target template for lookup
  # @return [Bool] returns true if successful, false if not.
  def set_rendering_color(template)
    # Get the standards data
    space_type_properties = get_standards_data(template)

    # Set the rendering color of the space type
    rgb = space_type_properties['rgb']
    if rgb.nil?
      return false
    end

    rgb = rgb.split('_')
    r = rgb[0].to_i
    g = rgb[1].to_i
    b = rgb[2].to_i
    rendering_color = OpenStudio::Model::RenderingColor.new(model)
    rendering_color.setRenderingRedValue(r)
    rendering_color.setRenderingGreenValue(g)
    rendering_color.setRenderingBlueValue(b)
    setRenderingColor(rendering_color)

    return true
  end

  # Sets the selected internal loads to standards-based or typical values.
  # For each category that is selected get all load instances. Remove all
  # but the first instance if multiple instances.  Add a new instance/definition
  # if no instance exists. Modify the definition for the remaining instance
  # to have the specified values. This method does not alter any
  # loads directly assigned to spaces.  This method skips plenums.
  #
  # @param set_people [Bool] if true, set the people density.
  # Also, assign reasonable clothing, air velocity, and work efficiency inputs
  # to allow reasonable thermal comfort metrics to be calculated.
  # @param set_lights [Bool] if true, set the lighting density, lighting fraction
  # to return air, fraction radiant, and fraction visible.
  # @param set_electric_equipment [Bool] if true, set the electric equipment density
  # @param set_gas_equipment [Bool] if true, set the gas equipment density
  # @param set_ventilation [Bool] if true, set the ventilation rates (per-person and per-area)
  # @param set_infiltration [Bool] if true, set the infiltration rates
  # @return [Bool] returns true if successful, false if not
  def set_internal_loads(template, set_people, set_lights, set_electric_equipment, set_gas_equipment, set_ventilation, set_infiltration)
    # Skip plenums
    # Check if the space type name
    # contains the word plenum.
    if name.get.to_s.downcase.include?('plenum')
      return false
    end
    if standardsSpaceType.is_initialized
      if standardsSpaceType.get.downcase.include?('plenum')
        return false
      end
    end

    # Get the standards data
    space_type_properties = get_standards_data(template)

    # Need to add a check, or it'll crash on space_type_properties['occupancy_per_area'].to_f below
    if space_type_properties.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} was not found in the standards data.")
      return false
    end
    # People
    people_have_info = false
    occupancy_per_area = space_type_properties['occupancy_per_area'].to_f
    people_have_info = true unless occupancy_per_area.zero?

    if set_people && people_have_info

      # Remove all but the first instance
      instances = people.sort
      if instances.size.zero?
        # Create a new definition and instance
        definition = OpenStudio::Model::PeopleDefinition.new(model)
        definition.setName("#{name} People Definition")
        instance = OpenStudio::Model::People.new(definition)
        instance.setName("#{name} People")
        instance.setSpaceType(self)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} had no people, one has been created.")
        instances << instance
      elsif instances.size > 1
        for i in 0..instances.size - 1
          next if i.zero?
          instance = instances[i]
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{instance.name} from #{name}.")
          instance.remove
        end
      end

      # Modify the definition of the instance
      instances.each do |instance|
        definition = instance.peopleDefinition
        unless occupancy_per_area.zero?
          definition.setPeopleperSpaceFloorArea(OpenStudio.convert(occupancy_per_area / 1000, 'people/ft^2', 'people/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set occupancy to #{occupancy_per_area} people/1000 ft^2.")
        end

        # Clothing schedule for thermal comfort metrics
        clothing_sch = model.getScheduleRulesetByName('Clothing Schedule')
        if clothing_sch.is_initialized
          clothing_sch = clothing_sch.get
        else
          clothing_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          clothing_sch.setName('Clothing Schedule')
          clothing_sch.defaultDaySchedule.setName('Clothing Schedule Default Winter Clothes')
          clothing_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)
          sch_rule = OpenStudio::Model::ScheduleRule.new(clothing_sch)
          sch_rule.daySchedule.setName('Clothing Schedule Summer Clothes')
          sch_rule.daySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.5)
          sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5), 1))
          sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30))
        end
        instance.setClothingInsulationSchedule(clothing_sch)

        # Air velocity schedule for thermal comfort metrics
        air_velo_sch = model.getScheduleRulesetByName('Air Velocity Schedule')
        if air_velo_sch.is_initialized
          air_velo_sch = air_velo_sch.get
        else
          air_velo_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          air_velo_sch.setName('Air Velocity Schedule')
          air_velo_sch.defaultDaySchedule.setName('Air Velocity Schedule Default')
          air_velo_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
        end
        instance.setAirVelocitySchedule(air_velo_sch)

        # Work efficiency schedule for thermal comfort metrics
        work_efficiency_sch = model.getScheduleRulesetByName('Work Efficiency Schedule')
        if work_efficiency_sch.is_initialized
          work_efficiency_sch = work_efficiency_sch.get
        else
          work_efficiency_sch = OpenStudio::Model::ScheduleRuleset.new(model)
          work_efficiency_sch.setName('Work Efficiency Schedule')
          work_efficiency_sch.defaultDaySchedule.setName('Work Efficiency Schedule Default')
          work_efficiency_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        end
        instance.setWorkEfficiencySchedule(work_efficiency_sch)
      end

    end

    # Lights
    lights_have_info = false
    lighting_per_area = space_type_properties['lighting_per_area'].to_f
    lighting_per_person = space_type_properties['lighting_per_person'].to_f
    lights_frac_to_return_air = space_type_properties['lighting_fraction_to_return_air'].to_f
    lights_frac_radiant = space_type_properties['lighting_fraction_radiant'].to_f
    lights_frac_visible = space_type_properties['lighting_fraction_visible'].to_f
    lights_have_info = true unless lighting_per_area.zero?
    lights_have_info = true unless lighting_per_person.zero?

    if set_lights && lights_have_info

      # Remove all but the first instance
      instances = lights.sort
      if instances.size.zero?
        definition = OpenStudio::Model::LightsDefinition.new(model)
        definition.setName("#{name} Lights Definition")
        instance = OpenStudio::Model::Lights.new(definition)
        instance.setName("#{name} Lights")
        instance.setSpaceType(self)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} had no lights, one has been created.")
        instances << instance
      elsif instances.size > 1
        for i in 0..instances.size - 1
          next if i.zero?
          instance = instances[i]
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{instance.name} from #{name}.")
          instance.remove
        end
      end

      # Modify the definition of the instance
      instances.each do |instance|
        definition = instance.lightsDefinition
        unless lighting_per_area.zero?
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set LPD to #{lighting_per_area} W/ft^2.")
        end
        unless lighting_per_person.zero?
          definition.setWattsperPerson(OpenStudio.convert(lighting_per_person.to_f, 'W/person', 'W/person').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set lighting to #{lighting_per_person} W/person.")
        end
        unless lights_frac_to_return_air.zero?
          definition.setReturnAirFraction(lights_frac_to_return_air)
        end
        unless lights_frac_radiant.zero?
          definition.setFractionRadiant(lights_frac_radiant)
        end
        unless lights_frac_visible.zero?
          definition.setFractionVisible(lights_frac_visible)
        end
      end

      # If additional lights are specified, add those too
      additional_lighting_per_area = space_type_properties['additional_lighting_per_area'].to_f
      unless additional_lighting_per_area.zero?
        # Create the lighting definition
        additional_lights_def = OpenStudio::Model::LightsDefinition.new(model)
        additional_lights_def.setName("#{name} Additional Lights Definition")
        additional_lights_def.setWattsperSpaceFloorArea(OpenStudio.convert(additional_lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
        additional_lights_def.setReturnAirFraction(lights_frac_to_return_air)
        additional_lights_def.setFractionRadiant(lights_frac_radiant)
        additional_lights_def.setFractionVisible(lights_frac_visible)

        # Create the lighting instance and hook it up to the space type
        additional_lights = OpenStudio::Model::Lights.new(additional_lights_def)
        additional_lights.setName("#{name} Additional Lights")
        additional_lights.setSpaceType(self)
      end

    end

    # Electric Equipment
    elec_equip_have_info = false
    elec_equip_per_area = space_type_properties['electric_equipment_per_area'].to_f
    elec_equip_frac_latent = space_type_properties['electric_equipment_fraction_latent'].to_f
    elec_equip_frac_radiant = space_type_properties['electric_equipment_fraction_radiant'].to_f
    elec_equip_frac_lost = space_type_properties['electric_equipment_fraction_lost'].to_f
    elec_equip_have_info = true unless elec_equip_per_area.zero?

    if set_electric_equipment && elec_equip_have_info

      # Remove all but the first instance
      instances = electricEquipment.sort
      if instances.size.zero?
        definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        definition.setName("#{name} Elec Equip Definition")
        instance = OpenStudio::Model::ElectricEquipment.new(definition)
        instance.setName("#{name} Elec Equip")
        instance.setSpaceType(self)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} had no electric equipment, one has been created.")
        instances << instance
      elsif instances.size > 1
        for i in 0..instances.size - 1
          next if i.zero?
          instance = instances[i]
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{instance.name} from #{name}.")
          instance.remove
        end
      end

      # Modify the definition of the instance
      instances.each do |instance|
        definition = instance.electricEquipmentDefinition
        unless elec_equip_per_area.zero?
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(elec_equip_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set electric EPD to #{elec_equip_per_area} W/ft^2.")
        end
        unless elec_equip_frac_latent.zero?
          definition.setFractionLatent(elec_equip_frac_latent)
        end
        unless elec_equip_frac_radiant.zero?
          definition.setFractionRadiant(elec_equip_frac_radiant)
        end
        unless elec_equip_frac_lost.zero?
          definition.setFractionLost(elec_equip_frac_lost)
        end
      end

    end

    # Gas Equipment
    gas_equip_have_info = false
    gas_equip_per_area = space_type_properties['gas_equipment_per_area'].to_f
    gas_equip_frac_latent = space_type_properties['gas_equipment_fraction_latent'].to_f
    gas_equip_frac_radiant = space_type_properties['gas_equipment_fraction_radiant'].to_f
    gas_equip_frac_lost = space_type_properties['gas_equipment_fraction_lost'].to_f
    gas_equip_have_info = true unless gas_equip_per_area.zero?

    if set_gas_equipment && gas_equip_have_info

      # Remove all but the first instance
      instances = gasEquipment.sort
      if instances.size.zero?
        definition = OpenStudio::Model::GasEquipmentDefinition.new(model)
        definition.setName("#{name} Gas Equip Definition")
        instance = OpenStudio::Model::GasEquipment.new(definition)
        instance.setName("#{name} Gas Equip")
        instance.setSpaceType(self)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} had no gas equipment, one has been created.")
        instances << instance
      elsif instances.size > 1
        for i in 0..instances.size - 1
          next if i.zero?
          instance = instances[i]
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{instance.name} from #{name}.")
          instance.remove
        end
      end

      # Modify the definition of the instance
      instances.each do |instance|
        definition = instance.gasEquipmentDefinition
        unless gas_equip_per_area.zero?
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(gas_equip_per_area.to_f, 'Btu/hr*ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set gas EPD to #{elec_equip_per_area} Btu/hr*ft^2.")
        end
        unless gas_equip_frac_latent.zero?
          definition.setFractionLatent(gas_equip_frac_latent)
        end
        unless gas_equip_frac_radiant.zero?
          definition.setFractionRadiant(gas_equip_frac_radiant)
        end
        unless gas_equip_frac_lost.zero?
          definition.setFractionLost(gas_equip_frac_lost)
        end
      end

    end

    # Ventilation
    ventilation_have_info = false
    ventilation_per_area = space_type_properties['ventilation_per_area'].to_f
    ventilation_per_person = space_type_properties['ventilation_per_person'].to_f
    ventilation_ach = space_type_properties['ventilation_air_changes'].to_f
    ventilation_have_info = true unless ventilation_per_area.zero?
    ventilation_have_info = true unless ventilation_per_person.zero?
    ventilation_have_info = true unless ventilation_ach.zero?

    # Get the design OA or create a new one if none exists
    ventilation = designSpecificationOutdoorAir
    if ventilation.is_initialized
      ventilation = ventilation.get
    else
      ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new(model)
      ventilation.setName("#{name} Ventilation")
      setDesignSpecificationOutdoorAir(ventilation)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} had no ventilation specification, one has been created.")
    end

    if set_ventilation && ventilation_have_info

      # Modify the ventilation properties
      ventilation.setOutdoorAirMethod('Sum')
      unless ventilation_per_area.zero?
        ventilation.setOutdoorAirFlowperFloorArea(OpenStudio.convert(ventilation_per_area.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set ventilation per area to #{ventilation_per_area} cfm/ft^2.")
      end
      unless ventilation_per_person.zero?
        ventilation.setOutdoorAirFlowperPerson(OpenStudio.convert(ventilation_per_person.to_f, 'ft^3/min*person', 'm^3/s*person').get)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set ventilation per person to #{ventilation_per_person} cfm/person.")
      end
      unless ventilation_ach.zero?
        ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set ventilation to #{ventilation_ach} ACH.")
      end

    elsif set_ventilation && !ventilation_have_info

      # All space types must have a design spec OA
      # object for ventilation controls to work correctly,
      # even if the values are all zero.
      ventilation.setOutdoorAirFlowperFloorArea(0)
      ventilation.setOutdoorAirFlowperPerson(0)
      ventilation.setOutdoorAirFlowAirChangesperHour(0)

    end

    # Infiltration
    infiltration_have_info = false
    infiltration_per_area_ext = space_type_properties['infiltration_per_exterior_area'].to_f
    infiltration_per_area_ext_wall = space_type_properties['infiltration_per_exterior_wall_area'].to_f
    infiltration_ach = space_type_properties['infiltration_air_changes'].to_f
    unless infiltration_per_area_ext.zero? && infiltration_per_area_ext_wall.zero? && infiltration_ach.zero?
      infiltration_have_info = true
    end

    if set_infiltration && infiltration_have_info

      # Remove all but the first instance
      instances = spaceInfiltrationDesignFlowRates.sort
      if instances.size.zero?
        instance = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        instance.setName("#{name} Infiltration")
        instance.setSpaceType(self)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} had no infiltration objects, one has been created.")
        instances << instance
      elsif instances.size > 1
        for i in 0..instances.size - 1
          next if i.zero?
          instance = instances[i]
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{instance.name} from #{name}.")
          instance.remove
        end
      end

      # Modify each instance
      instances.each do |instance|
        unless infiltration_per_area_ext.zero?
          instance.setFlowperExteriorSurfaceArea(OpenStudio.convert(infiltration_per_area_ext.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set infiltration to #{ventilation_ach} per ft^2 exterior surface area.")
        end
        unless infiltration_per_area_ext_wall.zero?
          instance.setFlowperExteriorWallArea(OpenStudio.convert(infiltration_per_area_ext_wall.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set infiltration to #{infiltration_per_area_ext_wall} per ft^2 exterior wall area.")
        end
        unless infiltration_ach.zero?
          instance.setAirChangesperHour(infiltration_ach)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set infiltration to #{ventilation_ach} ACH.")
        end
      end

    end
  end

  # Sets the schedules for the selected internal loads to typical schedules.
  # Get the default schedule set for this space type if one exists or make
  # one if none exists. For each category that is selected, add the typical
  # schedule for this category to the default schedule set.
  # This method does not alter any schedules of any internal loads that
  # does not inherit from the default schedule set.
  #
  # @param set_people [Bool] if true, set the occupancy and activity schedules
  # @param set_lights [Bool] if true, set the lighting schedule
  # @param set_electric_equipment [Bool] if true, set the electric schedule schedule
  # @param set_gas_equipment [Bool] if true, set the gas equipment density
  # @param set_infiltration [Bool] if true, set the infiltration schedule
  # @param make_thermostat [Bool] if true, makes a thermostat for this space type from the
  # schedules listed for the space type.  This thermostat is not hooked to any zone by this method,
  # but may be found and used later.
  # @return [Bool] returns true if successful, false if not
  def set_internal_load_schedules(template, set_people, set_lights, set_electric_equipment, set_gas_equipment, set_ventilation, set_infiltration, make_thermostat)
    # Get the standards data
    space_type_properties = get_standards_data(template)

    # Get the default schedule set
    # or create a new one if none exists.
    default_sch_set = nil
    if defaultScheduleSet.is_initialized
      default_sch_set = defaultScheduleSet.get
    else
      default_sch_set = OpenStudio::Model::DefaultScheduleSet.new(model)
      default_sch_set.setName("#{name} Schedule Set")
      setDefaultScheduleSet(default_sch_set)
    end

    # People
    if set_people
      occupancy_sch = space_type_properties['occupancy_schedule']
      unless occupancy_sch.nil?
        default_sch_set.setNumberofPeopleSchedule(model.add_schedule(occupancy_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set occupancy schedule to #{occupancy_sch}.")
      end

      occupancy_activity_sch = space_type_properties['occupancy_activity_schedule']
      unless occupancy_activity_sch.nil?
        default_sch_set.setPeopleActivityLevelSchedule(model.add_schedule(occupancy_activity_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set occupant activity schedule to #{occupancy_activity_sch}.")
      end

    end

    # Lights
    if set_lights

      lighting_sch = space_type_properties['lighting_schedule']
      unless lighting_sch.nil?
        default_sch_set.setLightingSchedule(model.add_schedule(lighting_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set lighting schedule to #{lighting_sch}.")
      end

    end

    # Electric Equipment
    if set_electric_equipment

      elec_equip_sch = space_type_properties['electric_equipment_schedule']
      unless elec_equip_sch.nil?
        default_sch_set.setElectricEquipmentSchedule(model.add_schedule(elec_equip_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set electric equipment schedule to #{elec_equip_sch}.")
      end

    end

    # Gas Equipment
    if set_gas_equipment

      gas_equip_sch = space_type_properties['gas_equipment_schedule']
      unless gas_equip_sch.nil?
        default_sch_set.setGasEquipmentSchedule(model.add_schedule(gas_equip_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set gas equipment schedule to #{gas_equip_sch}.")
      end

    end

    # Infiltration
    if set_infiltration

      infiltration_sch = space_type_properties['infiltration_schedule']
      unless infiltration_sch.nil?
        default_sch_set.setInfiltrationSchedule(model.add_schedule(infiltration_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set infiltration schedule to #{infiltration_sch}.")
      end

    end

    # Thermostat
    if make_thermostat

      thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
      thermostat.setName("#{name} Thermostat")

      heating_setpoint_sch = space_type_properties['heating_setpoint_schedule']
      unless heating_setpoint_sch.nil?
        thermostat.setHeatingSetpointTemperatureSchedule(model.add_schedule(heating_setpoint_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set heating setpoint schedule to #{heating_setpoint_sch}.")
      end

      cooling_setpoint_sch = space_type_properties['cooling_setpoint_schedule']
      unless cooling_setpoint_sch.nil?
        thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule(cooling_setpoint_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{name} set cooling setpoint schedule to #{cooling_setpoint_sch}.")
      end

    end

    return true
  end

  # Returns standards data for selected construction
  #
  # @param [string] target template for lookup
  # @param [string] intended_surface_type template for lookup
  # @param [string] standards_construction_type template for lookup
  # @return [hash] hash of construction properties
  def get_construction_properties(template, intended_surface_type, standards_construction_type)
    # get building_category value
    building_category = if !get_standards_data(template).nil? && get_standards_data(template)['is_residential'] == 'Yes'
                          'Residential'
                        else
                          'Nonresidential'
                        end

    # get climate_zone_set
    climate_zone = model.get_building_climate_zone_and_building_type['climate_zone']
    climate_zone_set = model.find_climate_zone_set(climate_zone, template)

    # populate search hash
    search_criteria = {
      'template' => template,
      'climate_zone_set' => climate_zone_set,
      'intended_surface_type' => intended_surface_type,
      'standards_construction_type' => standards_construction_type,
      'building_category' => building_category
    }

    # switch to use this but update test in standards and measures to load this outside of the method
    construction_properties = model.find_object($os_standards['construction_properties'], search_criteria)

    return construction_properties
  end
end
