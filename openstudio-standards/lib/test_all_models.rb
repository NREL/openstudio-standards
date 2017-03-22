require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestLargeOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['LargeOffice','MediumOffice','SmallOffice','LargeHotel']
  templates = ['90.1-2004','90.1-2007','90.1-2010']
  climate_zones = ['ASHRAE 169-2006-1A','ASHRAE 169-2006-1B','ASHRAE 169-2006-8A','ASHRAE 169-2006-8B']
  
  create_models = true
  run_models = true
  compare_results = false
  
  debug = false
  
  TestLargeOffice.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
