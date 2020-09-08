# This class will hold methods that apply OEESC 2014
# to a given model.
# @todo OEESC 2014 is incomplete and will default to the logic
# in the default Standard class methods
# @ref [References::OEESC2014]
class OEESC2014 < OEESC
  register_standard 'OEESC 2014'
  attr_reader :template

  def initialize
    @template = 'OEESC 2014'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end

end
