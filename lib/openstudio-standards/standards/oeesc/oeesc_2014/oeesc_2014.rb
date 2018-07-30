# This class will hold methods that apply OEESC 2014
# to a given model.
# @todo OEESC 2014 is incomplete and will default to the logic
# in the default Standard class methods
# @ref [References::OEESC2014]
class OEESC2014 < OEESC
  @@template = 'OEESC 2014' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
