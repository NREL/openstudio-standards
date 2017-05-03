require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


class HVACEfficienciesTest < MiniTest::Test
  #set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  #set to true to run the simulations.
  FULL_SIMULATIONS = false

  # Test to validate NECB 2011 rules for cooling tower:
  # "if capacity <= 1750 kW ---> one cell
  # if capacity > 1750 kW ---> number of cells = capacity/1750 rounded up"
  # power = 0.015 x capacity in kW
  def test_coolingtower
    output_folder = "#{File.dirname(__FILE__)}/output/coolingtower"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
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
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.716240_CWEC.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    chiller_types.each do |chiller_type|
      test_chiller_cap.each do |chiller_cap|
        name = "sys6_ChillerType_#{chiller_type}~#{chiller_cap}watts"
        puts "***************************************#{name}*******************************************************\n"
        model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.716240_CWEC.epw').set_weather_file(model)
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule	
        BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
        BTAP::Resources::HVAC::HVACTemplates::NECB2011.assign_zones_sys6(
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
        result = run_the_measure(model, "#{output_folder}/#{name}/sizing")
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
        assert(num_of_cells_is_correct, 'Tower number of cells is not correct based on NECB 2011')
        # compare the fan power to expected value
        necb2011_fan_power = 0.015 * tower_cap
        tower_fan_power_is_correct = false
        rel_diff = (necb2011_fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/necb2011_fan_power
        if rel_diff < tol then tower_fan_power_is_correct = true end
        assert(tower_fan_power_is_correct, 'Tower fan power is not correct based on NECB 2011')
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
      building_vintage = 'NECB 2011'
      building_type = 'NECB'
      climate_zone = 'NECB'
      # building_vintage = '90.1-2013'

      # Load the Openstudio_Standards JSON files
      # model.load_openstudio_standards_json

      # Assign the standards to the model
      # model.template = building_vintage

      # Make a directory to run the sizing run in

      unless Dir.exist? sizing_dir
        FileUtils.mkdir_p(sizing_dir)
      end

      # Perform a sizing run
      if model.runSizingRun("#{sizing_dir}/SizingRun1") == false
        puts "could not find sizing run #{sizing_dir}/SizingRun1"
        raise("could not find sizing run #{sizing_dir}/SizingRun1")
        return false
      else
        puts "found sizing run #{sizing_dir}/SizingRun1"
      end

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

      # need to set prototype assumptions so that HRV added
      model.apply_prototype_hvac_assumptions(building_type, building_vintage, climate_zone)
      # Apply the HVAC efficiency standard
      model.apply_hvac_efficiency_standard(building_vintage, climate_zone)
      # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end
  end
end
