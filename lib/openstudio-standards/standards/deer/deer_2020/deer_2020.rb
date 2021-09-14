# This class holds methods that apply DEER 2020 to a given model.
# @ref [References::DEERMASControl]
class DEER2020 < DEER
  register_standard 'DEER 2020'
  attr_reader :template

  def initialize
    @template = 'DEER 2020'
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
