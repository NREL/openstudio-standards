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
    assert_equal('Warehouse', ACM179dASHRAE9012007.__model_get_primary_building_type(@model))
    assert_equal(0, log_errors.size)
    assert_equal(1, log_warnings.size)
    assert_match(
      /The Building has standardsBuildingType 'Office' while the area determination based on space types has 'Warehouse'. Preferring the Space Type one/,
      log_warnings.first,
    )
    @@logSink.resetStringStream


    # When Space Type area not found, use building
    @model.getSpaceTypes.each(&:resetStandardsBuildingType)
    assert_equal('Office', ACM179dASHRAE9012007.__model_get_primary_building_type(@model))

    # When neither: it throws
    @model.getBuilding.resetStandardsBuildingType
    assert_raises(RuntimeError, 'No Primary Building Type found') { ACM179dASHRAE9012007.__model_get_primary_building_type(@model) }
    assert_equal(1, log_errors.size)
    assert_equal(0, log_warnings.size)
    assert_equal("Cannot identify a single building type in model, none of your 3 SpaceTypes have a standardsBuildingType assigned and neither does the Building",
                 log_errors.first)
  end


  def test_space_type_get_standards_data
    assert_equal('Warehouse', standard.model_get_primary_building_type(model))

    model.getSpaceTypes.each do |space_type|
      data = standard.space_type_get_standards_data(space_type)
      assert_equal('179d-90.1-2007', data['template'])
      assert_equal('Warehouse', data['building_type'])
      assert_equal('WholeBuilding', data['space_type'])
      assert_equal('ASHRAE 90.1-2007', data['lighting_standard'])
      assert_equal('Whole Building', data['lighting_primary_space_type'])
      assert_equal('Warehouse', data['lighting_secondary_space_type'])
    end

    data = standard.space_type_get_standards_data(model.getSpaceTypes.first)
    assert_equal('179d-90.1-2007', data['template'])
    assert_equal('Warehouse', data['building_type'])
    assert_equal('WholeBuilding', data['space_type'])
    assert_equal('ASHRAE 90.1-2007', data['lighting_standard'])
    assert_equal('Whole Building', data['lighting_primary_space_type'])
    assert_equal('Warehouse', data['lighting_secondary_space_type'])
    assert_in_delta(0.8, data['lighting_per_area'])
    assert_nil(data['rcr_threshold'])
    assert_nil(data['lighting_per_person'])
    assert_nil(data['additional_lighting_per_area'])
    assert_equal(0, data['lighting_fraction_to_return_air'])
    assert_in_delta(0.42, data['lighting_fraction_radiant'])
    assert_in_delta(0.18, data['lighting_fraction_visible'])
    assert_equal(1, data['lighting_fraction_replaceable'])
    assert_equal(1, data['lpd_fraction_linear_fluorescent'])
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
    assert_equal(0, data['electric_equipment_fraction_latent'])
    assert_in_delta(0.5, data['electric_equipment_fraction_radiant'])
    assert_equal(0, data['electric_equipment_fraction_lost'])
    assert_equal('Nonres_Equip_Sch', data['electric_equipment_schedule'])
    assert_nil(data['additional_electric_equipment_schedule'])
    assert_nil(data['additional_gas_equipment_schedule'])
    assert_equal(5, data['occupancy_per_area'])
    assert_equal('Nonres_Occ_Sch', data['occupancy_schedule'])
    assert_equal('Warehouse Office Activity Schedule', data['occupancy_activity_schedule'])
    assert_nil(data['is_residential'])
  end

end
