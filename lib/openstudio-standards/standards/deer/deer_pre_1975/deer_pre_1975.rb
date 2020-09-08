# This class holds methods that apply DEER Pre-1975
# to a given model.
# @ref [References::DEERMASControl]
class DEERPRE1975 < DEER
  register_standard 'DEER Pre-1975'
  attr_reader :template

  def initialize
    @template = 'DEER Pre-1975'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
