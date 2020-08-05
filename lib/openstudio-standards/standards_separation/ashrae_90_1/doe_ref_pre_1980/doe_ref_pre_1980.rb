# This class holds methods that apply the "standard" assumptions
# used in the DOE Pre-1980 Reference Buildings to a given model.
# @ref [References::USDOEReferenceBuildings]
class DOERefPre1980 < ASHRAE901
  register_standard 'DOE Ref Pre-1980'
  attr_reader :template

  def initialize
    @template = 'DOE Ref Pre-1980'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
