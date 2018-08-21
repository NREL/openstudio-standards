require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


class NECB_HVAC_Tests < MiniTest::Test
  #set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  #set to true to run the simulations.
  FULL_SIMULATIONS = false

  # Test to validate NECB2011 rules for cooling tower:
  # "if capacity <= 1750 kW ---> one cell
  # if capacity > 1750 kW ---> number of cells = capacity/1750 rounded up"
  # power = 0.015 x capacity in kW
  def test_NECB2011_coolingtower
    output_folder = "#{File.dirname(__FILE__)}/output/coolingtower"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2011')

    first_cutoff_twr_cap = 1750000.0
    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    test_chiller_cap = [1000000.0, 4000000.0]
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    template = 'NECB2011'
    clgtowerFanPowerFr = 0.015
    designInletTwb = 24.0
    designApproachTemperature = 5.0
    chiller_types.each do |chiller_type|
      test_chiller_cap.each do |chiller_cap|
        name = "sys6_#{template}_ChillerType_#{chiller_type}~#{chiller_cap}watts"
        puts "***************************************#{name}*******************************************************\n"
        model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
        standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
          model,
          model.getThermalZones,
          boiler_fueltype,
          heating_coil_type,
          baseboard_type,
          chiller_type,
          fan_type,
          hw_loop)
        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
        model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }
        # run the standards
        result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
        # Save the model
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
        assert_equal(true, result, "Failure in Standards for #{name}")
        necb2011_refCOP = 5.0
        model.getChillerElectricEIRs.each do |ichiller|
          if ichiller.name.to_s.include? 'Primary' then necb2011_refCOP = ichiller.referenceCOP end
        end
        tower_cap = chiller_cap * (1.0 + 1.0/necb2011_refCOP)
        this_is_the_first_cap_range = false
        this_is_the_second_cap_range = false
        if tower_cap < first_cutoff_twr_cap
          this_is_the_first_cap_range = true
        else
          this_is_the_second_cap_range = true
        end
        # compare tower number of cells to expected value
        tower = model.getCoolingTowerSingleSpeeds[0]
        num_of_cells_is_correct = false
        if this_is_the_first_cap_range
          necb2011_num_cells = 1
        elsif this_is_the_second_cap_range
          necb2011_num_cells = (tower_cap/first_cutoff_twr_cap + 0.5).round
        end
        if tower.numberofCells == necb2011_num_cells then num_of_cells_is_correct = true end
        assert(num_of_cells_is_correct, "Tower number of cells is not correct based on #{template}")
        # compare the fan power to expected value
        fan_power = clgtowerFanPowerFr * tower_cap
        tower_fan_power_is_correct = false
        rel_diff = (fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/fan_power
        if rel_diff < tol then tower_fan_power_is_correct = true end
        assert(tower_fan_power_is_correct, "Tower fan power is not correct based on #{template}")
        # compare design inlet wetbulb to expected value
        tower_Twb_is_correct = false
        rel_diff = (tower.designInletAirWetBulbTemperature.to_f - designInletTwb).abs/designInletTwb
        if rel_diff < tol then tower_Twb_is_correct = true end
        assert(tower_Twb_is_correct, "Tower inlet wet-bulb is not correct based on #{template}")
        # compare design approach temperature to expected value
        tower_appT_is_correct = false
        rel_diff = (tower.designApproachTemperature.to_f - designApproachTemperature).abs/designApproachTemperature
        if rel_diff < tol then tower_appT_is_correct = true end
        assert(tower_appT_is_correct, "Tower approach temperature is not correct based on #{template}")
      end
    end
  end

  # NECB2015 rules for cooling tower
  # power = 0.013 x capacity in kW
  def test_NECB2015_coolingtower
    output_folder = "#{File.dirname(__FILE__)}/output/coolingtower"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2015')

    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    chiller_cap = 1000000.0
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    template = 'NECB2015'
    clgtowerFanPowerFr = 0.013
    chiller_types.each do |chiller_type|
      name = "sys6_#{template}_ChillerType_#{chiller_type}~#{chiller_cap}watts"
      puts "***************************************#{name}*******************************************************\n"
      model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
        model,
        model.getThermalZones,
        boiler_fueltype,
        heating_coil_type,
        baseboard_type,
        chiller_type,
        fan_type,
        hw_loop)
      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
      model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }
      # run the standards
      result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
      # Save the model
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
      assert_equal(true, result, "Failure in Standards for #{name}")
      necb2011_refCOP = 5.0
      model.getChillerElectricEIRs.each do |ichiller|
        if ichiller.name.to_s.include? 'Primary' then necb2011_refCOP = ichiller.referenceCOP end
      end
      tower_cap = chiller_cap * (1.0 + 1.0/necb2011_refCOP)
      # compare the fan power to expected value
      fan_power = clgtowerFanPowerFr * tower_cap
      tower_fan_power_is_correct = false
      tower = model.getCoolingTowerSingleSpeeds[0]
      rel_diff = (fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/fan_power
      if rel_diff < tol then tower_fan_power_is_correct = true end
      assert(tower_fan_power_is_correct, "Tower fan power is not correct based on #{template}")
    end
  end

  def run_the_measure(model, template, sizing_dir)
    if PERFORM_STANDARDS
      # Hard-code the building vintage
      building_vintage = template
      building_type = 'NECB'
      climate_zone = 'NECB'
      standard = Standard.build(building_vintage)

      # Make a directory to run the sizing run in
      unless Dir.exist? sizing_dir
        FileUtils.mkdir_p(sizing_dir)
      end

      # Perform a sizing run
      if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
        puts "could not find sizing run #{sizing_dir}/SizingRun1"
        raise("could not find sizing run #{sizing_dir}/SizingRun1")
        return false
      else
        puts "found sizing run #{sizing_dir}/SizingRun1"
      end

      # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

      # need to set prototype assumptions so that HRV added
      standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
      # Apply the HVAC efficiency standard
      standard.model_apply_hvac_efficiency_standard(model, climate_zone)
      # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

      # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end
  end
end
