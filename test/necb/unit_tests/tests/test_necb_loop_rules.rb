require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Loop_Rules_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

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

    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    chiller_type = 'Scroll'
    heating_coil_type = 'Electric'
    fan_type = 'AF_or_BI_rdg_fancurve'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys6"
    puts "***************************************#{name}*******************************************************\n"
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
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

    # Run the measure.
    run_the_measure(model: model, test_name: name, template: template) if PERFORM_STANDARDS

    tol = 1.0e-3
    loops = model.getPlantLoops
    loops.each do |iloop|
      if iloop.name.to_s == 'Hot Water Loop'
        necb_deltaT = 16.0
        deltaT = iloop.sizingPlant.loopDesignTemperatureDifference
        diff = (necb_deltaT - deltaT).abs / necb_deltaT
        deltaT_set_correctly = true
        if diff > tol then deltaT_set_correctly = false end
        assert(deltaT_set_correctly,'test_hw_loop_rules: Hot water loop design temperature difference does not match necb requirement')
        supply_comps = iloop.supplyComponents
        pump_is_constant_speed = false
        supply_comps.each do |icomp|
          if icomp.to_PumpConstantSpeed.is_initialized
            pump_is_constant_speed = true
          end
        end
        assert(!pump_is_constant_speed,'test_hw_loop_rules: Hot water loop pump is not variable speed')
        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagers[0].to_SetpointManagerOutdoorAirReset.get
        necb_outdoorLowTemperature = -16.0
        diff1 = (necb_outdoorLowTemperature - set_point_manager.outdoorLowTemperature).abs / necb_outdoorLowTemperature
        necb_outdoorHighTemperature = 0.0
        diff2 = (necb_outdoorHighTemperature - set_point_manager.outdoorHighTemperature).abs / necb_outdoorHighTemperature
        necb_setpointatOutdoorLowTemperature = 82.0
        diff3 = (necb_setpointatOutdoorLowTemperature - set_point_manager.setpointatOutdoorLowTemperature).abs / necb_setpointatOutdoorLowTemperature
        necb_setpointatOutdoorHighTemperature = 60.0
        diff4 = (necb_setpointatOutdoorHighTemperature - set_point_manager.setpointatOutdoorHighTemperature).abs / necb_setpointatOutdoorHighTemperature
        pars_set_correlctly = true
        if diff1 > tol || diff2 > tol || diff3 > tol || diff4 > tol then pars_set_correlctly = false end
        assert(pars_set_correlctly, "test_hw_loop_rules: Outdoor temperature reset parameters do not match necb requirement #{name}")
      end
    end
  end

  # Test to validate chilled water loop rules
  def test_chw_loop_rules

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)

    # Generate the osm files for all relevant cases to generate the test data for system 2
    boiler_fueltype = 'Electricity'
    chiller_type = 'Centrifugal'
    mua_cooling_type = 'DX'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys2"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                     zones: model.getThermalZones,
                                     chiller_type: chiller_type,
                                     fan_coil_type: 'FPFC',
                                     mau_cooling_type: mua_cooling_type,
                                     hw_loop: hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

    # Run the measure.
    run_the_measure(model: model, test_name: name, template: template) if PERFORM_STANDARDS

    loops = model.getPlantLoops
    tol = 1.0e-3
    loops.each do |iloop|
      if iloop.name.to_s == 'Chilled Water Loop'
        necb_deltaT = 6.0
        deltaT = iloop.sizingPlant.loopDesignTemperatureDifference
        diff = (necb_deltaT - deltaT).abs / necb_deltaT
        deltaT_set_correctly = true
        if diff > tol then deltaT_set_correctly = false end
        assert(deltaT_set_correctly,'test_chw_loop_rules: Chilled water loop design temperature difference does not match necb requirement')
        supply_comps = iloop.supplyComponents
        pump_is_constant_speed = false
        supply_comps.each do |icomp|
          if icomp.to_PumpConstantSpeed.is_initialized
            pump_is_constant_speed = true
          end
        end
        assert(!pump_is_constant_speed,'test_chw_loop_rules: Chilled water loop pump is not variable speed')
        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagers[0].to_SetpointManagerScheduled.get
        setpoint_sch = set_point_manager.schedule.to_ScheduleRuleset.get
        sch_rules = setpoint_sch.scheduleRules
        necb_setpoint = 7.0
        setpoint_set_correctly = true
        sch_rules.each do |rule|
          day_sch = rule.daySchedule
          setpoints = day_sch.values
          setpoints.each do |ivalue|
            diff = (necb_setpoint - ivalue).abs / necb_setpoint
            if diff > tol then setpoint_set_correctly = false end
          end
        end
        assert(setpoint_set_correctly, "test_chw_loop_rules: Loop supply temperature schedule does not match necb requirement #{name}")
        pars_set_correlctly = true
      end
    end
  end
  
  # Test to validate condenser loop rules
  def test_NECB2011_cw_loop_rules

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)

    # Generate the osm files for all relevant cases to generate the test data for system 2
    boiler_fueltype = 'Electricity'
    chiller_type = 'Centrifugal'
    mua_cooling_type = 'DX'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys2"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                     zones: model.getThermalZones,
                                     chiller_type: chiller_type,
                                     fan_coil_type: 'FPFC',
                                     mau_cooling_type: mua_cooling_type,
                                     hw_loop: hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

    # Run the measure.
    run_the_measure(model: model, test_name: name, template: template) if PERFORM_STANDARDS

    loops = model.getPlantLoops
    tol = 1.0e-3
    loops.each do |iloop|
      if iloop.name.to_s == 'Condenser Water Loop'
        necb_deltaT = 6.0
        deltaT = iloop.sizingPlant.loopDesignTemperatureDifference
        diff = (necb_deltaT - deltaT).abs / necb_deltaT
        deltaT_set_correctly = true
        if diff > tol then deltaT_set_correctly = false end
        assert(deltaT_set_correctly,'test_cw_loop_rules: Condenser water loop design temperature difference does not match necb requirement')
        necb_exitT = 29.0
        exitT = iloop.sizingPlant.designLoopExitTemperature
        diff = (necb_exitT - exitT).abs / necb_exitT
        exitT_set_correctly = true
        if diff > tol then exitT_set_correctly = false end
        assert(exitT_set_correctly,'test_cw_loop_rules: Condenser water loop design exit temperature does not match necb requirement')
        supply_comps = iloop.supplyComponents
        pump_is_constant_speed = false
        supply_comps.each do |icomp|
          if icomp.to_PumpConstantSpeed.is_initialized
            pump_is_constant_speed = true
          end
        end
        assert(!pump_is_constant_speed,'test_cw_loop_rules: Hot water loop pump is not variable speed')
        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagers[0].to_SetpointManagerScheduled.get
        setpoint_sch = set_point_manager.schedule.to_ScheduleRuleset.get
        sch_rules = setpoint_sch.scheduleRules
        setpoint_set_correctly = true
        sch_rules.each do |rule|
          day_sch = rule.daySchedule
          setpoints = day_sch.values
          setpoints.each do |ivalue|
            diff = (necb_exitT - ivalue).abs / necb_exitT
            if diff > tol then setpoint_set_correctly = false end
          end
        end
        assert(setpoint_set_correctly, "test_cw_loop_rules: Loop supply temperature schedule does not match necb requirement #{name}")
      end
    end
  end
  
end
