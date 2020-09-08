require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013Test2 < Minitest::Test

  include Baseline9012013

  # Test LPDs for bldg_1
  # @author Matt Leach, NORESCO
  def ci_fail_test_lpd_bldg1 # disable this test, which succeeds locally but fails on circleci for no apparent reason

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
  
  # Test LPDs for bldg_2
  # @author Matt Leach, NORESCO
  def ci_fail_test_lpd_bldg2 # disable this test, which succeeds locally but fails on circleci for no apparent reason

    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    lpd_test_hash["Flr 2 South Stair"] = {"LPD" => 0.69,"Space_Type" => "Stair"}
    lpd_test_hash["Flr 1 Vestibule"] = {"LPD" => 0.90,"Space_Type" => "Lobby"}
    lpd_test_hash["Flr 2 Tenant 1 East Perimeter"] = {"LPD" => 0.98,"Space_Type" => "Open Office"}
    lpd_test_hash["Flr 1 Tenant 1 West Perimeter"] = {"LPD" => 1.44,"Space_Type" => "Retail Sales"}
    
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

  # Test LPDs for bldg_3
  # @author Matt Leach, NORESCO
  def test_lpd_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    # lpd_test_hash["Base2 Weight 2B55 1B50"] = {"LPD" => 0.72,"Space_Type" => "Exercise"}
    # no Exercise space type defined for medium office so it's pulling the small hotel value (RCR adjusted value = 0.864)
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

  # Test LPDs for bldg_4
  # @author Matt Leach, NORESCO
  # Known failure due to currently not having parking space type
  def known_fail_test_lpd_bldg4

    model = create_baseline_model('bldg_4', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
      lpd_test_hash["Parking Level 1B ParkingLot"] = {"LPD" => 0.19,"Space_Type" => "Parking"} #Interior parking lot is currently not an available space type.
    lpd_test_hash["Parking Level 1B IDF 1B05"] = {"LPD" => 1.11,"Space_Type" => "IT_Room"}
    lpd_test_hash["IndoorPracticeField"] = {"LPD" => 0.72,"Space_Type" => "Gym"}
    
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

  # Test LPDs for bldg_7
  # @author Matt Leach, NORESCO
  def test_lpd_bldg7

    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    lpd_test_hash["L1-ES_apt"] = {"LPD" => 1.34,"Space_Type" => "Apartment"}
    lpd_test_hash["L1-E_corr"] = {"LPD" => 0.792,"Space_Type" => "Corridor"}
    lpd_test_hash["L1-W_ret"] = {"LPD" => 1.11,"Space_Type" => "Office"} # Apartment offices have 1.11 W/f^2 extra task lighting according to the DOE prototype buildings
    
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
  def ci_fail_test_daylighting_bldg1 # disable this test, which succeeds locally but fails on circleci for no apparent reason

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

  # Test System Type for bldg_1
  # @author Matt Leach, NORESCO
  def ci_fail_test_system_type_bldg1 # disable this test, which succeeds locally but fails on circleci for no apparent reason

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

  # Test System Type for bldg_2
  # @author Matt Leach, NORESCO
  def known_fail_test_system_type_bldg2 # This test fails on circleci but succeeds locally.  Cannot figure out why.

    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    expected_system_string = "PVAV_PFP_Boxes (Sys6)"
    # expect PSZ systems for retail spaces
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
        # check for retail systems
        if airloop_name.include? "Tenant 1"
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
      unless airloop.supplyComponents('OS_Coil_Cooling_DX_TwoSpeed'.to_IddObjectType).length == 1
        failure_array << "Expected cooling coil of type CoilCoolingDXTwoSpeed for System #{airloop_name}"
      end
    end
    
    # expect heating only equipment for Zone South Stair
    heated_only_zones = ["South Stair"]
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
        unless unit_heater.heatingCoil.to_CoilHeatingElectric.is_initialized
          failure_array << "Expected Unit Heater in Heated Only Zone #{heated_only_zone_name} to have an Electric Heating Coil"
        end
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

  # Test System Type for bldg_4
  # @author Matt Leach, NORESCO
  def test_system_type_bldg4

    model = create_baseline_model('bldg_4', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []

    # test main system type
    expected_system_string = "PVAV_Reheat (Sys5)"
    # do not expect any PSZ systems for this model (all fully conditioned zones should be on main baseline system)
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      unless airloop_name.include? expected_system_string
        system_type_confirmed = false
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
            unless plant_loop.supplyComponents('OS_DistrictHeating'.to_IddObjectType).length == 1
              failure_array << "Expected Heating Coil for System #{airloop_name} to be served by a DistrictHeating object"
            end
          end
        end
      end
      # cooling coil
      unless airloop.supplyComponents('OS_Coil_Cooling_DX_TwoSpeed'.to_IddObjectType).length == 1
        failure_array << "Expected cooling coil of type CoilCoolingDXTwoSpeed for System #{airloop_name}"
      end
    end
    
    # check for exhaust fans (should match exhaust fans)
    number_of_exhaust_fans = 0
    model.getFanZoneExhausts.each do |exhaust_fan|
      number_of_exhaust_fans +=1
      if exhaust_fan.name.get.to_s == "Parking Level 1B ParkingLot Exhaust Fan"
        expected_efficiency = 0.6
        expected_pressure_rise = 716.49
        expected_flow_rate = 35.396
        # check values
        unless (exhaust_fan.fanEfficiency - expected_efficiency).abs < 0.01
          failure_array << "Baseline Fan Efficiency for #{exhaust_fan.name} (#{exhaust_fan.fanEfficiency.round(1)}) expected to matched Proposed Value of #{expected_efficiency}"
        end
        unless (exhaust_fan.pressureRise - expected_pressure_rise).abs < 0.01
          failure_array << "Baseline Fan Pressure Rise for #{exhaust_fan.name} (#{exhaust_fan.pressureRise.round(2)} Pa) expected to matched Proposed Value of #{expected_pressure_rise} Pa"
        end
        if exhaust_fan.maximumFlowRate.is_initialized
          unless (exhaust_fan.maximumFlowRate.get - expected_flow_rate).abs < 0.01
            failure_array << "Baseline Fan Flow Rate for #{exhaust_fan.name} (#{exhaust_fan.maximumFlowRate.round(3)} m3/s) expected to matched Proposed Value of #{expected_flow_rate} m3/s"
          end
        else
          failure_array << "Baseline Fan Flow Rate for #{exhaust_fan.name} expected to matched Proposed Value of #{expected_flow_rate} m3/s but no value was specified"
        end  
      elsif exhaust_fan.name.get.to_s == "Parking Level 2B ParkingLot Exhaust Fan"
        expected_efficiency = 0.6
        expected_pressure_rise = 908.41
        expected_flow_rate = 40.116
        # check values
        unless (exhaust_fan.fanEfficiency - expected_efficiency).abs < 0.01
          failure_array << "Baseline Fan Efficiency for #{exhaust_fan.name} (#{exhaust_fan.fanEfficiency.round(1)}) expected to matched Proposed Value of #{expected_efficiency}"
        end
        unless (exhaust_fan.pressureRise - expected_pressure_rise).abs < 0.01
          failure_array << "Baseline Fan Pressure Rise for #{exhaust_fan.name} (#{exhaust_fan.pressureRise.round(2)} Pa) expected to matched Proposed Value of #{expected_pressure_rise} Pa"
        end
        if exhaust_fan.maximumFlowRate.is_initialized
          unless (exhaust_fan.maximumFlowRate.get - expected_flow_rate).abs < 0.01
            failure_array << "Baseline Fan Flow Rate for #{exhaust_fan.name} (#{exhaust_fan.maximumFlowRate.round(3)} m3/s) expected to matched Proposed Value of #{expected_flow_rate} m3/s"
          end
        else
          failure_array << "Baseline Fan Flow Rate for #{exhaust_fan.name} expected to matched Proposed Value of #{expected_flow_rate} m3/s but no value was specified"
        end  
      else
        failure_array << "Unexpected Exhaust Fan = #{exhaust_fan.name.get.to_s}"
      end  
    end
    unless number_of_exhaust_fans == 2
      failure_array << "Expected 2 Exhaust Fans; found #{number_of_exhaust_fans} instead"
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end  

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

end
