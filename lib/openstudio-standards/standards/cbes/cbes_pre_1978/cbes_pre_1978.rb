# This class holds methods that apply CBES Pre-1978 to a given model.
# @ref [References::CBES]
class CBESPre1978 < CBES
  register_standard 'CBES Pre-1978'
  attr_reader :template

  def initialize
    @template = 'CBES Pre-1978'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
