require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'


class HVACEfficienciesTest < MiniTest::Test
  # set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  # set to true to run the simulations.
  FULL_SIMULATIONS = false
begin
  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
  end

  # Test to validate sizing rules for air loop
  def test_airloop_sizing_rules_vav
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build("NECB2011")

    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_type = 'Reciprocating'
    heating_coil_type = 'Electric'
    vavfan_type = 'AF_or_BI_rdg_fancurve'

    # save baseline
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    tol = 1.0e-3
    name = 'sys6'
    puts "***************************************#{name}*******************************************************\n"

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
      model: model,
      zones: model.getThermalZones,
      heating_coil_type: heating_coil_type,
      baseboard_type: baseboard_type,
      chiller_type: chiller_type,
      fan_type: vavfan_type,
      hw_loop: hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_airloop_sizing_rules_vav: Failure in Standards for #{name}")
    airloops = model.getAirLoopHVACs
    airloops.each do |iloop|
      thermal_zones = iloop.thermalZones
      tot_floor_area = 0.0
      thermal_zones.each do |izone|
        sizing_zone = izone.sizingZone
        # check sizing factors
        heating_sizing_factor = sizing_zone.zoneHeatingSizingFactor
        cooling_sizing_factor = sizing_zone.zoneCoolingSizingFactor
        necb_heating_sizing_factor = 1.3
        necb_cooling_sizing_factor = 1.1
        diff = (heating_sizing_factor.to_f - necb_heating_sizing_factor).abs / necb_heating_sizing_factor
        heating_sizing_factor_set_correctly = true
        if diff > tol then heating_sizing_factor_set_correctly = false end
        assert(heating_sizing_factor_set_correctly, "test_airloop_sizing_rules_vav: Heating sizing factor does not match necb requirement #{name}")
        diff = (cooling_sizing_factor.to_f - necb_cooling_sizing_factor).abs / necb_cooling_sizing_factor
        cooling_sizing_factor_set_correctly = true
        if diff > tol then cooling_sizing_factor_set_correctly = false end
        assert(cooling_sizing_factor_set_correctly, "test_airloop_sizing_rules_vav: Cooling sizing factor does not match necb requirement #{name}")
        # check supply temperatures
        heating_sizing_temp = sizing_zone.zoneHeatingDesignSupplyAirTemperature
        cooling_sizing_temp = sizing_zone.zoneCoolingDesignSupplyAirTemperature
        necb_heating_sizing_temp = 43.0
        necb_cooling_sizing_temp = 13.0
        diff = (heating_sizing_temp.to_f - necb_heating_sizing_temp).abs / necb_heating_sizing_temp
        heating_sizing_temp_set_correctly = true
        if diff > tol then heating_sizing_temp_set_correctly = false end
        assert(heating_sizing_temp_set_correctly, "test_airloop_sizing_rules_vav: Heating sizing supply temperature does not match necb requirement #{name}")
        diff = (heating_sizing_temp.to_f - necb_heating_sizing_temp).abs / necb_heating_sizing_temp
        cooling_sizing_temp_set_correctly = true
        if diff > tol then cooling_sizing_temp_set_correctly = false end
        assert(cooling_sizing_temp_set_correctly, "test_airloop_sizing_rules_vav: Cooling sizing supply temperature does not match necb requirement #{name}")
        tot_floor_area += izone.floorArea
      end
      #necb_min_flow_rate = 0.002 * tot_floor_area
      #demand_comps = iloop.demandComponents
      #tot_min_flow_rate = 0.0
      #demand_comps.each do |icomp|
        #if icomp.to_AirTerminalSingleDuctVAVReheat.is_initialized
          #vav_box = icomp.to_AirTerminalSingleDuctVAVReheat.get
          #tot_min_flow_rate += vav_box.fixedMinimumAirFlowRate
        #end
      #end
      #diff = (tot_min_flow_rate - necb_min_flow_rate).abs / necb_min_flow_rate
      #min_flow_rate_set_correctly = true
      #if diff > tol then min_flow_rate_set_correctly = false end
      #assert(min_flow_rate_set_correctly, "test_airloop_sizing_rules_vav: Minimum vav box flow rate does not match necb requirement #{name}")
    end
  end
end
  
