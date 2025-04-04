require_relative '../../../helpers/minitest_helper'
require_relative 'parametric_test_creator'

# Sample test to demonstrate how to call the test creator
class ECM_Sample_Test < ParametricTestCreator
  params =
    {
      template:
        [
          "NECB2011",
          # "NECB2015",
          # "NECB2017",
          # "NECB2020"
        ],
      primary_heating_fuel:
        [
          "Electricity",
          "NaturalGas"
        ],
      ecm_system_name:
        [
          "HS11_ASHP_PTHP"
        ]
    }
  self.generate_tests(params)
end