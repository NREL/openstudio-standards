require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)

class TestSecondarySchool < CreateDOEPrototypeBuildingTest

  building_types = ['SecondarySchool']
<<<<<<< HEAD
  #templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
  #climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  
  templates = [ 'NECB 2011']
  climate_zones = ['NECB HDD Method']
  epw_files = ['CAN_AB_Calgary.718770_CWEC.epw']
  
  create_models = true
  run_models = true
=======
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004']
  climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  
  create_models = true
  run_models = false
>>>>>>> remotes/origin/master
  compare_results = false
  
  debug = false
  
  TestSecondarySchool.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
  
end
