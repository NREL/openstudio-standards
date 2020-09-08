# This class holds methods that apply CBES T24 1978 to a given model.
# @ref [References::CBES]
class CBEST241978 < CBES
  register_standard 'CBES T24 1978'
  attr_reader :template

  def initialize
    @template = 'CBES T24 1978'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
