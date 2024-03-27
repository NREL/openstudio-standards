require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Loop_Rules_Tests < Minitest::Test


  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate hot water loop rules
  def test_hw_loop_rules

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    chiller_type = 'Scroll'
    heating_coil_type = 'Electric'
    fan_type = 'AF_or_BI_rdg_fancurve'

    name = "sys6"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                        zones: model.getThermalZones,
                                                                        heating_coil_type: heating_coil_type,
                                                                        baseboard_type: baseboard_type,
                                                                        chiller_type: chiller_type,
                                                                        fan_type: fan_type,
                                                                        hw_loop: hw_loop)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

    loops = model.getPlantLoops
    loops.each do |iloop|
      if iloop.name.to_s == 'Hot Water Loop'
        deltaT = iloop.sizingPlant.loopDesignTemperatureDifference
        msg = "#{self.class.name}::#{__method__}. Hot Water Loop deltaT is different from expected value"
        assert_in_delta(16.0, deltaT, 0.01, msg)

        supply_comps = iloop.supplyComponents
        supply_comps.each do |icomp|
          if icomp.to_PumpConstantSpeed.is_initialized
            msg = "#{self.class.name}::#{__method__}. Hot Water Loop pump, #{icomp.name}, is not variable speed"
            assert(false, msg)
          end
        end

        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagers[0].to_SetpointManagerOutdoorAirReset.get
        msg = "#{self.class.name}::#{__method__}. Outdoor low temperature is different from expected value"
        assert_in_delta(-16.0, set_point_manager.outdoorLowTemperature, 0.01, msg)
        msg = "#{self.class.name}::#{__method__}. Outdoor high temperature is different from expected value"
        assert_in_delta(0.0, set_point_manager.outdoorHighTemperature, 0.01, msg)
        msg = "#{self.class.name}::#{__method__}. Setpoint outdoor low temperature is different from expected value"
        assert_in_delta(82.0, set_point_manager.setpointatOutdoorLowTemperature, 0.01, msg)
        msg = "#{self.class.name}::#{__method__}. Setpoint outdoor high temperature is different from expected value"
        assert_in_delta(60.0, set_point_manager.setpointatOutdoorHighTemperature, 0.01, msg)
      end
    end
  end

  # Test to validate chilled water and condensate water loop rules
  def test_chw_loop_rules

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 2
    boiler_fueltype = 'Electricity'
    chiller_type = 'Centrifugal'
    mua_cooling_type = 'DX'

    name = "sys2_chw"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                     zones: model.getThermalZones,
                                     chiller_type: chiller_type,
                                     fan_coil_type: 'FPFC',
                                     mau_cooling_type: mua_cooling_type,
                                     hw_loop: hw_loop)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

    loops = model.getPlantLoops
    expected_exitT = 29.0
    expected_deltaT = 6.0
    expected_cw_setpoint = 7.0
    loops.each do |iloop|
      if iloop.name.to_s == 'Chilled Water Loop'
        deltaT = iloop.sizingPlant.loopDesignTemperatureDifference
        msg = "#{self.class.name}::#{__method__}. Chilled Water Loop deltaT is different from expected value"
        assert_in_delta(expected_deltaT, deltaT, 0.01, msg)

        # Check the supply loop. There should be a variable speed pump. Check confirms that we do not have a
        #  constant speed pump as there is no other easy way to extract just the pump.
        supply_comps = iloop.supplyComponents
        supply_comps.each do |icomp|
          if icomp.to_PumpConstantSpeed.is_initialized
            msg = "#{self.class.name}::#{__method__}. Chilled Water Loop pump, #{icomp.name}, is not variable speed"
            assert(false, msg)
          end
        end

        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagers[0].to_SetpointManagerScheduled.get
        setpoint_sch = set_point_manager.schedule.to_ScheduleRuleset.get
        sch_rules = setpoint_sch.scheduleRules
        msg = "#{self.class.name}::#{__method__}. Chilled Water Loop supply setpoint temperature is different from expected value"
        sch_rules.each do |rule|
          day_sch = rule.daySchedule
          setpoints = day_sch.values
          setpoints.each do |ivalue|
            assert_in_delta(expected_cw_setpoint, ivalue, 0.01, msg)
          end
        end

      elsif iloop.name.to_s == 'Condenser Water Loop'
        deltaT = iloop.sizingPlant.loopDesignTemperatureDifference
        msg = "#{self.class.name}::#{__method__}. Condenser Water Loop deltaT is different from expected value"
        assert_in_delta(expected_deltaT, deltaT, 0.01, msg)

        exitT = iloop.sizingPlant.designLoopExitTemperature
        msg = "#{self.class.name}::#{__method__}. Condenser Water Loop exitT is different from expected value"
        assert_in_delta(expected_exitT, exitT, 0.01, msg)

        # Check the supply loop. There should be a variable speed pump. Check confirms that we do not have a constant
        # speed pump as there is no other easy way to extract just the pump.
        supply_comps = iloop.supplyComponents
        supply_comps.each do |icomp|
          if icomp.to_PumpConstantSpeed.is_initialized
            msg = "#{self.class.name}::#{__method__}. Condenser Water Loop pump, #{icomp.name}, is not variable speed"
            assert(false, msg)
          end
        end

        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagers[0].to_SetpointManagerScheduled.get
        setpoint_sch = set_point_manager.schedule.to_ScheduleRuleset.get
        sch_rules = setpoint_sch.scheduleRules
        msg = "#{self.class.name}::#{__method__}. Condenser Water Loop supply setpoint temperature is different from expected value"
        sch_rules.each do |rule|
          day_sch = rule.daySchedule
          setpoints = day_sch.values
          setpoints.each do |ivalue|
            assert_in_delta(expected_exitT, ivalue, 0.01, msg)
          end
        end
      end
    end
  end
end
