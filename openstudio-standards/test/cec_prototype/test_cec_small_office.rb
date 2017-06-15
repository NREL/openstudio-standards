require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestSmallOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['SmallOffice']
  templates = ['CEC T24 2008']
  climate_zones = ['CEC T24-CEC3']
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['CZ03RV2.epw']
  
  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestSmallOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  
end
