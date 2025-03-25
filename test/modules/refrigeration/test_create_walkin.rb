require_relative '../../helpers/minitest_helper'

class TestRefrigerationWalkIn < Minitest::Test
  def setup
    @refrig = OpenstudioStandards::Refrigeration
  end

  def test_create_walkin
    model = OpenStudio::Model::Model.new
    zone = OpenStudio::Model::ThermalZone.new(model)

    # default case
    case1 = @refrig.create_walkin(model)

    # old case
    case2 = @refrig.create_walkin(model,
                                  template: 'old',
                                  operation_type: 'MT',
                                  thermal_zone: zone)

    # advanced case
    case3 = @refrig.create_walkin(model,
                                  template: 'advanced',
                                  operation_type: 'LT',
                                  walkin_type: 'Walk-in Freezer - 240SF',
                                  thermal_zone: zone)
  end
end
