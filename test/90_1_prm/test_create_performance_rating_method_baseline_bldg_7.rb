require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg7 < Minitest::Test

  include Baseline9012013

  # Test LPDs for bldg_7
  # @author Matt Leach, NORESCO
  def test_lpd_bldg7

    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    lpd_test_hash["L1-ES_apt"] = {"LPD" => 0.45,"Space_Type" => "Apartment"}
    lpd_test_hash["L1-E_corr"] = {"LPD" => 0.792,"Space_Type" => "Corridor"}
    lpd_test_hash["L1-W_ret"] = {"LPD" => 2.22,"Space_Type" => "Office"} # Apartment offices have 1.11 W/f^2 extra task lighting according to the DOE prototype buildings
    
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

  # Test System Type for bldg_7
  # @author Matt Leach, NORESCO
  def test_system_type_bldg7

    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # test main system type
    expected_system_string = "PVAV_Reheat (Sys5)"
    # expect PSZ-AC for L1-W_ret
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
        # look for residential zones
        if airloop_name.include? "_ret"
          # systems should be PSZ
          expected_psz_system_string = "PSZ-AC"
          unless airloop_name.include? expected_psz_system_string
            failure_array << "System Type for Airloop #{airloop_name} is Unexpected.  Expected Type #{expected_psz_system_string}"
          end
          # check terminal type
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
          unless airloop.supplyComponents('OS_Coil_Heating_Gas'.to_IddObjectType).length == 2
            failure_array << "Expected heating coils of type CoilHeatingGas for System #{airloop_name}"
          end
          # cooling coil
          unless airloop.supplyComponents('OS_Coil_Cooling_DX_SingleSpeed'.to_IddObjectType).length == 1
            failure_array << "Expected cooling coil of type CoilCoolingDXSingleSpeed for System #{airloop_name}"
          end
          # PSZ system checks end here
          next
        end
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
        failure_array << "Expected heating coil of type CoilHeatingWater for System #{airloop_name} (System Type 5 with District Heating)"
      else
        airloop.supplyComponents('OS_Coil_Heating_Water'.to_IddObjectType).each do |heating_water_coil|
          unless heating_water_coil.to_CoilHeatingWater.get.plantLoop.is_initialized
            failure_array << "Heating coil serving System #{airloop_name} is not attached to a plant loop"
          else
            plant_loop = heating_water_coil.to_CoilHeatingWater.get.plantLoop.get
            unless plant_loop.supplyComponents('OS_Boiler_HotWater'.to_IddObjectType).length > 0
              failure_array << "Expected Heating Coil for System #{airloop_name} to be served by a BoilerHotWater object"
            end
          end
        end
      end
      # cooling coil
      unless airloop.supplyComponents('OS_Coil_Cooling_DX_TwoSpeed'.to_IddObjectType).length == 1
        failure_array << "Expected heating coil of type CoilCoolingDXTwoSpeed for System #{airloop_name}"
      end
    end
    
    # check for PTACs in residential zones
    model.getThermalZones.each do |zone|
      next unless zone.name.get.to_s.include? "_apt"
      found_ptac = false
      zone.equipment.each do |zone_equipment|
        if zone_equipment.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          found_ptac = true
          ptac = zone_equipment.to_ZoneHVACPackagedTerminalAirConditioner.get
          # check fan
          fan = ptac.supplyAirFan
          unless fan.to_FanConstantVolume.is_initialized
            failure_array << "Expected Fan serving Zone Equipment #{ptac.name} to be of type FanConstantVolume"
          end
          # check cooling coil
          cooling_coil = ptac.coolingCoil
          unless cooling_coil.to_CoilCoolingDXSingleSpeed.is_initialized
            failure_array << "Expected Cooling Coil serving Zone Equipment #{ptac.name} to be of type CoilCoolingDXSingleSpeed"
          end
          # check heating coil
          heating_coil = ptac.heatingCoil
          unless heating_coil.to_CoilHeatingWater.is_initialized
            failure_array << "Expected Heating Coil serving Zone Equipment #{ptac.name} to be of type CoilHeatingWater"
          else
            unless heating_coil.to_CoilHeatingWater.get.plantLoop.is_initialized
              failure_array << "Heating coil serving Zone Equipment #{ptac.name} is not attached to a plant loop"
            else
              plant_loop = heating_coil.to_CoilHeatingWater.get.plantLoop.get
              unless plant_loop.supplyComponents('OS_Boiler_HotWater'.to_IddObjectType).length > 0
                failure_array << "Expected Heating Coil for Zone Equipment #{ptac.name} to be served by a BoilerHotWater object"
              end
            end
          end
        end
      end
      unless found_ptac
        failure_array << "Expected Zone #{zone.name} to be served by a PTAC"
      end
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end  

  # Test System Type for bldg_7
  # @author Matt Leach, NORESCO
  def test_system_type_bldg7_electric

    model = create_baseline_model('bldg_7_electric', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # test main system type
    expected_system_string = "PVAV_PFP_Boxes (Sys6)"
    # expect PSZ-AC for L1-W_ret
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
        # look for residential zones
        if airloop_name.include? "_ret"
          # systems should be PSZ
          expected_psz_system_string = "PSZ-HP"
          unless airloop_name.include? expected_psz_system_string
            failure_array << "System Type for Airloop #{airloop_name} is Unexpected.  Expected Type #{expected_psz_system_string}"
          end
          # check terminal type
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
          unless airloop.supplyComponents('OS_Coil_Heating_DX_SingleSpeed'.to_IddObjectType).length == 1
            failure_array << "Expected heating coil of type CoilHeatingDXSingleSpeed for System #{airloop_name}"
          end
          # cooling coil
          unless airloop.supplyComponents('OS_Coil_Cooling_DX_SingleSpeed'.to_IddObjectType).length == 1
            failure_array << "Expected cooling coil of type CoilCoolingDXSingleSpeed for System #{airloop_name}"
          end
          # PSZ system checks end here
          next
        end
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
          unless terminal.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
            failure_array << "Expected terminals to be of type AirTerminalSingleDuctParallelPIUReheat for System #{airloop_name}; this is not true for Terminal #{terminal.name}"
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
      unless airloop.supplyComponents('OS_Coil_Heating_Electric'.to_IddObjectType).length == 1
        failure_array << "Expected heating coil of type CoilHeatingElectric for System #{airloop_name}"
      end
      # cooling coil
      unless airloop.supplyComponents('OS_Coil_Cooling_DX_TwoSpeed'.to_IddObjectType).length == 1
        failure_array << "Expected cooling coil of type CoilCoolingDXTwoSpeed for System #{airloop_name}"
      end
    end
    
    # check for PTHPs in residential zones
    model.getThermalZones.each do |zone|
      next unless zone.name.get.to_s.include? "_apt"
      found_pthp = false
      zone.equipment.each do |zone_equipment|
        if zone_equipment.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          found_pthp = true
          pthp = zone_equipment.to_ZoneHVACPackagedTerminalHeatPump.get
          # check fan
          fan = pthp.supplyAirFan
          unless fan.to_FanConstantVolume.is_initialized
            failure_array << "Expected Fan serving Zone Equipment #{pthp.name} to be of type FanConstantVolume"
          end
          # check cooling coil
          cooling_coil = pthp.coolingCoil
          unless cooling_coil.to_CoilCoolingDXSingleSpeed.is_initialized
            failure_array << "Expected Cooling Coil serving Zone Equipment #{pthp.name} to be of type CoilCoolingDXSingleSpeed"
          end
          # check heating coil
          heating_coil = pthp.heatingCoil
          unless heating_coil.to_CoilHeatingDXSingleSpeed.is_initialized
            failure_array << "Expected Heating Coil serving Zone Equipment #{pthp.name} to be of type CoilHeatingDXSingleSpeed"
          end
        end
      end
      unless found_pthp
        failure_array << "Expected Zone #{zone.name} to be served by a PTHP"
      end
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Test Equipment Efficiencies for bldg_7
  # @author Matt Leach, NORESCO
  # Known failure; this test assumes that all fans should have the SP reset curve,
  # which does not make sense since SP reset is only prescriptively required
  # if there is DDC control of VAV terminals.
  def known_fail_test_hvac_eff_bldg7

    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Thermal Zone: L1-S_apt PTAC 1spd DX AC Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 66.0,"EfficiencyType" => "PTAC","Efficiency" => "NA"}
    dx_coil_hash["Thermal Zone: L2-N_apt_out PTAC 1spd DX AC Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 42.0,"EfficiencyType" => "PTAC","Efficiency" => "NA"}
    dx_coil_hash["Thermal Zone: L3-ES_apt_out PTAC 1spd DX AC Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 15.0,"EfficiencyType" => "PTAC","Efficiency" => "NA"}

    failure_array = check_dx_cooling_single_speed_efficiency(model, dx_coil_hash, failure_array)

    # get fan powers
    supply_fan_hash = {}
    # expect test to fail because pressure differential (0.9) for MERV 13 filter is being added to expected calculation
    # if pressure differential is set to zero, test passes
    supply_fan_hash["Thermal Zone: L1-S_apt PTAC Fan"] = {"CFM" => 2479.0,"PressureDifferential" => 0}
    supply_fan_hash["Thermal Zone: L2-N_apt_out PTAC Fan"] = {"CFM" => 1568.0,"PressureDifferential" => 0}
    supply_fan_hash["Thermal Zone: L3-ES_apt_out PTAC Fan"] = {"CFM" => 551.0,"PressureDifferential" => 0}

    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)

    # check plant loop components
    # boilers
    failure_array = check_boilers(model, failure_array)

    # hw pumps
    failure_array = check_hw_pumps(model, failure_array)

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

  # Combined space heating and DHW Test
  # @author Matt Leach, NORESCO
  # Known failure; this test assumes that the SWH pump in the baseline
  # will carry directly into the proposed.  While this is generally true,
  # in the baseline the motor efficiency will be set to the minimum value.
  def known_fail_test_dhw_bldg7

    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    found_dhw_loop = false
    model.getPlantLoops.each do |plant_loop|
      plant_loop_name = plant_loop.name.get.to_s
      next unless plant_loop_name == "Service Water Heating Loop"
      found_dhw_loop = true





      # confirm heating source is district heating
      unless plant_loop.supplyComponents('OS_WaterHeater_Mixed'.to_IddObjectType).length == 1
        failure_array << "Expected Service Water Heating Equipment for Loop #{plant_loop_name} to be served by a WaterHeaterMixed object"
      end
      # confirm that circulation pump inputs match hot water loop pump inputs for proposed case
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
        expected_motor_efficiency = 0.9
        expected_pump_head_ft = 60
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

end
