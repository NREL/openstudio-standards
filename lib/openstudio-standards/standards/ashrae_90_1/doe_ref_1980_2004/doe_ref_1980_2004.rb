# This class holds methods that apply the "standard" assumptions
# used in the DOE 1980-2004 Reference Buildings to a given model.
# @ref [References::USDOEReferenceBuildings]
class DOERef1980to2004 < ASHRAE901
  register_standard 'DOE Ref 1980-2004'
  attr_reader :template

  def initialize
    @template = 'DOE Ref 1980-2004'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
