# This class holds methods that apply DEER 1996
# to a given model.
# @ref [References::DEERMASControl]
class ComStockDEER1996 < DEER1996
  register_standard 'ComStock DEER 1996'
  attr_reader :template

  def initialize
    @template = 'ComStock DEER 1996'
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
