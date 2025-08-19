require_relative '../helpers/minitest_helper'
require_relative './prm_check'
require_relative './prm_test_model_generator'
# Part of the ASHRAE 90.1 Appendix G Performance Rating Method (PRM) baseline automation implementation test suite
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMPlantResetTests < Minitest::Test
  def test_plant_temp_reset_ctrl_01
    model_hash = prm_test_helper('plant_temp_reset_ctrl_01', require_prototype = false, require_baseline = true)
    check_hw_chw_reset(model_hash['baseline'])
  end

  def test_plant_temp_reset_ctrl_02
    model_hash = prm_test_helper('plant_temp_reset_ctrl_02', require_prototype = false, require_baseline = true)
    check_hw_chw_reset(model_hash['baseline'])
  end
end
