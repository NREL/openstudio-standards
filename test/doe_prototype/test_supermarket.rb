require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestSuperMarket < CreateDOEPrototypeBuildingTest
  building_types = ['SuperMarket']
  templates = ['90.1-2004','90.1-2007','90.1-2010','90.1-2013']
  climate_zones = ['ASHRAE 169-2013-1A','ASHRAE 169-2013-2A','ASHRAE 169-2013-2B','ASHRAE 169-2013-3A','ASHRAE 169-2013-3B','ASHRAE 169-2013-3C','ASHRAE 169-2013-4A','ASHRAE 169-2013-4B','ASHRAE 169-2013-4C','ASHRAE 169-2013-5A','ASHRAE 169-2013-5B','ASHRAE 169-2013-6A','ASHRAE 169-2013-6B','ASHRAE 169-2013-7A','ASHRAE 169-2013-8A']
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw'] # not used for ASHRAE/DOE archetypes, but required for call
  create_models = true
  run_models = false
  compare_results = false
  debug = true
  TestSuperMarket.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
end
