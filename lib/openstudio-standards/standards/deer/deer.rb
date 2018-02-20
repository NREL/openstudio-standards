# This abstract class holds methods that many versions of DEER share.
# If a method in this class is redefined by a subclass,
# the implementation in the subclass is used.
# @abstract
class DEER < Standard
  def initialize
    super()
  end
end
