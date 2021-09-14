# This class holds methods that apply CBES T24 1992 to a given model.
# @ref [References::CBES]
class CBEST241992 < CBES
  register_standard 'CBES T24 1992'
  attr_reader :template

  def initialize
    @template = 'CBES T24 1992'
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
