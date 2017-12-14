require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'






#LargeOffice
class TestNECBLargeOffice < CreateDOEPrototypeBuildingTest
  building_types = ['LargeOffice']

  templates = [ 'NECB 2011']
  climate_zones = ['NECB HDD Method']
  epw_files = [
      'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
  ]
  create_models = true
  run_models = false
  compare_results = false
  debug = false
  TestNECBLargeOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBLargeOffice.compare_test_results(building_types, templates, climate_zones, file_ext="")
end
