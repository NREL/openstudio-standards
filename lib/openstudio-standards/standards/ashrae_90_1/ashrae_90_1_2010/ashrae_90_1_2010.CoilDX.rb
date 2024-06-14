# A variety of DX coil methods that are the same regardless of coil type.
# These methods are available to:
# CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
module CoilDX
  # @!group CoilDX

  # Determine what application to use for looking up the minimum efficiency requirements of PTACs
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [String] PTAC application
  def coil_dx_ptac_application(coil_dx)
    return 'Standard Size'
  end
end
