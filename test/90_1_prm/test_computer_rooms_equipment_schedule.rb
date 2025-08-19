require_relative '../helpers/minitest_helper'
require_relative './prm_check'
require_relative './prm_test_model_generator'
# Part of the ASHRAE 90.1 Appendix G Performance Rating Method (PRM) baseline automation implementation test suite
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMComputerRoomsTests < Minitest::Test
  def test_computer_rooms_equipment_schedule
    model_hash = prm_test_helper('computer_rooms_equipment_schedule', require_prototype = false, require_baseline = true, require_proposed = true)

    check_computer_rooms_equipment_schedule(model_hash['baseline'])
    check_computer_rooms_equipment_schedule(model_hash['proposed'])
  end
end
