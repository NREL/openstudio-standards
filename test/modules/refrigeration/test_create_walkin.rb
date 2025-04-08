require_relative '../../helpers/minitest_helper'

class TestRefrigerationCreateWalkIn < Minitest::Test
  def setup
    @refrig = OpenstudioStandards::Refrigeration
  end

  def test_create_walkin
    model = OpenStudio::Model::Model.new
    zone = OpenStudio::Model::ThermalZone.new(model)

    # default walkin
    walkin1 = @refrig.create_walkin(model)

    # old walkin
    walkin2 = @refrig.create_walkin(model,
                                    template: 'old',
                                    thermal_zone: zone)

    # new walkin
    walkin3 = @refrig.create_walkin(model,
                                    template: 'new',
                                    walkin_type: 'Walk-in Freezer - 480SF',
                                    thermal_zone: zone)

    # advanced walkin
    walkin4 = @refrig.create_walkin(model,
                                    template: 'advanced',
                                    walkin_type: 'Walk-in Freezer - 240SF',
                                    thermal_zone: zone)
  end
end
