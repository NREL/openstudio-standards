require_relative 'minitest_helper'

class TestMediumOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['MediumOffice']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
  climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  create_models = true
  run_models = false
  compare_results = false
  
  TestMediumOffice.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results)
  
end
