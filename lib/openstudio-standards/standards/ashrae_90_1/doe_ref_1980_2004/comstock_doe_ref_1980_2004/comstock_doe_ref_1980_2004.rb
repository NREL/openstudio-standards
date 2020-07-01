# This class holds methods that apply the "standard" assumptions
# used in the DOE 1980-2004 Reference Buildings,
# but modified to better reflect the U.S. building stock to a given model.
# @ref [References::USDOEReferenceBuildings]
class ComStockDOERef1980to2004 < DOERef1980to2004
  register_standard 'ComStock DOE Ref 1980-2004'
  attr_reader :template

  def initialize
    @template = 'ComStock DOE Ref 1980-2004'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
