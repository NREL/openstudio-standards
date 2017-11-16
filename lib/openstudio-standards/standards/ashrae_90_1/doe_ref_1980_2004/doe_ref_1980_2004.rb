# This class holds methods that apply the "standard" assumptions
# used in the DOE 1980-2004 Reference Buildings to a given model.
class DOERef1980to2004 < ASHRAE901
  @@template = 'DOE Ref 1980-2004' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
