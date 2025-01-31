# This class holds methods that apply CBES Pre-1978 to a given model.
# @ref [References::CBES]
class CBESPre1978 < CBES
  register_standard 'CBES Pre-1978'
  attr_reader :template

  def initialize
    super()
    @template = 'CBES Pre-1978'
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
