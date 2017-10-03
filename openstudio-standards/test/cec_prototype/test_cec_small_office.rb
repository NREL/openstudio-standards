require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestSmallOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['SmallOffice']
  templates = ['CEC Pre-1978','CEC T24 1978','CEC T24 1992','CEC T24 2001','CEC T24 2005','CEC T24 2008']
  climate_zones = [
    #'CEC T24-CEC1',
    #'CEC T24-CEC2',
    'CEC T24-CEC3'
    #'CEC T24-CEC4',
    #'CEC T24-CEC5',
    #'CEC T24-CEC6',
    #'CEC T24-CEC7',
    #'CEC T24-CEC8',
    #'CEC T24-CEC9',
    #'CEC T24-CEC10',
    #'CEC T24-CEC11',
    #'CEC T24-CEC12',
    #'CEC T24-CEC13',
    #'CEC T24-CEC14',
    #'CEC T24-CEC15',
    #'CEC T24-CEC16'
    ]
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['CZ03RV2.epw']
  
  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestSmallOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  
end
