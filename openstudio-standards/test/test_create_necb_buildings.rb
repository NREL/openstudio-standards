require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)

#set global variables
  NECB_epw_files_for_cdn_climate_zones = [
    'CAN_BC_Vancouver.718920_CWEC.epw',#  CZ 5 - Gas HDD = 3019 
    'CAN_ON_Simcoe.715270_CWEC.epw', #CZ 6 - Gas HDD = 4066
    'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
    'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
    'CAN_NU_Resolute.719240_CWEC.epw' # CZ 8  -FuelOil2 HDD = 12570
    ] 
  NECB_climate_zone = ['NECB HDD Method']
  NECB_templates = [ 'NECB 2011']
  CREATE_MODELS = true
  RUN_MODELS = false
  COMPARE_RESULTS = false
  DEBUG = false


#FullServiceRestaurant
class TestNECBFullServiceRestaurant < CreateDOEPrototypeBuildingTest
  building_types = ['FullServiceRestaurant']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBFullServiceRestaurant.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBFullServiceRestaurant.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#HighriseApartment
class TestNECBHighriseApartment < CreateDOEPrototypeBuildingTest
  building_types = ['HighriseApartment']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBHighriseApartment.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBHighriseApartment.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#LargeHotel
class TestNECBLargeHotel < CreateDOEPrototypeBuildingTest
  building_types = ['LargeHotel']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBLargeHotel.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBLargeHotel.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#LargeOffice
class TestNECBLargeOffice < CreateDOEPrototypeBuildingTest
  building_types = ['LargeOffice']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBLargeOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBLargeOffice.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#MediumOffice
class TestNECBMediumOffice < CreateDOEPrototypeBuildingTest
  building_types = ['MediumOffice']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBMediumOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBMediumOffice.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#MidriseApartment
class TestNECBMidriseApartment < CreateDOEPrototypeBuildingTest
  building_types = ['MidriseApartment']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBMidriseApartment.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBMidriseApartment.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#Outpatient
class TestNECBOutpatient < CreateDOEPrototypeBuildingTest
  building_types = ['Outpatient']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBOutpatient.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBOutpatient.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#PrimarySchool
class TestNECBPrimarySchool < CreateDOEPrototypeBuildingTest
  building_types = ['PrimarySchool']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBPrimarySchool.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBPrimarySchool.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#QuickServiceRestaurant
class TestNECBQuickServiceRestaurant < CreateDOEPrototypeBuildingTest
  building_types = ['QuickServiceRestaurant']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBQuickServiceRestaurant.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBQuickServiceRestaurant.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#RetailStandalone
class TestNECBRetailStandalone < CreateDOEPrototypeBuildingTest
  building_types = ['RetailStandalone']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBRetailStandalone.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBRetailStandalone.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#SecondarySchool
class TestNECBSecondarySchool < CreateDOEPrototypeBuildingTest
  building_types = ['SecondarySchool']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBSecondarySchool.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBSecondarySchool.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#SmallHotel
class TestNECBSmallHotel < CreateDOEPrototypeBuildingTest
  building_types = ['SmallHotel']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBSmallHotel.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBSmallHotel.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#SmallOffice
class TestNECBSmallOffice < CreateDOEPrototypeBuildingTest
  building_types = ['SmallOffice']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBSmallOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBSmallOffice.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#RetailStripmall
class TestNECBRetailStripmall < CreateDOEPrototypeBuildingTest
  building_types = ['RetailStripmall']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBRetailStripmall.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBRetailStripmall.compare_test_results(building_types, templates, climate_zones, file_ext="")
end

#Warehouse
class TestNECBWarehouse < CreateDOEPrototypeBuildingTest
  building_types = ['Warehouse']
  templates = NECB_templates
  climate_zones = NECB_climate_zone
  epw_files = NECB_epw_files_for_cdn_climate_zones
  create_models = CREATE_MODELS
  run_models = RUN_MODELS
  compare_results = COMPARE_RESULTS
  debug = DEBUG
  TestNECBWarehouse.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  # TestNECBWarehouse.compare_test_results(building_types, templates, climate_zones, file_ext="")
end
