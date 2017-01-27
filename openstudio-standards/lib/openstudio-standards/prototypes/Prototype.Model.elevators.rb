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
    number_of_elevators = 0.0
    building_type_hash = {}

    # apply builidng type specific log to add to number of elevators based on Beyer (2009) rules of thumb
    space_type_hash = self.create_space_type_hash(template)
    space_type_hash.each do |space_type,hash|

      # update building_type_hash
      if building_type_hash.has_key?(hash[:stds_bldg_type])
        building_type_hash[hash[:stds_bldg_type]] += hash[:floor_area]
      else
        building_type_hash[hash[:stds_bldg_type]] = hash[:floor_area]
      end

      if ["Office","SmallOffice","MediumOffice","LargeOffice"].include?(hash[:stds_bldg_type])
        elevator_per_area = OpenStudio::convert(45000.0,"ft^2","m^2").get
        number_of_elevators += hash[:floor_area]/elevator_per_area
      else

        # todo - move all building types into elsif then use something similar to office logic as catchall for any other builidng types. Space types not mapped to standards are alrady skipped by create_space_type_hash

        # building type specific notes
        # prototype uses Beyer (2009) rules fo thumb
        # The office buildings have one elevator for every 45,000 ft2 (4,181 m2), plus one service elevator for the large office building.

        # The hotels have one elevator for every 75 rooms, and the large hotel includes one service elevator for every two public elevators, plus one additional elevator for the dining and banquet facilities on the top floor.
        # todo - need method to determine number of rooms based on floor area of guest rooms (what is guest room floor area per guest room avg. for small and large hotel, should vintage play a role)
        # sm hotel in ref pdf has mostly 351 ft^2 guestrooms (when 3x  combined is 378)
        # lg hotel uses 269 ft^2 and 420 ft^2 per guestroom

        # The hospital has one public and one service elevator for every 100 beds (250 total), plus two elevators for the offices and cafeteria on the top floor.
        # todo - need method to determine number of beds per patient room types (may be mixed of private or 2x rooms)
        # hospital patient room size ranges from 215 ft^2 to 367 ft^2 per room, but not necessarily 1 room per bed. May also have some beds outsdie of patient rooms. Certainly included ICU_PAT Rooms maybe also ER_Exam and OR

        # The outpatient healthcare model has the minimum recommendation of two elevators.
        # todo - determine logic, seems more high traffic than office of similar size, but is that more elevators or just more frequent use

        # The apartment building has one elevator for every 90 units, and the secondary school has two elevators.
        # todo - need logic to determine number of units per apartment floor area (different buildings will have mix of single, 2 bedroom and larger sizes)
        # mid_rise_apartment use 947 ft^2 per unit

        # todo - no logic for restaurants, retail and warehouse.
        # maybe have restaurants and retail follow office logic, but always with a freight elevator, and warehouse just have one (freight) elevator
        # currently add elevator doesn't allow me to choose the size of the elevator?
        # ref bldg pdf has formula for motor hp based on weight, speed, counterweight fraction and mech eff (in 5.1.4)

      end

    end

    # adjust number of elevators (can be double but if not 0 must be at least 1.0)
    if number_of_elevators > 0.0 and number_of_elevators < 1.0
      number_of_elevators = 1.0
    end

    # add freight elevators as separate step 1 if over 5k m^2 but more than one if over 50k m^2
    if self.getBuilding.floorArea > 5000.0 # m^2
      num_freight_elev = self.getBuilding.floorArea/50000 # m^2
      if num_freight_elev < 1.0 then num_freight_elev = 1.0 end
      OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.elevators', "Due to building size including #{num_freight_elev} freight elevators in count of total elevators")
    end
    number_of_elevators += num_freight_elev

    building_type = building_type_hash.key(building_type_hash.values.max)
    if building_type == "Office"
      building_type = self.remap_office(building_type_hash["Office"])
    end

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

    # todo - won't work if primary building type in prototype doesn't have elevators
    OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.elevators', 'Adding elevators schedules from protytpe_input. May not appropriate for use in non prototype models.')
    elevator_schedule = prototype_input['elevator_schedule']
    elevator_fan_schedule = prototype_input['elevator_fan_schedule']
    elevator_lights_schedule = prototype_input['elevator_fan_schedule']

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

    return elevator

  end

end