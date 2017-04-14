require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestRetailStandalone < CreateDOEPrototypeBuildingTest
  
  building_types = ['RetailStandalone']
  templates = ['90.1-2013']
  climate_zones = ['ASHRAE 169-2006-1A', 
                   'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B',
                   'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 
                   'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 
                   'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B', 
                   'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 
                   'ASHRAE 169-2006-7A', 
                   'ASHRAE 169-2006-8A']

  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw',                   
               'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw','USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw',
               'USA_TN_Memphis.Intl.AP.723340_TMY3.epw',                 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw',           'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw',
               'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw',    'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw',       'USA_OR_Salem-McNary.Field.726940_TMY3.epw',
               'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw',           'USA_ID_Boise.Air.Terminal.726810_TMY3.epw',  	     
               'USA_VT_Burlington.Intl.AP.726170_TMY3.epw',              'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw',
               'USA_MN_Duluth.Intl.AP.727450_TMY3.epw',
               'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw']
  
  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  TestRetailStandalone.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)

  # TestRetailStandalone.compare_test_results(building_types, templates, climate_zones, file_ext="")
  
end
