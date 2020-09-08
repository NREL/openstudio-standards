require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg9 < Minitest::Test

  include Baseline9012013

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_9

    base_model = create_baseline_model('bldg_9', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment', 'Xcel Energy CO EDA', false, true)

  end

end
