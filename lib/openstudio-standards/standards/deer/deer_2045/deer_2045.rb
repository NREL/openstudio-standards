# This class holds methods that apply DEER 2045 to a given model.
# @ref [References::DEERMASControl]
class DEER2045 < DEER
  @@template = 'DEER 2045' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
