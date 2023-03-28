require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg1 < Minitest::Test

  include Baseline9012013

  # Test LPDs for bldg_1
  # @author Matt Leach, NORESCO
  def test_lpd_bldg1

    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    lpd_test_hash["Stairs 1"] = {"LPD" => 0.69,"Space_Type" => "Stair"}
    lpd_test_hash["Lobby 1"] = {"LPD" => 0.90,"Space_Type" => "Lobby"}
    lpd_test_hash["Office CR 35b"] = {"LPD" => 0.98,"Space_Type" => "Open Office"}
    lpd_test_hash["RR 14"] = {"LPD" => 0.98,"Space_Type" => "Restroom"}
    lpd_test_hash["Utility 1"] = {"LPD" => 0.42,"Space_Type" => "Elec/MechRoom"}
    
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

  # Test Daylighting for bldg_1
  # @author Matt Leach, NORESCO
  def test_daylighting_bldg1

    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    daylighting_test_hash = {}
    daylighting_test_hash["Lobby 1"] = {"PrimaryArea" => 1869.7,"SecondaryArea" => 1631,"ControlType" => "PrimaryAndSecondary"}
    daylighting_test_hash["Retail 1b"] = {"PrimaryArea" => 870.4,"SecondaryArea" => 557.7,"ControlType" => "PrimaryAndSecondary"}
    daylighting_test_hash["Office PR 14c"] = {"PrimaryArea" => 2662.2,"SecondaryArea" => 491.6,"ControlType" => "PrimaryAndSecondary"}
    daylighting_test_hash["Office PR 35d"] = {"PrimaryArea" => 868.7,"SecondaryArea" => 147.1,"ControlType" => "PrimaryAndSecondary"}
    # currently the measure is not calculating the expected daylighting areas because window width is getting reduced from proposed to baseline 
    
    daylighting_test_hash.keys.each do |space_name|
      space = model.getSpaceByName(space_name).get
      # get thermal zone
      if space.thermalZone.is_initialized
        zone = space.thermalZone.get
        zone_name = zone.name.get.to_s
        zone_area_ft2 = zone.floorArea * 10.7639104167
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
              unless (expected_primary_control_fraction - primary_control_fraction).abs < 0.01
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
              unless (expected_primary_control_fraction - primary_control_fraction).abs < 0.01
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
              unless (expected_secondary_control_fraction - secondary_control_fraction).abs < 0.01
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

  # Test System Type for bldg_1
  # @author Matt Leach, NORESCO
  def test_system_type_bldg1

    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    expected_system_string = "VAV_PFP_Boxes (Sys8)"
    chillers = []
    # do not expect any PSZ systems for this model (all fully conditioned zones should be on main baseline system)
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
        # check for schedule exception systems
        if (airloop_name.include? "Utility 1" or airloop_name.include? "Elev Lobby 14" or airloop_name.include? "Elev Lobby 35")
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
          # supplementary heating coil
          unless airloop.supplyComponents('OS_Coil_Heating_Electric'.to_IddObjectType).length == 1
            failure_array << "Expected supplementary heating coil of type CoilHeatingElectric for System #{airloop_name}"
          end
          # PSZ system checks end here
          next
        end
      else
        system_type_confirmed = true
      end
      unless system_type_confirmed
        failure_array << "System Type for Airloop #{airloop_name} is Unexpected.  Expected Type #{expected_system_string}"
        next
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
      unless airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).length == 1
        failure_array << "Expected Cooling Coil of type CoilCoolingWater for System #{airloop_name}"
      else  
        airloop.supplyComponents('OS_Coil_Cooling_Water'.to_IddObjectType).each do |cooling_water_coil|
          unless cooling_water_coil.to_CoilCoolingWater.get.plantLoop.is_initialized
            failure_array << "Cooling Coil serving System #{airloop_name} is not attached to a plant loop"
          else
            plant_loop = cooling_water_coil.to_CoilCoolingWater.get.plantLoop.get
            unless plant_loop.supplyComponents('OS_Chiller_Electric_EIR'.to_IddObjectType).length > 0
              failure_array << "Expected Cooling Coil for System #{airloop_name} to be served by ChillerElectricEIR object(s)"
            else
              # get chiller(s)
              plant_loop.supplyComponents('OS_Chiller_Electric_EIR'.to_IddObjectType).each do |chiller|
                chillers << chiller
                chillers = chillers.uniq
              end
            end
          end
        end
      end
    end
    # check chillers
    chillers.each do |chiller|        
      chiller = chiller.to_ChillerElectricEIR.get
      # make sure chiller is water-cooled
      unless chiller.condenserType == "WaterCooled"
        failure_array << "Expected Chiller #{chiller.name} to be WaterCooled"
      else
        # get condenser loop
        if chiller.secondaryPlantLoop.is_initialized
          condenser_loop = chiller.secondaryPlantLoop.get
          unless condenser_loop.supplyComponents('OS_CoolingTower_VariableSpeed'.to_IddObjectType).length > 0
            failure_array << "Expected Condenser Water for Chiller #{chiller.name} to be cooled by CoolingTowerVariableSpeed object(s)"
          end
        else
          failure_array << "Expected Chiller #{chiller.name} to be connected to a Condenser Loop"
        end
      end
    end          
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Test Equipment Efficiencies for bldg_1
  # @author Matt Leach, NORESCO
  # Known failures due to code not yet accounting for zone multipliers affecting components.
  def known_fail_test_hvac_eff_bldg1

    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Thermal Zone: Elev Lobby 14 PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 274.0/20,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Thermal Zone: Elev Lobby 35 PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 70.0/7,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Thermal Zone: Utility 1 PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 22.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Thermal Zone: Elev Lobby 14 PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 281.0/20,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Thermal Zone: Elev Lobby 35 PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 70.0/7,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Thermal Zone: Utility 1 PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 22.0,"EfficiencyType" => "HSPF","Efficiency" => 7.7}

    failure_array = check_dx_cooling_single_speed_efficiency(model, dx_coil_hash, failure_array)
    failure_array = check_dx_heating_single_speed_efficiency(model, dx_coil_hash, failure_array)

    # check fan powers
    supply_fan_hash = {}
    # expect test to fail because pressure differential (0.9) for MERV 13 filter is being added to expected calculation
    # if pressure differential is set to zero, test passes
    supply_fan_hash["Building Story 1 VAV_PFP_Boxes (Sys8) Fan"] = {"CFM" => 3433.0,"PressureDifferential" => 0}
    supply_fan_hash["Building Story 2 VAV_PFP_Boxes (Sys8) Fan"] = {"CFM" => 378368.0/20,"PressureDifferential" => 0}
    supply_fan_hash["Building Story 4 VAV_PFP_Boxes (Sys8) Fan"] = {"CFM" => 124527.0/7,"PressureDifferential" => 0}
    supply_fan_hash["Thermal Zone: Elev Lobby 14 PSZ-HP Fan"] = {"CFM" => 8497.0/20,"PressureDifferential" => 0}
    supply_fan_hash["Thermal Zone: Elev Lobby 35 PSZ-HP Fan"] = {"CFM" => 2627.0/7,"PressureDifferential" => 0}
    supply_fan_hash["Thermal Zone: Utility 1 PSZ-HP"] = {"CFM" => 826.0,"PressureDifferential" => 0}

    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)

    # check plant loop components
    # chw/cw
    total_chilled_water_capacity_tons = 1002
    # chiller(s)
    chiller_check_output_hash = check_chillers(model, total_chilled_water_capacity_tons, failure_array)
    failure_array = chiller_check_output_hash["Failure_Array"]
    number_of_chillers = chiller_check_output_hash["Number_Of_Chillers"]
    # cooling tower(s)
    failure_array = check_cooling_towers(model, number_of_chillers, failure_array)
    # chw pumps
    failure_array = check_chw_pumps(model, number_of_chillers, total_chilled_water_capacity_tons, failure_array)
    # cw pump(s)
    failure_array = check_cw_pumps(model, number_of_chillers, failure_array)
    # check chw controls
    failure_array = check_chw_controls(model, failure_array)
    # check cw controls
    failure_array = check_cw_controls(model, failure_array)

    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")

  end

end
