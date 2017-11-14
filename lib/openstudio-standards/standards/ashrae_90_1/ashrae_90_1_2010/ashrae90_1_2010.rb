# This class holds methods that apply ASHRAE 90.1-2004
# to a given model.
class A90_1_2010_Model < A90_1_Model
  @@template = '90.1-2010'
  register_standard (@@template)
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
