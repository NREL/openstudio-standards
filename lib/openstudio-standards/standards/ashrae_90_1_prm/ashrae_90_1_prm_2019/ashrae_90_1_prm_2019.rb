# This class holds methods that apply ASHRAE 90.1-2013
# to a given model.
# @ref [References::ASHRAE9012013]
class ASHRAE901PRM2019 < ASHRAE901PRM
  register_standard '90.1-PRM-2019'
  attr_reader :template

  def initialize
    super()
    @template = '90.1-PRM-2019'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end

  # Determine the base infiltration rate at 75 PA.
  #
  # @param space [OpenStudio::Model::Space] space object
  # @return [Double] the baseline infiltration rate, in cfm/ft^2
  # defaults to no infiltration.
  def space_infiltration_rate_75_pa(space = nil)
    basic_infil_rate_cfm_per_ft2 = 1.0
    return basic_infil_rate_cfm_per_ft2
  end
end
