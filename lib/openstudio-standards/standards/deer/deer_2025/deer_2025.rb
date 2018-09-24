# This class holds methods that apply DEER 2025 to a given model.
# @ref [References::DEERMASControl]
class DEER2025 < DEER
  @@template = 'DEER 2025' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
  end
end
