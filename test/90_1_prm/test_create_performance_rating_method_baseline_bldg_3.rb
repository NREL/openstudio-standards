require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013Test3 < Minitest::Test

  include Baseline9012013

  # Test Equipment Efficiencies for bldg_1
  # @author Matt Leach, NORESCO
  # Known failures due to code not yet accounting for zone multipliers affecting components.
  def known_fail_test_hvac_eff_bldg1
  
    model = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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

  # Test Equipment Efficiencies for bldg_2
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg2
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["Building Story 1 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 176.0,"EfficiencyType" => "EER","Efficiency" => 11.0}
    dx_coil_hash["Building Story 2 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 314.0,"EfficiencyType" => "EER","Efficiency" => 10.0}
    dx_coil_hash["Building Story 3 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 317.0,"EfficiencyType" => "EER","Efficiency" => 10.0}
    dx_coil_hash["Building Story 4 PVAV_PFP_Boxes (Sys6) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 303.0,"EfficiencyType" => "EER","Efficiency" => 10.0}
    dx_coil_hash["Flr 1 Tenant 1 Core PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 86.0,"EfficiencyType" => "EER","Efficiency" => 11.2}
    dx_coil_hash["Flr 1 Tenant 1 East Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 13.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Flr 1 Tenant 1 North Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 44.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Flr 1 Tenant 1 South Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 40.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Flr 1 Tenant 1 West Perimeter PSZ-HP 1spd DX HP Clg Coil"] = {"CoilType" => "SingleSpeedCooling","Capacity" => 77.0,"EfficiencyType" => "SEER","Efficiency" => 14.0}
    dx_coil_hash["Flr 1 Tenant 1 Core PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 86.5,"EfficiencyType" => "COP","Efficiency" => 3.3}
    dx_coil_hash["Flr 1 Tenant 1 East Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 22.0,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Flr 1 Tenant 1 North Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 43.1,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Flr 1 Tenant 1 South Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 32.6,"EfficiencyType" => "HSPF","Efficiency" => 7.7}
    dx_coil_hash["Flr 1 Tenant 1 West Perimeter PSZ-HP HP Htg Coil"] = {"CoilType" => "SingleSpeedHeating","Capacity" => 77.1,"EfficiencyType" => "COP","Efficiency" => 3.3}
    
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
    supply_fan_hash["Flr 1 Tenant 1 West Perimeter PSZ-HP Fan"] = {"CFM" => 2903.0,"PressureDifferential" => 0}
    
    failure_array = check_variable_speed_fan_power(model, supply_fan_hash, failure_array)
    failure_array = check_constant_speed_fan_power(model, supply_fan_hash, failure_array)
    
    assert_equal(0, failure_array.length, "There were #{failure_array.length} failures:  #{failure_array.join('.  ')}")
    
  end

  # Test Equipment Efficiencies for bldg_3
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg3
  
    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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

  # Test Equipment Efficiencies for bldg_4
  # @author Matt Leach, NORESCO
  def test_hvac_eff_bldg4
  
    model = create_baseline_model('bldg_4', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
    
    # check coil efficiencies
    dx_coil_hash = {}
    dx_coil_hash["IPF Above Ground PVAV_Reheat (Sys5) Clg Coil"] = {"CoilType" => "TwoSpeedCooling","Capacity" => 3651.0,"EfficiencyType" => "EER","Efficiency" => 9.5}
  
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
  
    model = create_baseline_model('bldg_5', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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

  # Test Equipment Efficiencies for bldg_7
  # @author Matt Leach, NORESCO
  # Known failure; this test assumes that all fans should have the SP reset curve,
  # which does not make sense since SP reset is only prescriptively required
  # if there is DDC control of VAV terminals.
  def known_fail_test_hvac_eff_bldg7
  
    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2013-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
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
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5B', building_type, 'Xcel Energy CO EDA', false, true)
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
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-4B', building_type, 'Xcel Energy CO EDA', false, true)
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
    
    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
  # Known failure; this test assumes that the SWH pump in the baseline
  # will carry directly into the proposed.  While this is generally true,
  # in the baseline the motor efficiency will be set to the minimum value.
  def known_fail_test_dhw_bldg7
    
    model = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2013-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)
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
  def known_fail_test_dcv_bldg3
  
    model = create_baseline_model('bldg_3_LockerOtherDCV', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
  
    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2013-6B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
  
    model = create_baseline_model('bldg_2_NonPredominantHeating', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-1A', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5A', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
    model = create_baseline_model('bldg_2_thermostat_mod', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
    #system_sizing_test_hash["Building Story 1 PVAV_PFP_Boxes (Sys6)"] = {"Clg_Design_Temp" => ((73 - 20) - 32)/1.8,"Htg_Design_Temp" => ((73 - 20) - 32)/1.8}
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
  
    model = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
          min_flow = vav_terminal.fixedMinimumAirFlowRate
          if min_flow.is_initialized
            min_flow = min_flow.get
          else
            min_flow = 0.0
          end
          unless (expected_min_oa_rates_m3_per_s_hash[spot_check_zone_name] - min_flow).abs < 0.005
            failure_array << "Expected #{(expected_min_oa_rates_m3_per_s_hash[spot_check_zone_name]*2118.88).round()} cfm Fixed Flow Rate for Zone #{spot_check_zone_name}; found #{(vav_terminal.fixedMinimumAirFlowRate.get*2118.88).round()} cfm instead"
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
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
    failure_array = []
  
    # minimum flow fraction should be 30% and max secondary flow should be 50% of terminal size
    primary_flow_rates_m3_per_s_hash = {}
    primary_flow_rates_m3_per_s_hash["FLR 1 LOBBY"] = 0.3136
    primary_flow_rates_m3_per_s_hash["FLR 1 TENANT 2 EAST PERIMETER"] = 0.5821
    primary_flow_rates_m3_per_s_hash["FLR 1 TENANT 2 NORTH PERIMETER"] = 0.71818
    primary_flow_rates_m3_per_s_hash["FLR 2 TENANT 2 NORTH PERIMETER"] = 0.634
    primary_flow_rates_m3_per_s_hash["FLR 2 TENANT 1 CORE"] = 0.8848
  
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
  
    model = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2013-5B', 'MediumOffice', 'Xcel Energy CO EDA', false, true)
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
end
