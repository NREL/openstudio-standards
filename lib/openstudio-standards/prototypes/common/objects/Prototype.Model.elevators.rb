class Standard
  # Add an elevator the the specified space
  #
  # @param space [OpenStudio::Model::Space] the space
  # to assign the elevators to.
  # @param number_of_elevators [Integer] the number of elevators
  # @param elevator_type [String] valid choices are
  # Traction, Hydraulic
  # @param elevator_schedule [String] the name of the elevator schedule
  # @param elevator_fan_schedule [String] the name of the elevator fan schedule
  # @param elevator_lights_schedule [String] the name of the elevator lights schedule
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::ElectricEquipment] the resulting elevator
  def model_add_elevator(model,
                         space,
                         number_of_elevators,
                         elevator_type,
                         elevator_schedule,
                         elevator_fan_schedule,
                         elevator_lights_schedule,
                         building_type = nil)

    # Lift motor assumptions
    lift_pwr_w = model_elevator_lift_power(model, elevator_type, building_type)

    # Size assumptions
    length_ft = 6.66
    width_ft = 4.25
    height_ft = 8.0
    area_ft2 = length_ft * width_ft
    volume_ft3 = area_ft2 * height_ft

    # Ventilation assumptions
    vent_rate_acm = 1 # air changes per minute
    vent_rate_cfm = volume_ft3 / vent_rate_acm
    vent_pwr_w = model_elevator_fan_pwr(model, vent_rate_cfm)

    # Heating fraction radiant assumptions
    elec_equip_frac_radiant = 0.5

    # Lighting assumptions
    design_ltg_lm_per_ft2 = 30
    light_loss_factor = 0.75
    pct_incandescent = model_elevator_lighting_pct_incandescent(model)
    pct_led = 1.0 - pct_incandescent

    incandescent_efficacy_lm_per_w = 10.0
    led_efficacy_lm_per_w = 35.0
    target_ltg_lm_per_ft2 = design_ltg_lm_per_ft2 / light_loss_factor # 40
    target_ltg_lm = target_ltg_lm_per_ft2 * area_ft2 # 1132.2
    lm_incandescent = target_ltg_lm * pct_incandescent # 792.54
    lm_led = target_ltg_lm * pct_led # 339.66
    w_incandescent = lm_incandescent / incandescent_efficacy_lm_per_w # 79.254
    w_led = lm_led / led_efficacy_lm_per_w # 9.7
    lighting_pwr_w = w_incandescent + w_led

    # Elevator lift motor
    elevator_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elevator_definition.setName('Elevator Lift Motor')
    elevator_definition.setDesignLevel(lift_pwr_w)
    elevator_definition.setFractionRadiant(elec_equip_frac_radiant)

    elevator_equipment = OpenStudio::Model::ElectricEquipment.new(elevator_definition)
    elevator_equipment.setName("#{number_of_elevators.round} Elevator Lift Motors")
    elevator_sch = model_add_schedule(model, elevator_schedule)
    elevator_equipment.setSchedule(elevator_sch)
    elevator_equipment.setSpace(space)
    elevator_equipment.setMultiplier(number_of_elevators)

    # Elevator fan
    elevator_fan_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elevator_fan_definition.setName('Elevator Fan')
    elevator_fan_definition.setDesignLevel(vent_pwr_w)
    elevator_fan_definition.setFractionRadiant(elec_equip_frac_radiant)

    elevator_fan_equipment = OpenStudio::Model::ElectricEquipment.new(elevator_fan_definition)
    elevator_fan_equipment.setName("#{number_of_elevators.round} Elevator Fans")
    elevator_fan_sch = model_add_schedule(model, elevator_fan_schedule)
    elevator_fan_equipment.setSchedule(elevator_fan_sch)
    elevator_fan_equipment.setSpace(space)
    elevator_fan_equipment.setMultiplier(number_of_elevators)

    # Elevator lights
    elevator_lights_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elevator_lights_definition.setName('Elevator Lights')
    elevator_lights_definition.setDesignLevel(lighting_pwr_w)
    elevator_lights_definition.setFractionRadiant(elec_equip_frac_radiant)

    elevator_lights_equipment = OpenStudio::Model::ElectricEquipment.new(elevator_lights_definition)
    elevator_lights_equipment.setName("#{number_of_elevators.round} Elevator Lights")
    elevator_lights_sch = model_add_schedule(model, elevator_lights_schedule)
    elevator_lights_equipment.setSchedule(elevator_lights_sch)
    elevator_lights_equipment.setSpace(space)
    elevator_lights_equipment.setMultiplier(number_of_elevators)

    return elevator_equipment
  end

  # Determines the power required by an individual elevator
  # of a given type.  Defaults to the values used by the DOE
  # prototype buildings.
  # @param elevator_type [String] valid choices are
  # Traction, Hydraulic
  def model_elevator_lift_power(model, elevator_type, building_type)
    lift_pwr_w = 0
    if elevator_type == 'Traction'
      lift_pwr_w = 20_370.0
    elsif elevator_type == 'Hydraulic'
      lift_pwr_w = 16_055.0
    else
      lift_pwr_w = 16_055.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Elevator type '#{elevator_type}', not recognized, will assume Hydraulic elevator, #{lift_pwr_w} W.")
    end

    return lift_pwr_w
  end

  # Determines the percentage of the elevator cab
  # lighting that is incandescent.  The remainder
  # is assumed to be LED.  Defaults to 70% incandescent,
  # representing older elevators.
  def model_elevator_lighting_pct_incandescent(model)
    pct_incandescent = 0.7
    return pct_incandescent
  end

  # Determines the power of the elevator ventilation fan.
  # Defaults to 90.1-2010, which had no requirement
  # for ventilation fan efficiency.
  # @return [Double] the ventilaton fan power (W)
  def model_elevator_fan_pwr(model, vent_rate_cfm)
    vent_pwr_per_flow_w_per_cfm = 0.33
    vent_pwr_w = vent_pwr_per_flow_w_per_cfm * vent_rate_cfm

    return vent_pwr_w
  end

  # Add elevators to the model based on the building size,
  # number of stories, and building type.  Logic was derived
  # from the DOE prototype buildings.
  #
  # @return [OpenStudio::Model::ElectricEquipment] the resulting elevator
  def model_add_elevators(model)
    # determine effective number of stories
    effective_num_stories = model_effective_num_stories(model)

    # determine elevator type
    # todo - add logic here or upstream to have some multi-story buildings without elevators (e.g. small multi-family and small hotels)
    elevator_type = nil
    if effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 2
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', 'The building only has 1 story, no elevators will be added.')
      return nil # don't add elevators
    elsif effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 6
      elevator_type = 'Hydraulic'
    else
      elevator_type = 'Traction'
    end

    # determine space to put elevator load in
    # largest bottom story (including basement) space that has multiplier of 1
    bottom_spaces = {}
    bottom_story = effective_num_stories[:story_hash].keys.first
    bottom_story.spaces.each do |space|
      next if space.multiplier > 1
      bottom_spaces[space] = space.floorArea
    end
    target_space = bottom_spaces.key(bottom_spaces.values.max)

    # determine number of elevators
    number_of_pass_elevators = 0.0
    number_of_freight_elevators = 0.0
    building_type_hash = {}

    # apply building type specific log to add to number of elevators based on Beyer (2009) rules of thumb
    space_type_hash = model_create_space_type_hash(model)
    space_type_hash.each do |space_type, hash|
      # update building_type_hash
      if building_type_hash.key?(hash[:stds_bldg_type])
        building_type_hash[hash[:stds_bldg_type]] += hash[:floor_area]
      else
        building_type_hash[hash[:stds_bldg_type]] = hash[:floor_area]
      end

      # building type specific notes; prototype uses Beyer (2009) rules of thumb
      area_per_pass_elev_ft2 = nil
      units_per_pass_elevator = nil
      beds_per_pass_elevator = nil
      area_per_freight_elev_ft2 = nil
      units_per_freight_elevator = nil
      beds_per_freight_elevator = nil
      if ['Office', 'SmallOffice', 'MediumOffice', 'LargeOffice'].include?(hash[:stds_bldg_type])
        # The office buildings have one elevator for every 45,000 ft2 (4,181 m2),
        # plus one service elevator for the large office building (500,000 ft^2).
        area_per_pass_elev_ft2 = 45_000
        bldg_area_ft2 = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get
        if bldg_area_ft2 > 500_000
          area_per_freight_elev_ft2 = 500_000
        end
      elsif ['SmallHotel', 'LargeHotel'].include?(hash[:stds_bldg_type])
        # The hotels have one elevator for every 75 rooms.
        if hash[:stds_space_type].include?('GuestRoom')
          units_per_pass_elevator = 75.0
        end
        # The large hotel includes one service elevator for every two public elevators,
        # plus one additional elevator for the dining and banquet facilities on the top floor.
        # None of the other space types generate elevators.
        if ['LargeHotel'].include?(hash[:stds_bldg_type]) && hash[:stds_space_type].include?('GuestRoom')
          units_per_freight_elevator = 150.0
        elsif ['LargeHotel'].include?(hash[:stds_bldg_type]) && ['Banquet', 'Cafe'].include?(hash[:stds_space_type])
          area_per_pass_elev_ft2 = 10_000
        end
      elsif ['MidriseApartment', 'HighriseApartment'].include?(hash[:stds_bldg_type]) && hash[:stds_space_type].include?('Apartment')
        # The apartment building has one elevator for every 90 units
        units_per_pass_elevator = 90.0
      elsif ['Hospital'].include?(hash[:stds_bldg_type])
        # The hospital has one public and one service elevator for every 100 beds (250 total),
        # plus two elevators for the offices and cafeteria on the top floor.
        # None of the other space types generate elevators.
        if ['PatRoom', 'ICU_PatRm', 'ICU_Open'].include?(hash[:stds_space_type])
          beds_per_pass_elevator = 100.0
          beds_per_freight_elevator = 100.0
        elsif ['Dining', 'Kitchen', 'Office'].include?(hash[:stds_space_type])
          area_per_pass_elev_ft2 = 12_500
        end
      elsif ['PrimarySchool', 'SecondarySchool'].include?(hash[:stds_bldg_type])
        # 210,887 ft^2 secondary school prototype has 2 elevators
        area_per_pass_elev_ft2 = 100_000
      elsif ['Outpatient'].include?(hash[:stds_bldg_type])
        # 40,946 Outpatient has 3 elevators
        area_per_pass_elev_ft2 = 15_000
      elsif ['Warehouse'].include?(hash[:stds_bldg_type])
        # Warehouse has no elevators, but assume some would be needed
        area_per_freight_elev_ft2 = 250_000
      else
        # TODO: - improve catchall for building types without elevator data, using same value as what Outpatient would be if not already in space type
        # includes RetailStandalone, RetailStripmall, QuickServiceRestaurant, FullServiceRestaurant, SuperMarket (made unique logic above for warehouse)
        area_per_pass_elev_ft2 = 15_000
      end

      # passenger elevators
      if area_per_pass_elev_ft2
        pass_elevs = hash[:floor_area] / OpenStudio.convert(area_per_pass_elev_ft2, 'ft^2', 'm^2').get
        number_of_pass_elevators += pass_elevs
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "For #{space_type.name}, adding #{pass_elevs.round(1)} passenger elevators at 1 per #{area_per_pass_elev_ft2.round} ft^2.")
      end

      if units_per_pass_elevator
        pass_elevs = hash[:num_units] / units_per_pass_elevator
        number_of_pass_elevators += pass_elevs
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "For #{space_type.name}, adding #{pass_elevs.round(1)} passenger elevators at 1 per #{units_per_pass_elevator} units.")
      end

      if beds_per_pass_elevator
        pass_elevs = hash[:num_beds] / beds_per_pass_elevator
        number_of_pass_elevators += pass_elevs
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "For #{space_type.name}, adding #{pass_elevs.round(1)} passenger elevators at 1 per #{beds_per_pass_elevator} beds.")
      end

      # freight or service elevators
      if area_per_freight_elev_ft2
        freight_elevs = hash[:floor_area] / OpenStudio.convert(area_per_freight_elev_ft2, 'ft^2', 'm^2').get
        number_of_freight_elevators += freight_elevs
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "For #{space_type.name}, adding #{freight_elevs.round(1)} freight/service elevators at 1 per #{area_per_freight_elev_ft2.round} ft^2.")
      end

      if units_per_freight_elevator
        freight_elevs = hash[:num_units] / units_per_freight_elevator
        number_of_freight_elevators += freight_elevs
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "For #{space_type.name}, adding #{freight_elevs.round(1)} freight/service elevators at 1 per #{units_per_freight_elevator} units.")
      end

      if beds_per_freight_elevator
        freight_elevs = hash[:num_beds] / beds_per_freight_elevator
        number_of_freight_elevators += freight_elevs
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "For #{space_type.name}, adding #{freight_elevs.round(1)} freight/service elevators at 1 per #{beds_per_freight_elevator} beds.")
      end
    end

    # adjust number of elevators (can be double but if not 0 must be at least 1.0)
    if (number_of_pass_elevators > 0.0) && (number_of_pass_elevators < 1.0)
      number_of_pass_elevators = 1.0
    end
    if (number_of_freight_elevators > 0.0) && (number_of_freight_elevators < 1.0)
      number_of_freight_elevators = 1.0
    end
    number_of_elevators = number_of_pass_elevators + number_of_freight_elevators

    building_type = building_type_hash.key(building_type_hash.values.max)
    # rename space types as needed
    if building_type == 'Office'
      building_type = model_remap_office(model, building_type_hash['Office'])
    end
    if building_type == 'SmallHotel' then building_type = 'LargeHotel' end # no elevator schedules for SmallHotel
    if building_type == 'PrimarySchool' then building_type = 'SecondarySchool' end # no elevator schedules for PrimarySchool
    if building_type == 'Retail' then building_type = 'RetailStandalone' end # no elevator schedules for PrimarySchool
    if building_type == 'StripMall' then building_type = 'RetailStripmall' end # no elevator schedules for PrimarySchool
    if building_type == 'Outpatient'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', 'Outpatient ElevatorPumpRoom plug loads contain the elevator loads. Not adding extra elevator loads on top of it.')
    end

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
      'template' => template,
      'building_type' => building_type
    }

    prototype_input = model_find_object(standards_data['prototype_inputs'], search_criteria)
    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.elevators', "Could not find prototype inputs for #{search_criteria}, cannot add elevators.")
      return nil
    end

    # assign schedules
    if ['Office', 'MediumOffice', 'MidriseApartment', 'HighriseApartment', 'SecondarySchool'].include?(building_type)
      elevator_schedule = prototype_input['elevator_schedule']
      elevator_fan_schedule = prototype_input['elevator_fan_schedule']
      elevator_lights_schedule = prototype_input['elevator_fan_schedule']
    elsif ['LargeHotel', 'Hospital', 'LargeOffice'].include?(building_type)
      elevator_schedule = prototype_input['exterior_fuel_equipment1_schedule']
      elevator_fan_schedule = prototype_input['exterior_fuel_equipment2_schedule']
      elevator_lights_schedule = prototype_input['exterior_fuel_equipment2_schedule']
    else

      # identify occupancy schedule from largest space type of this building type
      space_type_size = {}
      space_type_hash.each do |space_type, hash|
        next unless building_type.include?(hash[:stds_bldg_type])
        space_type_size[space_type] = hash[:floor_area]
      end

      # Get the largest space type
      largest_space_type = space_type_size.key(space_type_size.values.max)

      # Get the occ sch, if one is specified
      occ_sch = nil
      if largest_space_type.defaultScheduleSet.is_initialized
        if largest_space_type.defaultScheduleSet.get.numberofPeopleSchedule.is_initialized
          occ_sch = largest_space_type.defaultScheduleSet.get.numberofPeopleSchedule.get
        end
      else
        occ_sch = model.alwaysOffDiscreteSchedule
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.elevators', "No occupancy schedule was specified for #{largest_space_type.name}, an always off schedule will be used for the elvevators and the elevators will never run.")
      end

      # clone and assign to elevator
      elev_sch = occ_sch.clone(model)
      elevator_schedule = elev_sch.name.to_s
      elevator_fan_schedule = elev_sch.name.to_s
      elevator_lights_schedule = elev_sch.name.to_s

      # TODO: - scale down peak value based on building type lookup, or make parametric schedule based on hours of operation
      # includes RetailStandalone, RetailStripmall, QuickServiceRestaurant, FullServiceRestaurant, SuperMarket (made unique logic above for warehouse)

      if building_type == 'Warehouse'
        # alter default profile, summer, winter, and rules
        max_value = 0.2
        elev_sch = elev_sch.to_ScheduleRuleset.get
        day_schedules = []
        elev_sch.scheduleRules.each do |rule|
          day_schedules << rule.daySchedule
        end
        day_schedules << elev_sch.defaultDaySchedule
        day_schedules << elev_sch.summerDesignDaySchedule
        day_schedules << elev_sch.winterDesignDaySchedule

        day_schedules.each do |day_schedule|
          values = day_schedule.values
          times = day_schedule.times
          values.each_with_index do |value, i|
            if value > max_value
              day_schedule.addValue(times[i], max_value)
            end
          end
        end
      end

    end

    # TODO: - currently add elevator doesn't allow me to choose the size of the elevator?
    # ref bldg pdf has formula for motor hp based on weight, speed, counterweight fraction and mech eff (in 5.1.4)

    # TODO: - should schedules change based on traction vs. hydraulic vs. just taking what is in prototype.

    # call add_elevator in Prototype.hvac_systems.rb to create elevator objects
    elevator = model_add_elevator(model,
                                  target_space,
                                  number_of_elevators,
                                  elevator_type,
                                  elevator_schedule,
                                  elevator_fan_schedule,
                                  elevator_lights_schedule,
                                  building_type)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "Adding #{elevator.multiplier.round(1)} #{elevator_type} elevators to the model in #{target_space.name}.")

    # check fraction lost on heat from elevator if traction, change to 100% lost if not setup that way.
    if elevator_type == 'Traction'
      elevator.definition.to_ElectricEquipmentDefinition.get.setFractionLost(1.0)
      elevator.definition.to_ElectricEquipmentDefinition.get.setFractionRadiant(0.0)
    end

    return elevator
  end
end
