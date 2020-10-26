# This class holds methods that apply DEER 1996
# to a given model.
# @ref [References::DEERMASControl]
class DEER1996 < DEER
  register_standard 'DEER 1996'
  attr_reader :template

  def initialize
    @template = 'DEER 1996'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
