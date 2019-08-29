# This class holds methods that apply DEER 2035 to a given model.
# @ref [References::DEERMASControl]
class DEER2035 < DEER
  register_standard 'DEER 2035'
  attr_reader :template

  def initialize
    @template = 'DEER 2035'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
