require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg5 < Minitest::Test

  include Baseline9012013

  # Test System Type for bldg_5
  # @author Matt Leach, NORESCO
  def test_system_type_bldg5

    model = create_baseline_model('bldg_5', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # test main system type
    expected_system_string = "PVAV_Reheat (Sys7)"
    # expect PSZ systems for: (1) zones that meet load exception
    zones_with_load_exception = ["Athletic Admin Level IDF","Coaches Level IDF 4470","Concourse Level IDF 315","Field Level IDF 104A", "Field Level IDF 122A", "Field Level IDF 131","Concourse Level Kitchen 304","Field Level Laundry 101J","Field Level Pool Hydrotherapy 115","Field Level Pool Recovery 111"]

    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
        # look for zones without mechanical cooling
        zones_with_load_exception.each do |zone_name|
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
                    failure_array << "Expected Cooling Coil for System #{airloop_name} to be served by a District Cooling object"
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
    heated_only_zones = ["Athletic Admin Level Stair ST501", "Athletic Admin Level Stair ST502", "Athletic Admin Level Stair ST503", "Coaches Level Stair ST401"]
    heated_only_zones = heated_only_zones + ["Coaches Level Stair ST402", "Coaches Level Stair ST403", "Concourse Level Mechanical 326", "Concourse Level Stair ST301"]
    heated_only_zones = heated_only_zones + ["Concourse Level Stair ST302", "Concourse Level Stair ST303", "Field Level Mechanical Mezzanine", "Field Level Stair ST101"]
    heated_only_zones = heated_only_zones + ["Field Level Stair ST102", "Field Level Stair ST103", "Field Level Stair ST104", "Field Level Unspecified Quad B Northeast"]
    heated_only_zones = heated_only_zones + ["Field Level Vestibule 129C", "Field Level Vestibule 687", "Main Level Mechanical 213", "Main Level Stair Quad B", "Main Level Stair ST201"]
    heated_only_zones = heated_only_zones + ["Main Level Stair ST202", "Main Level Stair ST203", "Rooftop Terrace Level Mechanical 600", "Rooftop Terrace Level Restroom RRM602"]
    heated_only_zones = heated_only_zones + ["Rooftop Terrace Level Restroom RRW603", "Rooftop Terrace Level Stair ST601", "Rooftop Terrace Level Stair ST602"]
    heated_only_zones = heated_only_zones + ["Rooftop Terrace Level Stair ST603", "Rooftop Terrace Level Vestibule 352"]
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

  # Test LPDs for bldg_5
  # @author Matt Leach, NORESCO
  def test_lpd_bldg5

    model = create_baseline_model('bldg_5', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    lpd_test_hash["Field Level Conference 128D"] = {"LPD" => 1.23,"Space_Type" => "Conference"}
    lpd_test_hash["Field Level Break 101B"] = {"LPD" => 0.73,"Space_Type" => "BreakRoom"}
    lpd_test_hash["Field Level Laundry 114A"] = {"LPD" => 0.60,"Space_Type" => "Laundry"}
    lpd_test_hash["Field Level Pool Recovery 111"] = {"LPD" => 0.91,"Space_Type" => "PhysTherapy"}
    
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

  # Test Equipment Efficiencies for bldg_5
  # @author Matt Leach, NORESCO
  def ci_fail_test_hvac_eff_bldg5

    model = create_baseline_model('bldg_5', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # check fan powers
    supply_fan_hash = {}
    # expect test to fail because pressure differential for MERV 13 filter is being added to expected calculation
    # if pressure differential is set to zero, test passes
    supply_fan_hash["Field Level VAV_Reheat (Sys7) Fan"] = {"CFM" => 63121.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Main Level VAV_Reheat (Sys7) Fan"] = {"CFM" => 30978.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Concourse Level VAV_Reheat (Sys7) Fan"] = {"CFM" => 25363.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Coaches Level VAV_Reheat (Sys7) Fan"] = {"CFM" => 26168.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Athletic Admin Level VAV_Reheat (Sys7) Fan"] = {"CFM" => 32143,"PressureDifferential" => 0.0}
    supply_fan_hash["Rooftop Terrace Level VAV_Reheat (Sys7) Fan"] = {"CFM" => 5742.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Athletic Admin Level IDF PSZ-AC Fan"] = {"CFM" => 1038.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Coaches Level IDF 4470 PSZ-AC Fan"] = {"CFM" => 1102.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Concourse Level IDF 315 PSZ-AC Fan"] = {"CFM" => 826.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Concourse Level Kitchen 304 PSZ-AC Fan"] = {"CFM" => 9048.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Field Level IDF 104A PSZ-AC Fan"] = {"CFM" => 1102.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Field Level IDF 122A PSZ-AC Fan"] = {"CFM" => 1080.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Field Level IDF 131 PSZ-AC Fan"] = {"CFM" => 869.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Field Level Laundry 101J PSZ-AC Fan"] = {"CFM" => 2797.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Field Level Pool Hydrotherapy 115 PSZ-AC Fan"] = {"CFM" => 869.0,"PressureDifferential" => 0.0}
    supply_fan_hash["Field Level Pool Recovery 111 PSZ-AC Fan"] = {"CFM" => 1398.0,"PressureDifferential" => 0.0}

    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)

    # check plant loop components
    total_chilled_water_capacity_tons = 542
    # chw pumps
    failure_array = check_district_chw_pumps(model, total_chilled_water_capacity_tons, failure_array)
    # hw pumps
    failure_array = check_district_hw_pumps(model, failure_array)

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

end
