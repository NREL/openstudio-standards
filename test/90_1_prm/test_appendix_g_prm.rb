require_relative '../helpers/minitest_helper'
require_relative './prm_check'
require_relative './prm_test_model_generator'
# Test suite for the ASHRAE 90.1 appendix G Performance
# Rating Method (PRM) baseline automation implementation
# in openstudio-standards.
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMTests < Minitest::Test
  def test_baseline_oa
    model_hash = prm_test_helper('baseline_outdoor_air', require_prototype = false, require_baseline = true)
    check_baseline_oa(model_hash['baseline'])
  end

  def test_building_rotation_check
    model_hash = prm_test_helper('building_rotation_check', require_prototype = false, require_baseline = true)
    check_building_rotation_exception(model_hash['baseline'], 'building_rotation_check')
  end

  def test_computer_rooms_equipment_schedule
    model_hash = prm_test_helper('computer_rooms_equipment_schedule', require_prototype = false, require_baseline = true, require_proposed = true)

    check_computer_rooms_equipment_schedule(model_hash['baseline'])
    check_computer_rooms_equipment_schedule(model_hash['proposed'])
  end

  def test_daylighting_control
    model_hash = prm_test_helper('daylighting_control', require_prototype = false, require_baseline = true)
    check_daylighting_control(model_hash['baseline'])
  end

  def test_dcv_01
    model_hash = prm_test_helper('dcv_01', require_prototype = false, require_baseline = true)
    check_dcv(model_hash['baseline'])
  end

  def test_dcv_02
    model_hash = prm_test_helper('dcv_02', require_prototype = false, require_baseline = true)
    check_dcv(model_hash['baseline'])
  end

  def test_economizer_exception
    model_hash = prm_test_helper('economizer_exception', require_prototype = false, require_baseline = true)
    check_economizer_exception(model_hash['baseline'])
  end

  def test_elevators
    model_hash = prm_test_helper('elevators', require_prototype = false, require_baseline = true)
    check_elevators(model_hash['baseline'])
  end

  def test_envelope
    model_hash = prm_test_helper('envelope', require_prototype = false, require_baseline = true)
    check_envelope(model_hash['baseline'])
  end

  def test_exhaust_air_energy
    model_hash = prm_test_helper('exhaust_air_energy', require_prototype = false, require_baseline = true)
    check_exhaust_air_energy(model_hash['baseline'])
  end

  def test_exterior_lighting
    model_hash = prm_test_helper('exterior_lighting', require_prototype = false, require_baseline = true)
    check_exterior_lighting(model_hash['baseline'])
  end

  def test_fan_power_credits
    model_hash = prm_test_helper('fan_power_credits', require_prototype = false, require_baseline = true)
    check_fan_power_credits(model_hash['baseline'])
  end

  def test_f_c_factors
    model_hash = prm_test_helper('f_c_factors', require_prototype = false, require_baseline = true)
    check_f_c_factors(model_hash['baseline'])
  end

  def test_hvac_baseline_01
    model_hash = prm_test_helper('hvac_baseline_01', require_prototype = false, require_baseline = true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_02
    model_hash = prm_test_helper('hvac_baseline_02', require_prototype = false, require_baseline = true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_03
    model_hash = prm_test_helper('hvac_baseline_03', require_prototype = false, require_baseline = true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_04
    model_hash = prm_test_helper('hvac_baseline_04', require_prototype = false, require_baseline = true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_baseline_05
    model_hash = prm_test_helper('hvac_baseline_05', require_prototype = false, require_baseline = true)
    check_hvac(model_hash['baseline'])
  end

  def test_hvac_efficiency
    model_hash = prm_test_helper('hvac_efficiency', require_prototype = false, require_baseline = true)
    check_hvac_efficiency(model_hash['baseline'])
  end

  def test_hvac_psz_split_from_mz
    model_hash = prm_test_helper('hvac_psz_split_from_mz', require_prototype = false, require_baseline = true)
    check_psz_split_from_mz(model_hash['baseline'])
  end

  def test_hvac_sizing_01
    model_hash = prm_test_helper('hvac_sizing_01', require_prototype = false, require_baseline = true)
    check_hvac_sizing(model_hash['baseline'])
  end

  def test_hvac_sizing_02
    model_hash = prm_test_helper('hvac_sizing_02', require_prototype = false, require_baseline = true)
    check_hvac_sizing(model_hash['baseline'])
  end

  def test_hvac_sizing_03
    model_hash = prm_test_helper('hvac_sizing_03', require_prototype = false, require_baseline = true)
    check_hvac_sizing(model_hash['baseline'])
  end

  def test_infiltration
    model_hash = prm_test_helper('infiltration', require_prototype = true, require_baseline = true, require_proposed = true)
    check_infiltration(model_hash['prototype'], model_hash['baseline'], 'baseline')
    check_infiltration(model_hash['prototype'], model_hash['proposed'], 'proposed')
  end

  def test_isresidential
    model_hash = prm_test_helper('isresidential', require_prototype = false, require_baseline = true)
    check_residential_flag(model_hash['baseline'])
  end

  def test_lighting_exceptions
    model_hash = prm_test_helper('lighting_exceptions', require_prototype = false, require_baseline = true)
    check_lighting_exceptions(model_hash['baseline'])
  end

  def test_light_occ_sensor
    model_hash = prm_test_helper('light_occ_sensor', require_prototype = true, require_baseline = true)
    check_light_occ_sensor(model_hash['prototype'], model_hash['baseline'])
  end

  def test_lpd
    model_hash = prm_test_helper('lpd', require_prototype = false, require_baseline = true)
    check_lpd(model_hash['baseline'])
  end

  def test_lpd_userdata_handling
    model_hash = prm_test_helper('lpd_userdata_handling', require_prototype = false, require_baseline = true)
    check_multi_lpd_handling(model_hash['baseline'])
  end

  def test_multi_bldg_handling
    model_hash = prm_test_helper('multi_bldg_handling', require_prototype = false, require_baseline = true)
    check_multi_bldg_handling(model_hash['baseline'])
  end

  def test_night_cycle_exception
    model_hash = prm_test_helper('night_cycle_exception', require_prototype = false, require_baseline = true)
    check_nightcycle_exception(model_hash['baseline'])
  end

  def test_number_of_boilers
    model_hash = prm_test_helper('number_of_boilers', require_prototype = false, require_baseline = true)
    check_number_of_boilers(model_hash['baseline'])
  end

  def test_number_of_chillers
    model_hash = prm_test_helper('number_of_chillers', require_prototype = false, require_baseline = true)
    check_number_of_chillers(model_hash['baseline'])
  end

  def test_number_of_cooling_towers
    model_hash = prm_test_helper('number_of_cooling_towers', require_prototype = false, require_baseline = true)
    check_number_of_cooling_towers(model_hash['baseline'])
  end

  def test_num_systems_in_zone
    model_hash = prm_test_helper('number_of_systems_in_zone', require_prototype = false, require_baseline = true)
    check_num_systems_in_zone(model_hash['baseline'])
  end

  def test_pe_userdata_handling
    model_hash = prm_test_helper('pe_userdata_handling', require_prototype = false, require_baseline = true)
    check_power_equipment_handling(model_hash['baseline'])
  end

  def test_pipe_insulation
    model_hash = prm_test_helper('pipe_insulation', require_prototype = false, require_baseline = true, require_proposed = true)
    check_pipe_insulation(model_hash['baseline'])
    check_pipe_insulation(model_hash['proposed'])
  end

  def test_plant_temp_reset_ctrl_01
    model_hash = prm_test_helper('plant_temp_reset_ctrl_01', require_prototype = false, require_baseline = true)
    check_hw_chw_reset(model_hash['baseline'])
  end

  def test_plant_temp_reset_ctrl_02
    model_hash = prm_test_helper('plant_temp_reset_ctrl_02', require_prototype = false, require_baseline = true)
    check_hw_chw_reset(model_hash['baseline'])
  end

  def test_preheat_coil_ctrl
    model_hash = prm_test_helper('preheat_coil_ctrl', require_prototype = false, require_baseline = true)
    check_preheat_coil_ctrl(model_hash['baseline'])
  end

  def test_proposed_model_residential_lpd
    model_hash = prm_test_helper('proposed_model_residential_lpd', require_prototype = false, require_baseline = false, require_proposed = true)
    check_residential_lpd(model_hash['proposed'])
  end

  def test_return_air_type
    model_hash = prm_test_helper('return_air_type', require_prototype = false, require_baseline = true)
    check_return_air_type(model_hash['baseline'])
  end

  def test_sat_ctrl
    model_hash = prm_test_helper('sat_ctrl', require_prototype = false, require_baseline = true)
    check_sat_ctrl(model_hash['baseline'])
  end

  def test_srr
    model_hash = prm_test_helper('srr', require_prototype = false, require_baseline = true)
    check_srr(model_hash['baseline'])
  end

  def test_unenclosed_spaces
    model_hash = prm_test_helper('unenclosed_spaces', require_prototype = false, require_baseline = true)
    check_unenclosed_spaces(model_hash['baseline'])
  end

  def test_unmet_load_hours
    model_hash = prm_test_helper('unmet_load_hours', require_prototype = false, require_baseline = true)
    check_unmet_load_hours(model_hash['baseline'])
  end

  def test_vav_fan_curve
    model_hash = prm_test_helper('vav_fan_curve', require_prototype = false, require_baseline = true)
    check_variable_speed_fan_power(model_hash['baseline'])
  end

  def test_vav_min_sp
    model_hash = prm_test_helper('vav_min_sp', require_prototype = false, require_baseline = true)
    check_vav_min_sp(model_hash['baseline'])
  end

  def test_wwr
    model_hash = prm_test_helper('wwr', require_prototype = false, require_baseline = true)
    check_wwr(model_hash['baseline'])
  end
end

