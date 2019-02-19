require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestSHW < CreateDOEPrototypeBuildingTest

  def self.model_test(template, building_type)
    climate_zone = 'ASHRAE 169-2006-2A'
    epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
    @test_dir = "#{Dir.pwd}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
    model_name = "#{building_type}-#{template}-#{climate_zone}"
    run_dir = "#{@test_dir}/#{model_name}"
    if !Dir.exists?(run_dir)
  	  Dir.mkdir(run_dir)
    end
    prototype_creator = Standard.build("#{template}_#{building_type}")
    model = prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir) 

    return model
  end
  
  def test_shw
    # Large Hotel - 90.1-2004
    template = '90.1-2004'
    building_type = 'LargeHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.6010057946521)
	  elsif water_heater.name.to_s.include?('300gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 11.2541398681688)
	  elsif water_heater.name.to_s.include?('6.0gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 2.25796531511459)
      end
    end

    # Large Hotel - 90.1-2013
    template = '90.1-2013'
    building_type = 'LargeHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.6010057946521)
	  elsif water_heater.name.to_s.include?('300gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 11.2541398681688)
	  elsif water_heater.name.to_s.include?('6.0gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.05315929589012)
      end
    end

    # High Rise Apt. - 90.1-2010
    template = '90.1-2010'
    building_type = 'HighriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.60100707829)
    end

    # Highrise Apt. - 90.1-2013
    template = '90.1-2013'
    building_type = 'HighriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.60100707829)
    end

    # Midrise Apt. - 90.1-2013
    template = '90.1-2013'
    building_type = 'MidriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 2.012559766)
    end

    # Hospital - 90.1-2004
    template = '90.1-2004'
    building_type = 'Hospital'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.6010057946521)
	  elsif water_heater.name.to_s.include?('300gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 11.2541398681688)
	  elsif water_heater.name.to_s.include?('6.0gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 2.25796531511459)
      end
    end

    # Hospital - 90.1-2013
    template = '90.1-2013'
    building_type = 'Hospital'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.6010057946521)
	  elsif water_heater.name.to_s.include?('300gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 11.2541398681688)
	  elsif water_heater.name.to_s.include?('6.0gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.053159296)
      end
    end

    # Small Hotel - 90.1-2013
    template = '90.1-2013'
    building_type = 'SmallHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  if water_heater.name.to_s.include?('300gal')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 11.2541398681688)
	  else
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 9.64328650469705)
      end
    end

    # Small Office - 90.1-2004
    template = '90.1-2004'
    building_type = 'SmallOffice'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.870180469)
    end

    # Small Office - 90.1-2013
    template = '90.1-2013'
    building_type = 'SmallOffice'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.205980747)
    end

    # Full Service Restaurant - 90.1-2004
    template = '90.1-2004'
    building_type = 'FullServiceRestaurant'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  if water_heater.name.to_s.include?('Booster')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 2.257965315)
	  else
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 9.643286505)
      end
    end

    # Full Service Restaurant - 90.1-2013
    template = '90.1-2013'
    building_type = 'FullServiceRestaurant'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  if water_heater.name.to_s.include?('Booster')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.053159296)
	  else
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 9.643286505)
      end
    end

    # Retail Standalone - 90.1-2004
    #template = '90.1-2004'
    #building_type = 'RetailStandalone'

    #model = TestSHW.model_test(template, building_type)  
    #model.getWaterHeaterMixeds.sort.each do |water_heater|
	#  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 5.477430026)
    #end

    # Retail Standalone - 90.1-2013
    template = '90.1-2013'
    building_type = 'RetailStandalone'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 4.10807252)
    end

    # Retail Stripmall - 90.1-2004
    template = '90.1-2004'
    building_type = 'RetailStripmall'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.870180469)
    end

    # Retail Stripmall - 90.1-2013
    template = '90.1-2013'
    building_type = 'RetailStripmall'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.205980747)
    end

    # Primary School - 90.1-2004
    template = '90.1-2004'
    building_type = 'PrimarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  if water_heater.name.to_s.include?('Booster')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 2.257965315)
	  else
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 9.643286505)
      end
    end

    # Primary School - 90.1-2010
    template = '90.1-2013'
    building_type = 'PrimarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  if water_heater.name.to_s.include?('Booster')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.053159296)
	  else
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 9.643286505)
      end
    end

    # Secondary School - 90.1-2010
    template = '90.1-2010'
    building_type = 'SecondarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  if water_heater.name.to_s.include?('Booster')
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.591045154)
	  else
	    assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 15.60100579)
      end
    end

    # Warehouse - 90.1-2004
    template = '90.1-2004'
    building_type = 'Warehouse'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 1.42530487240476)
    end

    # Warehouse - 90.1-2013
    template = '90.1-2013'
    building_type = 'Warehouse'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
	  assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value == 0.798542707)
    end
  end

end