require_relative '../helpers/minitest_helper'

class TestResetEquipment < Minitest::Test
    
  def test_reset_equipment
    
    initial_template = 'ComStock DOE Ref Pre-1980'
    standard = Standard.build(initial_template)

    # make an empty model
    model = OpenStudio::Model::Model.new
    model.getBuilding.setStandardsBuildingType('Outpatient')

    # make a spacetype 
    st = OpenStudio::Model::SpaceType.new(model)
    st.setStandardsSpaceType('Toilet')
    st.setName("Outpatient Toilet - #{initial_template}")
    # set initial electric equipment
    standard.space_type_apply_internal_loads(st, false, false, true, false, false, false)

    definition = st.electricEquipment.first.electricEquipmentDefinition
    assert_equal(0.3, definition.fractionRadiant)
    assert_equal(0.7, definition.fractionLost)
    # new standard
    standard = Standard.build('ComStock 90.1-2013')
    # re-set equipment with different load fractions
    assert(standard.space_type_apply_internal_loads(st, false, false, true, false, false, false))
    definition = st.electricEquipment.first.electricEquipmentDefinition
    assert_equal(0.5, definition.fractionRadiant)
    assert_equal(0.0, definition.fractionLost)

    # no error thrown
    logs = get_logs
    logs.each do |str|
      refute_match(/Latent Fraction and Lost Fraction sum to 0.7 and you supplied a Radiant Fraction of 0.5 which would result in a sum greater than 1.0/, str, "Error thrown resetting equipment load components")
    end
  end
end