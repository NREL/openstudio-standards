require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_deer_prototype_helper'

class TestMFm < CreateDEERPrototypeBuildingTest
  
  building_types = ['MFm']
  templates = ['DEER Pre-1975']
  hvacs = ['NCEH','NCGF'] #[]
  climate_zones = ['CEC T24-CEC9']
  
  # building_types = ['MFm']
  # templates = ['DEER Pre-1975', 'DEER 1985', 'DEER 1996', 'DEER 2003', 'DEER 2007', 'DEER 2011', 'DEER 2014', 'DEER 2015', 'DEER 2017']
  # hvacs = ['DXGF', 'DXHP', 'NCEH', 'NCGF']
  # climate_zones = ['CEC T24-CEC1', 'CEC T24-CEC2', 'CEC T24-CEC3', 'CEC T24-CEC4',
                  # 'CEC T24-CEC5', 'CEC T24-CEC6', 'CEC T24-CEC7', 'CEC T24-CEC8',
                  # 'CEC T24-CEC9', 'CEC T24-CEC10', 'CEC T24-CEC11', 'CEC T24-CEC12',
                  # 'CEC T24-CEC13', 'CEC T24-CEC14', 'CEC T24-CEC15', 'CEC T24-CEC16']

  create_models = true
  run_models = false
  compare_results = false
  
  debug = true
  
  TestMFm.create_run_model_tests(building_types, templates, hvacs, climate_zones, create_models, run_models, compare_results, debug)
  
end
