# This class holds methods that apply DEER 2003
# to a given model.
# @ref [References::DEERMASControl]
class ComStockDEER2003 < DEER2003
  @@template = 'ComStock DEER 2003' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
