require_relative '../helpers/minitest_helper'
require_relative './prm_check'
require_relative './prm_test_model_generator'
# Part of the ASHRAE 90.1 Appendix G Performance Rating Method (PRM) baseline automation implementation test suite
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMInfiltrationTests < Minitest::Test
  def test_infiltration
    model_hash = prm_test_helper('infiltration', require_prototype = true, require_baseline = true, require_proposed = true)
    check_infiltration(model_hash['prototype'], model_hash['baseline'], 'baseline')
    check_infiltration(model_hash['prototype'], model_hash['proposed'], 'proposed')
  end
end
