require_relative '../helpers/minitest_helper'
require_relative 'doe_prototype_regression_helper'

class DOEPrototypeRegressionTest < Minitest::Test

  def setup
    @building_types = ['SmallOffice']
    @templates = ['DOE Ref Pre-1980']#,'DOE Ref 1980-2004','90.1-2010']
    @climate_zones = ['ASHRAE 169-2006-2A']#,'ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  end

  def test_doe_prototype_sim_settings
    errs = compare_properties('sim_settings', @building_types, @templates, @climate_zones)
    assert(errs.size == 0, "There were #{errs.size} errors: #{errs.join(',')}")
  end

  def test_doe_prototype_envelope
    errs = compare_properties('envelope', @building_types, @templates, @climate_zones)
    assert(errs.size == 0, "There were #{errs.size} errors: #{errs.join(',')}")
  end

  def test_doe_prototype_internal_loads
    errs = compare_properties('internal_loads', @building_types, @templates, @climate_zones)
    assert(errs.size == 0, "There were #{errs.size} errors: #{errs.join(',')}")
  end

  def test_doe_prototype_outdoor_air
    errs = compare_properties('outdoor_air', @building_types, @templates, @climate_zones)
    assert(errs.size == 0, "There were #{errs.size} errors: #{errs.join(',')}")
  end

  def test_doe_prototype_zone_sizing
    errs = compare_properties('zone_sizing', @building_types, @templates, @climate_zones)
    assert(errs.size == 0, "There were #{errs.size} errors: #{errs.join(',')}")
  end

end