begin
  # Test to validate sizing rules for air loop
  def test_airloop_sizing_rules_heatpump
    standard = Standard.build("NECB2011")
    output_folder = "#{File.dirname(__FILE__)}/output/airloop_sizing_rules"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'DX'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    tol = 1.0e-3
    name = 'sys3'
    puts "***************************************#{name}*******************************************************\n"
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/../resources/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(
      model: model,
      zones: model.getThermalZones,
      heating_coil_type: heating_coil_type,
      baseboard_type: baseboard_type,
      hw_loop: hw_loop,
      new_auto_zoner: false)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_airloop_sizing_rules_heatpump: Failure in Standards for #{name}")
    airloops = model.getAirLoopHVACs
    airloops.each do |iloop|
      thermal_zones = iloop.thermalZones
      tot_floor_area = 0.0
      thermal_zones.each do |izone|
        sizing_zone = izone.sizingZone
        # check sizing factors
        heating_sizing_factor = sizing_zone.zoneHeatingSizingFactor
        cooling_sizing_factor = sizing_zone.zoneCoolingSizingFactor
        necb_heating_sizing_factor = 1.3
        necb_cooling_sizing_factor = 1.0
        diff = (heating_sizing_factor.to_f - necb_heating_sizing_factor).abs / necb_heating_sizing_factor
        heating_sizing_factor_set_correctly = true
        if diff > tol then heating_sizing_factor_set_correctly = false end
        assert(heating_sizing_factor_set_correctly, "test_airloop_sizing_rules_heatpump: Heating sizing factor does not match necb requirement #{name} got #{heating_sizing_factor} expected #{necb_heating_sizing_factor}")
        diff = (cooling_sizing_factor.to_f - necb_cooling_sizing_factor).abs / necb_cooling_sizing_factor
        cooling_sizing_factor_set_correctly = true
        if diff > tol then cooling_sizing_factor_set_correctly = false end
        assert(cooling_sizing_factor_set_correctly, "test_airloop_sizing_rules_heatpump: Cooling sizing factor does not match necb requirement #{name} got #{cooling_sizing_factor} expected #{necb_cooling_sizing_factor}")
        # check supply temperatures
        heating_sizing_temp = sizing_zone.zoneHeatingDesignSupplyAirTemperature
        cooling_sizing_temp = sizing_zone.zoneCoolingDesignSupplyAirTemperature
        necb_heating_sizing_temp = 43.0
        necb_cooling_sizing_temp = 13.0
        diff = (heating_sizing_temp.to_f - necb_heating_sizing_temp).abs / necb_heating_sizing_temp
        heating_sizing_temp_set_correctly = true
        if diff > tol then heating_sizing_temp_set_correctly = false end
        assert(heating_sizing_temp_set_correctly, "test_airloop_sizing_rules_heatpump: Heating sizing supply temperature does not match necb requirement #{name}")
        diff = (heating_sizing_temp.to_f - necb_heating_sizing_temp).abs / necb_heating_sizing_temp
        cooling_sizing_temp_set_correctly = true
        if diff > tol then cooling_sizing_temp_set_correctly = false end
        assert(cooling_sizing_temp_set_correctly, "test_airloop_sizing_rules_heatpump: Cooling sizing supply temperature does not match necb requirement #{name}")
        tot_floor_area += izone.floorArea
      end
    end
  end
end
  
  def run_simulations(output_folder)
    if FULL_SIMULATIONS == true
      file_array = []
      BTAP::FileIO.get_find_files_from_folder_by_extension(output_folder, '.osm').each do |file|
        # skip any sizing.osm file.
        unless file.to_s.include? 'sizing.osm'
          file_array << file
        end
      end
      BTAP::SimManager.simulate_files(output_folder, file_array)
      BTAP::Reporting.get_all_annual_results_from_runmanger_by_files(output_folder, file_array)

      are_there_no_severe_errors = File.zero?("#{output_folder}/failed simulations.txt")
      assert_equal(true, are_there_no_severe_errors, "Simulations had severe errors. Check #{output_folder}/failed simulations.txt")
    end
  end

  def run_the_measure(model, sizing_dir)
    if PERFORM_STANDARDS
      # Hard-code the building vintage
      building_vintage = 'NECB2011'
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
