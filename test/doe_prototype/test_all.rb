require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestAllBldgTypes < CreateDOEPrototypeBuildingTest
  building_types = [
    'SmallOffice',
    'MediumOffice',
    'LargeOffice',
    'RetailStandalone',
    'RetailStripmall',
    'PrimarySchool',
    'SecondarySchool',
    'Outpatient',
    'Hospital',
    'SmallHotel',
    'LargeHotel',
    'QuickServiceRestaurant',
    'FullServiceRestaurant',
    'MidriseApartment',
    'HighriseApartment',
    'Warehouse'
  ]
  templates = [
     'DOE Ref Pre-1980',
     'DOE Ref 1980-2004',
     '90.1-2004',
     '90.1-2007',
     '90.1-2010',
     '90.1-2013'
  ]
  climate_zones = [
    'ASHRAE 169-1A',
    'ASHRAE 169-2A',
    'ASHRAE 169-2B',
    'ASHRAE 169-3A',
    'ASHRAE 169-3B',
    'ASHRAE 169-3C',
    'ASHRAE 169-4A',
    'ASHRAE 169-4B',
    'ASHRAE 169-4C',
    'ASHRAE 169-5A',
    'ASHRAE 169-5B',
    'ASHRAE 169-6A',
    'ASHRAE 169-6B',
    'ASHRAE 169-7A',
    'ASHRAE 169-8A'
  ]
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw'] # not used for ASHRAE/DOE archetypes, but required for call
  create_models = true
  run_models = false
  compare_results = true
  debug = true
  TestAllBldgTypes.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
end
