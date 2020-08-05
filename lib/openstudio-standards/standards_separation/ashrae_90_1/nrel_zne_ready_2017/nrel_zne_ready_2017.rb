# This class holds methods that apply the "standard" assumptions
# for ZNE-Ready buildings, as defined by NREL in 2017, to a given model.
# @ref [References::NRELZNEReady2017]
class NRELZNEReady2017 < ASHRAE901
  register_standard 'NREL ZNE Ready 2017'
  attr_reader :template

  def initialize
    @template = 'NREL ZNE Ready 2017'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
