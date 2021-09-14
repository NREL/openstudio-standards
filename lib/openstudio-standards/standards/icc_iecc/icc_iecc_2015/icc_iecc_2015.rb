# This class will hold methods that apply ICC IECC 2015
# to a given model.
# @todo ICC IECC 2015 is incomplete and will default to the logic
# in the default Standard class methods
# @ref [References::ICCIECC2015]
class ICCIECC2015 < ICCIECC
  register_standard 'ICC IECC 2015'
  attr_reader :template

  def initialize
    @template = 'ICC IECC 2015'
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
