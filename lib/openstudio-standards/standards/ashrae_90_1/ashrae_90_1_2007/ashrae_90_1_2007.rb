# This class holds methods that apply ASHRAE 90.1-2007
# to a given model.
class ASHRAE9012007 < ASHRAE901
  @@template = '90.1-2007' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
