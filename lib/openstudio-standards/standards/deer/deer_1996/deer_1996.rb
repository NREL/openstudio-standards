# This class holds methods that apply DEER 1996
# to a given model.
# @ref [References::DEERMASControl]
class DEER1996 < DEER
  @@template = 'DEER 1996' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
