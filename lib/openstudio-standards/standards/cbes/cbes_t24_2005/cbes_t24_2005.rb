# This class holds methods that apply CBES T24 2005 to a given model.
# @ref [References::CBES]
class CBEST242005 < CBES
  @@template = 'CBES T24 2005' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
