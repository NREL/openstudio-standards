# This abstract class holds methods that many versions of CBES share.
# If a method in this class is redefined by a subclass,
# the implementation in the subclass is used.
# @abstract
# @ref [References::CBES]
class CBES < Standard
  def initialize
    super()
  end
end