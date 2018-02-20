require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_deer_prototype_helper'

class TestHtl < CreateDEERPrototypeBuildingTest
  
  building_types = ['Htl']
  templates = ['DEER Pre-1975']
  hvacs = ['DXEH'] # , 'DXGF', 'DXHP', 'NCEH', 'NCGF', 'PVVE', 'PVVG', 'SVVE', 'SVVG', 'WLHP']
  climate_zones = ['CEC T24-CEC1']
  
  # building_types = ['Htl']
  # templates = ['DEER Pre-1975', 'DEER 1985', 'DEER 1996', 'DEER 2003', 'DEER 2007', 'DEER 2011', 'DEER 2014', 'DEER 2015', 'DEER 2017']
  # hvacs = ['DXEH', 'DXGF', 'DXHP', 'NCEH', 'NCGF', 'PVVE', 'PVVG', 'SVVE', 'SVVG', 'WLHP']
  # climate_zones = ['CEC T24-CEC1', 'CEC T24-CEC2', 'CEC T24-CEC3', 'CEC T24-CEC4',
                  # 'CEC T24-CEC5', 'CEC T24-CEC6', 'CEC T24-CEC7', 'CEC T24-CEC8',
                  # 'CEC T24-CEC9', 'CEC T24-CEC10', 'CEC T24-CEC11', 'CEC T24-CEC12',
                  # 'CEC T24-CEC13', 'CEC T24-CEC14', 'CEC T24-CEC15', 'CEC T24-CEC16']

  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestHtl.create_run_model_tests(building_types, templates, hvacs, climate_zones, create_models, run_models, compare_results, debug)
  
end
