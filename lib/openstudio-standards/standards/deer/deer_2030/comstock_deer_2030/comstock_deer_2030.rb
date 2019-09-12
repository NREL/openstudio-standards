# This class holds methods that apply DEER 2030 to a given model.
# @ref [References::DEERMASControl]
class ComStockDEER2030 < DEER2030
  register_standard 'ComStock DEER 2030'
  attr_reader :template

  def initialize
    @template = 'ComStock DEER 2030'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
