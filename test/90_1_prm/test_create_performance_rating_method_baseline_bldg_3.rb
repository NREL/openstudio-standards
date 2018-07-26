require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg3 < Minitest::Test

  include Baseline9012013

  # Test Equipment Efficiencies for bldg_3
  # @author Matt Leach, NORESCO
  def ci_fail_test_hvac_eff_bldg3
  
    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Base1 LockerOther 1B30 PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 19.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Base1 LockerPlayer E PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 61.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Base1 LockerPlayer NE PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 50.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Base1 LockerPlayer SW PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 131.0,"EfficiencyType" => "EER","Efficiency" => 11.0}
    dx_coil_hash["Base2 MechRoom 2B75 PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 1.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Base2 Weight NE PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 8.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Base2 Weight SW PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 36.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Flr2 Kitchen PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 627.0,"EfficiencyType" => "EER","Efficiency" => 9.8}
  
    failure_array = check_dx_cooling_single_speed_efficiency(model, dx_coil_hash, failure_array)  
  
    # check fan powers
    supply_fan_hash = {}
    # expect test to fail because pressure differential (0.9) for MERV 13 filter is being added to expected calculation
    # if pressure differential is set to zero, test passes
    supply_fan_hash["Base2 PVAV_Reheat (Sys5) Fan"] = {"CFM" => 13349.0,"PressureDifferential" => 0}
    supply_fan_hash["Base1 PVAV_Reheat (Sys5) Fan"] = {"CFM" => 12460.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr1 PVAV_Reheat (Sys5) Fan"] = {"CFM" => 20151.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr2 PVAV_Reheat (Sys5) Fan"] = {"CFM" => 18307.0,"PressureDifferential" => 0}
    # there should not be a Flr3 system (if load exception is corrected)
    supply_fan_hash["Base1 LockerOther 1B30 PSZ-AC Fan"] = {"CFM" => 593.0,"PressureDifferential" => 0}
    supply_fan_hash["Base1 LockerPlayer E PSZ-AC Fan"] = {"CFM" => 1547.0,"PressureDifferential" => 0}
    supply_fan_hash["Base1 LockerPlayer NE PSZ-AC Fan"] = {"CFM" => 1271.0,"PressureDifferential" => 0}
    supply_fan_hash["Base1 LockerPlayer SW PSZ-AC Fan"] = {"CFM" => 3305.0,"PressureDifferential" => 0}
    supply_fan_hash["Base2 MechRoom 2B75 PSZ-AC Fan"] = {"CFM" => 42.0,"PressureDifferential" => 0}
    supply_fan_hash["Base2 Weight NE PSZ-AC Fan"] = {"CFM" => 254.0,"PressureDifferential" => 0}
    supply_fan_hash["Base2 Weight SW PSZ-AC Fan"] = {"CFM" => 1165.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr2 Kitchen PSZ-AC Fan"] = {"CFM" => 15934.0,"PressureDifferential" => 0}
    
    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)
    
    # check plant loop components
    total_chilled_water_capacity_tons = 139
    # chw pumps
    failure_array = check_district_chw_pumps(model, total_chilled_water_capacity_tons, failure_array)    
    # hw pumps
    failure_array = check_district_hw_pumps(model, failure_array)
    
    # check hw controls
    failure_array = check_hw_controls(model, failure_array)
    
    
    
    
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # District Heating DHW Test
  # @author Matt Leach, NORESCO
  def test_dhw_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    found_dhw_loop = false
    model.getPlantLoops.each do |plant_loop|
      plant_loop_name = plant_loop.name.get.to_s
      next unless plant_loop_name == "Service Water Heating Loop"
      found_dhw_loop = true
      # confirm heating source is district heating
      unless plant_loop.supplyComponents('OS_DistrictHeating'.to_IddObjectType).length == 1
        failure_array << "Expected Service Water Heating Equipment for Loop #{plant_loop_name} to be served by a DistrictHeating object"
      end
      # confirm that circulation pump inputs match proposed case
      # variable speed pump
      # pump head
      # motor efficiency
      # coefficients
      # check number and type of pump(s)
      unless plant_loop.supplyComponents('OS_Pump_VariableSpeed'.to_IddObjectType).length == 1
        failure_array << "Expected #{plant_loop_name} to have one VariableSpeed pump; found #{plant_loop.supplyComponents('OS_Pump_VariableSpeed'.to_IddObjectType).length} instead"
      else
        pump =   plant_loop.supplyComponents('OS_Pump_VariableSpeed'.to_IddObjectType)[0].to_PumpVariableSpeed.get
        # pump power
        motor_efficiency = pump.motorEfficiency
        impeller_efficiency = 0.78
        pump_efficiency = motor_efficiency * impeller_efficiency
        pump_head_pa = pump.ratedPumpHead
        pump_head_ft = pump_head_pa / (12*249.09)
        pump_watts_per_gpm = pump_head_ft / (5.302*pump_efficiency)
        expected_motor_efficiency = 0.7
        expected_pump_head_ft = 70.52
        expected_pump_efficiency = expected_motor_efficiency * impeller_efficiency
        expected_pump_watts_per_gpm = expected_pump_head_ft / (5.302*expected_pump_efficiency)
        unless (pump_watts_per_gpm - expected_pump_watts_per_gpm).abs < 0.05
          failure_array << "Expected pump for #{plant_loop_name} to be #{expected_pump_watts_per_gpm} W/gpm; #{pump.name} is #{pump_watts_per_gpm.round(2)} W/gpm"
        end
        # pump curve
        expected_coefficient_1 = 0
        expected_coefficient_2 = 3.2485
        expected_coefficient_3 = -4.7443
        expected_coefficient_4 = 2.5294
        # coefficient 1
        coefficient_1 = pump.coefficient1ofthePartLoadPerformanceCurve
        unless (coefficient_1 - expected_coefficient_1).abs < 0.01
          failure_array << "Expected Coefficient 1 for #{pump.name} to be equal to #{expected_coefficient_1}; found #{coefficient_1} instead"
        end
        # coefficient 2
        coefficient_2 = pump.coefficient2ofthePartLoadPerformanceCurve
        unless (coefficient_2 - expected_coefficient_2).abs < 0.01
          failure_array << "Expected Coefficient 2 for #{pump.name} to be equal to #{expected_coefficient_2}; found #{coefficient_2} instead"
        end
        # coefficient 3
        coefficient_3 = pump.coefficient3ofthePartLoadPerformanceCurve
        unless (coefficient_3 - expected_coefficient_3).abs < 0.01
          failure_array << "Expected Coefficient 3 for #{pump.name} to be equal to #{expected_coefficient_3}; found #{coefficient_3} instead"
        end
        # coefficient 4
        coefficient_4 = pump.coefficient4ofthePartLoadPerformanceCurve
        unless (coefficient_4 - expected_coefficient_4).abs < 0.01
          failure_array << "Expected Coefficient 4 for #{pump.name} to be equal to #{expected_coefficient_4}; found #{coefficient_4} instead"
        end
      end
      unless plant_loop.supplyComponents('OS_Pump_ConstantSpeed'.to_IddObjectType).length == 0
        failure_array << "Expected Loop #{plant_loop_name} to have zero ConstantSpeed pumps; found #{plant_loop.supplyComponents('OS_Pump_ConstantSpeed'.to_IddObjectType).length} instead"
      end
    end

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # DCV Test
  # @author Matt Leach, NORESCO
  def known_fail_test_dcv_bldg3

    model = create_baseline_model('bldg_3_LockerOtherDCV', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    dcv_test_hash = {}
    dcv_test_hash["Base1 LockerOther 1B30 PSZ-AC"] = {"DesignOutdoorAirflow" => 0.46583}
    people_per_1000_ft2_threshold = 25

    # increased occupancy density for LockerOther space type to trigger DCV for the corresponding PSZ system
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      next unless dcv_test_hash.keys.include? airloop_name
      if airloop.airLoopHVACOutdoorAirSystem.is_initialized
        airloop_oa_system = airloop.airLoopHVACOutdoorAirSystem.get
        airloop_controller_oa = airloop_oa_system.getControllerOutdoorAir
        airloop_controller_mech_vent = airloop_controller_oa.controllerMechanicalVentilation
        # check for economizer
        economizer_control_type = airloop_controller_oa.getEconomizerControlType
        economizer_control_action_type = airloop_controller_oa.getEconomizerControlActionType
        economizer = false
        unless economizer_control_type == "NoEconomizer"
          economizer = true
          unless economizer_control_action_type == "ModulateFlow"
            failure_array << "Economizer Control Action Type (#{economizer_control_action_type}) for Airloop #{airloop_name} is not correct; it should be ModulateFlow"
          end
        else
          failure_array << "Economizer expected for Airloop #{airloop_name} but not found; economizer control type is set to #{economizer_control_type}"
        end
        if economizer
          next unless (dcv_test_hash["Base1 LockerOther 1B30 PSZ-AC"]["DesignOutdoorAirflow"] * 2118.88) > 750
        else
          next unless (dcv_test_hash["Base1 LockerOther 1B30 PSZ-AC"]["DesignOutdoorAirflow"] * 2118.88) > 3000
        end
        # check number of people
        number_of_people = 0
        floor_area = 0
        airloop.thermalZones.each do |zone|
          number_of_people += zone.numberOfPeople
          floor_area += zone.floorArea
        end
        next unless ((number_of_people * 1000) / (floor_area * 10.7639104167)) > people_per_1000_ft2_threshold
        # check for dcv
        unless airloop_controller_mech_vent.demandControlledVentilation
          failure_array << "DCV is expected for #{airloop.name} but was not found"
        end
      else
        failure_array << "An outdoor air system is expected for #{airloop.name} but was not found"
      end
    end

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # ERV Test
  # @author Matt Leach, NORESCO
  def test_erv_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-6B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    dcv_test_hash = {}
    dcv_test_hash["Base2 VAV_Reheat (Sys7)"] = {"DesignSupplyAirflow" => 6.28 * 2118.88,"DesignOutdoorAirflow" => 4.05 * 2118.88,"ClimateZone" => "6B","LessThan8000Hours" => true}
    dcv_test_hash["Base1 VAV_Reheat (Sys7)"] = {"DesignSupplyAirflow" => 5.82 * 2118.88,"DesignOutdoorAirflow" => 5.82 * 2118.88,"ClimateZone" => "6B","LessThan8000Hours" => true}

    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      next unless dcv_test_hash.keys.include? airloop_name
      # system_oa_rate_cfm = 0
      # airloop_name = airloop.name.get.to_s
      # airloop.thermalZones.each do |zone|
      # zone.spaces.each do |space|
      # system_oa_rate_cfm += calculate_oa_per_space(space) * 2118.88
      # end
      # end
      # puts "#{airloop_name} OA = #{system_oa_rate_cfm.round()} cfm"
      # check OA fraction, hours of operation, and climate zone
      erv_expected = false
      if dcv_test_hash[airloop_name]["ClimateZone"] == "6B"
        # puts "Climate Zone is 6B for #{airloop_name}"
        oa_fraction = dcv_test_hash[airloop_name]["DesignOutdoorAirflow"] / dcv_test_hash[airloop_name]["DesignSupplyAirflow"]
        # puts "OA fraction is #{oa_fraction.round(2)} for #{airloop_name}"
        if dcv_test_hash[airloop_name]["LessThan8000Hours"]
          if dcv_test_hash[airloop_name]["DesignSupplyAirflow"] >= 1500
            if dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 2500
              if oa_fraction >= 0.8
                erv_expected = true
              end
            elsif dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 3500
              if oa_fraction >= 0.7
                erv_expected = true
              end
            elsif dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 4500
              if oa_fraction >= 0.6
                erv_expected = true
              end
            elsif dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 5500
              if oa_fraction >= 0.5
                erv_expected = true
              end
            elsif dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 11000
              if oa_fraction >= 0.4
                erv_expected = true
              end
            elsif dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 26500
              if oa_fraction >= 0.3
                erv_expected = true
              end
            elsif dcv_test_hash[airloop_name]["DesignSupplyAirflow"] < 28000
              if oa_fraction >= 0.2
                erv_expected = true
              end
            else
              if oa_fraction >= 0.1
                erv_expected = true
              end
            end
          end
        else
          failure_array << "ERV Test does not currently support cases where hours of operation are more than 8000"
        end
        # check for erv where relevant
        if erv_expected
          # look for erv on airloop
          erv_components = []
          airloop.oaComponents.each do |component|
            component_name = component.name.to_s
            next if component_name.include? "Node"
            if component_name.include? "ERV"
              erv_components << component
              erv_components = erv_components.uniq
            end
          end
          unless erv_components.length == 1
            if erv_components.length == 0
              failure_array << "Expected ERV for System #{airloop_name}"
            elsif erv_components.length > 1
              failure_array << "Expected one ERV for System #{airloop_name}; found #{erv_components.length} instead"
            end
          else
            # get ERV
            erv_components.each do |erv|
              if erv.to_HeatExchangerAirToAirSensibleAndLatent.is_initialized
                erv = erv.to_HeatExchangerAirToAirSensibleAndLatent.get
                # check economizer bypass
                unless erv.economizerLockout
                  failure_array << "Economizer lockout should be 'true' for #{erv.name}"
                else
                  # check controller oa
                  if airloop.airLoopHVACOutdoorAirSystem.is_initialized
                    oa_system = airloop.airLoopHVACOutdoorAirSystem.get
                    controller_oa = oa_system.getControllerOutdoorAir
                    unless controller_oa.getHeatRecoveryBypassControlType.is_initialized
                      failure_array << "Heat Recovery Bypass Control Type should be set to 'BypassWhenOAFlowGreaterThanMinimum' in OA Controller for System #{airloop_name}; it was not set"
                    else
                      unless controller_oa.getHeatRecoveryBypassControlType.get == "BypassWhenOAFlowGreaterThanMinimum"
                        failure_array << "Heat Recovery Bypass Control Type should be set to 'BypassWhenOAFlowGreaterThanMinimum' in OA Controller for System #{airloop_name}; found '#{controller_oa.getHeatRecoveryBypassControlType.get}' instead"
                      end
                    end
                  else
                    failure_array << "An outdoor air system is expected for #{airloop.name} but was not found"
                  end
                end
                # check erv effectiveness
                expected_effectiveness = 0.5
                # sensible
                unless erv.sensibleEffectivenessat100CoolingAirFlow == expected_effectiveness
                  if erv.sensibleEffectivenessat100CoolingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Sensible Effectiveness is specified as #{erv.sensibleEffectivenessat100CoolingAirFlow} at 100% Cooling Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Sensible Effectiveness is specified as only #{erv.sensibleEffectivenessat100CoolingAirFlow} at 100% Cooling Airflow for #{erv.name} "
                  end
                end
                unless erv.sensibleEffectivenessat75CoolingAirFlow == expected_effectiveness
                  if erv.sensibleEffectivenessat75CoolingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Sensible Effectiveness is specified as #{erv.sensibleEffectivenessat75CoolingAirFlow} at 75% Cooling Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Sensible Effectiveness is specified as only #{erv.sensibleEffectivenessat75CoolingAirFlow} at 75% Cooling Airflow for #{erv.name} "
                  end
                end
                unless erv.sensibleEffectivenessat100HeatingAirFlow == expected_effectiveness
                  if erv.sensibleEffectivenessat100HeatingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Sensible Effectiveness is specified as #{erv.sensibleEffectivenessat100HeatingAirFlow} at 100% Heating Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Sensible Effectiveness is specified as only #{erv.sensibleEffectivenessat100HeatingAirFlow} at 100% Heating Airflow for #{erv.name} "
                  end
                end
                unless erv.sensibleEffectivenessat75HeatingAirFlow == expected_effectiveness
                  if erv.sensibleEffectivenessat75HeatingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Sensible Effectiveness is specified as #{erv.sensibleEffectivenessat75HeatingAirFlow} at 75% Heating Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Sensible Effectiveness is specified as only #{erv.sensibleEffectivenessat75HeatingAirFlow} at 75% Heating Airflow for #{erv.name} "
                  end
                end
                # latent
                unless erv.latentEffectivenessat100CoolingAirFlow == expected_effectiveness
                  if erv.latentEffectivenessat100CoolingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Latent Effectiveness is specified as #{erv.latentEffectivenessat100CoolingAirFlow} at 100% Cooling Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Latent Effectiveness is specified as only #{erv.latentEffectivenessat100CoolingAirFlow} at 100% Cooling Airflow for #{erv.name} "
                  end
                end
                unless erv.latentEffectivenessat75CoolingAirFlow == expected_effectiveness
                  if erv.latentEffectivenessat75CoolingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Latent Effectiveness is specified as #{erv.latentEffectivenessat75CoolingAirFlow} at 75% Cooling Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Latent Effectiveness is specified as only #{erv.latentEffectivenessat75CoolingAirFlow} at 75% Cooling Airflow for #{erv.name} "
                  end
                end
                unless erv.latentEffectivenessat100HeatingAirFlow == expected_effectiveness
                  if erv.latentEffectivenessat100HeatingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Latent Effectiveness is specified as #{erv.latentEffectivenessat100HeatingAirFlow} at 100% Heating Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Latent Effectiveness is specified as only #{erv.latentEffectivenessat100HeatingAirFlow} at 100% Heating Airflow for #{erv.name} "
                  end
                end
                unless erv.latentEffectivenessat75HeatingAirFlow == expected_effectiveness
                  if erv.latentEffectivenessat75HeatingAirFlow > expected_effectiveness
                    failure_array << "Appendix G only requires 50% ERV effectiveness, but Latent Effectiveness is specified as #{erv.latentEffectivenessat75HeatingAirFlow} at 75% Heating Airflow for #{erv.name} "
                  else
                    failure_array << "Appendix G requires at least 50% ERV effectiveness, but Latent Effectiveness is specified as only #{erv.latentEffectivenessat75HeatingAirFlow} at 75% Heating Airflow for #{erv.name} "
                  end
                end
              else
                failure_array << "OA Component #{erv.name} on #{airloop_name} contains 'ERV' in its name but is not of type 'HeatExchangerAirToAirSensibleAndLatent'"
              end
            end
          end
        end
      else
        failure_array << "ERV Test does not currently support Climate Zone #{dcv_test_hash[airloop_name]["ClimateZone"]}; only Climate Zone 6B is supported"
      end
    end

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # Test LPDs for bldg_3
  # @author Matt Leach, NORESCO
  def test_lpd_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    lpd_test_hash = {}
    lpd_test_hash["Base2 Weight 2B55 1B50"] = {"LPD" => 0.72,"Space_Type" => "Exercise"}
    lpd_test_hash["Flr1 Corridor 115"] = {"LPD" => 0.66,"Space_Type" => "Corridor"}
    lpd_test_hash["Flr2 Office 280"] = {"LPD" => 1.11,"Space_Type" => "ClosedOfficeOffice"}
    lpd_test_hash["Flr2 Computer 266"] = {"LPD" => 1.24,"Space_Type" => "Classroom"}
    lpd_test_hash["Flr1 Dining 150"] = {"LPD" => 0.89,"Space_Type" => "Dining"}
    lpd_test_hash["Flr2 Kitchen"] = {"LPD" => 1.21,"Space_Type" => "Kitchen"}
    lpd_test_hash["Flr1 Storage 150F"] = {"LPD" => 0.63,"Space_Type" => "Storage"}

    lpd_test_hash.keys.each do |space_name|
      space = model.getSpaceByName(space_name).get
      lpd_w_per_m2 = space.lightingPowerPerFloorArea
      lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get

      unless (lpd_test_hash[space_name]["LPD"] - lpd_w_per_ft2).abs < 0.01
        failure_array << "Expected LPD of #{lpd_test_hash[space_name]["LPD"]} W/ft2 for Space #{space_name} of Type #{lpd_test_hash[space_name]["Space_Type"]}; got #{lpd_w_per_ft2.round(2)} W/ft2 instead"
      end
    end

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # Test System Type for bldg_3
  # @author Matt Leach, NORESCO
  def test_system_type_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # test main system type
    expected_system_string = "PVAV_Reheat (Sys5)"
    # expect PSZ systems for: (1) zones without mechanical cooling; (2) zones that meet schedule exception; (3) zones that meet load exception
    zones_without_mechanical_cooling = ["Base1 LockerOther 1B30", "Base1 LockerPlayer E", "Base1 LockerPlayer NE", "Base1 LockerPlayer SW", "Base2 MechRoom 2B75", "Base2 Weight NE", "Base2 Weight SW", "Flr2 Kitchen"]
    zones_with_schedule_exception = ["Base1 LockerPlayer SE", "Base1 Lounge 1B33 36", "Base1 Office 1B32", "Base1 Storage 1B38", "Flr1 Treatment NE", "Flr2 Lounge Core"]
    zones_with_load_exception = ["Flr2 Computer 266"]
    # hydrotherapy zone likely should be a load exception zone; right now, the measure is applying load exception at the 'floor' level instead of at the 'building' level
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
        # look for zones without mechanical cooling
        zones_without_mechanical_cooling.each do |zone_name|
          # should have district heating but NOT district cooling
          if airloop_name.include? zone_name
            # check terminal types
            thermal_zones_attached = 0
            airloop.thermalZones.each do |zone|
              thermal_zones_attached += 1
              # look for air terminal for zone
              if zone.airLoopHVACTerminal.is_initialized
                terminal = zone.airLoopHVACTerminal.get
                # get terminal and make sure it is the correct type
                unless terminal.to_AirTerminalSingleDuctUncontrolled.is_initialized
                  failure_array << "Expected terminals to be of type AirTerminalSingleDuctUncontrolled for System #{airloop_name}; this is not true for Terminal #{terminal.name}"
                end
              else
                failure_array << "No terminal attaching Zone #{zone} to System #{airloop_name}"
              end
            end
            unless thermal_zones_attached == 1
              failure_array << "Expected 1 Thermal Zone to be attached to System #{airloop_name}; found #{thermal_zones_attached} Zone(s) attached"
            end
            # check fan type
            unless airloop.supplyFan.is_initialized
              failure_array << "No supply fan attached to System #{airloop_name}"
            else
              # get fan type
              supply_fan = airloop.supplyFan.get
              unless supply_fan.to_FanConstantVolume.is_initialized
                failure_array << "Expected fan of type ConstantVolume for System #{airloop_name}"
              end
            end
            # check heating and cooling coil types
            # heating coil
            unless airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).length == 1
              failure_array << "Expected heating coil of type CoilHeatingWater for System #{airloop_name} (System Type 3 with District Heating)"
            else
              airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).each do |heating_water_coil|
                unless heating_water_coil.to_CoilHeatingWater.get.plantLoop.is_initialized
                  failure_array << "Heating coil serving System #{airloop_name} is not attached to a plant loop"
                else
                  plant_loop = heating_water_coil.to_CoilHeatingWater.get.plantLoop.get
                  unless plant_loop.supplyComponents('OS_DistrictHeating'.to_IddObjectType).length == 1
                    failure_array << "Expected Heating Coil for System #{airloop_name} to be served by a DistrictHeating object"
                  end
                end
              end
            end
            # cooling coil
            unless airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).length == 1
              failure_array << "Expected cooling coil of type CoilCoolingWater for System #{airloop_name}"
            end
          end
        end
        # look for zones with schedule or load exception
        zones_with_exceptions = zones_with_schedule_exception + zones_with_load_exception
        zones_with_exceptions.each do |zone_name|
          # should have district heating AND district cooling
          if airloop_name.include? zone_name
            # check terminal types
            thermal_zones_attached = 0
            airloop.thermalZones.each do |zone|
              thermal_zones_attached += 1
              # look for air terminal for zone
              if zone.airLoopHVACTerminal.is_initialized
                terminal = zone.airLoopHVACTerminal.get
                # get terminal and make sure it is the correct type
                unless terminal.to_AirTerminalSingleDuctUncontrolled.is_initialized
                  failure_array << "Expected terminals to be of type AirTerminalSingleDuctUncontrolled for System #{airloop_name}; this is not true for Terminal #{terminal.name}"
                end
              else
                failure_array << "No terminal attaching Zone #{zone} to System #{airloop_name}"
              end
            end
            unless thermal_zones_attached == 1
              failure_array << "Expected 1 Thermal Zone to be attached to System #{airloop_name}; found #{thermal_zones_attached} Zone(s) attached"
            end
            # check fan type
            unless airloop.supplyFan.is_initialized
              failure_array << "No supply fan attached to System #{airloop_name}"
            else
              # get fan type
              supply_fan = airloop.supplyFan.get
              unless supply_fan.to_FanConstantVolume.is_initialized
                failure_array << "Expected fan of type ConstantVolume for System #{airloop_name}"
              end
            end
            # check heating and cooling coil types
            # heating coil
            unless airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).length == 1
              failure_array << "Expected heating coil of type CoilHeatingWater for System #{airloop_name} (System Type 3 with District Heating)"
            else
              airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).each do |heating_water_coil|
                unless heating_water_coil.to_CoilHeatingWater.get.plantLoop.is_initialized
                  failure_array << "Heating coil serving System #{airloop_name} is not attached to a plant loop"
                else
                  plant_loop = heating_water_coil.to_CoilHeatingWater.get.plantLoop.get
                  unless plant_loop.supplyComponents('OS_DistrictHeating'.to_IddObjectType).length == 1
                    failure_array << "Expected Heating Coil for System #{airloop_name} to be served by a DistrictHeating object"
                  end
                end
              end
            end
            # cooling coil
            unless airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).length == 1
              failure_array << "Expected cooling coil of type CoilCoolingWater for System #{airloop_name} (System Type 3 with District Cooling)"
            else
              airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).each do |cooling_water_coil|
                unless cooling_water_coil.to_CoilCoolingWater.get.plantLoop.is_initialized
                  failure_array << "Cooling coil serving System #{airloop_name} is not attached to a plant loop"
                else
                  plant_loop = cooling_water_coil.to_CoilCoolingWater.get.plantLoop.get
                  unless plant_loop.supplyComponents('OS_DistrictCooling'.to_IddObjectType).length == 1
                    failure_array << "Expected Cooling Coil for System #{airloop_name} to be served by a DistrictCooling object"
                  end
                end
              end
            end
          end
        end
        # PSZ system checks end here
        next
      else
        system_type_confirmed = true
      end
      unless system_type_confirmed
        failure_array << "System Type for Airloop #{airloop_name} is Unexpected.  Expected Type #{expected_system_string}"
      end
      # check terminal types
      thermal_zones_attached = 0
      airloop.thermalZones.each do |zone|
        thermal_zones_attached += 1
        # look for air terminal for zone
        if zone.airLoopHVACTerminal.is_initialized
          terminal = zone.airLoopHVACTerminal.get
          # get terminal and make sure it is the correct type
          unless terminal.to_AirTerminalSingleDuctVAVReheat.is_initialized
            failure_array << "Expected terminals to be of type AirTerminalSingleDuctVAVReheat for System #{airloop_name}; this is not true for Terminal #{terminal.name}"
          end
        else
          failure_array << "No terminal attaching Zone #{zone} to System #{airloop_name}"
        end
      end
      unless thermal_zones_attached > 0
        failure_array << "No thermal zones attached to System #{airloop_name}"
      end
      # check fan type
      unless airloop.supplyFan.is_initialized
        failure_array << "No supply fan attached to System #{airloop_name}"
      else
        # get fan type
        supply_fan = airloop.supplyFan.get
        unless supply_fan.to_FanVariableVolume.is_initialized
          failure_array << "Expected fan of type VariableVolume for System #{airloop_name}"
        end
      end
      # check heating and cooling coil types
      # heating coil
      unless airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).length == 1
        failure_array << "Expected heating coil of type CoilHeatingWater for System #{airloop_name}"
      else
        airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).each do |heating_water_coil|
          unless heating_water_coil.to_CoilHeatingWater.get.plantLoop.is_initialized
            failure_array << "Heating coil serving System #{airloop_name} is not attached to a plant loop"
          else
            plant_loop = heating_water_coil.to_CoilHeatingWater.get.plantLoop.get
            unless plant_loop.supplyComponents('OS_DistrictHeating'.to_IddObjectType).length == 1
              failure_array << "Expected Heating Coil for System #{airloop_name} to be served by a DistrictHeating object"
            end
          end
        end
      end
      # cooling coil

      unless airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).length == 1
        failure_array << "Expected cooling coil of type CoilCoolingWater for System #{airloop_name} (System Type 5 with District Cooling)"
      else
        airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).each do |cooling_water_coil|
          unless cooling_water_coil.to_CoilCoolingWater.get.plantLoop.is_initialized
            failure_array << "Cooling coil serving System #{airloop_name} is not attached to a plant loop"
          else
            plant_loop = cooling_water_coil.to_CoilCoolingWater.get.plantLoop.get
            unless plant_loop.supplyComponents('OS_DistrictCooling'.to_IddObjectType).length == 1
              failure_array << "Expected Cooling Coil for System #{airloop_name} to be served by a DistrictCooling object"
            end
          end
        end
      end
    end

    # check heated only zones
    heated_only_zones = ["Base1 Storage 1B06", "Base1 Vestibule 1B20", "Base1 Vestibule CR1B87", "Base1 Vestibule W", "Base2 Storage Perimeter N", "Flr1 Corridor CR125"]
    heated_only_zones = heated_only_zones + ["Flr1 Storage 101 105", "Flr1 Vestibule 156", "Flr3 MechRoom Core", "Flr3 MechRoom E", "Flr3 MechRoom W"]
    heated_only_zones.each do |heated_only_zone_name|
      heated_only_zone = model.getThermalZoneByName(heated_only_zone_name).get
      unit_heater = heated_only_zone.equipment[0].to_ZoneHVACUnitHeater
      if unit_heater.is_initialized
        found_unit_heater = true
      else
        found_unit_heater = false
      end
      unless found_unit_heater
        failure_array << "Expected to find a Unit Heater in Heated Only Zone #{heated_only_zone_name} but did not"
      else
        unit_heater = unit_heater.get
        # check heating coil fuel type
        unless unit_heater.heatingCoil.to_CoilHeatingWater.is_initialized
          failure_array << "Expected Unit Heater in Heated Only Zone #{heated_only_zone_name} to have a Hot Water Heating Coil"
        else
          # make sure heating coil is connected to district heating object
          plant_loop = unit_heater.heatingCoil.to_CoilHeatingWater.get.to_CoilHeatingWater.get.plantLoop.get
          unless plant_loop.supplyComponents('OS_DistrictHeating'.to_IddObjectType).length == 1
            failure_array << "Expected Heating Coil for Unit Heater in Heated Only Zone #{heated_only_zone_name} to be served by a DistrictHeating object"
          end
        end
      end
    end

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # Test Daylighting for bldg_3
  # @author Matt Leach, NORESCO
  def test_daylighting_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', true, true)
    failure_array = []

    daylighting_test_hash = {}
    daylighting_test_hash["Flr2 Lounge Perimeter 250CD"] = {"PrimaryArea" => 1074.5,"SecondaryArea" => 974.1,"ControlType" => "PrimaryAndSecondary"}
    # Don't expect daylighting controls in closed offices; assume
    # that spaces would in reality be broken into multiple rooms
    # less than the minimum size to require daylighting controls.
    # daylighting_test_hash["Flr1 Office 130-132 136 138 139"] = {"PrimaryArea" => 340,"SecondaryArea" => 340,"ControlType" => "PrimaryAndSecondary"}
    daylighting_test_hash["Flr1 Dining 150"] = {"PrimaryArea" => 1725.9,"SecondaryArea" => 1500.4,"ControlType" => "PrimaryAndSecondary"}
    # currently the measure is not calculating the expected daylighting areas because window width is getting reduced from proposed to baseline

    daylighting_test_hash.keys.each do |space_name|
      space = model.getSpaceByName(space_name).get
      # get thermal zone
      if space.thermalZone.is_initialized
        zone = space.thermalZone.get
        zone_name = zone.name.get.to_s
        zone_area_ft2 = zone.floorArea * 10.76
        # check for zones with multiple spaces.  if multiple spaces, make sure other spaces don't have windows
        windows_in_one_space = true
        zone.spaces.each do |space|
          s_name = space.name.get.to_s
          next if s_name == space_name
          space.surfaces.each do |surface|
            next if not surface.surfaceType.casecmp("Wall").zero?
            next if not surface.outsideBoundaryCondition.casecmp("Outdoors").zero?
            unless surface.subSurfaces.length == 0
              windows_in_one_space = false
              failure_array << "Thermal Zone #{zone_name} containing space #{space_name} contains one or more other spaces with a window, including space #{s_name}.  Pick a different space for daylighting check"
            end
          end
        end
        if windows_in_one_space
          # get daylighting control object(s)
          if daylighting_test_hash[space_name]["ControlType"] == "PrimaryOnly"
            # primary
            if zone.primaryDaylightingControl.is_initialized
              # check fraction controlled
              expected_primary_control_fraction = daylighting_test_hash[space_name]["PrimaryArea"]/zone_area_ft2
              primary_control_fraction = zone.fractionofZoneControlledbyPrimaryDaylightingControl
              unless (expected_primary_control_fraction - primary_control_fraction).abs < 0.05
                failure_array << "Expected Primary Daylighting Control Fraction for Zone #{zone_name} to be #{expected_primary_control_fraction.round(2)}; found #{primary_control_fraction.round(2)} instead"
              end
            else
              failure_array << "No Primary Daylighting Control object found for Thermal Zone #{zone_name}"
            end
          elsif daylighting_test_hash[space_name]["ControlType"] == "PrimaryAndSecondary"
            # primary
            if zone.primaryDaylightingControl.is_initialized
              # check fraction controlled
              expected_primary_control_fraction = daylighting_test_hash[space_name]["PrimaryArea"]/zone_area_ft2
              primary_control_fraction = zone.fractionofZoneControlledbyPrimaryDaylightingControl
              unless (expected_primary_control_fraction - primary_control_fraction).abs < 0.05
                failure_array << "Expected Primary Daylighting Control Fraction for Zone #{zone_name} to be #{expected_primary_control_fraction.round(2)}; found #{primary_control_fraction.round(2)} instead"
              end
            else
              failure_array << "No Primary Daylighting Control object found for Thermal Zone #{zone_name}"
            end

            # secondary
            if zone.secondaryDaylightingControl.is_initialized
              # check fraction controlled
              expected_secondary_control_fraction = daylighting_test_hash[space_name]["SecondaryArea"]/zone_area_ft2
              secondary_control_fraction = zone.fractionofZoneControlledbySecondaryDaylightingControl
              unless (expected_secondary_control_fraction - secondary_control_fraction).abs < 0.05
                failure_array << "Expected Secondary Daylighting Control Fraction for Zone #{zone_name} to be #{expected_secondary_control_fraction.round(2)}; found #{secondary_control_fraction.round(2)} instead"
              end
            else
              failure_array << "No Secondary Daylighting Control object found for Thermal Zone #{zone_name}"
            end
          else
            failure_array << "Invalid daylighting Control Type #{daylighting_test_hash[space_name]["ControlType"]} specified for Space #{space_name}"
          end
        end
      else
        failure_array << "Space #{space_name} is not assigned to a thermal zone.  Pick a different space for daylighting check"
      end
    end

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # VAV Terminal Min Flow Rate Test
  # @author Matt Leach, NORESCO
  def test_vav_terminal_min_flows_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    expected_min_oa_rates_m3_per_s_hash = {}
    expected_min_oa_rates_m3_per_s_hash["BASE1 CORRIDOR E"] = 0.12265
    expected_min_oa_rates_m3_per_s_hash["BASE2 BREAK 2B53 54"] = 5.46757E-002
    expected_min_oa_rates_m3_per_s_hash["FLR1 CONFERENCE 135"] = 9.07225E-002
    expected_min_oa_rates_m3_per_s_hash["FLR2 OFFICE PERIMETER SE"] = 3.09786E-002

    number_of_vav_terminals = 0
    model.getAirTerminalSingleDuctVAVReheats.each do |vav_terminal|
      number_of_vav_terminals += 1
      vav_terminal_name = vav_terminal.name.get.to_s
      zone_name = vav_terminal_name.gsub(" VAV Term","")
      # check zone minimum air flow method
      unless vav_terminal.zoneMinimumAirFlowMethod == "Constant"
        failure_array << "Expected Zone Minimum Air Flow Method to be Constant for VAV Reheat Terminal for Zone #{zone_name}; found #{vav_terminal.zoneMinimumAirFlowMethod} instead"
      end
      # look for spot check terminals
      # puts "Zone Name = #{zone_name}"
      expected_min_oa_rates_m3_per_s_hash.keys.each do |spot_check_zone_name|
        if spot_check_zone_name.casecmp(zone_name).zero?
          # puts "Zone #{zone_name} is a spot check zone"
          # check fixed flow rate (equal to minimum oa requirement)
          unless (expected_min_oa_rates_m3_per_s_hash[spot_check_zone_name] - vav_terminal.fixedMinimumAirFlowRate).abs < 0.005
            failure_array << "Expected #{(expected_min_oa_rates_m3_per_s_hash[spot_check_zone_name]*2118.88).round()} cfm Fixed Flow Rate for Zone #{spot_check_zone_name}; found #{(vav_terminal.fixedMinimumAirFlowRate*2118.88).round()} cfm instead"
          end
        end
      end
      # constant minimum flow fraction will be set to the larger of 0.3, the fraction corresponding to the minimum OA rate, or the result of the VRP calculation
    end
    unless number_of_vav_terminals > 0
      failure_array << "No VAV Reheat Terminals found, even though Baseline HVAC System Type is 5"
    end

    # check for failures
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end


  # Economizer Test
  # @author Matt Leach, NORESCO
  def ci_fail_test_economizing_bldg2_5B
  
    # Climate zone is 5B.  All systems except 1, 2, 9 and 10 should have economizers
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      
      oa_system = airloop.airLoopHVACOutdoorAirSystem
      if oa_system.is_initialized
        found_oa_system = true
      else
        found_oa_system = false
      end
      unless found_oa_system
        failure_array << "Airloop #{airloop_name} should have an OA System but does not"
      end
      
      if found_oa_system
        oa_system = oa_system.get
        controller_oa = oa_system.getControllerOutdoorAir
        # check economizer control type
        economizer_control_type = controller_oa.getEconomizerControlType
        unless economizer_control_type == "FixedDryBulb"
          failure_array << "Economizer Control Type (#{economizer_control_type}) for Airloop #{airloop_name} is not correct; it should be FixedDryBulb"
        end
        # check economizer control action type
        economizer_control_action_type = controller_oa.getEconomizerControlActionType
        unless economizer_control_action_type == "ModulateFlow"
          failure_array << "Economizer Control Action Type (#{economizer_control_action_type}) for Airloop #{airloop_name} is not correct; it should be FixedDryBulb"
        end
        # check high limit temperature shutoff
        economizer_high_limit_shutoff_temperature = controller_oa.getEconomizerMaximumLimitDryBulbTemperature
        expected_high_limit_shutoff_temperature = 75.0
        if economizer_high_limit_shutoff_temperature.is_initialized
          found_economizer_high_limit_shutoff_temperature = true
          economizer_high_limit_shutoff_temperature = (economizer_high_limit_shutoff_temperature.get*1.8+32).round(2)
          unless (expected_high_limit_shutoff_temperature - economizer_high_limit_shutoff_temperature).abs < 0.01
            failure_array << "Expected Economizer High Limit Shutoff Temperature of #{expected_high_limit_shutoff_temperature} F for Airloop #{airloop_name}; got #{economizer_high_limit_shutoff_temperature} F instead"
          end
        else
          found_economizer_high_limit_shutoff_temperature = false
        end
        unless found_economizer_high_limit_shutoff_temperature
          failure_array << "Airloop #{airloop_name} has an economizer but not a high limit shutoff temperature; high limit should be set to #{expected_high_limit_shutoff_temperature} F"
        end
        # check high limit enthalpy shutoff
        economizer_high_limit_shutoff_enthalpy = controller_oa.getEconomizerMaximumLimitEnthalpy
        if economizer_high_limit_shutoff_enthalpy.is_initialized
          not_found_economizer_high_limit_shutoff_enthalpy = false
        else
          not_found_economizer_high_limit_shutoff_enthalpy = true
        end
        unless not_found_economizer_high_limit_shutoff_enthalpy
          failure_array << "Airloop #{airloop_name} has an economizer with a maximum enthalpy limit; this field should not be set"
        end
      end
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Economizer Test
  # @author Matt Leach, NORESCO
  def ci_fail_test_economizing_bldg2_1A
  
    # Climate zone is 1A.  No systems should have economizers
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-1A', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      
      oa_system = airloop.airLoopHVACOutdoorAirSystem
      if oa_system.is_initialized
        found_oa_system = true
      else
        found_oa_system = false
      end
      unless found_oa_system
        failure_array << "Airloop #{airloop_name} should have an OA System but does not"
      end
      
      if found_oa_system
        oa_system = oa_system.get
        controller_oa = oa_system.getControllerOutdoorAir
        # check economizer control type
        economizer_control_type = controller_oa.getEconomizerControlType
        unless economizer_control_type == "NoEconomizer"
          failure_array << "Economizer Control Type (#{economizer_control_type}) for Airloop #{airloop_name} is not correct; it should be NoEconomizer"
        end
      end
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Economizer Test
  # @author Matt Leach, NORESCO
  def ci_fail_test_economizing_bldg2_5A
  
    # Climate zone is 5A.  All systems except 1, 2, 9 and 10 should have economizers
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5A', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      
      oa_system = airloop.airLoopHVACOutdoorAirSystem
      if oa_system.is_initialized
        found_oa_system = true
      else
        found_oa_system = false
      end
      unless found_oa_system
        failure_array << "Airloop #{airloop_name} should have an OA System but does not"
      end
      
      if found_oa_system
        oa_system = oa_system.get
        controller_oa = oa_system.getControllerOutdoorAir
        # check economizer control type
        economizer_control_type = controller_oa.getEconomizerControlType
        unless economizer_control_type == "FixedDryBulb"
          failure_array << "Economizer Control Type (#{economizer_control_type}) for Airloop #{airloop_name} is not correct; it should be FixedDryBulb"
        end
        # check economizer control action type
        economizer_control_action_type = controller_oa.getEconomizerControlActionType
        unless economizer_control_action_type == "ModulateFlow"
          failure_array << "Economizer Control Action Type (#{economizer_control_action_type}) for Airloop #{airloop_name} is not correct; it should be FixedDryBulb"
        end
        # check high limit temperature shutoff
        economizer_high_limit_shutoff_temperature = controller_oa.getEconomizerMaximumLimitDryBulbTemperature
        expected_high_limit_shutoff_temperature = 70.0
        if economizer_high_limit_shutoff_temperature.is_initialized
          found_economizer_high_limit_shutoff_temperature = true
          economizer_high_limit_shutoff_temperature = (economizer_high_limit_shutoff_temperature.get*1.8+32).round(2)
          unless (expected_high_limit_shutoff_temperature - economizer_high_limit_shutoff_temperature).abs < 0.01
            failure_array << "Expected Economizer High Limit Shutoff Temperature of #{expected_high_limit_shutoff_temperature} F for Airloop #{airloop_name}; got #{economizer_high_limit_shutoff_temperature} F instead"
          end
        else
          found_economizer_high_limit_shutoff_temperature = false
        end
        unless found_economizer_high_limit_shutoff_temperature
          failure_array << "Airloop #{airloop_name} has an economizer but not a high limit shutoff temperature; high limit should be set to #{expected_high_limit_shutoff_temperature} F"
        end
        # check high limit enthalpy shutoff
        economizer_high_limit_shutoff_enthalpy = controller_oa.getEconomizerMaximumLimitEnthalpy
        if economizer_high_limit_shutoff_enthalpy.is_initialized
          not_found_economizer_high_limit_shutoff_enthalpy = false
        else
          not_found_economizer_high_limit_shutoff_enthalpy = true
        end
        unless not_found_economizer_high_limit_shutoff_enthalpy
          failure_array << "Airloop #{airloop_name} has an economizer with a maximum enthalpy limit; this field should not be set"
        end
      end
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

end
