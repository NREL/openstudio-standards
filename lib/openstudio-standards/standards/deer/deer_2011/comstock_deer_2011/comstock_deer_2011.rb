# This class holds methods that apply DEER 2011
# to a given model.
# @ref [References::DEERMASControl]
class ComStockDEER2011 < DEER2011
  register_standard 'ComStock DEER 2011'
  attr_reader :template

  def initialize
    @template = 'ComStock DEER 2011'
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
