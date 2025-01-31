require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Cooling_Tower_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate NECB2011 rules for cooling tower:
  # "if capacity <= 1750 kW ---> one cell
  # if capacity > 1750 kW ---> number of cells = capacity/1750 rounded up"
  # power = 0.015 x capacity in kW
  def test_NECB2011_coolingtower

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = "NECB2011"
    standard = get_standard(template)
    save_intermediate_models = false

    first_cutoff_twr_cap = 1750000.0
    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    test_chiller_cap = [1000000.0, 4000000.0]
    clgtowerFanPowerFr = 0.015
    designInletTwb = 24.0
    designApproachTemperature = 5.0
    chiller_types.each do |chiller_type|
      test_chiller_cap.each do |chiller_cap|
        name = "sys6_#{template}_ChillerType_#{chiller_type}-#{chiller_cap}watts"
        name.gsub!(/\s+/, "-")
        puts "***************#{name}***************\n"

        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
        OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, boiler_fueltype, always_on)
        standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                            zones: model.getThermalZones,
                                                                            heating_coil_type: heating_coil_type,
                                                                            baseboard_type: baseboard_type,
                                                                            chiller_type: chiller_type,
                                                                            fan_type: fan_type,
                                                                            hw_loop: hw_loop)
        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
        model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }

        # Run the measure.
        run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

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

        # Compare tower number of cells to expected value.
        tower = model.getCoolingTowerSingleSpeeds[0]
        num_of_cells_is_correct = false
        if this_is_the_first_cap_range
          necb2011_num_cells = 1
        elsif this_is_the_second_cap_range
          necb2011_num_cells = (tower_cap/first_cutoff_twr_cap + 0.5).round
        end
        if tower.numberofCells == necb2011_num_cells then num_of_cells_is_correct = true end
        assert(num_of_cells_is_correct, "Tower number of cells is not correct based on #{template}")

        # Compare the fan power to expected value.
        fan_power = clgtowerFanPowerFr * tower_cap
        tower_fan_power_is_correct = false
        rel_diff = (fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/fan_power
        if rel_diff < tol then tower_fan_power_is_correct = true end
        assert(tower_fan_power_is_correct, "Tower fan power is not correct based on #{template}")

        # Compare design inlet wetbulb to expected value.
        tower_Twb_is_correct = false
        rel_diff = (tower.designInletAirWetBulbTemperature.to_f - designInletTwb).abs/designInletTwb
        if rel_diff < tol then tower_Twb_is_correct = true end
        assert(tower_Twb_is_correct, "Tower inlet wet-bulb is not correct based on #{template}")

        # Compare design approach temperature to expected value.
        tower_appT_is_correct = false
        rel_diff = (tower.designApproachTemperature.to_f - designApproachTemperature).abs/designApproachTemperature
        if rel_diff < tol then tower_appT_is_correct = true end
        assert(tower_appT_is_correct, "Tower approach temperature is not correct based on #{template}")
      end
    end
  end

  # NECB2015 rules for cooling tower.
  # power = 0.013 x capacity in kW.
  def test_NECB2015_coolingtower

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2015'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 6.
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    chiller_cap = 1000000.0
    clgtowerFanPowerFr = 0.013

    chiller_types.each do |chiller_type|
      name = "sys6_#{template}_ChillerType_#{chiller_type}-#{chiller_cap}watts"
      name.gsub!(/\s+/, "-")
      puts "***************#{name}***************\n"

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                          zones: model.getThermalZones,
                                                                          heating_coil_type: heating_coil_type,
                                                                          baseboard_type: baseboard_type,
                                                                          chiller_type: chiller_type,
                                                                          fan_type: fan_type,
                                                                          hw_loop: hw_loop)
      model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }

      # Run sizing.
      run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

      refCOP = 5.0
      model.getChillerElectricEIRs.each do |ichiller|
        if ichiller.name.to_s.include? 'Primary' then refCOP = ichiller.referenceCOP end
      end
      tower_cap = chiller_cap * (1.0 + 1.0/refCOP)

      # Compare the fan power to expected value.
      tol = 1.0e-3
      fan_power = clgtowerFanPowerFr * tower_cap
      tower_fan_power_is_correct = false
      tower = model.getCoolingTowerSingleSpeeds[0]
      rel_diff = (fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/fan_power
      if rel_diff < tol then tower_fan_power_is_correct = true end
      assert(tower_fan_power_is_correct, "Tower fan power is not correct based on #{template}")
    end
  end

end
