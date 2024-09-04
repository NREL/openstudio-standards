# This class holds methods that apply ASHRAE 90.1-2007
# to a given model.
# @ref [References::ASHRAE9012007]
class ASHRAE9012007 < ASHRAE901
  register_standard '90.1-2007'
  attr_reader :template

  def initialize
    super()
    @template = '90.1-2007'
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
