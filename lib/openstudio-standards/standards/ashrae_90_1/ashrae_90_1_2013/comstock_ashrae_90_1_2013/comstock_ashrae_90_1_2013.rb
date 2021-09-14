# This class holds methods that apply a version of ASHRAE 90.1-2013 that has
# been modified to better reflect the U.S. building stock to a given model.
# @ref [References::ASHRAE9012013]
class ComStockASHRAE9012013 < ASHRAE9012013
  register_standard 'ComStock 90.1-2013'
  attr_reader :template

  def initialize
    @template = 'ComStock 90.1-2013'
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
