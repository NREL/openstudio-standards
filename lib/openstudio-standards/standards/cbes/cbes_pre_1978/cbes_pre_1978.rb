# This class holds methods that apply CBES Pre-1978 to a given model.
# @ref [References::CBES]
class CBESPre1978 < CBES
  @@template = 'CBES Pre-1978' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
