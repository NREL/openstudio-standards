# This abstract class holds methods that many versions of CBES share.
# If a method in this class is redefined by a subclass,
# the implementation in the subclass is used.
# @abstract
# @ref [References::CBES]
class CBES < Standard
  def initialize
    super()
    load_standards_database
  end

  # Loads the openstudio standards dataset for this standard.
  #
  # @param data_directories [Array<String>] array of file paths that contain standards data
  # @return [Hash] a hash of standards data
  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end
