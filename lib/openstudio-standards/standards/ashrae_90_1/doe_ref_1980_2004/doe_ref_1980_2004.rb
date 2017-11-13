# This class holds methods that apply the "standard" assumptions
# used in the DOE 1980-2004 Reference Buildings to a given model.
class DOERef1980_2004_Model < A90_1_Model
  @@template = 'DOE Ref 1980-2004'
  register_standard (@@template)
  attr_reader :instvartemplate

  def initialize
    super()
    @instvartemplate = @@template
    load_standards_database
  end
end
