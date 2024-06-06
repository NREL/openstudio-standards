require_relative '../helpers/minitest_helper'

class ACM179dASHRAE9012007Test < Minitest::Test

  @@logSink = nil

  def suite_init
    OpenStudio::Logger.instance.standardOutLogger.disable
    sink = OpenStudio::StringStreamLogSink.new
    sink.setLogLevel(OpenStudio::Warn)
    sink
  end

  attr_accessor :template, :standard, :model
  def setup
    @@logSink ||= suite_init
    @@logSink.resetStringStream

    @template = '179D 90.1-2007'
    @standard = Standard.build(@template)

    model = OpenStudio::Model::exampleModel
    model.getSpaceTypes.map(&:remove)

    spaces = model.getSpaces.sort_by(&:nameString)

    wh_bulk = OpenStudio::Model::SpaceType.new(model)
    wh_bulk.setStandardsBuildingType('Warehouse')
    wh_bulk.setStandardsSpaceType('Bulk')
    spaces[0].setSpaceType(wh_bulk)
    spaces[1].setSpaceType(wh_bulk)

    wh_office = OpenStudio::Model::SpaceType.new(model)
    wh_office.setStandardsBuildingType('Warehouse')
    wh_office.setStandardsSpaceType('Office')
    spaces[2].setSpaceType(wh_bulk)

    retail_pt_sale = OpenStudio::Model::SpaceType.new(model)
    retail_pt_sale.setStandardsBuildingType('Retail')
    retail_pt_sale.setStandardsSpaceType('Point_of_Sale')
    spaces[3].setSpaceType(retail_pt_sale)
    @model = model
  end

  def log_errors
    @@logSink.logMessages.select{ |l| l.logLevel == OpenStudio::Error }.map(&:logMessage)
  end

  def log_warnings
    @@logSink.logMessages.select{ |l| l.logLevel == OpenStudio::Warn }.map(&:logMessage)
  end


  def test_model_get_primary_building_type
    assert_equal('Warehouse', @standard.model_get_primary_building_type(@model))

    # Avoid the memoization by calling the static method instead
    # Space Type area method is prefered
    @model.getBuilding.setStandardsBuildingType("Office")
    assert_equal('Warehouse', @standard.__model_get_primary_building_type(@model))
    assert_equal(0, log_errors.size)
    assert_equal(1, log_warnings.size)
    assert_match(
      /The Building has standardsBuildingType 'Office' while the area determination based on space types has 'Warehouse'. Preferring the Space Type one/,
      log_warnings.first,
    )
    @@logSink.resetStringStream


    # When Space Type area not found, use building
    @model.getSpaceTypes.each(&:resetStandardsBuildingType)
    assert_equal('Office', @standard.__model_get_primary_building_type(@model))

    # When neither: it throws
    @model.getBuilding.resetStandardsBuildingType
    assert_raises(RuntimeError, 'No Primary Building Type found') { @standard.__model_get_primary_building_type(@model) }
    assert_equal(1, log_errors.size)
    assert_equal(0, log_warnings.size)
    assert_equal("Cannot identify a single building type in model, none of your 3 SpaceTypes have a standardsBuildingType assigned and neither does the Building",
                 log_errors.first)
  end

  def test_model_get_standards_data
    assert_equal('Warehouse', standard.model_get_primary_building_type(model))

    data = standard.model_get_standards_data(model)
    assert_equal('179d-90.1-2007', data['template'])
    assert_equal('Warehouse', data['building_type'])
    assert_equal('WholeBuilding', data['space_type'])
    assert_equal('ASHRAE 90.1-2007', data['lighting_standard'])
    assert_equal('WholeBuilding', data['lighting_primary_space_type'])
    assert_equal('Warehouse', data['lighting_secondary_space_type'])
    assert_equal('Nonres_HVAC_Sch', data['hvac_operation_schedule'])
  end

  def test_space_type_get_standards_data
    assert_equal('Warehouse', standard.model_get_primary_building_type(model))

    model.getSpaceTypes.each do |space_type|
      data = standard.space_type_get_standards_data(space_type)
      assert_equal('179d-90.1-2007', data['template'])
      assert_equal('Warehouse', data['building_type'])
      assert_equal('WholeBuilding', data['space_type'])
      assert_equal('ASHRAE 90.1-2007', data['lighting_standard'])
      assert_equal('WholeBuilding', data['lighting_primary_space_type'])
      assert_equal('Warehouse', data['lighting_secondary_space_type'])
    end

    space_type = model.getSpaceTypes.select { |sp| sp.standardsSpaceType.get == 'Bulk' }.first

    data_only_179d = standard.space_type_get_standards_data(space_type, extend_with_2007: false)
    assert_empty(data_only_179d.select{|k, _| ['ventilation', 'exhaust'].any? { |x| k.include?(x) } })

    std_2007 = Standard.build('90.1-2007')
    data2007 = std_2007.space_type_get_standards_data(space_type)
    refute_empty(data2007.select{|k, _| ['ventilation', 'exhaust'].any? { |x| k.include?(x) } })

    # This is the merged data
    data = standard.space_type_get_standards_data(space_type)
    refute_empty(data.select{|k, _| ['ventilation', 'exhaust'].any? { |x| k.include?(x) } })

    # All keys from 2007 and in our
    assert_empty(data2007.keys - data.keys)

    assert_includes(data.keys, 'space_type_2007')
    enhanced_keys = data.keys - data_only_179d.keys - ['space_type_2007']
    refute_empty(enhanced_keys)
    assert_equal(25, enhanced_keys.size)

    # Ensure all keys defined specifically in 179D are left untouched
    data_only_179d.keys.each do |k|
      if data_only_179d[k].nil?
        assert_nil(data[k])
      else
        assert_equal(data_only_179d[k], data[k])
      end
    end
    # Ensure all enhanced keys are directly from 2007
    enhanced_keys.each do |k|
      if data2007[k].nil?
        assert_nil(data[k])
      else
        assert_equal(data2007[k], data[k])
      end
    end

    assert_equal('179d-90.1-2007', data['template'])
    assert_equal('Warehouse', data['building_type'])
    assert_equal('WholeBuilding', data['space_type'])
    assert_equal('Bulk', data['space_type_2007'])

    assert_equal('ASHRAE 90.1-2007', data['lighting_standard'])
    assert_equal('WholeBuilding', data['lighting_primary_space_type'])
    assert_equal('Warehouse', data['lighting_secondary_space_type'])
    assert_in_delta(0.8, data['lighting_per_area'])
    assert_nil(data['rcr_threshold'])
    assert_nil(data['lighting_per_person'])
    assert_nil(data['additional_lighting_per_area'])
    assert_in_delta(0.0, data['lighting_fraction_to_return_air'])
    assert_in_delta(0.42, data['lighting_fraction_radiant'])
    assert_in_delta(0.18, data['lighting_fraction_visible'])
    assert_in_delta(1.0, data['lighting_fraction_replaceable'])
    assert_in_delta(1.0, data['lpd_fraction_linear_fluorescent'])
    assert_nil(data['lpd_fraction_compact_fluorescent'])
    assert_nil(data['lpd_fraction_high_bay'])
    assert_nil(data['lpd_fraction_specialty_lighting'])
    assert_nil(data['lpd_fraction_exit_lighting'])
    assert_equal('Nonres_Light_Sch', data['lighting_schedule'])
    assert_nil(data['compact_fluorescent_lighting_schedule'])
    assert_nil(data['high_bay_lighting_schedule'])
    assert_nil(data['specialty_lighting_schedule'])
    assert_nil(data['exit_lighting_schedule'])
    assert_nil(data['target_illuminance_setpoint'])
    assert_nil(data['psa_nongeometry_fraction'])
    assert_nil(data['ssa_nongeometry_fraction'])
    assert_nil(data['notes'])
    assert_nil(data['gas_equipment_per_area'])
    assert_nil(data['gas_equipment_fraction_latent'])
    assert_nil(data['gas_equipment_fraction_radiant'])
    assert_nil(data['gas_equipment_fraction_lost'])
    assert_nil(data['gas_equipment_schedule'])
    assert_in_delta(0.43, data['electric_equipment_per_area'])
    assert_in_delta(0.0, data['electric_equipment_fraction_latent'])
    assert_in_delta(0.5, data['electric_equipment_fraction_radiant'])
    assert_in_delta(0.0, data['electric_equipment_fraction_lost'])
    assert_equal('Nonres_Equip_Sch', data['electric_equipment_schedule'])
    assert_nil(data['additional_electric_equipment_schedule'])
    assert_nil(data['additional_gas_equipment_schedule'])
    assert_in_delta(5.0, data['occupancy_per_area'])
    assert_equal('Nonres_Occ_Sch', data['occupancy_schedule'])
    assert_equal('ACM_Warehouse_ACTIVITY_SCH', data['occupancy_activity_schedule'])
    assert_nil(data['is_residential'])

    assert_in_delta(0.038, data['infiltration_per_exterior_area'])
    assert_nil(data['infiltration_per_exterior_wall_area'])
    assert_nil(data['infiltration_air_changes'])
    assert_equal('Nonres_Infil_Sch', data['infiltration_schedule'])
    assert_nil(data['infiltration_schedule_perimeter'])
    assert_equal('Nonres_Heat_Sch', data['heating_setpoint_schedule'])
    assert_equal('Warehouse_Cool_Sch', data['cooling_setpoint_schedule'])
    assert_nil(data['service_water_heating_peak_flow_rate'])
    assert_nil(data['service_water_heating_area'])
    assert_in_delta(0.0007, data['service_water_heating_peak_flow_per_area'])
    assert_nil(data['service_water_heating_system_type'])
    assert_nil(data['booster_water_heater_fraction'])
    assert_in_delta(140.0, data['service_water_heating_target_temperature'])
    assert_nil(data['booster_water_heating_target_temperature'])
    assert_nil(data['service_water_heating_fraction_sensible'])
    assert_nil(data['service_water_heating_fraction_latent'])
    assert_equal('Nonres_SWH_Sch', data['service_water_heating_schedule'])

    # Enhanced from 2007, based on actual Space Type
    assert_equal('ASHRAE 62.1-2004', data['ventilation_standard'])
    assert_equal('Miscellaneous Spaces', data['ventilation_primary_space_type'])
    assert_equal('Warehouses', data['ventilation_secondary_space_type'])
    assert_in_delta(0.06, data['ventilation_per_area'])
    assert_nil(data['ventilation_per_person'])
    assert_nil(data['ventilation_air_changes'])
    assert_nil(data['minimum_total_air_changes'])

    assert_nil(data['manual_continuous_dimming'])
    assert_nil(data['programmable_multilevel_dimming'])
    assert_nil(data['multilevel_occupancy_sensors'])
    assert_nil(data['occupancy_sensors'])
    assert_nil(data['occupancy_sensors_with_personal_continuous_dimming'])
    assert_nil(data['automatic_multilevel_switching_in_primary_sidelighted_areas'])
    assert_nil(data['automatic_continuous_daylight_dimming_in_primary_sidelighted_areas'])
    assert_nil(data['automatic_continuous_daylight_dimming_in_secondary_sidelighted_areas'])
    assert_nil(data['automatic_continuous_daylight_dimming_in_daylighted_areas_under_skylights'])
    assert_nil(data['exhaust_per_area'])
    assert_nil(data['exhaust_fan_efficiency'])
    assert_nil(data['exhaust_fan_power'])
    assert_nil(data['exhaust_fan_pressure_rise'])
    assert_nil(data['exhaust_fan_maximum_flow_rate'])
    assert_nil(data['exhaust_availability_schedule'])
    assert_nil(data['exhaust_flow_fraction_schedule'])
    assert_nil(data['balanced_exhaust_fraction_schedule'])
    assert_equal('41_31_169', data['rgb'])
  end

  TEST_BASELINE_SYS_NUM_DATA = [
      # area_type, area_ft2, num_stories, expected
      ['residential', 24_999, 1, '1_or_2'],
      ['residential', 24_999, 10, '1_or_2'],

      ['nonresidential', 24_900, 3, '3_or_4'],

      ['nonresidential', 24_900, 4, '5_or_6'],
      ['nonresidential', 24_900, 5, '5_or_6'],
      ['nonresidential', 75_000, 4, '5_or_6'],
      ['nonresidential', 75_900, 5, '5_or_6'],

      ['nonresidential', 24_900, 10, '7_or_8'],
      ['nonresidential', 150_001, 1, '7_or_8'],
      ['nonresidential', 150_001, 10, '7_or_8'],

      ['heatedonly', 24_900, 1, '9_or_10'],
      ['heatedonly', 150_001, 1, '9_or_10'],
      ['heatedonly', 150_001, 10, '9_or_10'],
  ]
  TEST_BASELINE_SYS_NUM_DATA.each do |area_type, area_ft2, num_stories, expected_system_number|
    define_method("test_model_prm_baseline_system_number_#{area_type}_#{area_ft2.to_i}sqft_#{num_stories}floors") do
      _model = nil
      _climate_zone = nil
      _fuel_type = nil
      custom = ''

      assert_equal(expected_system_number, @standard.model_prm_baseline_system_number(_model, _climate_zone, area_type, _fuel_type, area_ft2, num_stories, custom))
    end
  end

  def test_zone_hvac_component_apply_standard_controls
    fan = OpenStudio::Model::FanSystemModel.new(model)
    heating_coil = OpenStudio::Model::CoilHeatingWater.new(model)
    cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model)
    four_pipe_fan_coil = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, model.alwaysOnDiscreteSchedule, fan, cooling_coil, heating_coil)
    four_pipe_fan_coil.addToThermalZone(model.getThermalZones.first)

    assert_empty(four_pipe_fan_coil.supplyAirFanOperatingModeSchedule)

    four_pipe_fan_coil.setMaximumOutdoorAirFlowRate(0.0)
    standard.zone_hvac_component_apply_standard_controls(four_pipe_fan_coil.to_ZoneHVACComponent.get)
    assert_empty(four_pipe_fan_coil.supplyAirFanOperatingModeSchedule)

    four_pipe_fan_coil.autosizeMaximumOutdoorAirFlowRate
    assert_empty(four_pipe_fan_coil.maximumOutdoorAirFlowRate)
    assert four_pipe_fan_coil.isMaximumOutdoorAirFlowRateAutosized
    standard.zone_hvac_component_apply_standard_controls(four_pipe_fan_coil.to_ZoneHVACComponent.get)
    refute_empty(four_pipe_fan_coil.supplyAirFanOperatingModeSchedule)

    four_pipe_fan_coil.resetSupplyAirFanOperatingModeSchedule
    four_pipe_fan_coil.setMaximumOutdoorAirFlowRate(0.1)
    standard.zone_hvac_component_apply_standard_controls(four_pipe_fan_coil.to_ZoneHVACComponent.get)
    refute_empty(four_pipe_fan_coil.supplyAirFanOperatingModeSchedule)
  end
end
