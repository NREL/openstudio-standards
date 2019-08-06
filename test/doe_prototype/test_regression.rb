require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './doe_prototype_regression_helper'

class TestDOEPrototypesRegression < TestDOEPrototypesRegressionHelper
  def test_regression()
   @building_types = [
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
     'Warehouse']
   @climate_zones = [
#     'ASHRAE 169-2013-1A',
#     'ASHRAE 169-2013-1B',
#     'ASHRAE 169-2013-2A',
#     'ASHRAE 169-2013-2B',
#     'ASHRAE 169-2013-3A',
#     'ASHRAE 169-2013-3B',
#     'ASHRAE 169-2013-3C',
     'ASHRAE 169-2013-4A']#,
#     'ASHRAE 169-2013-4B',
#     'ASHRAE 169-2013-4C',
#     'ASHRAE 169-2013-5A',
#     'ASHRAE 169-2013-5B',
#     'ASHRAE 169-2013-5C',
#     'ASHRAE 169-2013-6A',
#     'ASHRAE 169-2013-6B',
#     'ASHRAE 169-2013-7A',
#     'ASHRAE 169-2013-7B',
#     'ASHRAE 169-2013-8A',
#     'ASHRAE 169-2013-8B']
   @templates = [
     '90.1-2004',
#     '90.1-2007',
#     '90.1-2010',
     '90.1-2013']
   @epw_files = [#'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw']#,
#                 'IND_Delhi_New.Delhi-Safdarjung.AP.421820_IWEC2.epw',
#                 'USA_FL_Tampa-MacDill.AFB.747880_TMY3.epw',
#                 'USA_AZ_Tucson-Davis-Monthan.AFB.722745_TMY3.epw',
#                 'USA_GA_Atlanta-Hartsfield.Jackson.Intl.AP.722190_TMY3.epw',
#                 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw',
#                 'USA_CA_San.Deigo-Brown.Field.Muni.AP.722904_TMY3.epw',
                  'USA_NY_New.York-John.F.Kennedy.Intl.AP.744860_TMY3.epw']#,
#                 'USA_NM_Albuquerque.Intl.Sunport.723650_TMY3.epw',
#                 'USA_WA_Seattle-Tacoma.Intl.AP.727930_TMY3.epw',
#                 'USA_NY_Buffalo.Niagara.Intl.AP.725280_TMY3.epw',
#                 'USA_CO_Denver-Aurora-Buckley.AFB.724695_TMY3.epw',
#                 'USA_WA_Port.Angeles-William.R.Fairchild.Intl.AP.727885_TMY3.epw',
#                 'USA_MN_Rochester.Intl.AP.726440_TMY3.epw',
#                 'USA_MT_Great.Falls.Intl.AP.727750_TMY3.epw',
#                 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw',
#                 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw',
#                 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw',
#                 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw']

    all_comp =  @building_types.product @epw_files, @templates, @climate_zones
    all_comp.each do |building_type, epw_file, template, climate_zone|
	  result, msg = create_model_and_regression_test(building_type, epw_file, template, climate_zone)
      assert(result, msg)
    end
  end
end
