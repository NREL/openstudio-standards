require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)


class TestSuperMarket < CreateDOEPrototypeBuildingTest
  
  building_types = ['SuperMarket']
  templates = ['90.1-2004']#,'90.1-2007','90.1-2010','90.1-2013']
  climate_zones = ['ASHRAE 169-2006-5A']
  
  create_models = true
  run_models = true
  compare_results = true
  
  debug = true
  
  TestSuperMarket.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)
  
end
