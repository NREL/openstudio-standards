
NECB_2011_Model.class_eval do
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
  def space_type_apply_internal_loads(space_type, set_people, set_lights, set_electric_equipment, set_gas_equipment, set_ventilation, set_infiltration)
    # Skip plenums
    # Check if the space type name
    # contains the word plenum.
    if space_type.name.get.to_s.downcase.include?('plenum')
      return false
    end
    if space_type.standardsSpaceType.is_initialized
      if space_type.standardsSpaceType.get.downcase.include?('plenum')
        return false
      end
    end

    # Get the standards data
    space_type_properties = space_type_get_standards_data(space_type)

    # Need to add a check, or it'll crash on space_type_properties['occupancy_per_area'].to_f below
    if space_type_properties.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} was not found in the standards data.")
      return false
    end
    # People
    people_have_info = false
    occupancy_per_area = space_type_properties['occupancy_per_area'].to_f
    people_have_info = true unless occupancy_per_area.zero?

    if set_people && people_have_info

      # Remove all but the first instance
      instances = space_type.people.sort
      if instances.size.zero?
        # Create a new definition and instance
        definition = OpenStudio::Model::PeopleDefinition.new(space_type.model)
        definition.setName("#{space_type.name} People Definition")
        instance = OpenStudio::Model::People.new(definition)
        instance.setName("#{space_type.name} People")
        instance.setSpaceType(space_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no people, one has been created.")
        instances << instance
      elsif instances.size > 1
        instances.each_with_index do |inst, i|
          next if i.zero?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
          inst.remove
        end
      end

      # Modify the definition of the instance
      space_type.people.sort.each do |inst|
        definition = inst.peopleDefinition
        unless occupancy_per_area.zero?
          definition.setPeopleperSpaceFloorArea(OpenStudio.convert(occupancy_per_area / 1000, 'people/ft^2', 'people/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set occupancy to #{occupancy_per_area} people/1000 ft^2.")
        end

        # set fraction radiant  ##
        definition.setFractionRadiant(0.3)
        
        # Clothing schedule for thermal comfort metrics
        clothing_sch = space_type.model.getScheduleRulesetByName('Clothing Schedule')
        if clothing_sch.is_initialized
          clothing_sch = clothing_sch.get
        else
          clothing_sch = OpenStudio::Model::ScheduleRuleset.new(space_type.model)
          clothing_sch.setName('Clothing Schedule')
          clothing_sch.defaultDaySchedule.setName('Clothing Schedule Default Winter Clothes')
          clothing_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)
          sch_rule = OpenStudio::Model::ScheduleRule.new(clothing_sch)
          sch_rule.daySchedule.setName('Clothing Schedule Summer Clothes')
          sch_rule.daySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.5)
          sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5), 1))
          sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30))
        end
        inst.setClothingInsulationSchedule(clothing_sch)

        # Air velocity schedule for thermal comfort metrics
        air_velo_sch = space_type.model.getScheduleRulesetByName('Air Velocity Schedule')
        if air_velo_sch.is_initialized
          air_velo_sch = air_velo_sch.get
        else
          air_velo_sch = OpenStudio::Model::ScheduleRuleset.new(space_type.model)
          air_velo_sch.setName('Air Velocity Schedule')
          air_velo_sch.defaultDaySchedule.setName('Air Velocity Schedule Default')
          air_velo_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
        end
        inst.setAirVelocitySchedule(air_velo_sch)

        # Work efficiency schedule for thermal comfort metrics
        work_efficiency_sch = space_type.model.getScheduleRulesetByName('Work Efficiency Schedule')
        if work_efficiency_sch.is_initialized
          work_efficiency_sch = work_efficiency_sch.get
        else
          work_efficiency_sch = OpenStudio::Model::ScheduleRuleset.new(space_type.model)
          work_efficiency_sch.setName('Work Efficiency Schedule')
          work_efficiency_sch.defaultDaySchedule.setName('Work Efficiency Schedule Default')
          work_efficiency_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        end
        inst.setWorkEfficiencySchedule(work_efficiency_sch)
      end

    end

    # Lights
    lights_have_info = false
    lighting_per_area = space_type_properties['lighting_per_area'].to_f
    lighting_per_person = space_type_properties['lighting_per_person'].to_f
    lights_frac_to_return_air = space_type_properties['lighting_fraction_to_return_air'].to_f
    lights_frac_radiant = space_type_properties['lighting_fraction_radiant'].to_f
    lights_frac_visible = space_type_properties['lighting_fraction_visible'].to_f
    lights_frac_replaceable = space_type_properties['lighting_fraction_replaceable'].to_f
    lights_have_info = true unless lighting_per_area.zero?
    lights_have_info = true unless lighting_per_person.zero?

    if set_lights && lights_have_info

      # Remove all but the first instance
      instances = space_type.lights.sort
      if instances.size.zero?
        definition = OpenStudio::Model::LightsDefinition.new(space_type.model)
        definition.setName("#{space_type.name} Lights Definition")
        instance = OpenStudio::Model::Lights.new(definition)
        instance.setName("#{space_type.name} Lights")
        instance.setSpaceType(space_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no lights, one has been created.")
        instances << instance
      elsif instances.size > 1
        instances.each_with_index do |inst, i|
          next if i.zero?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
          inst.remove
        end
      end

      # Modify the definition of the instance
      space_type.lights.sort.each do |inst|
        definition = inst.lightsDefinition
        unless lighting_per_area.zero?
          occSensLPDfactor = 1.0
          # NECB 2011 space types that require a reduction in the LPD to account for 
          # the requirement of an occupancy sensor (8.4.4.6(3) and 4.2.2.2(2))
          reduceLPDSpaces = ["Classroom/lecture/training", "Conf./meet./multi-purpose", "Lounge/recreation",
            "Conf./meet./multi-purpose", "Washroom-sch-A", "Washroom-sch-B", "Washroom-sch-C", "Washroom-sch-D", 
            "Washroom-sch-E", "Washroom-sch-F", "Washroom-sch-G", "Washroom-sch-H", "Washroom-sch-I", 
            "Dress./fitt. - performance arts", "Locker room", "Locker room-sch-A", "Locker room-sch-B", 
            "Locker room-sch-C", "Locker room-sch-D", "Locker room-sch-E", "Locker room-sch-F", "Locker room-sch-G",
            "Locker room-sch-H", "Locker room-sch-I", "Retail - dressing/fitting"]
          if reduceLPDSpaces.include?(space_type.standardsSpaceType.get)
            # Note that "Storage area", "Storage area - refrigerated", "Hospital - medical supply" and "Office - enclosed" 
            # LPD should only be reduced if their space areas are less than specific area values. 
            # This is checked in a space loop after this function in the calling routine.
            occSensLPDfactor = 0.9
          end
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f * occSensLPDfactor, 'W/ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set LPD to #{lighting_per_area} W/ft^2.")
        end
        unless lighting_per_person.zero?
          definition.setWattsperPerson(OpenStudio.convert(lighting_per_person.to_f, 'W/person', 'W/person').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set lighting to #{lighting_per_person} W/person.")
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
        # unless lights_frac_replaceable.zero?
        #  definition.setFractionReplaceable(lights_frac_replaceable)
        # end        
      end

      # If additional lights are specified, add those too
      additional_lighting_per_area = space_type_properties['additional_lighting_per_area'].to_f
      unless additional_lighting_per_area.zero?
        # Create the lighting definition
        additional_lights_def = OpenStudio::Model::LightsDefinition.new(space_type.model)
        additional_lights_def.setName("#{space_type.name} Additional Lights Definition")
        additional_lights_def.setWattsperSpaceFloorArea(OpenStudio.convert(additional_lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
        additional_lights_def.setReturnAirFraction(lights_frac_to_return_air)
        additional_lights_def.setFractionRadiant(lights_frac_radiant)
        additional_lights_def.setFractionVisible(lights_frac_visible)

        # Create the lighting instance and hook it up to the space type
        additional_lights = OpenStudio::Model::Lights.new(additional_lights_def)
        additional_lights.setName("#{space_type.name} Additional Lights")
        additional_lights.setSpaceType(space_type)
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
      instances = space_type.electricEquipment.sort
      if instances.size.zero?
        definition = OpenStudio::Model::ElectricEquipmentDefinition.new(space_type.model)
        definition.setName("#{space_type.name} Elec Equip Definition")
        instance = OpenStudio::Model::ElectricEquipment.new(definition)
        instance.setName("#{space_type.name} Elec Equip")
        instance.setSpaceType(space_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no electric equipment, one has been created.")
        instances << instance
      elsif instances.size > 1
        instances.each_with_index do |inst, i|
          next if i.zero?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
          inst.remove
        end
      end

      # Modify the definition of the instance
      space_type.electricEquipment.sort.each do |inst|
        definition = inst.electricEquipmentDefinition
        unless elec_equip_per_area.zero?
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(elec_equip_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set electric EPD to #{elec_equip_per_area} W/ft^2.")
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
      instances = space_type.gasEquipment.sort
      if instances.size.zero?
        definition = OpenStudio::Model::GasEquipmentDefinition.new(space_type.model)
        definition.setName("#{space_type.name} Gas Equip Definition")
        instance = OpenStudio::Model::GasEquipment.new(definition)
        instance.setName("#{space_type.name} Gas Equip")
        instance.setSpaceType(space_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no gas equipment, one has been created.")
        instances << instance
      elsif instances.size > 1
        instances.each_with_index do |inst, i|
          next if i.zero?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
          inst.remove
        end
      end

      # Modify the definition of the instance
      space_type.gasEquipment.sort.each do |inst|
        definition = inst.gasEquipmentDefinition
        unless gas_equip_per_area.zero?
          definition.setWattsperSpaceFloorArea(OpenStudio.convert(gas_equip_per_area.to_f, 'Btu/hr*ft^2', 'W/m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set gas EPD to #{elec_equip_per_area} Btu/hr*ft^2.")
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
    ventilation = space_type.designSpecificationOutdoorAir
    if ventilation.is_initialized
      ventilation = ventilation.get
    else
      ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new(space_type.model)
      ventilation.setName("#{space_type.name} Ventilation")
      space_type.setDesignSpecificationOutdoorAir(ventilation)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no ventilation specification, one has been created.")
    end

    if set_ventilation && ventilation_have_info

      # Modify the ventilation properties
      ventilation.setOutdoorAirMethod('Sum')
      unless ventilation_per_area.zero?
        ventilation.setOutdoorAirFlowperFloorArea(OpenStudio.convert(ventilation_per_area.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set ventilation per area to #{ventilation_per_area} cfm/ft^2.")
      end
      unless ventilation_per_person.zero?
        ventilation.setOutdoorAirFlowperPerson(OpenStudio.convert(ventilation_per_person.to_f, 'ft^3/min*person', 'm^3/s*person').get)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set ventilation per person to #{ventilation_per_person} cfm/person.")
      end
      unless ventilation_ach.zero?
        ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set ventilation to #{ventilation_ach} ACH.")
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
      instances = space_type.spaceInfiltrationDesignFlowRates.sort
      if instances.size.zero?
        instance = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space_type.model)
        instance.setName("#{space_type.name} Infiltration")
        instance.setSpaceType(space_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no infiltration objects, one has been created.")
        instances << instance
      elsif instances.size > 1
        instances.each_with_index do |inst, i|
          next if i.zero?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
          inst.remove
        end
      end

      # Modify each instance
      space_type.spaceInfiltrationDesignFlowRates.sort.each do |inst|
        unless infiltration_per_area_ext.zero?
          inst.setFlowperExteriorSurfaceArea(OpenStudio.convert(infiltration_per_area_ext.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set infiltration to #{ventilation_ach} per ft^2 exterior surface area.")
        end
        unless infiltration_per_area_ext_wall.zero?
          inst.setFlowperExteriorWallArea(OpenStudio.convert(infiltration_per_area_ext_wall.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set infiltration to #{infiltration_per_area_ext_wall} per ft^2 exterior wall area.")
        end
        unless infiltration_ach.zero?
          inst.setAirChangesperHour(infiltration_ach)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set infiltration to #{ventilation_ach} ACH.")
        end
      end

    end
  end
end
