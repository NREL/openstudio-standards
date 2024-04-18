require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'

class ACM179dASHRAE9012007BaselineBuildingTest < Minitest::Test

  def test_179d_warehouse

    model_name = 'Warehouse_5A'
    standard = '179D 90.1-2007'
    climate_zone = 'ASHRAE 169-2013-5A'
    # Use addenda dn (heated only systems)
    custom = nil
    debug = true
    load_existing_model = true
    model = create_baseline_model(model_name, standard, climate_zone, 'MidriseApartment', custom, debug, load_existing_model)
  end
end
