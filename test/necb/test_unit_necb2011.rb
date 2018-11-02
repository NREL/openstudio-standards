require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

#LargeOffice
class TestNECBLargeOffice < CreateDOEPrototypeBuildingTest
  building_type = 'LargeOffice'

  template = 'NECB2011'
  climate_zone = 'NECB HDD Method'
  epw_file = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'


  model = NECB2011.new()
  model.load_building_type_methods(building_type, template, climate_zone)
  model_add_design_days_and_weather_file(model,  climate_zone, epw_file)
  model_add_ground_temperatures(model, building_type, climate_zone)
  model.check_weather_file()

  puts JSON.pretty_generate(standards_data["necb_fdwr"])
  puts JSON.pretty_generate(standards_data["necb_surface_conductances"])

  puts model.get_standard_max_fdwr
  puts model.standard_climate_zone_index
  puts model.get_standard_climate_zone_name
  puts model.get_standard_surface_conductance('ExteriorWall')

end
