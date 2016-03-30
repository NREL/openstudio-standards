require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestWarehouse < CreateDOEPrototypeBuildingTest

  building_types = ['Warehouse']
  templates = ['90.1-2010']
  climate_zones = ['ASHRAE 169-2006-4A']

  create_models = true
  run_models = true
  compare_results = true

  debug = false

  TestWarehouse.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results, debug)

end
