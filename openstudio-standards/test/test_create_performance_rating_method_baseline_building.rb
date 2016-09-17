require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013Test < Minitest::Test

  include Baseline9012013

  # Simple example test that checks LPD of gyms
  def testsec_school_example_test

    base_model = create_baseline_model('SecondarySchool-DOE Ref Pre-1980-ASHRAE 169-2006-2A', '90.1-2013', 'ASHRAE 169-2006-2A', 'SecondarySchool', 'Xcel Energy CO EDA', false, true)

    # Conditions expected to be true in the baseline model
    
    # Lighting power densities
    
    # Classroom LPD should be 1.24 W/ft2
    space = base_model.getSpaceByName("Corner_Class_1_Pod_1_ZN_1_FLR_1").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    #               (expected, actual, tolerance, message to show if it fails) 
    assert_in_delta(1.24, lpd_w_per_ft2, 0.01, "Classroom LPD is wrong.")
      
  end  
  
  # Start NORESCO Tests

  # Test LPDs for bldg_1
  # @author Matt Leach, NORESCO
  def test_lpd_bldg1

    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    lpd_test_hash = {}
    lpd_test_hash["Stairs 1"] = {"LPD" => 0.69,"Space_Type" => "Stair"}
    lpd_test_hash["Lobby 1"] = {"LPD" => 0.90,"Space_Type" => "Lobby"}
    lpd_test_hash["Office CR 35b"] = {"LPD" => 0.98,"Space_Type" => "Open Office"}
    lpd_test_hash["RR 14"] = {"LPD" => 0.9,"Space_Type" => "Restroom"}
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
  def test_lpd_bldg2

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
    lpd_test_hash["Base2 Weight 2B55 1B50"] = {"LPD" => 0.72,"Space_Type" => "Exercise"}
    lpd_test_hash["Flr1 Corridor 115"] = {"LPD" => 0.66,"Space_Type" => "Corridor"}
    lpd_test_hash["Flr2 Office 280"] = {"LPD" => 1.11,"Space_Type" => "ClosedOfficeOffice"}
    lpd_test_hash["Flr2 Computer 266"] = {"LPD" => 1.24,"Space_Type" => "Classroom"}
    lpd_test_hash["Flr1 Dining 150"] = {"LPD" => 0.65,"Space_Type" => "Dining"}
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
  def test_lpd_bldg4

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
    lpd_test_hash["L1-ES_apt"] = {"LPD" => 0.45,"Space_Type" => "Apartment"}
    lpd_test_hash["L1-E_corr"] = {"LPD" => 0.792,"Space_Type" => "Corridor"}
    lpd_test_hash["L1-W_ret"] = {"LPD" => 1.11,"Space_Type" => "Office"}
    
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

  # Test Daylighting for bldg_3
  # @author Matt Leach, NORESCO
  def test_daylighting_bldg3

    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    daylighting_test_hash = {}
    daylighting_test_hash["Flr2 Lounge Perimeter 250CD"] = {"PrimaryArea" => 1074.5,"SecondaryArea" => 974.1,"ControlType" => "PrimaryAndSecondary"}
    daylighting_test_hash["Flr1 Office 130-132 136 138 139"] = {"PrimaryArea" => 340,"SecondaryArea" => 340,"ControlType" => "PrimaryAndSecondary"}
    daylighting_test_hash["Flr1 Dining 150"] = {"PrimaryArea" => 1725.9,"SecondaryArea" => 1500.4,"ControlType" => "PrimaryAndSecondary"}
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

  # Test System Type for bldg_2
  # @author Matt Leach, NORESCO
  def test_system_type_bldg2

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
            unless airloop.supplyComponents('OS_Coil_Cooling_DX_SingleSpeed'.to_IddObjectType).length == 1
              failure_array << "Expected cooling coil of type CoilCoolingDXSingleSpeed for System #{airloop_name}"
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

  # Test Equipment Efficiencies for bldg_1
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg1
  
    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Thermal Zone: Elev Lobby 14 PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 281.0/20,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Thermal Zone: Elev Lobby 35 PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 70.0/7,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Thermal Zone: Utility 1 PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 22.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
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

  # Test Equipment Efficiencies for bldg_2
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg2
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Building Story 1 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 176.0,"EfficiencyType" => "EER","Efficiency" => 11.0}
    dx_coil_hash["Building Story 2 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 257.0,"EfficiencyType" => "EER","Efficiency" => 10.0}
    dx_coil_hash["Building Story 3 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 265.0,"EfficiencyType" => "EER","Efficiency" => 10.0}
    dx_coil_hash["Building Story 4 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 266.0,"EfficiencyType" => "EER","Efficiency" => 10.0}
    dx_coil_hash["Flr 1 Tenant 1 Core PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 86.0,"EfficiencyType" => "EER","Efficiency" => 11.2}
    dx_coil_hash["Flr 1 Tenant 1 East Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 13.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Flr 1 Tenant 1 North Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 43.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Flr 1 Tenant 1 South Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 32.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Flr 1 Tenant 1 West Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 52.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Flr 1 Tenant 1 Core PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 86.5,"EfficiencyType" => "COP","Efficiency" => 3.3}
    dx_coil_hash["Flr 1 Tenant 1 East Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 12.7,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Flr 1 Tenant 1 North Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 43.1,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Flr 1 Tenant 1 South Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 32.6,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Flr 1 Tenant 1 West Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 52.1,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    
    failure_array = check_dx_cooling_single_speed_efficiency(model, dx_coil_hash, failure_array)  
    failure_array = check_dx_cooling_two_speed_efficiency(model, dx_coil_hash, failure_array)  
    failure_array = check_dx_heating_single_speed_efficiency(model, dx_coil_hash, failure_array)  
  
    # check fan powers
    supply_fan_hash = {}
    # expect test to fail because pressure differential (0.9) for MERV 13 filter is being added to expected calculation
    # if pressure differential is set to zero, test passes
    supply_fan_hash["Building Story 1 PVAV_PFP_Boxes (Sys6) Fan"] = {"CFM" => 5869.0,"PressureDifferential" => 0}
    supply_fan_hash["Building Story 2 PVAV_PFP_Boxes (Sys6) Fan"] = {"CFM" => 9641.0,"PressureDifferential" => 0}
    supply_fan_hash["Building Story 3 PVAV_PFP_Boxes (Sys6) Fan"] = {"CFM" => 9916.0,"PressureDifferential" => 0}
    supply_fan_hash["Building Story 4 PVAV_PFP_Boxes (Sys6) Fan"] = {"CFM" => 9959.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr 1 Tenant 1 Core PSZ-HP Fan"] = {"CFM" => 2839.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr 1 Tenant 1 East Perimeter PSZ-HP Fan"] = {"CFM" => 466.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr 1 Tenant 1 North Perimeter PSZ-HP Fan"] = {"CFM" => 1547.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr 1 Tenant 1 South Perimeter PSZ-HP Fan"] = {"CFM" => 1144.0,"PressureDifferential" => 0}
    supply_fan_hash["Flr 1 Tenant 1 West Perimeter PSZ-HP Fan"] = {"CFM" => 1949.0,"PressureDifferential" => 0}
    
    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Test Equipment Efficiencies for bldg_3
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg3
  
    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Base1 LockerOther 1B30 PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 19.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Base1 LockerPlayer E PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 61.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
    dx_coil_hash["Base1 LockerPlayer NE PSZ-AC 1spd DX AC Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 50.0,"EfficiencyType" => "SEER","Efficiency" => 13.0}
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
    supply_fan_hash["Base1 PVAV_Reheat (Sys5) Fan"] = {"CFM" => 2521.0,"PressureDifferential" => 0}
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

  # Test Equipment Efficiencies for bldg_4
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg4
  
    model = create_baseline_model('bldg_4', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["IPF Above Ground PVAV_Reheat (Sys5) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 3726.0,"EfficiencyType" => "EER","Efficiency" => 9.5}
  
    failure_array = check_dx_cooling_two_speed_efficiency(model, dx_coil_hash, failure_array)  
    
    # check fan powers
    supply_fan_hash = {}
    # expect test to fail because pressure differential for MERV 13 filter is being added to expected calculation
    # if pressure differential is set to zero, test passes
    supply_fan_hash["IPF Above Ground PVAV_Reheat (Sys5) Fan"] = {"CFM" => 136667.0,"PressureDifferential" => 0.0}
    
    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)
    
    # check plant loop components
    # hw pumps
    failure_array = check_district_hw_pumps(model, failure_array)
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Test Equipment Efficiencies for bldg_5
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg5
  
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
    supply_fan_hash["Field Level IDF 122A PSZ-AC Fan"] = {"CFM" => 1059.0,"PressureDifferential" => 0.0}
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

  # Test Equipment Efficiencies for bldg_7
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg7
  
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

  # Electric DHW Test
  # @author Matt Leach, NORESCO
  def test_dhw_bldg2_electric
    
    building_type = "MediumOffice"
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', building_type, 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    expected_fuel_type = "Electricity"
    
    # get water heater(s)
    model.getWaterHeaterMixeds.each do |water_heater|
      water_heater_name = water_heater.name.get.to_s
      # check fuel type
      fuel_type = water_heater.heaterFuelType
      unless fuel_type == expected_fuel_type
        failure_array << "Building Type is #{building_type}, so expected Water Heater Fuel Type to be #{expected_fuel_type}, but #{water_heater_name} has Fuel Type #{fuel_type}"
      end
      # get water heater capacity
      next unless water_heater.heaterMaximumCapacity.is_initialized
      capacity_kw = water_heater.heaterMaximumCapacity.get/1000
      # get water heater volume
      next unless water_heater.tankVolume.is_initialized
      volume_gal = water_heater.tankVolume.get*264.173
      # get thermal efficiency
      if water_heater.heaterThermalEfficiency.is_initialized
        thermal_efficiency = water_heater.heaterThermalEfficiency.get
      else
        failure_array << "No Thermal Efficiency assigned to #{water_heater_name}"
      end
      # get UA
      if water_heater.offCycleLossCoefficienttoAmbientTemperature.is_initialized
        ua_watts_per_k = water_heater.offCycleLossCoefficienttoAmbientTemperature.get
      else
        failure_array << "No UA for skin losses assigned to #{water_heater_name}"
      end
      # check thermal efficiency and tank losses
      if fuel_type == "Electricity"
        # check thermal efficiency
        expected_thermal_efficiency = 1
        unless (expected_thermal_efficiency - thermal_efficiency).abs < 0.01
          failure_array << "Expected Thermal Efficiency for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_thermal_efficiency.round(2)}; found #{thermal_efficiency.round(2)} instead"
        end
        # check tank losses
        if capacity_kw < 12
          energy_factor = 0.97 - (0.00035*volume_gal)
          ua_btu_per_hr_per_f = (41_094 * (1 / energy_factor - 1)) / (24 * 67.5)
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
        else
          standby_loss_fraction = (0.3 + 27/volume_gal)/100
          standby_loss_btu_per_hr = standby_loss_fraction * volume_gal * 8.25 * 70
          ua_btu_per_hr_per_f = standby_loss_btu_per_hr / 70
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
        end
      elsif fuel_type == "NaturalGas"
        capacity_btu_per_hr = capacity_kw * 3412.141633
        if capacity_btu_per_hr <= 75000
          expected_thermal_efficiency = 0.82
          unless (expected_thermal_efficiency - thermal_efficiency).abs < 0.01
            failure_array << "Expected Thermal Efficiency for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_thermal_efficiency.round(2)}; found #{thermal_efficiency.round(2)} instead"
          end
          # Calculate the minimum Energy Factor (EF)
          ef = 0.67 - (0.0005 * volume_gal)
          # Calculate the Recovery Efficiency (RE)
          # based on a fixed capacity of 75,000 Btu/hr
          # and a fixed volume of 40 gallons by solving
          # this system of equations:
          # ua = (1/.95-1/re)/(67.5*(24/41094-1/(re*cap)))
          # 0.82 = (ua*67.5+cap*re)/cap
          cap = 75000.0
          re = (Math.sqrt(6724 * ef**2 * cap**2 + 40_409_100 * ef**2 * cap - 28_080_900 * ef * cap + 29_318_000_625 * ef**2 - 58_636_001_250 * ef + 29_318_000_625) + 82 * ef * cap + 171_225 * ef - 171_225) / (200 * ef * cap)
          # Calculate the skin loss coefficient (UA)
          # based on the actual capacity.
          ua_btu_per_hr_per_f = (expected_thermal_efficiency - re) * capacity_btu_per_hr / 67.5
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
        else
          # Thermal efficiency requirement from 90.1
          et = 0.8
          # Calculate the max allowable standby loss (SL)
          standby_loss_btu_per_hr = (capacity_btu_per_hr / 800 + 110 * Math.sqrt(volume_gal))
          # Calculate the skin loss coefficient (UA)
          ua_btu_per_hr_per_f = (standby_loss_btu_per_hr * et) / 70
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
          # Calculate water heater efficiency
          expected_thermal_efficiency = (ua_btu_per_hr_per_f * 70 + capacity_btu_per_hr * et) / capacity_btu_per_hr
        end
      else
        failure_array << "Unexpected WaterHeater Fuel Type (#{fuel_type}) for #{water_heater_name}; cannot check efficiency and tank losses"
      end
    end
  
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
  
  end

  # Gas DHW Test
  # @author Matt Leach, NORESCO
  def test_dhw_bldg2_naturalgas
    
    building_type = "PrimarySchool"
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-4B', building_type, 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    expected_fuel_type = "NaturalGas"
    
    # get water heater(s)
    model.getWaterHeaterMixeds.each do |water_heater|
      water_heater_name = water_heater.name.get.to_s
      # check fuel type
      fuel_type = water_heater.heaterFuelType
      unless fuel_type == expected_fuel_type
        failure_array << "Building Type is #{building_type}, so expected Water Heater Fuel Type to be #{expected_fuel_type}, but #{water_heater_name} has Fuel Type #{fuel_type}"
      end
      # get water heater capacity
      next unless water_heater.heaterMaximumCapacity.is_initialized
      capacity_kw = water_heater.heaterMaximumCapacity.get/1000
      # get water heater volume
      next unless water_heater.tankVolume.is_initialized
      volume_gal = water_heater.tankVolume.get*264.173
      # get thermal efficiency
      if water_heater.heaterThermalEfficiency.is_initialized
        thermal_efficiency = water_heater.heaterThermalEfficiency.get
      else
        failure_array << "No Thermal Efficiency assigned to #{water_heater_name}"
      end
      # get UA
      if water_heater.offCycleLossCoefficienttoAmbientTemperature.is_initialized
        ua_watts_per_k = water_heater.offCycleLossCoefficienttoAmbientTemperature.get
      else
        failure_array << "No UA for skin losses assigned to #{water_heater_name}"
      end
      # check thermal efficiency and tank losses
      if fuel_type == "Electricity"
        # check thermal efficiency
        expected_thermal_efficiency = 1
        unless (expected_thermal_efficiency - thermal_efficiency).abs < 0.01
          failure_array << "Expected Thermal Efficiency for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_thermal_efficiency.round(2)}; found #{thermal_efficiency.round(2)} instead"
        
        else
          puts "    Et pass for #{water_heater_name}"
        
        end
        # check tank losses
        if capacity_kw < 12
        
          puts "Small Electric Tank"
        
          energy_factor = 0.97 - (0.00035*volume_gal)
          ua_btu_per_hr_per_f = (41_094 * (1 / energy_factor - 1)) / (24 * 67.5)
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          else
            puts "    UA pass for #{water_heater_name}"
          
          
          end
        else
          standby_loss_fraction = (0.3 + 27/volume_gal)/100
          standby_loss_btu_per_hr = standby_loss_fraction * volume_gal * 8.25 * 70
          ua_btu_per_hr_per_f = standby_loss_btu_per_hr / 70
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
        end
      elsif fuel_type == "NaturalGas"
        capacity_btu_per_hr = capacity_kw * 3412.141633
        if capacity_btu_per_hr <= 75000
          expected_thermal_efficiency = 0.82
          unless (expected_thermal_efficiency - thermal_efficiency).abs < 0.01
            failure_array << "Expected Thermal Efficiency for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_thermal_efficiency.round(2)}; found #{thermal_efficiency.round(2)} instead"
          end
          # Calculate the minimum Energy Factor (EF)
          ef = 0.67 - (0.0005 * volume_gal)
          # Calculate the Recovery Efficiency (RE)
          # based on a fixed capacity of 75,000 Btu/hr
          # and a fixed volume of 40 gallons by solving
          # this system of equations:
          # ua = (1/.95-1/re)/(67.5*(24/41094-1/(re*cap)))
          # 0.82 = (ua*67.5+cap*re)/cap
          cap = 75000.0
          re = (Math.sqrt(6724 * ef**2 * cap**2 + 40_409_100 * ef**2 * cap - 28_080_900 * ef * cap + 29_318_000_625 * ef**2 - 58_636_001_250 * ef + 29_318_000_625) + 82 * ef * cap + 171_225 * ef - 171_225) / (200 * ef * cap)
          # Calculate the skin loss coefficient (UA)
          # based on the actual capacity.
          ua_btu_per_hr_per_f = (expected_thermal_efficiency - re) * capacity_btu_per_hr / 67.5
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
        else
          # Thermal efficiency requirement from 90.1
          et = 0.8
          # Calculate the max allowable standby loss (SL)
          standby_loss_btu_per_hr = (capacity_btu_per_hr / 800 + 110 * Math.sqrt(volume_gal))
          # Calculate the skin loss coefficient (UA)
          ua_btu_per_hr_per_f = (standby_loss_btu_per_hr * et) / 70
          expected_ua_watts_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
          unless (expected_ua_watts_per_k - ua_watts_per_k).abs < 0.02
            failure_array << "Expected UA Skin Losses for #{water_heater_name} with Fuel Type #{fuel_type} to be #{expected_ua_watts_per_k.round(2)} W/K; found #{ua_watts_per_k.round(2)} W/K instead"
          end
          # Calculate water heater efficiency
          expected_thermal_efficiency = (ua_btu_per_hr_per_f * 70 + capacity_btu_per_hr * et) / capacity_btu_per_hr
        end
      else
        failure_array << "Unexpected WaterHeater Fuel Type (#{fuel_type}) for #{water_heater_name}; cannot check efficiency and tank losses"
      end
    end
  
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

  # Combined space heating and DHW Test
  # @author Matt Leach, NORESCO
  def test_dhw_bldg7
    
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

  # DCV Test
  # @author Matt Leach, NORESCO
  def test_dcv_bldg3
  
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

  # Non-Predominant Heating Condition Test
  # @author Matt Leach, NORESCO
  def test_non_predominant_heating_condition_bldg_2
  
    model = create_baseline_model('bldg_2_NonPredominantHeating', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    # modified model so that DOAS serving Flr2 has a gas heating coil instead of an electric heating coil
    # expect this change to trigger non-predominant heating condition and apply PSZ systems to all zones on Flr 2
    
    model.getThermalZones.each do |zone|
      zone_name = zone.name.get.to_s
      if zone_name.include? "Flr2"
        found_psz_system = false
        model.getAirLoopHVACs.each do |airloop|
          airloop_name = airloop.name.get.to_s
          if airloop_name.include? zone_name
            found_psz_system = true
            # check for gas heating coil
            unless airloop.supplyComponents('OS_Coil_Heating_Gas'.to_IddObjectType).length == 2
              failure_array << "Expected supplementary heating coils of type CoilHeatingGas for System #{airloop_name}"
            end
          end
        end
      end
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
  
  end

  # Sizing Factors Test
  # @author Matt Leach, NORESCO
  def test_sizing_factors_bldg2
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    expected_cooling_sizing_factor = 1.15
    expected_heating_sizing_factor = 1.25
  
    sizing_params = model.getSizingParameters
    
    unless (expected_cooling_sizing_factor - sizing_params.coolingSizingFactor).abs < 0.01
      failure_array << "Expected Cooling Sizing Factor of #{expected_cooling_sizing_factor}; got #{sizing_params.coolingSizingFactor} instead"
    end
    
    unless (expected_heating_sizing_factor - sizing_params.heatingSizingFactor).abs < 0.01
      failure_array << "Expected Heating Sizing Factor of #{expected_heating_sizing_factor}; got #{sizing_params.heatingSizingFactor} instead"
    end
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
  
  end

  # Economizer Test
  # @author Matt Leach, NORESCO
  def test_economizing_bldg2_5B
  
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
  def test_economizing_bldg2_1A
  
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
  def test_economizing_bldg2_5A
  
    # Climate zone is 5A.  All systems except 1, 2, 9 and 10 should have economizers
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

  # SAT/Zone Sizing/System Sizing Test
  # @author Matt Leach, NORESCO
  def test_design_supply_air_temp_bldg2_thermostat_mod
    model = create_baseline_model('bldg_2_thermostat_mod', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # check zone sizing objects
    zone_sizing_test_hash = {}
    zone_sizing_test_hash["North Stair"] = {"Clg_Design_Temp" => (((80 - 20) - 32)/1.8),"Htg_Design_Temp" => (((55 + 20) - 32)/1.8)}
    zone_sizing_test_hash["Flr 1 Tenant 2 East Perimeter"] = {"Clg_Design_Temp" => (24 - 20/1.8),"Htg_Design_Temp" => (21 + 20/1.8)}
    zone_sizing_test_hash["Flr 1 Tenant 1 Core"] = {"Clg_Design_Temp" => (((73 - 20) - 32)/1.8),"Htg_Design_Temp" => (((72 + 20) - 32)/1.8)}
    
    zone_sizing_test_hash.keys.each do |zone_name|
      zone = model.getThermalZoneByName(zone_name).get
      sizing_zone = zone.sizingZone
      clg_design_temp_c = sizing_zone.zoneCoolingDesignSupplyAirTemperature
      htg_design_temp_c = sizing_zone.zoneHeatingDesignSupplyAirTemperature
      clg_design_temp_delta_c = sizing_zone.zoneCoolingDesignSupplyAirTemperatureDifference
      htg_design_temp_delta_c = sizing_zone.zoneHeatingDesignSupplyAirTemperatureDifference
      
      # verify that design temperature difference is set correctly
      # cooling
      unless (20/1.8 - clg_design_temp_delta_c).abs < 0.01
        failure_array << "Expected Design Cooling Temperature Difference of 20 F for Zone #{zone_name}; got #{(clg_design_temp_delta_c*1.8+32).round(2)} F instead"
      end
      # heating
      unless (20/1.8 - htg_design_temp_delta_c).abs < 0.01
        failure_array << "Expected Design Heating Temperature Difference of 20 F for Zone #{zone_name}; got #{(htg_design_temp_delta_c*1.8+32).round(2)} F instead"
      end
      
      # verify that design temperatures are set correctly
      # cooling
      unless (zone_sizing_test_hash[zone_name]["Clg_Design_Temp"] - clg_design_temp_c).abs < 0.01
        failure_array << "Expected Design Cooling Temperature of #{(zone_sizing_test_hash[zone_name]["Clg_Design_Temp"]*1.8+32).round(2)} F for Zone #{zone_name}; got #{(clg_design_temp_c*1.8+32).round(2)} F instead"
      end
      # heating
      unless (zone_sizing_test_hash[zone_name]["Htg_Design_Temp"] - htg_design_temp_c).abs < 0.01
        failure_array << "Expected Design Cooling Temperature of #{(zone_sizing_test_hash[zone_name]["Htg_Design_Temp"]*1.8+32).round(2)} F for Zone #{zone_name}; got #{(htg_design_temp_c*1.8+32).round(2)} F instead"
      end
    end  
      
    # check system sizing objects
    system_sizing_test_hash = {}
    system_sizing_test_hash["Building Story 1 PVAV_PFP_Boxes (Sys6)"] = {"Clg_Design_Temp" => ((73 - 20) - 32)/1.8,"Htg_Design_Temp" => ((73 - 20) - 32)/1.8}
    system_sizing_test_hash["Building Story 2 PVAV_PFP_Boxes (Sys6)"] = {"Clg_Design_Temp" => 24 - 20/1.8,"Htg_Design_Temp" => 24 - 20/1.8}
    
    system_sizing_test_hash.keys.each do |airloop_name|
      airloop = model.getAirLoopHVACByName(airloop_name).get
      system_sizing = airloop.sizingSystem
      central_clg_design_temp_c = system_sizing.centralCoolingDesignSupplyAirTemperature
      central_htg_design_temp_c = system_sizing.centralHeatingDesignSupplyAirTemperature
        
      # verify that design temperatures are set correctly
      # cooling
      unless (system_sizing_test_hash[airloop_name]["Clg_Design_Temp"] - central_clg_design_temp_c).abs < 0.01
        failure_array << "Expected Design Cooling Temperature of #{(system_sizing_test_hash[airloop_name]["Clg_Design_Temp"]*1.8+32).round(2)} F for System #{airloop_name}; got #{(central_clg_design_temp_c*1.8+32).round(2)} F instead"
      end
      # heating
      unless (system_sizing_test_hash[airloop_name]["Htg_Design_Temp"] - central_htg_design_temp_c).abs < 0.01
        failure_array << "Expected Design Cooling Temperature of #{(system_sizing_test_hash[airloop_name]["Htg_Design_Temp"]*1.8+32).round(2)} F for System #{airloop_name}; got #{(central_htg_design_temp_c*1.8+32).round(2)} F instead"
      end
    end
    
    # check airloop setpoint managers
    # PSZ systems should have single zone reheat setpoint managers
    # VAV systems should have warmest setpoint managers (low setpoint temperature should match system sizing central cooling design temperature; high setpoint temperature should be 5 F higher)
    model.getAirLoopHVACs.each do |airloop|
      airloop_name = airloop.name.get.to_s
      if airloop_name.include? "PSZ"
        # PSZ airloop (expect SZR setpoint manager)
        found_correct_setpoint_manager = false
        # check airloop setpoint manager
        model.getSetpointManagerSingleZoneReheats.each do |szr_reset_manager|
          if szr_reset_manager.airLoopHVAC.is_initialized
            airloop_to_match = szr_reset_manager.airLoopHVAC.get
            next unless airloop_to_match == airloop
            found_correct_setpoint_manager = true
          else
            failure_array << "#{szr_reset_manager.name} not connected to an airloop"
          end  
        end
        unless found_correct_setpoint_manager
          failure_array << "Expected to find Setpoint Manager of Type Single Zone Reheat for #{airloop.name} but did not"
        end
      else
        # VAV airloop (system 5-8; expect warmest setpoint manager)
        found_correct_setpoint_manager = false
        # check airloop setpoint manager
        model.getSetpointManagerWarmests.each do |warmest_setpoint_manager|
          if warmest_setpoint_manager.airLoopHVAC.is_initialized
            airloop_to_match = warmest_setpoint_manager.airLoopHVAC.get
            next unless airloop_to_match == airloop
            found_correct_setpoint_manager = true
          else
            failure_array << "#{warmest_setpoint_manager.name} not connected to an airloop"
          end
          # check setpoint manager setpoints
          next unless system_sizing_test_hash.keys.include? airloop_name 
          # minimum setpoint temperature
          minimum_setpoint_temperature_c = warmest_setpoint_manager.minimumSetpointTemperature
          unless (system_sizing_test_hash[airloop_name]["Clg_Design_Temp"] - minimum_setpoint_temperature_c).abs < 0.01
            failure_array << "Expected Minimum Setpoint Temperature of #{(system_sizing_test_hash[airloop_name]["Clg_Design_Temp"]*1.8+32).round(2)} F for System #{airloop_name}; got #{(minimum_setpoint_temperature_c*1.8+32).round(2)} F instead"
          end
          # maximum setpoint temperature
          maximum_setpoint_temperature_c = warmest_setpoint_manager.maximumSetpointTemperature
          unless (system_sizing_test_hash[airloop_name]["Clg_Design_Temp"] + 5/1.8 - maximum_setpoint_temperature_c).abs < 0.01
            failure_array << "Expected Maximum Setpoint Temperature of #{(system_sizing_test_hash[airloop_name]["Clg_Design_Temp"]*1.8+32+5).round(2)} F for System #{airloop_name}; got #{(maximum_setpoint_temperature_c*1.8+32).round(2)} F instead"
          end
        end
        unless found_correct_setpoint_manager
          failure_array << "Expected to find Setpoint Manager of Type Warmest for #{airloop.name} but did not"
        end
      end
    end
    
    # check for failures
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

  # Fan Powered Terminal Test
  # @author Matt Leach, NORESCO
  def test_fan_powered_terminals_bldg2
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # minimum flow fraction should be 30% and max secondary flow should be 50% of terminal size
    primary_flow_rates_m3_per_s_hash = {}
    primary_flow_rates_m3_per_s_hash["FLR 1 LOBBY"] = 0.31013
    primary_flow_rates_m3_per_s_hash["FLR 1 TENANT 2 EAST PERIMETER"] = 0.48728
    primary_flow_rates_m3_per_s_hash["FLR 1 TENANT 2 NORTH PERIMETER"] = 0.71818
    primary_flow_rates_m3_per_s_hash["FLR 2 TENANT 2 NORTH PERIMETER"] = 0.54006
    primary_flow_rates_m3_per_s_hash["FLR 2 TENANT 1 CORE"] = 0.72797
  
    number_of_piu_terminals = 0
    model.getAirTerminalSingleDuctParallelPIUReheats.each do |piu_terminal|
      piu_terminal_name = piu_terminal.name.get.to_s
      zone_name = piu_terminal_name.gsub(" PFP Term","")
      number_of_piu_terminals += 1
      # check minimum primary air flow fraction
      if piu_terminal.minimumPrimaryAirFlowFraction.is_initialized
        unless piu_terminal.minimumPrimaryAirFlowFraction.get == 0.3
          failure_array << "Expected Minimum Primary Air Flow Fraction to be set to 0.3 for Parallel PIU Terminal for Zone #{zone_name}; found #{piu_terminal.minimumPrimaryAirFlowFraction.get} instead"
        end
      else
        failure_array << "Expected Minimum Primary Air Flow Fraction to be set for Parallel PIU Terminal for Zone #{zone_name}"
      end
      # look for spot check terminals
      # puts "Zone Name = #{zone_name}"
      primary_flow_rates_m3_per_s_hash.keys.each do |spot_check_zone_name|
        if spot_check_zone_name.casecmp(zone_name).zero?
          # puts "Zone #{zone_name} is a spot check zone"
          # check maximum secondary flow rate (equal to half primary air flow rate)
          if piu_terminal.maximumSecondaryAirFlowRate.is_initialized
            unless (primary_flow_rates_m3_per_s_hash[spot_check_zone_name]/2 - piu_terminal.maximumSecondaryAirFlowRate.get).abs < 0.005
              failure_array << "Expected #{(primary_flow_rates_m3_per_s_hash[spot_check_zone_name]*2118.88/2).round()} cfm Maximum Secondary Flow Rate for Zone #{spot_check_zone_name}; found #{(piu_terminal.maximumSecondaryAirFlowRate.get*2118.88).round()} cfm instead"
            end
          else
            failure_array << "Expected Maximum Secondary Air Flow Rate to be set for Parallel PIU Terminal for Zone #{zone_name}"
          end  
        end
      end
    end
    unless number_of_piu_terminals > 0
      failure_array << "No Parallel PIU Terminals found, even though Baseline HVAC System Type is 6"
    end
    
    # check for failures
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
  
  end

  # Fan Operation Mode Test
  # @author Matt Leach, NORESCO
  def test_fan_operation_bldg2
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    model.getAirLoopHVACs.each do |airloop|
      # check for night cycle manager for all airloops
      if airloop.availabilityManager.is_initialized
        availability_manager = airloop.availabilityManager.get
        # check availability manager type
        unless availability_manager.to_AvailabilityManagerNightCycle.is_initialized
          failure_array << "Expected Availability Manager of Type NightCycle for Airloop #{airloop.name}"
        end
      else
        failure_array << "No Availability Manager found for Airloop #{airloop.name}"
      end
      # check fan operation schedule
      # check for fan powers less than 0.75 hp
      systems_with_small_fans = ["Flr 1 Tenant 1 East Perimeter PSZ-HP"]
      if systems_with_small_fans.include? airloop.name.get.to_s
        # fan schedule should be set to always on discrete
        if airloop.supplyFan.is_initialized
          supply_fan = airloop.supplyFan.get
          if airloop.name.get.to_s.include? "PSZ"
            # look for constant volume fan
            if airloop.supplyFan.get.to_FanConstantVolume.is_initialized
              supply_fan = airloop.supplyFan.get.to_FanConstantVolume.get
              # check availability schedule
              unless supply_fan.availabilitySchedule.name.get.to_s == "Always On Discrete"
                failure_array << "Expected SupplyFan Availability Schedule to be set to Always On Discrete for Airloop #{airloop.name} because fan is smaller than 0.75 hp"
              else
              end
            else
              failure_array << "Expected Supply Fan of Type ConstantVolume for Airloop #{airloop.name}"
            end
          else
            # look for variable volume fan
            if airloop.supplyFan.get.to_FanVariableVolume.is_initialized
              supply_fan = airloop.supplyFan.get.to_FanVariableVolume.get
              # check availability schedule
              unless supply_fan.availabilitySchedule.name.get.to_s == "Always On Discrete"
                failure_array << "Expected SupplyFan Availability Schedule to be set to Always On Discrete for Airloop #{airloop.name} because fan is smaller than 0.75 hp"
              end
            else
              failure_array << "Expected Supply Fan of Type VariableVolume for Airloop #{airloop.name}"
            end
          end
        else
          failure_array << "Expected to find Supply Fan for Airloop #{airloop.name}"
        end
      end
    end
    
    # check for failures
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
  
  end
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_9

    base_model = create_baseline_model('bldg_9', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)

  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_shw

    test_model_name = 'bldg_10'
    building_type = 'MediumOffice'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_shw(base_model, prop_model,building_type) 
    
  end  

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_purchased_energy

    test_model_name = 'bldg_10'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice' ,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_purchased_energy(base_model, prop_model) 
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_num_boilers
 
    test_model_name = 'bldg_10'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_boilers(base_model, prop_model) 
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_num_chillers
 
    test_model_name = 'bldg_10'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_chillers(base_model, prop_model) 
 
  end
 
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_plant_controls
 
    test_model_name = 'bldg_10'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_plant_controls(base_model, prop_model)
 
  end 

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_shw
 
    test_model_name = 'bldg_11'
    building_type = 'LargeOffice'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_shw(base_model, prop_model,building_type)
 
  end  
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_baseline_sys
 
    test_model_name = 'bldg_11'
    building_type = 'LargeOffice'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_baseline_system_type(base_model, prop_model, building_type, climate_zone)
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_num_boilers
 
    test_model_name = 'bldg_11'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_boilers(base_model, prop_model) 
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_num_chillers
 
    test_model_name = 'bldg_11'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_chillers(base_model, prop_model) 
 
  end
 
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_plant_controls
 
    test_model_name = 'bldg_11'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_plant_controls(base_model, prop_model) 
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_shw

    test_model_name = 'bldg_12'
    building_type = 'MidriseApartment'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_shw(base_model, prop_model,building_type)   
    
  end
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_baseline_sys

    test_model_name = 'bldg_12'
    building_type = 'MidriseApartment'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)

    # Check for PTAC in the apartments
    ['2-3F E Apt West', '4F W Apt Studio North'].each do |zone_name|
      zone = base_model.getThermalZoneByName(zone_name).get
      zone.equipment.each do |equip|
        next if equip.to_FanZoneExhaust.is_initialized
        assert(equip.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized, "Apartment HVAC is not correct, it should be a PTAC.")
      end
    end
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_num_boilers

    test_model_name = 'bldg_12'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_boilers(base_model, prop_model)
    
  end  
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_num_chillers

    test_model_name = 'bldg_12'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_chillers(base_model, prop_model)
    
  end   

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_plant_controls

    test_model_name = 'bldg_12'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_plant_controls(base_model, prop_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_economizer

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_economizers(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_sat_delta

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_sat_delta(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_sat_reset
  
    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_sat_reset(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_min_vav_setpoints

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_min_vav_setpoints(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_coil_efficiencies

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_coil_efficiencies(base_model)
  
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_ventilation_rates

    test_model_name = 'bldg_13'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)

    check_ventilation_rates(base_model, prop_model)    
  
  end 

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_14_coil_efficiencies

    base_model = create_baseline_model('bldg_14', '90.1-2013', 'ASHRAE 169-2006-5B', 'Warehouse','Xcel Energy CO EDA', false, true)
    check_coil_efficiencies(base_model)
  
  end
 
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_14_ventilation_rates

    test_model_name = 'bldg_14'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'Warehouse','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_ventilation_rates(base_model, prop_model)    
  
  end

  # @author Taylor Roberts, Group14 Engineering
  def known_fail_test_bldg_15_retail_standalone
  
    # Create the baseline model
    model = create_baseline_model('bldg_15', '90.1-2013', 'ASHRAE 169-2006-5B', 'RetailStandalone','Xcel Energy CO EDA', false, true)
  
    # Conditions expected to be true in the baseline model
    
    #Check that the office system is a VAV system
    zone = model.getThermalZoneByName("15.Office.Cs Zone").get
    air_terminal = zone.airLoopHVACTerminal.get
    assert(air_terminal.to_AirTerminalSingleDuctVAVReheat.is_initialized, "Office HVAC is not correct, it should be a VAV with hot water heating.  Wrong terminal type.")
    has_hw_coil = false
    air_terminal.airLoopHVAC.get.supplyComponents.each do |supply_component|
      htg_coil = supply_component.to_CoilHeatingWater
      if htg_coil.is_initialized
        has_hw_coil = true
      end
    end
    assert(has_hw_coil, "Office HVAC is not correct, it should be a VAV with hot water heating.  No HW coil found.")
    
    #Check that their is chilled water system
    model.getPlantLoops.each do |plant_loop|
      next unless plant_loop.sizingPlant.loopType == 'Cooling'
      has_chlr = false
      plant_loop.supplyComponents.each do |supply_component|
        if supply_component.to_ChillerElectricEIR.is_initialized
          has_chlr = true
        end
      end
      assert(has_chlr, "Office HVAC is not correct, it should be a VAV with CHW.  Missing chiller.")
    end #The measure did this correctly
    
    #Check in window to wall ratio
    total_window_area = 0.0
    model.getSubSurfaces.each do |sub_surface|
      if sub_surface.subSurfaceType == "FixedWindow"
        window_area = sub_surface.grossArea
        total_window_area += window_area
      end
    end
    assert_in_delta(4750, total_window_area, 50.0, "Window area is wrong.") #The measure did this correctly

  end

  # @author Taylor Roberts, Group14 Engineering
  def known_fail_test_bldg_16_medium_office

    # Create the baseline model
    model = create_baseline_model('bldg_16', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
  
    # Conditions expected to be true in the baseline model
    
    # Lighting Power Density
    
    # Open Office LPD should be 0.98 W/ft2
    space = model.getSpaceByName("9.OpenOffice 2").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    assert_in_delta(0.98, lpd_w_per_ft2, 0.01, "Open Office LPD is wrong.") #The measure did this correctly
    
    # Conference LPD should be 1.23 W/ft2  
    space = model.getSpaceByName("9.Conference 1").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    assert_in_delta(1.23, lpd_w_per_ft2, 0.01, "Conference LPD is wrong.") #The measure did this correctly
    
    # Parking Garage LPD should be 0.19 W/sf
    # *** There is no "Standards Space Type" for Parking Garage ***
    space = model.getSpaceByName("P3.Parking Garage").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    assert_in_delta(0.19, lpd_w_per_ft2, 0.01, "Parking Garage LPD is wrong.")   #The measure did NOT do this correctly - LPD of 0.63 W/sf not sure why?

    # Occupancy Vacancy Controls
    # Not sure how to check for this Andrew
    # The baseline model should a 10% schedule reduction for all the zones that occupancy sensors are required in
    # BUT because they are required they should already be in the proposed model so really the baseline doesn't have to change anything for those zones
    # for the zones it is NOT required in but the proposed has a schedule adjustment the baseline should go back to the orginal schedule
    # how to do this I am not sure, but maybe they will need to have a flag
    
    # Daylighting Controls
    
    # OpenOffice Zones with glass should have daylighting
    zone = model.getThermalZoneByName("9.OpenOffice 16 Zone").get
    primary_daylighting_control = zone.primaryDaylightingControl
    if primary_daylighting_control.is_initialized
      # Zone info - 1,359.5 ft2 zone area, >300 W so primary and secondary sidelighted area
      # Primary sdielighted area - 7'3" head height, 48' 2 11/16" glass and wall width, 349.6 ft2 daylighting area,  25.7% of zone controlled
      primary_fraction_daylight = zone.fractionofZoneControlledbyPrimaryDaylightingControl
      assert_in_delta(0.257, primary_fraction_daylight, 0.02, "Daylighting Control Fraction is wrong.")
      primary_dl_control = primary_daylighting_control.lightingControlType
      assert_equal("Stepped", primary_dl_control, "Dayligthing control is not correct, it should be Stepped")
    end #The measure did NOT do this correctly - no daylighting control here at all
    secondary_daylighting_control = zone.secondaryDaylightingControl
    if secondary_daylighting_control.is_initialized
      # Zone info - 1,359.5 ft2 zone area, >300 W so primary and secondary sidelighted area
      # Primary sdielighted area - 7'3" head height, 48' 2 11/16" glass and wall width, 174.8 ft2 daylighting area,  12.9% of zone controlled
      secondary_fraction_daylight = zone.fractionofZoneControlledbySecondaryDaylightingControl
      assert_in_delta(0.129, secondary_fraction_daylight, 0.02, "Daylighting Control Fraction is wrong.")
      secondary_dl_control = secondary_daylighting_control.lightingControlType
      assert_equal("Stepped", secondary_dl_control, "Dayligthing control is not correct, it should be Stepped")
    end #The measure did NOT do this correctly - no daylighting control here at all
    
    # OpenOffice Zones with out glass should NOT have daylighting
    zone = model.getThermalZoneByName("9.OpenOffice Zone").get
    primary_daylighting_control = zone.primaryDaylightingControl
    assert(primary_daylighting_control.empty?, "Dayligthing control is in zones with no windows")
        
    # Retail Zones with windows (no skylights) should NOT have daylighting
    zone = model.getThermalZoneByName("1.Retail 2 Zone").get
    primary_daylighting_control = zone.primaryDaylightingControl
    assert(primary_daylighting_control.empty?, "Dayligthing control is in Retail zones, but should not be.")
    #The measure did NOT do this correctly - there is a daylighting control present    

  end

  # @author Taylor Roberts, Group14 Engineering
  def known_fail_test_bldg_17_midrise_apartment_lowrise_iecc_constructions
  
    # Create the baseline model
    model = create_baseline_model('bldg_17', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
  
    # Conditions expected to be true in the baseline model
    
    # *** Note, the point of this test to to test for under three story apartment buildings ***
    # *** Might need a lowrise apartment building type for this ***
    # *** EDA protocol requires that low rise <3 stories residential buildings have baselines with IECC constructions ***
    
    # Climate zone 5B Residential IECC U-values
    # Walls - 0.06 Btu/ft2*h*F
    # Roof - 0.026 Btu/ft2*h*F
    # Windows - 0.32 Btu/ft2*h*F  note no non-metal or metal, just 0.32 for everything
    
    # Envelope properties
    
    # Check for wall construction properties
    space = model.getSpaceByName("3.Apartment 13").get
    space.surfaces.each do |surface|
      if surface.surfaceType == "Wall" && surface.outsideBoundaryCondition == "Outdoors"
        u_value_si = surface.construction.get.thermalConductance.get
        u_value_ip = OpenStudio.convert(u_value_si,'W/m^2*K','Btu/ft^2*h*R').get
        assert_in_delta(0.06, u_value_ip, 0.002, "Exterior Wall U-value is not correct")
      end
    end
    
    # Check for wall construction properties
    space = model.getSpaceByName("3.Apartment 13").get
    space.surfaces.each do |surface|
      if surface.surfaceType == "Roof" && surface.outsideBoundaryCondition == "Outdoors"
        u_value_si = surface.construction.get.thermalConductance.get
        u_value_ip = OpenStudio.convert(u_value_si,'W/m^2*K','Btu/ft^2*h*R').get
        assert_in_delta(0.026, u_value_ip, 0.002, "Roof U-value is not correct")
      end
    end
    
    # Check for window construction properties
    space = model.getSpaceByName("3.Apartment 13").get
    space.surfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        if sub_surface.subSurfaceType == "FixedWindow" && sub_surface.outsideBoundaryCondition == "Outdoors"
          u_value_si = sub_surface.construction.get.to_Construction.get.calculated_u_factor
          u_value_ip = OpenStudio.convert(u_value_si,'W/m^2*K','Btu/ft^2*h*R').get
          assert_in_delta(0.32, u_value_ip, 0.01, "Window u-value is wrong.")
        end
      end
    end
    
    # The measure also made a VAV system to serve the apartment units, which should be served by a PTHP system
    # Another issue is that the measure deleted the exhuast fans from the apartment units, which are used for the ventilation strategy
 
  end
 
  # @author Taylor Roberts, Group14 Engineering
  def known_fail_test_bldg_18_retail_standalone
  
    # Create the baseline model
    model = create_baseline_model('bldg_18', '90.1-2013', 'ASHRAE 169-2006-5B', 'RetailStandalone','Xcel Energy CO EDA', false, true)
  
    # Conditions expected to be true in the baseline model
    
    # Skylight properties
    
    # Check for skylight construction properties
    space = model.getSpaceByName("2.Retail 12").get
    space.surfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        if sub_surface.subSurfaceType == "Skylight" and sub_surface.outsideBoundaryCondition == "Outdoors"
          u_value_si = sub_surface.construction.get.to_Construction.get.calculated_u_factor
          u_value_ip = OpenStudio.convert(u_value_si,'W/m^2*K','Btu/ft^2*h*R').get
          assert_in_delta(0.50, u_value_ip, 0.04, "Skylight U-value is wrong.") #ashrae 90.1-2013 skylight u-value of 0.50
        end
      end
    end
    
    # Check for reduction in total skylight area to meet 3% SRR
    total_skylight_area = 0.0
    model.getSubSurfaces.each do |sub_surface|
      if sub_surface.subSurfaceType == "Skylight"
        total_skylight_area += sub_surface.grossArea
      end
    end
    assert_in_delta(330, total_skylight_area, 1.0, "Skylight area is wrong.") #The measure did this correctly
    
    # Retail zones should have PSZ with gas heat
    zone = model.getThermalZoneByName("2.Retail 12 Zone").get
    air_terminal = zone.airLoopHVACTerminal.get
    assert(air_terminal.to_AirTerminalSingleDuctUncontrolled.is_initialized, "Retail HVAC is not correct, it should be a PSZ with Gas Heating.  Wrong terminal type.")
    has_gas_ht = false
    air_terminal.airLoopHVAC.supplyComponents.each do |supply_component|
      htg_coil = supply_component.to_CoilHeatingGas
      if htg_coil.is_initialized
        has_gas_ht = true
      end
    end
    assert(has_gas_ht, "Retail HVAC is not correct, it should be a PSZ with Gas Heating.  Gas heating coil missing.")
    #The measure did NOT do this correctly - all retail zones should have PSZ systems not a VAV system

  end
  
  # @author Taylor Roberts, Group14 Engineering
  def known_fail_test_bldg_19_medium_office
  
    # Create the baseline model
    model = create_baseline_model('bldg_19', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
  
    # Conditions expected to be true in the baseline model
    
    #Check that the office system is a VAV system
    zone = model.getThermalZoneByName("12.Office.C1 Zone").get
    air_terminal = zone.airLoopHVACTerminal.get
    assert(air_terminal.to_AirTerminalSingleDuctVAVReheat.is_initialized, "Office HVAC is not correct, it should be a VAV with hot water heating.  Wrong terminal type.")
    has_hw_coil = false
    air_terminal.airLoopHVAC.get.supplyComponents.each do |supply_component|
      htg_coil = supply_component.to_CoilHeatingWater
      if htg_coil.is_initialized
        has_hw_coil = true
      end
    end
    assert(has_hw_coil, "Office HVAC is not correct, it should be a VAV with hot water heating.  No HW coil found.")
    
    #Check that the hotel is a PTAC system
    zone = model.getThermalZoneByName("8.Hotel.E1 Zone").get
    zone.equipment.each do |equipment|
      assert(equipment.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized,  "Hotel HVAC is not correct, it should be a PTAC with hot water heating")
      equipment = equipment.to_ZoneHVACPackagedTerminalAirConditioner.get
      assert(equipment.heatingCoil.to_CoilHeatingWater.is_initialized, "Hotel HVAC is not correct, it should be a PTAC with hot water heating")
    end #The measure did NOT do this correctly - it put in a VAV system
    
    #Check in window to wall ratio
    total_window_area = 0
    model.getSubSurfaces.each do |sub_surface|
      if sub_surface.subSurfaceType == "FixedWindow"
        window_area = sub_surface.grossArea
        total_window_area += window_area
      end
    end
    assert_in_delta(3600, total_window_area, 60.0, "Window area is wrong.") #The measure did NOT do this correctly - it did 36.81% W2W ratio for some reason
      
  end  

  # @author Taylor Roberts, Group14 Engineering
  def known_fail_test_bldg_20_large_hotel
  
    # Create the baseline model
    model = create_baseline_model('bldg_20', '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeHotel','Xcel Energy CO EDA', false, true)
  
    # Conditions expected to be true in the baseline model
    
    # Window Properties
    
    # Check for non-metal frames for hotel room windows
    space = model.getSpaceByName("Level 5.GuestRoom 5").get
    space.surfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        if sub_surface.subSurfaceType == "FixedWindow" and sub_surface.outsideBoundaryCondition == "Outdoors"
          u_value_si = sub_surface.construction.get.to_Construction.get.calculated_u_factor
          u_value_ip = OpenStudio.convert(u_value_si,'W/m^2*K','Btu/ft^2*h*R').get
          assert_in_delta(0.32, u_value_ip, 0.01, "Hotel room non-metal framing is wrong.") #ashrae 90.1-2013 non-metal framing u-value of 0.32
        end
      end
    end
    
    # Check for metal frames for storefront
    space = model.getSpaceByName("Level 1.Lobby 3").get
    space.surfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        if sub_surface.subSurfaceType == "FixedWindow" and sub_surface.outsideBoundaryCondition == "Outdoors"
          u_value_si = sub_surface.construction.get.to_Construction.get.calculated_u_factor
          u_value_ip = OpenStudio.convert(u_value_si,'W/m^2*K','Btu/ft^2*h*R').get
          assert_in_delta(0.42, u_value_ip, 0.01, "Storefront metal framing is wrong.") #ashrae 90.1-2013 metal framing u-value of 0.42
        end
      end
    end
    
    # Check to seee that the baseline model does not have shading surfaces
    num_shading_surfaces = 0
    model.getShadingSurfaceGroups.each do |shade_group|
      # Site and Building shading (other buildings) does not count
      next if shade_group.shadingSurfaceType == 'Site' || shade_group.shadingSurfaceType == 'Building'
      # Space shading surfaces should have been removed
      num_shading_surfaces += shade_group.shadingSurfaces.size
    end
    assert_equal(0, num_shading_surfaces, "There should be no space or building shading surfaces in the baseline model")
    
    # Baseline HVAC systems
    
    # Check for PTHP in the guest rooms
    zone = model.getThermalZoneByName("Level 2.GuestRoom 1 Zone").get
    zone.equipment.each do |equip|
      assert(equip.to_ZoneHVACPackagedTerminalHeatPump.is_initialized, "Guestroom HVAC is not correct, it should be a PTHP")
      # The proposed building has VRF with gas-fired DOAS.  This model should have
      # a mixed-fuel baseline for Xcel
    end
    
    #check the corridor zones for fuel switching, should be gas or hot water heating
    zone = model.getThermalZoneByName("Level 3.Corridor 1 Zone").get
    zone.airLoopHVACTerminal.each do |air_terminal|
      assert(air_terminal.is_initialized, "Corridor HVAC is not correct, it should be an Air Loop with Gas Heating")
      has_gas_or_hw_htg_coil = false
      air_terminal.airLoopHVAC.supplyComponents.each do |supply_component|
        htg_coil = supply_component.to_CoilHeatingGas || supply_component.to_CoilHeatingWater
        if htg_coil.is_initialized
          has_gas_or_hw_htg_coil = true
        end
      end
      assert(has_gas_or_hw_htg_coil, "Corridor HVAC is not correct, it should be an Air Loop with Gas Heating")
    end
    
  end

end
