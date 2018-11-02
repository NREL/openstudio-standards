# This class will hold methods that apply ICC IECC 2015
# to a given model.
# @todo ICC IECC 2015 is incomplete and will default to the logic
# in the default Standard class methods
# @ref [References::ICCIECC2015]
class ICCIECC2015 < ICCIECC
  @@template = 'ICC IECC 2015' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
