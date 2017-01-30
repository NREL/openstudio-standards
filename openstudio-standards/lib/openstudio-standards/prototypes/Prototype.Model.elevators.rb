# open the class to add methods to add elevators
class OpenStudio::Model::Model

  # Add elevators to the model
  #
  # @param template [String] Valid choices are
  # @return [OpenStudio::Model::ElectricEquipment] the resulting elevator
  def add_elevators(template)

    # determine effective number of stories
    effective_num_stories = self.effective_num_stories

    # determine elevator type
    # todo - add logic here or upstream to have some multi-story buildings without elevators (e.g. small multi-family and small hotels)
    elevator_type = nil
    if effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 2
      return nil # don't add elevators
    elsif effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 6
      elevator_type = "Hydraulic"
    else
      elevator_type = "Traction"
    end

    # determine space to put elevator load in
    # largest bottom story (including basement) space
    bottom_spaces = {}
    bottom_story = effective_num_stories[:story_hash].keys.first
    bottom_story.spaces.each do |space|
      bottom_spaces[space] = space.floorArea
    end
    target_space = bottom_spaces.key(bottom_spaces.values.max)

    # determine number of elevators
    number_of_pass_elevators = 0.0
    number_of_freight_elevators = 0.0
    building_type_hash = {}

    # apply building type specific log to add to number of elevators based on Beyer (2009) rules of thumb
    space_type_hash = self.create_space_type_hash(template)
    space_type_hash.each do |space_type,hash|

      # update building_type_hash
      if building_type_hash.has_key?(hash[:stds_bldg_type])
        building_type_hash[hash[:stds_bldg_type]] += hash[:floor_area]
      else
        building_type_hash[hash[:stds_bldg_type]] = hash[:floor_area]
      end

      # building type specific notes; prototype uses Beyer (2009) rules fo thumb
      if ["Office","SmallOffice","MediumOffice","LargeOffice"].include?(hash[:stds_bldg_type])
        # The office buildings have one elevator for every 45,000 ft2 (4,181 m2), plus one service elevator for the large office building.
        pass_elevator_per_area = OpenStudio::convert(45000.0,"ft^2","m^2").get
        number_of_pass_elevators += hash[:floor_area]/pass_elevator_per_area
        # add freight elevators as separate step 1 if over 5k m^2 but more than one if over 50k m^2
        if self.getBuilding.floorArea > 45000.0 # m^2
          number_of_freight_elevators += self.getBuilding.floorArea/500000.0 # m^2
        end
      elsif["SmallHotel","LargeHotel"].include?(hash[:stds_bldg_type]) && hash[:stds_space_type].include?("GuestRoom")
        # The hotels have one elevator for every 75 rooms, and the large hotel includes one service elevator for every two public elevators, plus one additional elevator for the dining and banquet facilities on the top floor.
        units_per_pass_elevator = 75.0
        freight_elevators_per_unit = units_per_pass_elevator/2.0
        number_of_pass_elevators += hash[:num_units]/units_per_pass_elevator
        number_of_freight_elevators += hash[:num_units]/freight_elevators_per_unit
      elsif["LargeHotel"].include?(hash[:stds_bldg_type]) && ["Banquet","Cafe"].include?(hash[:stds_space_type])
        pass_elevator_per_area = OpenStudio::convert(10000.0,"ft^2","m^2").get
        number_of_pass_elevators += hash[:floor_area]/pass_elevator_per_area
      elsif["MidriseApartment","HighriseApartment"].include?(hash[:stds_bldg_type]) && hash[:stds_space_type].include?("Apartment")
        # The apartment building has one elevator for every 90 units
        units_per_pass_elevator = 90.0
        number_of_pass_elevators += hash[:num_units]/units_per_pass_elevator
      elsif["Hospital"].include?(hash[:stds_bldg_type]) && ["PatRoom","ICU_PatRm","ICU_Open"].include?(hash[:stds_space_type])
        # The hospital has one public and one service elevator for every 100 beds (250 total), plus two elevators for the offices and cafeteria on the top floor.
        beds_per_pass_elevator = 100.0
        number_of_pass_elevators += hash[:num_beds]/beds_per_pass_elevator
        number_of_freight_elevators += hash[:num_beds]/beds_per_pass_elevator
      elsif["Hospital"].include?(hash[:stds_bldg_type]) && ["Dining","Kitchen","Office"].include?(hash[:stds_space_type])
        pass_elevator_per_area = OpenStudio::convert(12500.0,"ft^2","m^2").get
        number_of_pass_elevators += hash[:floor_area]/pass_elevator_per_area
      else
        
        # The outpatient healthcare model has the minimum recommendation of two elevators.
        # todo - determine logic, seems more high traffic than office of similar size, but is that more elevators or just more frequent use

        # todo - school logic
        # The secondary school has two elevators.

        # todo - no logic for restaurants, retail and warehouse.
        # maybe have restaurants and retail follow office logic, but always with a freight elevator, and warehouse just have one (freight) elevator
        # currently add elevator doesn't allow me to choose the size of the elevator?
        # ref bldg pdf has formula for motor hp based on weight, speed, counterweight fraction and mech eff (in 5.1.4)

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
      building_type = self.remap_office(building_type_hash["Office"])
    end
    if building_type == "SmallHotel" then building_type = "LargeHotel" end # no elevator schedules for SmallHotel

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
        'template' => template,
        'building_type' => building_type
    }

    prototype_input = find_object($os_standards['prototype_inputs'], search_criteria, nil)
    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'Prototype.Model.elevators', "Could not find prototype inputs for #{search_criteria}.")
      return false
    end

    # assign schedules
    if ["Office","SmallOffice","MediumOffice","LargeOffice","MidriseApartment","HighriseApartment"].include?(building_type)
      elevator_schedule = prototype_input['elevator_schedule']
      elevator_fan_schedule = prototype_input['elevator_fan_schedule']
      elevator_lights_schedule = prototype_input['elevator_fan_schedule']
    elsif ["LargeHotel","Hospital"].include?(building_type)
      elevator_schedule = prototype_input['exterior_fuel_equipment1_schedule']
      elevator_fan_schedule = prototype_input['exterior_fuel_equipment2_schedule']
      elevator_lights_schedule = prototype_input['exterior_fuel_equipment2_schedule']
    end

    # call add_elevator in Prototype.hvac_systems.rb to create elevator objects
    elevator = self.add_elevator(template,
                       target_space,
                       number_of_elevators,
                       elevator_type,
                       elevator_schedule,
                       elevator_fan_schedule,
                       elevator_lights_schedule,
                       building_type)

    OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.elevators', "Adding #{elevator.multiplier} #{elevator_type} elevators to the model in #{target_space.name}.")

    # check fraction lost on heat from elevator if traction, change to 100% lost if not setup that way.
    if elevator_type == "Traction"
      elevator.definition.to_ElectricEquipmentDefinition.get.setFractionLost(1.0)
    end

    return elevator

  end

end