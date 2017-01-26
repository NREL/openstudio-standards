# open the class to add methods to add elevators
class OpenStudio::Model::Model

  # todo - add in comments need for docs to work
  # Add elevators to the model
  #
  # @param template [String] Valid choices are
  # @return [OpenStudio::Model::ElectricEquipment] the resulting elevator
  def add_elevators(template)

    # todo - determine effective number of stories
    effective_num_stories = self.effective_num_stories

    # determine elevator type
    elevator_type = nil
    if effective_num_stories[:below_grade] + effective_num_stories[:above_grade] < 6
      elevator_type = "Hydraulic"
    else
      elevator_type = "Traction"
    end

    # todo - determine space to put elevator load in
    # largest bottom story (including basement) core space
    space = nil

    # todo - determine number of elevators
    number_of_elevators = nil # does this have to be an integer

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

    # todo - determine elevator schedules (look at Appendix C of Prototype pdf)
    elevator_schedule = nil
    elevator_fan_schedule = nil
    elevator_lights_schedule = nil

    # todo - determine building type
    # this is only used to use custom lift_pwr_w for MidriseApartment, but not sure why
    building_type = nil

    # todo - call add_elevator in Prototype.hvac_systems.rb to create elevator objects
    elevator = self.add_elevator(template,
                       space,
                       number_of_elevators,
                       elevator_type,
                       elevator_schedule,
                       elevator_fan_schedule,
                       elevator_lights_schedule,
                       building_type)

    # adjust instances for loads (maybe change how that works in add_elevator, but talk to Andrew first if I plan to do that)

    return elevator

  end

end