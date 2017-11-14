# This class holds methods that apply ASHRAE 90.1-2004
# to a given model.
class ASHRAE9012004 < ASHRAE901
  @@template = '90.1-2004'
  register_standard (@@template)
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end








