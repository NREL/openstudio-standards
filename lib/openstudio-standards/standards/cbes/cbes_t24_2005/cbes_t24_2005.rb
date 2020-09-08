# This class holds methods that apply CBES T24 2005 to a given model.
# @ref [References::CBES]
class CBEST242005 < CBES
  register_standard 'CBES T24 2005'
  attr_reader :template

  def initialize
    @template = 'CBES T24 2005'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
