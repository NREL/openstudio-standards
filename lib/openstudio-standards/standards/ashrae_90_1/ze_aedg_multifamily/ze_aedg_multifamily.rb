# This class holds methods that apply the "standard" assumptions
# for Zero Energy Advanced Energy Design Guide for Multifamily Buildings to a given model.
# @ref [References::ZEAEDGMultifamily]
class ZEAEDGMultifamily < ASHRAE901
  register_standard 'ZE AEDG Multifamily'
  attr_reader :template

  def initialize
    super()
    @template = 'ZE AEDG Multifamily'
    load_standards_database
  end

  # Loads the openstudio standards dataset for this standard.
  #
  # @param data_directories [Array<String>] array of file paths that contain standards data
  # @return [Hash] a hash of standards data
  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
