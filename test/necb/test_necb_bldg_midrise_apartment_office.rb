require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'






#MediumOffice
class TestNECBMidriseApartment < CreateDOEPrototypeBuildingTest
  building_types = ['MidriseApartment']

  templates = ['NECB2011','NECB2015']
  climate_zones = ['NECB HDD Method']
  epw_files = [
      'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
  ]
  create_models = true
  run_models = false
  compare_results = false
  debug = false
  TestNECBMidriseApartment.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBMidriseApartment.compare_test_results(building_types, templates, climate_zones, file_ext="")
end
