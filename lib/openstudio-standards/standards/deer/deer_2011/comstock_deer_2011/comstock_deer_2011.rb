# This class holds methods that apply DEER 2011
# to a given model.
# @ref [References::DEERMASControl]
class ComStockDEER2011 < DEER2011
  @@template = 'ComStock DEER 2011' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
