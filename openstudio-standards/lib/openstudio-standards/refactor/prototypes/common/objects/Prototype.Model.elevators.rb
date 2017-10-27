# open the class to add methods to add elevators
class StandardsModel < OpenStudio::Model::Model

  # Add elevators to the model
  #
  # @param template [String] Valid choices are
  # @return [OpenStudio::Model::ElectricEquipment] the resulting elevator
  def model_add_elevators(model, template)

    # determine effective number of stories
    effective_num_stories = model.effective_num_stories

    # determine elevator type
    # todo - add logic here or upstream to have some multi-story buildings without elevators (e.g. small multi-family and small hotels)
    elevator_type = nil
    if effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 2
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "The building only has 1 story, no elevators will be added.")
      return nil # don't add elevators
    elsif effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 6
      elevator_type = "Hydraulic"
    else
      elevator_type = "Traction"
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
    space_type_hash = model.create_space_type_hash(template)
    space_type_hash.each do |space_type,hash|

      # update building_type_hash
      if building_type_hash.has_key?(hash[:stds_bldg_type])
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
      if ["Office","SmallOffice","MediumOffice","LargeOffice"].include?(hash[:stds_bldg_type])
        # The office buildings have one elevator for every 45,000 ft2 (4,181 m2),
        # plus one service elevator for the large office building (500,000 ft^2).
        area_per_pass_elev_ft2 = 45_000
        bldg_area_ft2 = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get
        if bldg_area_ft2 > 500_000
          area_per_freight_elev_ft2 = 500_000
        end
      elsif["SmallHotel","LargeHotel"].include?(hash[:stds_bldg_type])
        # The hotels have one elevator for every 75 rooms.
        if hash[:stds_space_type].include?("GuestRoom")
          units_per_pass_elevator = 75.0
        end
        # The large hotel includes one service elevator for every two public elevators,
        # plus one additional elevator for the dining and banquet facilities on the top floor.
        # None of the other space types generate elevators.
        if["LargeHotel"].include?(hash[:stds_bldg_type]) && hash[:stds_space_type].include?("GuestRoom")
          units_per_freight_elevator = 150.0
        elsif["LargeHotel"].include?(hash[:stds_bldg_type]) && ["Banquet","Cafe"].include?(hash[:stds_space_type])
          area_per_pass_elev_ft2 = 10_000
        end
      elsif["MidriseApartment","HighriseApartment"].include?(hash[:stds_bldg_type]) && hash[:stds_space_type].include?("Apartment")
        # The apartment building has one elevator for every 90 units
        units_per_pass_elevator = 90.0
      elsif["Hospital"].include?(hash[:stds_bldg_type])
        # The hospital has one public and one service elevator for every 100 beds (250 total),
        # plus two elevators for the offices and cafeteria on the top floor.
        # None of the other space types generate elevators.
        if ["PatRoom","ICU_PatRm","ICU_Open"].include?(hash[:stds_space_type])
          beds_per_pass_elevator = 100.0
          beds_per_freight_elevator = 100.0
        elsif["Dining","Kitchen","Office"].include?(hash[:stds_space_type])
          area_per_pass_elev_ft2 = 12_500
        end
      elsif ["PrimarySchool","SecondarySchool"].include?(hash[:stds_bldg_type])
        # 210,887 ft^2 secondary school prototype has 2 elevators
        area_per_pass_elev_ft2 = 100_000
      elsif ["Outpatient"].include?(hash[:stds_bldg_type])
        # 40,946 Outpatient has 3 elevators
        area_per_pass_elev_ft2 = 15_000
      elsif ["Warehouse"].include?(hash[:stds_bldg_type])
        # Warehouse has no elevators, but assume some would be needed
        area_per_freight_elev_ft2 = 250_000
      else
        # todo - improve catchall for building types without elevator data, using same value as what Outpatient would be if not already in space type
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
    if number_of_pass_elevators > 0.0 and number_of_pass_elevators < 1.0
      number_of_pass_elevators = 1.0
    end
    if number_of_freight_elevators > 0.0 and number_of_freight_elevators < 1.0
      number_of_freight_elevators = 1.0
    end
    number_of_elevators = number_of_pass_elevators + number_of_freight_elevators

    building_type = building_type_hash.key(building_type_hash.values.max)
    # rename space types as needed
    if building_type == "Office"
      building_type = model.remap_office(building_type_hash["Office"])
    end
    if building_type == "SmallHotel" then building_type = "LargeHotel" end # no elevator schedules for SmallHotel
    if building_type == "PrimarySchool" then building_type = "SecondarySchool" end # no elevator schedules for PrimarySchool
    if building_type == "Retail" then building_type = "RetailStandalone" end # no elevator schedules for PrimarySchool
    if building_type == "StripMall" then building_type = "RetailStripmall" end # no elevator schedules for PrimarySchool
    if building_type == "Outpatient"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "Outpatient ElevatorPumpRoom plug loads contain the elevator loads. Not adding extra elevator loads on top of it.")
    end

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
        'template' => template,
        'building_type' => building_type
    }

    prototype_input = find_object($os_standards['prototype_inputs'], search_criteria, nil)
    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.elevators', "Could not find prototype inputs for #{search_criteria}, cannot add elevators.")
      return nil
    end

    # assign schedules
    if ["Office","MediumOffice","MidriseApartment","HighriseApartment","SecondarySchool"].include?(building_type)
      elevator_schedule = prototype_input['elevator_schedule']
      elevator_fan_schedule = prototype_input['elevator_fan_schedule']
      elevator_lights_schedule = prototype_input['elevator_fan_schedule']
    elsif ["LargeHotel","Hospital","LargeOffice"].include?(building_type)
      elevator_schedule = prototype_input['exterior_fuel_equipment1_schedule']
      elevator_fan_schedule = prototype_input['exterior_fuel_equipment2_schedule']
      elevator_lights_schedule = prototype_input['exterior_fuel_equipment2_schedule']
    else

      # identify occupancy schedule from largest space type of this building type
      space_type_size = {}
      space_type_hash.each do |space_type,hash|
        next if not building_type.include?(hash[:stds_bldg_type])
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

      # todo - scale down peak value based on building type lookup, or make parametric schedule based on hours of operation
      # includes RetailStandalone, RetailStripmall, QuickServiceRestaurant, FullServiceRestaurant, SuperMarket (made unique logic above for warehouse)

      if building_type == "Warehouse"
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
          values.each_with_index do |value,i|
            if value > max_value
              day_schedule.addValue(times[i],max_value)
            end
          end
        end
      end

    end

    # todo - currently add elevator doesn't allow me to choose the size of the elevator?
    # ref bldg pdf has formula for motor hp based on weight, speed, counterweight fraction and mech eff (in 5.1.4)

    # todo - should schedules change based on traction vs. hydraulic vs. just taking what is in prototype.

    # call add_elevator in Prototype.hvac_systems.rb to create elevator objects
    elevator = model_add_elevator(model, template,
                       target_space,
                       number_of_elevators,
                       elevator_type,
                       elevator_schedule,
                       elevator_fan_schedule,
                       elevator_lights_schedule,
                       building_type)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.elevators', "Adding #{elevator.multiplier.round(1)} #{elevator_type} elevators to the model in #{target_space.name}.")

    # check fraction lost on heat from elevator if traction, change to 100% lost if not setup that way.
    if elevator_type == "Traction"
      elevator.definition.to_ElectricEquipmentDefinition.get.setFractionLost(1.0)
      elevator.definition.to_ElectricEquipmentDefinition.get.setFractionRadiant(0.0)
    end

    return elevator

  end

end
