# Methods to create and modify parametric schedules
module OpenstudioStandards
  module Schedules
    # @!group Parametric

    # This method looks at occupancy profiles for the building as a whole and generates an hours of operation default
    # schedule for the building. It also clears out any higher level hours of operation schedule assignments.
    # Spaces are organized by res and non_res. Whichever of the two groups has higher design level of people is used for building hours of operation
    # Resulting hours of operation can have as many rules as necessary to describe the operation.
    # Each ScheduleDay should be an on/off schedule with only values of 0 and 1. There should not be more than one on/off cycle per day.
    # In future this could create different hours of operation for residential vs. non-residential, by building type, story, or space type.
    # However this measure is a stop gap to convert old generic schedules to parametric schedules.
    # Future new schedules should be designed as paramtric from the start and would not need to run through this inference process
    #
    # @author David Goldwasser
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param fraction_of_daily_occ_range [Double] fraction above/below daily min range required to start and end hours of operation
    # @param invert_res [Boolean] if true will reverse hours of operation for residential space types
    # @param gen_occ_profile [Boolean] if true creates a merged occupancy schedule for diagnostic purposes. This schedule is added to the model but no specifically returned by this method
    # @return [ScheduleRuleset] schedule that is assigned to the building as default hours of operation
    def self.model_infer_hours_of_operation_building(model, fraction_of_daily_occ_range: 0.25, invert_res: true, gen_occ_profile: false)
      # create an array of non-residential and residential spaces
      res_spaces = []
      non_res_spaces = []
      res_people_design = 0
      non_res_people_design = 0
      model.getSpaces.sort.each do |space|
        if OpenstudioStandards::Schedules.space_residential??(space)
          res_spaces << space
          res_people_design += space.numberOfPeople * space.multiplier
        else
          non_res_spaces << space
          non_res_people_design += space.numberOfPeople * space.multiplier
        end
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Schedules', "Model has design level of #{non_res_people_design} people in non residential spaces and #{res_people_design} people in residential spaces.")

    end
  end
end
