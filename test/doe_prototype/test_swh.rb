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
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 16, 'Large Hotel (90.1-2004) - 600 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.803 * 1.005 && e_t > 0.803 * 0.995, 'Large Hotel (90.1-2004) - 600 gal - Thermal Efficiency')
        assert(off_par_fuel_cons < 18667.44 * 1.005 && off_par_fuel_cons > 18667.44 * 0.995, 'Large Hotel (90.1-2004) - 600 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 18667.44 * 1.005 && on_par_fuel_cons > 18667.44 * 0.995, 'Large Hotel (90.1-2004) - 600 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('300gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 11, 'Large Hotel (90.1-2004) - 300 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.804 * 1.005, 'Large Hotel (90.1-2004) - 300 gal - Thermal Efficiency')
        assert(e_t > 0.804 * 0.995, 'Large Hotel (90.1-2004) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Large Hotel (90.1-2004) - 300 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Large Hotel (90.1-2004) - 300 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('6.0gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 2, 'Large Hotel (90.1-2004) - 6.0 gal - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Large Hotel (90.1-2004) - 6.0 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Large Hotel (90.1-2004) - 6.0 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Large Hotel (90.1-2004) - 6.0 gal - On cycle parasitic fuel consumption')
      end
    end

    # Large Hotel - 90.1-2013
    template = '90.1-2013'
    building_type = 'LargeHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 16, 'Large Hotel (90.1-2013) - 600 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.803 * 1.005 && e_t > 0.803 * 0.995, 'Large Hotel (90.1-2013) - 600 gal - Thermal Efficiency')
        assert(off_par_fuel_cons < 18467.44 * 1.005 && off_par_fuel_cons > 18467.44 * 0.995, 'Large Hotel (90.1-2013) - 600 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 18467.44 * 1.005 && on_par_fuel_cons > 18467.44 * 0.995, 'Large Hotel (90.1-2013) - 600 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('300gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 11, 'Large Hotel (90.1-2013) - 300 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.804 * 1.005 && e_t > 0.804 * 0.995, 'Large Hotel (90.1-2013) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Large Hotel (90.1-2013) - 300 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Large Hotel (90.1-2013) - 300 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('6.0gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 1, 'Large Hotel (90.1-2013) - 6.0 gal - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Large Hotel (90.1-2013) - 6.0 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Large Hotel (90.1-2013) - 6.0 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Large Hotel (90.1-2013) - 6.0 gal - On cycle parasitic fuel consumption')
      end
    end

    # Highrise Apt. - 90.1-2013
    template = '90.1-2013'
    building_type = 'HighriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 16, 'Highrise Apt. (90.1-2013) - Off cycle loss coefficient to ambient')
      assert(e_t < 0.803 * 1.005 && e_t > 0.803 * 0.995, 'Highrise Apt. (90.1-2013) - Thermal Efficiency')
      assert(off_par_fuel_cons < 9260.51 * 1.005 && off_par_fuel_cons > 9260.51 * 0.995, 'Highrise Apt. (90.1-2013) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 9260.51 * 1.005 && on_par_fuel_cons > 9260.51 * 0.995, 'Highrise Apt. (90.1-2013) - On cycle parasitic fuel consumption')
    end

    # Midrise Apt. - 90.1-2013
    template = '90.1-2013'
    building_type = 'MidriseApartment'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 66, 'Midrise Apt. (90.1-2013) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Midrise Apt. (90.1-2013) - Thermal Efficiency')
      assert(off_par_fuel_cons < 1889.00 * 1.005 && off_par_fuel_cons > 1889.00 * 0.995, 'Midrise Apt. (90.1-2013) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 1889.00 * 1.005 && on_par_fuel_cons > 1889.00 * 0.995, 'Midrise Apt. (90.1-2013) - On cycle parasitic fuel consumption')
    end

    # Hospital - 90.1-2004
    template = '90.1-2004'
    building_type = 'Hospital'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 16, 'Hospital (90.1-2004) - 600 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.803 * 1.005 && e_t > 0.803 * 0.995, 'Hospital (90.1-2004) - 600 gal - Thermal Efficiency')
        assert(off_par_fuel_cons < 20291.76 * 1.005 && off_par_fuel_cons > 20291.76 * 0.995, 'Hospital (90.1-2004) - 600 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 20291.76 * 1.005 && on_par_fuel_cons > 20291.76 * 0.995, 'Hospital (90.1-2004) - 600 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('300gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 11, 'Hospital (90.1-2004) - 300 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.804 * 1.005 && e_t > 0.804 * 0.995, 'Hospital (90.1-2004) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Hospital (90.1-2004) - 300 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Hospital (90.1-2004) - 300 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('6.0gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 2, 'Large Hotel (90.1-2013) - 6.0 gal - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Hospital (90.1-2004) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Hospital (90.1-2004) - 6.0 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Hospital (90.1-2004) - 6.0 gal - On cycle parasitic fuel consumption')
      end
    end

    # Hospital - 90.1-2013
    template = '90.1-2013'
    building_type = 'Hospital'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('600gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 16, 'Hospital (90.1-2013) - 600 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.803 * 1.005 && e_t > 0.803 * 0.995, 'Hospital (90.1-2013) - 600 gal - Thermal Efficiency')
        assert(off_par_fuel_cons < 20036.76 * 1.005 && off_par_fuel_cons > 20036.76 * 0.995, 'Hospital (90.1-2013) - 600 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 20036.76 * 1.005 && on_par_fuel_cons > 20036.76 * 0.995, 'Hospital (90.1-2013) - 600 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('300gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 11, 'Hospital (90.1-2013) - 300 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.804 * 1.005 && e_t > 0.804 * 0.995, 'Hospital (90.1-2013) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Hospital (90.1-2013) - 300 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Hospital (90.1-2013) - 300 gal - On cycle parasitic fuel consumption')
      elsif water_heater.name.to_s.include?('6.0gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 1, 'Hospital (90.1-2013) - 6.0 gal - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Hospital (90.1-2013) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Hospital (90.1-2013) - 6.0 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Hospital (90.1-2013) - 6.0 gal - On cycle parasitic fuel consumption')
      end
    end

    # Small Hotel - 90.1-2013
    template = '90.1-2013'
    building_type = 'SmallHotel'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('300gal')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        assert(water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0) == 11)
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 11, 'Small Hotel (90.1-2013) - 300 gal - Off cycle loss coefficient to ambient')
        assert(e_t < 0.804 * 1.005 && e_t > 0.804 * 0.995, 'Small Hotel (90.1-2013) - 300 gal - Thermal Efficiency')
        assert(off_par_fuel_cons < 8296.73 * 1.005 && off_par_fuel_cons > 8296.73 * 0.995, 'Small Hotel (90.1-2013) - 300 gal - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 8296.73 * 1.005 && on_par_fuel_cons > 8296.73 * 0.995, 'Small Hotel (90.1-2013) - 300 gal - On cycle parasitic fuel consumption')
      else
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 10, 'Small Hotel (90.1-2013) - Off cycle loss coefficient to ambient')
        assert(e_t < 0.805 * 1.005 && e_t > 0.805 * 0.995, 'Small Hotel (90.1-2013) - Thermal Efficiency')
        assert(off_par_fuel_cons == 0, 'Small Hotel (90.1-2013) - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons == 0, 'Small Hotel (90.1-2013) - On cycle parasitic fuel consumption')
      end
    end

    # Small Office - 90.1-2004
    template = '90.1-2004'
    building_type = 'SmallOffice'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 2, 'Small Office (90.1-2004) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Small Office (90.1-2004) - Thermal Efficiency')
      assert(off_par_fuel_cons < 572 * 1.005 && off_par_fuel_cons > 572 * 0.995, 'Small Office (90.1-2004) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 572 * 1.005 && on_par_fuel_cons > 572 * 0.995, 'Small Office (90.1-2004) - On cycle parasitic fuel consumption')
    end

    # Small Office - 90.1-2013
    template = '90.1-2013'
    building_type = 'SmallOffice'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 1, 'Small Office (90.1-2013) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Small Office (90.1-2013) - Thermal Efficiency')
      assert(off_par_fuel_cons < 571 * 1.005 && off_par_fuel_cons > 571 * 0.995, 'Small Office (90.1-2013) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 571 * 1.005 && on_par_fuel_cons > 571 * 0.995, 'Small Office (90.1-2013) - On cycle parasitic fuel consumption')
    end

    # Full Service Restaurant - 90.1-2004
    template = '90.1-2004'
    building_type = 'FullServiceRestaurant'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        assert(off_cycle_loss_coeff_to_amb == 2, 'Full Service Restaurant (90.1-2004) - Booster - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Full Service Restaurant (90.1-2004) - Booster - Thermal Efficiency')
      else
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 10, 'Full Service Restaurant (90.1-2004) - Off cycle loss coefficient to ambient')
        assert(e_t < 0.805 * 1.005 && e_t > 0.805 * 0.995, 'Full Service Restaurant (90.1-2004) - Thermal Efficiency')
        assert(off_par_fuel_cons < 1053.32 * 1.005 && off_par_fuel_cons > 1053.32 * 0.995, 'Full Service Restaurant (90.1-2004) - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 1053.32 * 1.005 && on_par_fuel_cons > 1053.32 * 0.995, 'Full Service Restaurant (90.1-2004) - On cycle parasitic fuel consumption')
      end
    end

    # Full Service Restaurant - 90.1-2013
    template = '90.1-2013'
    building_type = 'FullServiceRestaurant'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        assert(off_cycle_loss_coeff_to_amb == 1, 'Full Service Restaurant (90.1-2013) - Booster - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Full Service Restaurant (90.1-2013) - Booster - Thermal Efficiency')
      else
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 10, 'Full Service Restaurant (90.1-2013) - Off cycle loss coefficient to ambient')
        assert(e_t < 0.805 * 1.005 && e_t > 0.805 * 0.995, 'Full Service Restaurant (90.1-2013) - Thermal Efficiency')
        assert(off_par_fuel_cons < 993.32 * 1.005 && off_par_fuel_cons > 993.32 * 0.995, 'Full Service Restaurant (90.1-2013) - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 993.32 * 1.005 && on_par_fuel_cons > 993.32 * 0.995, 'Full Service Restaurant (90.1-2013) - On cycle parasitic fuel consumption')
      end
    end

    # Retail Standalone - 90.1-2013
    template = '90.1-2013'
    building_type = 'RetailStandalone'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 4, 'Retail Standalone (90.1-2013) - Off cycle loss coefficient to ambient')
      assert(e_t < 0.820 * 1.005 && e_t > 0.820 * 0.995, 'Retail Standalone (90.1-2013) - Thermal Efficiency')
      assert(off_par_fuel_cons < 1860 * 1.005 && off_par_fuel_cons > 1860 * 0.995, 'Retail Standalone (90.1-2013) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 1860 * 1.005 && on_par_fuel_cons > 1860 * 0.995, 'Retail Standalone (90.1-2013) - On cycle parasitic fuel consumption')
    end

    # Retail Stripmall - 90.1-2004
    template = '90.1-2004'
    building_type = 'RetailStripmall'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 2, 'Retail Stripmall (90.1-2004) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Retail Stripmall (90.1-2004) - Thermal Efficiency')
      assert(off_par_fuel_cons < 174 * 1.005 && off_par_fuel_cons > 174 * 0.995, 'Retail Stripmall (90.1-2004) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 174 * 1.005 && on_par_fuel_cons > 174 * 0.995, 'Retail Stripmall (90.1-2004) - On cycle parasitic fuel consumption')
    end

    # Retail Stripmall - 90.1-2013
    template = '90.1-2013'
    building_type = 'RetailStripmall'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 1, 'Retail Stripmall (90.1-2013) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Retail Stripmall (90.1-2013) - Thermal Efficiency')
      assert(off_par_fuel_cons < 173 * 1.005 && off_par_fuel_cons > 173 * 0.995, 'Retail Stripmall (90.1-2013) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 173 * 1.005 && on_par_fuel_cons > 173 * 0.995, 'Retail Stripmall (90.1-2013) - On cycle parasitic fuel consumption')
    end

    # Primary School - 90.1-2004
    template = '90.1-2004'
    building_type = 'PrimarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        assert(off_cycle_loss_coeff_to_amb == 2, 'Primary School (90.1-2004) - Booster - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Primary School (90.1-2004) - Booster - Thermal Efficiency')
      else
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 10, 'Primary School (90.1-2004) - Off cycle loss coefficient to ambient')
        assert(e_t < 0.805 * 1.005 && e_t > 0.805 * 0.995, 'Primary School (90.1-2004) - Thermal Efficiency')
        assert(off_par_fuel_cons < 1065.49 * 1.005 && off_par_fuel_cons > 1065.49 * 0.995, 'Primary School (90.1-2004) - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 1065.49 * 1.005 && on_par_fuel_cons > 1065.49 * 0.995, 'Primary School (90.1-2004) - On cycle parasitic fuel consumption')
      end
    end

    # Primary School - 90.1-2010
    template = '90.1-2013'
    building_type = 'PrimarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        assert(off_cycle_loss_coeff_to_amb == 1, 'Primary School (90.1-2010) - Booster - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Primary School (90.1-2010) - Booster - Thermal Efficiency')
      else
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 10, 'Primary School (90.1-2010) - Off cycle loss coefficient to ambient')
        assert(e_t < 0.805 * 1.005 && e_t > 0.805 * 0.995, 'Primary School (90.1-2010) - Thermal Efficiency')
        assert(off_par_fuel_cons < 1006.49 * 1.005 && off_par_fuel_cons > 1006.49 * 0.995, 'Primary School (90.1-2010) - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 1006.49 * 1.005 && on_par_fuel_cons > 1006.49 * 0.995, 'Primary School (90.1-2010) - On cycle parasitic fuel consumption')
      end
    end

    # Secondary School - 90.1-2010
    template = '90.1-2010'
    building_type = 'SecondarySchool'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        assert(off_cycle_loss_coeff_to_amb == 2, 'Secondary School (90.1-2010) - Booster - Off cycle loss coefficient to ambient')
        assert(e_t == 1, 'Secondary School (90.1-2010) - Booster - Thermal Efficiency')
      else
        off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
        e_t = water_heater.heaterThermalEfficiency.get
        off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
        on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
        assert(off_cycle_loss_coeff_to_amb == 16, 'Secondary School (90.1-2010) - Off cycle loss coefficient to ambient')
        assert(e_t < 0.803 * 1.005 && e_t > 0.803 * 0.995, 'Secondary School (90.1-2010) - Thermal Efficiency')
        assert(off_par_fuel_cons < 1268.35 * 1.005 && off_par_fuel_cons > 1268.35 * 0.995, 'Secondary School (90.1-2010) - Off cycle parasitic fuel consumption')
        assert(on_par_fuel_cons < 1268.35 * 1.005 && on_par_fuel_cons > 1268.35 * 0.995, 'Secondary School (90.1-2010) - On cycle parasitic fuel consumption')
      end
    end

    # Warehouse - 90.1-2004
    template = '90.1-2004'
    building_type = 'Warehouse'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 1, 'Warehouse (90.1-2004) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Warehouse (90.1-2004) - Thermal Efficiency')
      assert(off_par_fuel_cons < 483 * 1.005 && off_par_fuel_cons > 483 * 0.995, 'Warehouse (90.1-2004) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 483 * 1.005 && on_par_fuel_cons > 483 * 0.995, 'Warehouse (90.1-2004) - On cycle parasitic fuel consumption')
    end

    # Warehouse - 90.1-2013
    template = '90.1-2013'
    building_type = 'Warehouse'

    model = TestSHW.model_test(template, building_type)  
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      off_cycle_loss_coeff_to_amb = water_heater.offCycleLossCoefficienttoAmbientTemperature.get.round(0)
      e_t = water_heater.heaterThermalEfficiency.get
      off_par_fuel_cons = water_heater.offCycleParasiticFuelConsumptionRate
      on_par_fuel_cons = water_heater.onCycleParasiticFuelConsumptionRate
      assert(off_cycle_loss_coeff_to_amb == 1, 'Warehouse (90.1-2013) - Off cycle loss coefficient to ambient')
      assert(e_t == 1, 'Warehouse (90.1-2013) - Thermal Efficiency')
      assert(off_par_fuel_cons < 481 * 1.005 && off_par_fuel_cons > 481 * 0.995, 'Warehouse (90.1-2013) - Off cycle parasitic fuel consumption')
      assert(on_par_fuel_cons < 481 * 1.005 && on_par_fuel_cons > 481 * 0.995, 'Warehouse (90.1-2013) - On cycle parasitic fuel consumption')
    end
  end

end