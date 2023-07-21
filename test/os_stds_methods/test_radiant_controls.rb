require_relative '../helpers/minitest_helper'
require_relative '../helpers/hvac_system_test_helper'

class TestRadiantControls < Minitest::Test
  def test_radiant_controls
    hvac_systems = [
      {system_type: 'Radiant Slab with DOAS', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       unmet_hrs_htg: 700.0, unmet_hrs_clg: 3500.0}
    ]
    
    # TODO: Add additional tests and edit the test hash arguments as necessary

    group_hvac_test(hvac_systems)
  end
end
