require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestFullServiceRestaurant < CreateDOEPrototypeBuildingTest
  
  building_types = ['FullServiceRestaurant']
  # templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2004','90.1-2007','90.1-2010','90.1-2013']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
   climate_zones = ['ASHRAE 169-2A','ASHRAE 169-3B','ASHRAE 169-4A','ASHRAE 169-5A']   
  #climate_zones = ['ASHRAE 169-1A', 'ASHRAE 169-2A','ASHRAE 169-2B',
                   # 'ASHRAE 169-3A', 'ASHRAE 169-3B', 'ASHRAE 169-3C', 'ASHRAE 169-4A',
                   # 'ASHRAE 169-4B', 'ASHRAE 169-4C', 'ASHRAE 169-5A', 'ASHRAE 169-5B',
                   # 'ASHRAE 169-6A', 'ASHRAE 169-6B', 'ASHRAE 169-7A', 'ASHRAE 169-8A'] 
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw']

  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestFullServiceRestaurant.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)

  # TestFullServiceRestaurant.compare_test_results(building_types, templates, climate_zones, file_ext="")

     
end
