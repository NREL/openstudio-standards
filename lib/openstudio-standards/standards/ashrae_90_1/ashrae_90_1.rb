# This abstract class holds methods that many versions of ASHRAE 90.1 share.
# If a method in this class is redefined by a child class,
# the implementation in the child class is used.
# @abstract
class ASHRAE901 < Standard
  def initialize
    super()
  end
end
