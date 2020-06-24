require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'


class NECB_HVAC_Tests < MiniTest::Test
  # set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  # set to true to run the simulations.
  FULL_SIMULATIONS = false

  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
  end

  # Test to validate the effectiveness of the hrv
  def test_NECB2011_hrv_eff
    output_folder = "#{File.dirname(__FILE__)}/output/coolingtower"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    template = 'NECB2011'
    standard = Standard.build(template)
 
    # Generate the osm files for all relevant cases to generate the test data
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "hrv"
    puts "***************************************#{name}*******************************************************\n"
    # add hvac system
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'DX'
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                zones: model.getThermalZones,
                                                                                                heating_coil_type: heating_coil_type,
                                                                                                baseboard_type: baseboard_type,
                                                                                                hw_loop: hw_loop,
                                                                                                new_auto_zoner: false)
    systems = model.getAirLoopHVACs
    # increase default outdoor air requirement so that some of the systems in the project would require an HRV
    for isys in 0..0
      zones = systems[isys].thermalZones
      zones.each do |izone|
        spaces = izone.spaces
        spaces.each do |ispace|
          oa_objs = ispace.designSpecificationOutdoorAir.get
          oa_flow_p_person = oa_objs.outdoorAirFlowperPerson
          oa_objs.setOutdoorAirFlowperPerson(30.0*oa_flow_p_person) #l/s
        end
      end
    end

    # run the standards
    result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_shw_curves: Failure in Standards for #{name}")
    systems = model.getAirLoopHVACs
    tol = 1.0e-5
    necb_hrv_eff = 0.5
    systems.each do |isys|
      has_hrv = standard.air_loop_hvac_energy_recovery_ventilator_required?(isys, 'NECB')
      if has_hrv
        hrv_objs = model.getHeatExchangerAirToAirSensibleAndLatents
        diff1 = (hrv_objs[0].latentEffectivenessat100CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff2 = (hrv_objs[0].latentEffectivenessat100HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff3 = (hrv_objs[0].latentEffectivenessat75CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff4 = (hrv_objs[0].latentEffectivenessat75HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff5 = (hrv_objs[0].sensibleEffectivenessat100CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff6 = (hrv_objs[0].sensibleEffectivenessat100HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff7 = (hrv_objs[0].sensibleEffectivenessat75CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff8 = (hrv_objs[0].sensibleEffectivenessat75HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        hrv_eff_value_is_correct = false
        if diff1 && diff2 && diff3 && diff4 && diff5 && diff6 && diff7 && diff8 then hrv_eff_value_is_correct = true end
        assert(hrv_eff_value_is_correct,"HRV effectiveness test results do not match expected results!")
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
