require_relative '../helpers/minitest_helper'

class TestApplyHVACEfficiencyStandard < Minitest::Test
  def test_pthp_90_1_2019
    test_name = 'test_pthp_90_1_2019'
    # Load model
    std = Standard.build('90.1-2019')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/models/basic_pthp_model.osm")
    building = model.getBuilding
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: 'ASHRAE 169-2013-4A')

    # Set the heating and cooling sizing parameters
    std.model_apply_prm_sizing_parameters(model)
    # Perform a sizing run
    if std.model_run_sizing_run(model, "output/#{test_name}/SR1") == false
      return false
    end
    # If there are any multizone systems, reset damper positions
    # to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    std.model_apply_multizone_vav_outdoor_air_sizing(model)
    # get the climate zone
    climate_zone_obj = model.getClimateZones.getClimateZone('ASHRAE', 2006)
    if climate_zone_obj.empty
      climate_zone_obj = model.getClimateZones.getClimateZone('ASHRAE', 2013)
    end
    climate_zone = climate_zone_obj.value
    # get the building type
    bldg_type = nil
    unless building.standardsBuildingType.empty?
      bldg_type = building.standardsBuildingType.get
    end
    # Apply the prototype HVAC assumptions
    std.model_apply_prototype_hvac_assumptions(model, bldg_type, climate_zone)

    model.getCoilHeatingDXSingleSpeeds.each do |coil|
      # find ac properties
      search_criteria = std.coil_dx_find_search_criteria(coil, true)
      sub_category = search_criteria['subcategory']
      suppl_heating_type = search_criteria['heating_type']
      capacity_w = std.coil_heating_dx_single_speed_find_capacity(coil, true)
      capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
      capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get
      ac_props = std.model_find_object(std.standards_data['heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)
      # puts "#{coil.name} #{capacity_btu_per_hr}"
      # puts ac_props
    end

    # Apply the HVAC efficiency standard
    std.model_apply_hvac_efficiency_standard(model, climate_zone)
  end

  def test_efficiency_conversions
    std = Standard.build('90.1-2019')
    # SEER conversions
    seer = 15
    cop_nf = std.seer_to_cop_no_fan(seer)
    new_seer = std.cop_no_fan_to_seer(cop_nf)
    assert(seer == new_seer)

    # COP conversions
    cop = std.seer_to_cop(seer)
    new_seer = std.cop_to_seer(cop)
    assert(seer == new_seer)

    # EER conversions
    eer = 11
    cop_nf = std.eer_to_cop_no_fan(eer)
    cop = std.eer_to_cop(eer)
    new_err = std.cop_no_fan_to_eer(cop_nf)
    assert(cop_nf > cop)
    assert(new_err == eer)

    # HSPF conversions
    hspf = 9
    cop_nf = std.hspf_to_cop_no_fan(hspf)
    cop = std.hspf_to_cop(hspf)
    assert(cop_nf > cop)

    # kW/ton conversions
    cop = 5
    kwpton = std.cop_to_kw_per_ton(5)
    new_cop = std.kw_per_ton_to_cop(kwpton)
    assert(cop == new_cop)

    # AFUE conversions
    afue = 0.93
    te = std.afue_to_thermal_eff(afue)
    new_afue = std.thermal_eff_to_afue(te)
    assert (afue == new_afue)

    # Combustion efficiency conversions
    tc = 0.8
    te = std.combustion_eff_to_thermal_eff(tc)
    new_tc = std.thermal_eff_to_comb_eff(te)
    assert(tc == new_tc)
  end

  def test_unitary_ac_eff_lookups
      test_name = 'unitary_ac_eff_lookups'
      model = OpenStudio::Model::Model.new
      coil_cooling_dx_single_speed = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)
      coil_cooling_dx_single_speed.setRatedTotalCoolingCapacity(10000 / 3.412) #10 kBtu/h
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      heating_coil = OpenStudio::Model::CoilHeatingGas.new(model)
      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model, model.alwaysOnDiscreteSchedule, fan, heating_coil, coil_cooling_dx_single_speed)
      unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      
      # PTAC
      std = Standard.build('90.1-2019')
      cop = std.coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false, false, true)
      assert cop.round(2) == std.eer_to_cop_no_fan(14 - 0.3 * 10).round(2)

      std = Standard.build('90.1-2004')
      cop = std.coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false, false, true)
      assert cop.round(2) == std.eer_to_cop_no_fan(12.5 - 0.213 * 10).round(2)

      # Single-speed Unitary AC
      ptac.remove()
      coil_cooling_dx_single_speed = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)
      coil_cooling_dx_single_speed.setRatedTotalCoolingCapacity(10000 / 3.412) #10 kBtu/h
      unitary.setCoolingCoil(coil_cooling_dx_single_speed)
      std = Standard.build('90.1-2019')
      cop = std.coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false, false, true)
      assert cop.round(2) == std.seer_to_cop_no_fan(13.4).round(2)

      coil_cooling_dx_single_speed.setRatedTotalCoolingCapacity(780000 / 3.412) #780 kBtu/h
      cop = std.coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false, false, true)
      assert cop.round(2) == std.ieer_to_cop_no_fan(12.5).round(2)

      std = Standard.build('90.1-2004')
      cop = std.coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false, false, true)
      assert cop.round(2) == std.eer_to_cop_no_fan(9.2).round(2)

      coil_cooling_dx_single_speed.setRatedTotalCoolingCapacity(10000 / 3.412) #10 kBtu/h
      cop = std.coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false, false, true)
      assert cop.round(2) == std.seer_to_cop_no_fan(12).round(2)

      # Two-speed Unitary AC
      unitary_2 = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      coil_cooling_dx_two_speed = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model)
      coil_cooling_dx_two_speed.setRatedHighSpeedTotalCoolingCapacity(780000 / 3.412) #780 kBtu/h
      unitary_2.setCoolingCoil(coil_cooling_dx_two_speed)
      cop = std.coil_cooling_dx_two_speed_standard_minimum_cop(coil_cooling_dx_two_speed)
      assert cop.round(2) == std.eer_to_cop_no_fan(9.2).round(2)

      # Multi-speed Unitary AC
      unitary_3 = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      coil_cooling_dx_multi_speed = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      stage_1.setGrossRatedTotalCoolingCapacity(780000 / 3.412) #780 kBtu/h
      coil_cooling_dx_multi_speed.setStages([stage_1])
      unitary_3.setCoolingCoil(coil_cooling_dx_multi_speed)
      cop, new_name = std.coil_cooling_dx_multi_speed_standard_minimum_cop(coil_cooling_dx_multi_speed)
      assert cop.round(2) == std.eer_to_cop_no_fan(9.2).round(2)
  end
end