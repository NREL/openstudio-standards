require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestHighRiseApartment < CreateDOEPrototypeBuildingTest
  
  building_types = ['HighriseApartment']
  templates = ['90.1-2004','90.1-2007','90.1-2010']
  climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  
  create_models = true
  run_models = true
  compare_results = true
  
  TestHighRiseApartment.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results)
     
end
