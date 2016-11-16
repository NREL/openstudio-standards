require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)




#MediumOffice
class TestNECBQuickServiceRestaurant < CreateDOEPrototypeBuildingTest
  building_types = ['QuickServiceRestaurant']

  templates = [ 'NECB 2011']
  climate_zones = ['NECB HDD Method']
  epw_files = [
#  'CAN_BC_Vancouver.718920_CWEC.epw',#  CZ 5 - Gas HDD = 3019 
#  'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
#  'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
#  'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
  'CAN_NU_Resolute.719240_CWEC.epw' # CZ 8  -FuelOil2 HDD = 12570
] 
  create_models = true
  run_models = false
  compare_results = false
  debug = false
  TestNECBQuickServiceRestaurant.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBQuickServiceRestaurant.compare_test_results(building_types, templates, climate_zones, file_ext="")
end
