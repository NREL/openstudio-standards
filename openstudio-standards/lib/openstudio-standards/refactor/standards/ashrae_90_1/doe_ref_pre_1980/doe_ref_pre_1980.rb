# This class holds methods that apply the "standard" assumptions
# used in the DOE Pre-1980 Reference Buildings to a given model.
class DOERefPre1980_Model < A90_1_Model
  @@template = 'DOE Ref Pre-1980'
  register_standard (@@template)
  attr_reader :instvartemplate

  def initialize
    super()
    @instvartemplate = @@template
  end
end
