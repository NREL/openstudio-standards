# This class holds methods that apply the "standard" assumptions
# used in the DOE Pre-1980 Reference Buildings,
# but modified to better reflect the U.S. building stock to a given model.
# @ref [References::USDOEReferenceBuildings]
class ComStockDOERefPre1980 < DOERefPre1980
  register_standard 'ComStock DOE Ref Pre-1980'
  attr_reader :template

  def initialize
    super()
    @template = 'ComStock DOE Ref Pre-1980'
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
