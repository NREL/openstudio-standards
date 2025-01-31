# This class will hold methods that apply OEESC 2014
# to a given model.
# @todo OEESC 2014 is incomplete and will default to the logic
# in the default Standard class methods
# @ref [References::OEESC2014]
class OEESC2014 < OEESC
  register_standard 'OEESC 2014'
  attr_reader :template

  def initialize
    super()
    @template = 'OEESC 2014'
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
