require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestRetailStandalone < CreateDOEPrototypeBuildingTest
  
  building_types = ['SmallOffice'] # 'MidriseApartment','RetailStripmall','SmallOffice',
  templates = ['90.1-2013']
  climate_zones = ['ASHRAE 169-2006-1A', 
                   'ASHRAE 169-2006-5A',
                   'ASHRAE 169-2006-8A']

  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw',
               'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw',
               'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw']
  
  create_models = true
  run_models = true
  compare_results = false
  
  debug = true
  
  TestRetailStandalone.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)

  # TestRetailStandalone.compare_test_results(building_types, templates, climate_zones, file_ext="")
  
end
