require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class Baseline9012013UserTest < Minitest::Test

  def dont_test_bldg_user_1

    base_model = create_baseline_model('bldg_u_1', '90.1-2013', 'ASHRAE 169-2006-3A', 'LargeHotel', nil, false, true)

  end

  def dont_test_bldg_user_2

    base_model = create_baseline_model('bldg_u_2', '90.1-2013', 'ASHRAE 169-2006-2A', 'MediumOffice', nil, false, true)

  end

  def dont_test_bldg_user_3

    base_model = create_baseline_model('bldg_u_3', '90.1-2013', 'ASHRAE 169-2006-2A', 'MediumOffice', nil, true, true)

  end

  def test_bldg_user_5

    base_model = create_baseline_model('bldg_u_5.osm', '90.1-2010', 'ASHRAE 169-2006-6A', 'MediumOffice', nil, false, true)

  end

end
