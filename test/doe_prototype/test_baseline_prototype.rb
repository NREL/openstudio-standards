require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestBaselinePrototype < CreateDOEPrototypeBuildingTest
  
	##Select one building type
    #building_type = ['LargeOffice']
    #building_type = ['SecondarySchool']
    #building_type = [ 'PrimarySchool']
    #building_type = [ 'SmallOffice']
    #building_type = [ 'MediumOffice']
    #building_type = [ 'SmallHotel']
    #building_type = [ 'LargeHotel']
    #building_type = [ 'Warehouse']
    #building_type = [ 'RetailStandalone']
    building_type = [ 'RetailStripmall']
    #building_type = [ 'QuickServiceRestaurant']
    #building_type = [ 'FullServiceRestaurant']
    #building_type = [ 'MidriseApartment']
    #building_type = [ 'HighriseApartment']
    #building_type = [ 'Hospital']
    #building_type = [ 'Outpatient']
	
	##Select one template
    #template = ['DOE Ref Pre-1980']
    #template = ['DOE Ref 1980-2004']
    #template = [ '90.1-2004']
    #template = ['90.1-2007']
    template = ['90.1-2010']
    #template = [ '90.1-2013']
	
	##only SLC weather supported now
    climate_zone = ['ASHRAE 169-2006-5B']
  
    $cool_cap=0
    $heat_cap=0
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_name = ['USA_UT_Salt.Lake.City.Intl.AP.725720_TMY3.epw']
  model_name = "#{building_type}-#{template}-#{climate_zone}"
  
  create_models = true
  run_models = true
  compare_results = false
  debug = true
  
create_run_model_tests(building_type, template, climate_zone, epw_name, create_models, run_models, compare_results, debug)

end
