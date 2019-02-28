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
    osm_path_string = "#{run_dir}/#{model_name}.osm"
    osm_path = OpenStudio::Path.new(osm_path_string)
    idf_path_string = "#{run_dir}/#{model_name}.idf"
    idf_path = OpenStudio::Path.new(idf_path_string)
    model.save(osm_path, true)
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf.save(idf_path,true)

    return model
  end
  
  def test_shw
    # Large Hotel - 90.1-2004
    template = '90.1-2004'
    building_type = 'LargeHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 16)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.803 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.803 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 18667.44 * 1.01)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 18667.44 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 18667.44 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 18667.44 * 0.995)
      elsif water_heater.name.to_s.include?('300gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 11)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.804 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.804 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      elsif water_heater.name.to_s.include?('6.0gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      end
    end

    # Large Hotel - 90.1-2013
    template = '90.1-2013'
    building_type = 'LargeHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 16)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.803 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.803 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 18467.44 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 18467.44 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 18467.44 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 18467.44 * 0.995)
      elsif water_heater.name.to_s.include?('300gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 11)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.804 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.804 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      elsif water_heater.name.to_s.include?('6.0gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      end
    end

    # Highrise Apt. - 90.1-2013
    template = '90.1-2013'
    building_type = 'HighriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 16)
      assert(water_heater.getHeaterThermalEfficiency.get.value < 0.803 * 1.005)
      assert(water_heater.getHeaterThermalEfficiency.get.value > 0.803 * 0.995)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 9260.51 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 9260.51 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 9260.51 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 9260.51 * 0.995)
    end

    # Midrise Apt. - 90.1-2013
    template = '90.1-2013'
    building_type = 'MidriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 46)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
	  puts water_heater.getOffCycleParasiticFuelConsumptionRate.value 
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 1889.00 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 1889.00 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 1889.00 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 1889.00 * 0.995)
    end

    # Hospital - 90.1-2004
    template = '90.1-2004'
    building_type = 'Hospital'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 16)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.803 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.803 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 20291.76 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 20291.76 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 20291.76 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 20291.76 * 0.995)
      elsif water_heater.name.to_s.include?('300gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 11)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.804 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.804 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      elsif water_heater.name.to_s.include?('6.0gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      end
    end

    # Hospital - 90.1-2013
    template = '90.1-2013'
    building_type = 'Hospital'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 16)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.803 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.803 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 20036.76 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 20036.76 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 20036.76 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 20036.76 * 0.995)
      elsif water_heater.name.to_s.include?('300gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 11)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.804 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.804 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      elsif water_heater.name.to_s.include?('6.0gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      end
    end

    # Small Hotel - 90.1-2013
    template = '90.1-2013'
    building_type = 'SmallHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('300gal')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 11)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.804 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.804 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 8296.73 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 8296.73 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 8296.73 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 8296.73 * 0.995)
      else
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 10)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.805 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.805 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  == 0)
      end
    end

    # Small Office - 90.1-2004
    template = '90.1-2004'
    building_type = 'SmallOffice'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 572 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 572 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 572 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 572 * 0.995)
    end

    # Small Office - 90.1-2013
    template = '90.1-2013'
    building_type = 'SmallOffice'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 571 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 571 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 571 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 571 * 0.995)
    end

    # Full Service Restaurant - 90.1-2004
    template = '90.1-2004'
    building_type = 'FullServiceRestaurant'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      else
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 10)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.805 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.805 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 1053.32 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 1053.32 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 1053.32 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 1053.32 * 0.995)
      end
    end

    # Full Service Restaurant - 90.1-2013
    template = '90.1-2013'
    building_type = 'FullServiceRestaurant'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      else
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 10)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.805 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.805 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 993.32 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 993.32 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 993.32 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 993.32 * 0.995)
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
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 4)
      assert(water_heater.getHeaterThermalEfficiency.get.value < 0.820 * 1.005)
      assert(water_heater.getHeaterThermalEfficiency.get.value > 0.820 * 0.995)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 1860 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 1860 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 1860 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 1860 * 0.995)
    end

    # Retail Stripmall - 90.1-2004
    template = '90.1-2004'
    building_type = 'RetailStripmall'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 174 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 174 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 174 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 174 * 0.995)
    end

    # Retail Stripmall - 90.1-2013
    template = '90.1-2013'
    building_type = 'RetailStripmall'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 173 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 173 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 173 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 173 * 0.995)
    end

    # Primary School - 90.1-2004
    template = '90.1-2004'
    building_type = 'PrimarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      else
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 10)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.805 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.805 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 1065.49 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 1065.49 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 1065.49 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 1065.49 * 0.995)
      end
    end

    # Primary School - 90.1-2010
    template = '90.1-2013'
    building_type = 'PrimarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      else
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 10)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.805 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.805 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 1006.49 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 1006.49 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 1006.49 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 1006.49 * 0.995)
      end
    end

    # Secondary School - 90.1-2010
    template = '90.1-2010'
    building_type = 'SecondarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 2)
        assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      else
        assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 16)
        assert(water_heater.getHeaterThermalEfficiency.get.value < 0.803 * 1.005)
        assert(water_heater.getHeaterThermalEfficiency.get.value > 0.803 * 0.995)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 1268.35 * 1.005)
        assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 1268.35 * 0.995)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 1268.35 * 1.005)
        assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 1268.35 * 0.995)
      end
    end

    # Warehouse - 90.1-2004
    template = '90.1-2004'
    building_type = 'Warehouse'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 483 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 483 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 483 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 483 * 0.995)
    end

    # Warehouse - 90.1-2013
    template = '90.1-2013'
    building_type = 'Warehouse'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      assert(water_heater.getOffCycleLossCoefficienttoAmbientTemperature.get.value.round(0) == 1)
      assert(water_heater.getHeaterThermalEfficiency.get.value == 1.0)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  < 481 * 1.005)
      assert(water_heater.getOffCycleParasiticFuelConsumptionRate.value  > 481 * 0.995)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  < 481 * 1.005)
      assert(water_heater.getOnCycleParasiticFuelConsumptionRate.value  > 481 * 0.995)
    end
  end

end