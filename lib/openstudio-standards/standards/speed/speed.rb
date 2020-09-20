# This abstract class holds methods that many versions of Speed share.
# If a method in this class is redefined by a subclass,
# the implementation in the subclass is used.
# @abstract
class Speed < Standard
  register_standard 'Speed'

  def initialize
    load_standards_database
  end

  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
