# This class holds methods that apply the "standard" assumptions
# for ZNE-Ready buildings, as defined by NREL in 2017, to a given model.
class NRELZNEReady2017_Model < A90_1_Model
  @@template = 'NREL ZNE Ready 2017'
  register_standard (@@template)
  attr_reader :instvartemplate

  def initialize
    super()
    @instvartemplate = @@template
  end
end
