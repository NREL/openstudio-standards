# This class holds methods that apply ASHRAE 90.1-2010
# to a given model.
class ASHRAE9012010 < ASHRAE901
  @@template = '90.1-2010' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
