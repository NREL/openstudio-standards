# This class holds methods that apply DEER Pre-1975
# to a given model.
# @ref [References::DEERMASControl]
class DEERPRE1975 < DEER
  @@template = 'DEER Pre-1975' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
