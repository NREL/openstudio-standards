# This class holds methods that apply DEER 2075 to a given model.
# @ref [References::DEERMASControl]
class DEER2075 < DEER
  register_standard 'DEER 2075'
  attr_reader :template

  def initialize
    @template = 'DEER 2075'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
