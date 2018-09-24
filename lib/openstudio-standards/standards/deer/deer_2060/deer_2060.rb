# This class holds methods that apply DEER 2060 to a given model.
# @ref [References::DEERMASControl]
class DEER2060 < DEER
  @@template = 'DEER 2060' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
