# This class holds methods that apply DEER 2040
# @ref [References::DEERMASControl]
class DEER2040 < DEER
  @@template = 'DEER 2040' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
