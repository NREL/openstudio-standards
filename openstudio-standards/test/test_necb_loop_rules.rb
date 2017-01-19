require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'
$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)

class HVACEfficienciesTest < MiniTest::Test
  # set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  # set to true to run the simulations.
  FULL_SIMULATIONS = false

  # Test to validate hot water loop rules
  def test_hw_loop_rules
    output_folder = "#{File.dirname(__FILE__)}/output/hw_loop_rules"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    chiller_type = 'Scroll'
    heating_coil_type = 'Electric'
    fan_type = 'AF_or_BI_rdg_fancurve'
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.716240_CWEC.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys6"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys6(
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
    # run the standards
    result = run_the_measure(model, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_hw_loop_rules: Failure in Standards for #{name}")
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
        assert(pump_is_constant_speed,'test_hw_loop_rules: Hot water loop pump is not constant speed')
        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagerOutdoorAirReset.get
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
    output_folder = "#{File.dirname(__FILE__)}/output/chw_loop_rules"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    # Generate the osm files for all relevant cases to generate the test data for system 2
    boiler_fueltype = 'Electricity'
    chiller_type = 'Centrifugal'
    mua_cooling_type = 'DX'
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.716240_CWEC.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys2"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(
      model, 
      model.getThermalZones, 
      boiler_fueltype, 
      chiller_type, 
      mua_cooling_type,
      hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_chw_loop_rules: Failure in Standards for #{name}")
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
        assert(pump_is_constant_speed,'test_chw_loop_rules: Hot water loop pump is not constant speed')
        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagerScheduled.get
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
  def test_cw_loop_rules
    output_folder = "#{File.dirname(__FILE__)}/output/cw_loop_rules"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    # Generate the osm files for all relevant cases to generate the test data for system 2
    boiler_fueltype = 'Electricity'
    chiller_type = 'Centrifugal'
    mua_cooling_type = 'DX'
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.716240_CWEC.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys2"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(
      model, 
      model.getThermalZones, 
      boiler_fueltype, 
      chiller_type, 
      mua_cooling_type,
      hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_cw_loop_rules: Failure in Standards for #{name}")
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
        assert(pump_is_constant_speed,'test_cw_loop_rules: Hot water loop pump is not constant speed')
        supply_out_node = iloop.supplyOutletNode
        set_point_manager = supply_out_node.setpointManagerScheduled.get
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
