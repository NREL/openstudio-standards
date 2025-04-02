require_relative '../../helpers/minitest_helper'

class TestRefrigerationCreateTypicalRefrigeration < Minitest::Test
  def setup
    @refrig = OpenstudioStandards::Refrigeration
  end

  def test_create_typical_refrigeration
    model = OpenStudio::Model::Model.new
    zone = OpenStudio::Model::ThermalZone.new(model)

    # default refrigeration system
    result = @refrig.create_typical_refrigeration(model)
    assert(result)
  end
end
