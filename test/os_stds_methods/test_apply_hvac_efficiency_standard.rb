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

  def test_vrf_90_1_2019
    test_name = 'test_vrf_90_1_2019'
    # Load model
    std = Standard.build('90.1-2019')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../90_1_prm/models/bldg_20.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: 'ASHRAE 169-2013-4A')

    # Perform a sizing run
    if std.model_run_sizing_run(model, File.join(File.dirname(__FILE__),"output/#{test_name}/SR1")) == false
      return false
    end

    # Apply the HVAC efficiency standard
    std.model_apply_hvac_efficiency_standard(model, 'ASHRAE 169-2013-4A')
    model.save(File.join(File.dirname(__FILE__),"output/#{test_name}.osm"), true)

    # Spot check expected efficiencies
    vrfs = model.getAirConditionerVariableRefrigerantFlows
    assert vrfs[0].name.to_s.include?('11EER')
    assert vrfs[-1].name.to_s.include?('10.6EER')
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
end