# This abstract class holds methods that many versions of ASHRAE 90.1 share.
# If a method in this class is redefined by a subclass,
# the implementation in the subclass is used.
# @abstract
class ASHRAE901 < Standard
  def initialize
    super()
  end
end
