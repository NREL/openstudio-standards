# This class holds methods that apply DEER 2075 to a given model.
# @ref [References::DEERMASControl]
class DEER2075 < DEER
  @@template = 'DEER 2075' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
