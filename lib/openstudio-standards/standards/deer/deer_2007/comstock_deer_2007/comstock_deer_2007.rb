# This class holds methods that apply DEER 2007
# to a given model.
# @ref [References::DEERMASControl]
class ComStockDEER2007 < DEER2007
  register_standard 'ComStock DEER 2007'
  attr_reader :template

  def initialize
    @template = 'ComStock DEER 2007'
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
