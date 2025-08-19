require_relative '../helpers/minitest_helper'
require_relative './prm_check'
require_relative './prm_test_model_generator'
# Part of the ASHRAE 90.1 Appendix G Performance Rating Method (PRM) baseline automation implementation test suite
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMHVAC5Tests < Minitest::Test
  def test_hvac_baseline_05
    model_hash = prm_test_helper('hvac_baseline_05', require_prototype = false, require_baseline = true)
    check_hvac(model_hash['baseline'])
  end
end
