require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestLargeOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['MediumOffice']
  templates = ['90.1-2013']
  climate_zones = ['ASHRAE 169-2006-1A','ASHRAE 169-2006-1B','ASHRAE 169-2006-2A','ASHRAE 169-2006-2B','ASHRAE 169-2006-3A','ASHRAE 169-2006-3B','ASHRAE 169-2006-3C','ASHRAE 169-2006-4A','ASHRAE 169-2006-4B','ASHRAE 169-2006-4C','ASHRAE 169-2006-5A','ASHRAE 169-2006-5B','ASHRAE 169-2006-5C','ASHRAE 169-2006-6A','ASHRAE 169-2006-6B','ASHRAE 169-2006-7A','ASHRAE 169-2006-7B','ASHRAE 169-2006-8A','ASHRAE 169-2006-8B']
  
  create_models = true
  run_models = true
  compare_results = false
  
  debug = false
  
  TestLargeOffice.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
