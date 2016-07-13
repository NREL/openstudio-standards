require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestHospital < CreateDOEPrototypeBuildingTest
  
  building_types = ['Hospital']
  templates = ['DOE Ref 1980-2004']
  climate_zones = ['ASHRAE 169-2006-2A']
  
  create_models = true
  run_models = true
  compare_results = true
  
  debug = true
  
  TestHospital.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
