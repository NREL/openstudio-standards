require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestSmallOffice < CreateDOEPrototypeBuildingTest
  
  building_types = ['SmallOffice']
  templates = ['90.1-2013']
  climate_zones = ['ASHRAE 169-2006-3C']
  # templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
  # climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw']
  
  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestSmallOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  
end
