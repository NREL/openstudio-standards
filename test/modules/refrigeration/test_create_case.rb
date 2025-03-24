require_relative '../../helpers/minitest_helper'

class TestRefrigerationCreateCase < Minitest::Test
  def setup
    @refrig = OpenstudioStandards::Refrigeration
  end

  def test_create_case
    model = OpenStudio::Model::Model.new
    zone = OpenStudio::Model::ThermalZone.new(model)

    # default case
    case1 = @refrig.create_case(model)
    assert_equal(2.4, case1.caseLength)
    assert_in_delta(0.6, case1.caseOperatingTemperature, 0.1)

    # old case
    case2 = @refrig.create_case(model,
                                template: 'old',
                                operation_type: 'MT',
                                thermal_zone: zone)
    assert_equal(2.4, case2.caseLength)
    assert_in_delta(0.6, case2.caseOperatingTemperature, 0.1)

    # advanced case
    case3 = @refrig.create_case(model,
                                template: 'advanced',
                                operation_type: 'LT',
                                case_type: 'Coffin - Frozen Food',
                                thermal_zone: zone)
    assert_equal(2.2, case3.caseLength)
    assert_in_delta(-23.3, case3.caseOperatingTemperature, 0.1)
  end
end
