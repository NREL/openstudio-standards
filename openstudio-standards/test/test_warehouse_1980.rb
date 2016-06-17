require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestWarehouse < CreateDOEPrototypeBuildingTest

  building_types = ['Warehouse']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004']
  climate_zones = ['ASHRAE 169-2006-5B','ASHRAE 169-2006-6B']

  create_models = true
  run_models = true
  compare_results = true

  debug = false

  TestWarehouse.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)

end
