require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestMediumOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['RetailStandalone']
  templates = ['CEC T24 2008']
  climate_zones = ['CEC 2008-3']
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['CZ03RV2.epw']
  
  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestMediumOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  
end
