# This class holds methods that apply the "standard" assumptions
# for ZNE-Ready buildings, as defined by NREL in 2017, to a given model.
class NRELZNEReady2017 < ASHRAE901
  @@template = 'NREL ZNE Ready 2017'
  register_standard (@@template)
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
