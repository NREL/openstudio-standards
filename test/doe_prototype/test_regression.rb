require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './doe_prototype_regression_helper'

class TestDOEPrototypesRegression < TestDOEPrototypesRegressionHelper
  def test_regression()
    @building_types = [
#      'SmallOffice',
#      'MediumOffice',
#      'LargeOffice',
#      'RetailStandalone',
#      'RetailStripmall',
#      'PrimarySchool',
#      'SecondarySchool',
#      'Outpatient',
#      'Hospital',
#      'SmallHotel',
#      'LargeHotel',
#      'QuickServiceRestaurant',
#      'FullServiceRestaurant',
#      'MidriseApartment',
#      'HighriseApartment',
#      'Warehouse']
#    @climate_zones = [
#      'ASHRAE 169-2013-1A',
#      'ASHRAE 169-2013-1B',
#      'ASHRAE 169-2013-2A',
#      'ASHRAE 169-2013-2B',
#      'ASHRAE 169-2013-3A',
#      'ASHRAE 169-2013-3B',
#      'ASHRAE 169-2013-3C',
#      'ASHRAE 169-2013-4A',
#      'ASHRAE 169-2013-4B',
#      'ASHRAE 169-2013-4C',
#      'ASHRAE 169-2013-5A',
#      'ASHRAE 169-2013-5B',
#      'ASHRAE 169-2013-5C',
#      'ASHRAE 169-2013-6A',
#      'ASHRAE 169-2013-6B',
#      'ASHRAE 169-2013-7A',
#      'ASHRAE 169-2013-7B',
#      'ASHRAE 169-2013-8A',
#      'ASHRAE 169-2013-8B']
#    @templates = [
#      '90.1-2004',
#      '90.1-2007',
#      '90.1-2010',
#      '90.1-2013']
#    @epw_files = [
#      'USA_FL_Miami.Intl.AP.722020_TMY3.epw',
#      'SAU_Riyadh.404380_IWEC.epw',
#      'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw',
#      'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw',
#      'USA_TN_Memphis.Intl.AP.723340_TMY3.epw',
#      'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw',
#      'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw',
#      'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw',
#      'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw',
#      'USA_OR_Salem-McNary.Field.726940_TMY3.epw',
#      'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw',
#      'USA_ID_Boise.Air.Terminal.726810_TMY3.epw',
#      'CAN_BC_Vancouver.718920_CWEC.epw',
#      'USA_VT_Burlington.Intl.AP.726170_TMY3.epw',
#      'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw',
#      'USA_MN_Duluth.Intl.AP.727450_TMY3.epw',
#      'USA_MN_Duluth.Intl.AP.727450_TMY3.epw',
#      'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw',
#      'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw']

  @building_types = ['SecondarySchool']
	@climate_zones [
      'ASHRAE 169-2006-1A',
      'ASHRAE 169-2006-1B',
      'ASHRAE 169-2006-2A',
      'ASHRAE 169-2006-2B',
      'ASHRAE 169-2006-3A',
      'ASHRAE 169-2006-3B',
      'ASHRAE 169-2006-3C',
      'ASHRAE 169-2006-4A',
      'ASHRAE 169-2006-4B',
      'ASHRAE 169-2006-4C',
      'ASHRAE 169-2006-5A',
      'ASHRAE 169-2006-5B',
      'ASHRAE 169-2006-5C',
      'ASHRAE 169-2006-6A',
      'ASHRAE 169-2006-6B',
      'ASHRAE 169-2006-7A',
      'ASHRAE 169-2006-7B',
      'ASHRAE 169-2006-8A',
      'ASHRAE 169-2006-8B']
	@templates = ['90.1-2004']
	@epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw']
    all_comp =  @building_types.product @epw_files, @templates, @climate_zones
    all_comp.each do |building_type, epw_file, template, climate_zone|
	  result, msg = create_model_and_regression_test(building_type, epw_file, template, climate_zone)
      assert(result, msg)
    end
  end
end
