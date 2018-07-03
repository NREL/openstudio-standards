# This class holds methods that apply CBES T24 2001 to a given model.
# @ref [References::CBES]
class CBEST242001 < CBES
  @@template = 'CBES T24 2001' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
