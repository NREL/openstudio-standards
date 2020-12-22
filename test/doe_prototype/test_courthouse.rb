require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestCourthouse < CreateDOEPrototypeBuildingTest
  building_types = ['Courthouse']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  climate_zones = ['ASHRAE 169-2006-1A','ASHRAE 169-2006-2A','ASHRAE 169-2006-2B','ASHRAE 169-2006-3A','ASHRAE 169-2006-3B','ASHRAE 169-2006-3C','ASHRAE 169-2006-4A','ASHRAE 169-2006-4B','ASHRAE 169-2006-4C','ASHRAE 169-2006-5A','ASHRAE 169-2006-5B','ASHRAE 169-2006-6A','ASHRAE 169-2006-6B','ASHRAE 169-2006-7A','ASHRAE 169-2006-8A']
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw'] # not used for ASHRAE/DOE archetypes, but required for call
  create_models = true
  run_models = true
  compare_results = false
  debug = false
  TestCourthouse.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  
end
