# This class holds methods that apply DEER 1985
# to a given model.
# @ref [References::DEERMASControl]
class DEER1985 < DEER
  register_standard 'DEER 1985'
  attr_reader :template

  def initialize
    @template = 'DEER 1985'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
