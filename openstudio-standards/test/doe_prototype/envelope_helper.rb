
require_relative 'legacy_comparison_helper'

# Create a base class for testing doe prototype buildings
class PrototypeRegressionTest < Minitest::Test

  # create more detailed csv for results comparison (from previous codes)
  def PrototypeRegressionTest.compare_envelope(bldg_types, vintages, climate_zones)
  
    compare_properties('envelope', bldg_types, vintages, climate_zones)    

  end

end
