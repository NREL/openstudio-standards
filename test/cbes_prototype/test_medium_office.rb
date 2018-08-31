require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestCBESMediumOffice < CreateDOEPrototypeBuildingTest

  building_types = ['MediumOffice']
  templates = ['CBES Pre-1978', 'CBES T24 1978', 'CBES T24 1992', 'CBES T24 2001', 'CBES T24 2005', 'CBES T24 2008']
  climate_zones = [
      # 'CEC T24-CEC1',
      # 'CEC T24-CEC2',
      'CEC T24-CEC3'
      # 'CEC T24-CEC4',
      # 'CEC T24-CEC5',
      # 'CEC T24-CEC6',
      # 'CEC T24-CEC7',
      # 'CEC T24-CEC8',
      # 'CEC T24-CEC9',
      # 'CEC T24-CEC10',
      # 'CEC T24-CEC11',
      # 'CEC T24-CEC12',
      # 'CEC T24-CEC13',
      # 'CEC T24-CEC14',
      # 'CEC T24-CEC15',
      # 'CEC T24-CEC16'
  ]
  # not used for CBES
  epw_files = []

  create_models = true
  run_models = false
  compare_results = false

  debug = false

  TestCBESMediumOffice.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)

end
