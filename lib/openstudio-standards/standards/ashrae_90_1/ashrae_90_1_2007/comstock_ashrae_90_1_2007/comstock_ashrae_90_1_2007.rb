# This class holds methods that apply a version of ASHRAE 90.1-2007 that has
# been modified to better reflect the U.S. building stock to a given model.
# @ref [References::ASHRAE9012007]
class ComStockASHRAE9012007 < ASHRAE9012007
  register_standard 'ComStock 90.1-2007'
  attr_reader :template

  def initialize
    @template = 'ComStock 90.1-2007'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
