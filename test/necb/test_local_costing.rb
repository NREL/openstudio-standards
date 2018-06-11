=begin
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestCosting < NECB2011

  #create model
  template = 'NECB2011'

  #building_type = 'FullServiceRestaurant'
  #building_type ='SmallOffice'
  #building_type ='MediumOffice'
  building_type ='LargeOffice'

  climate_zone = 'NECB HDD Method'
  epw_file = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'

  model = nil

  prototype_creator = Standard.build("#{template}_#{building_type}")
  model = prototype_creator.model_create_prototype_model(climate_zone, epw_file)

  weather = BTAP::Environment::WeatherFile.new(epw_file)
  weather.set_weather_file(model)

  costing = BTAPCosting.instance()
  costing.load('13421j23lk4j1k2897198324hkjhk13j2')
  cost_result = costing.cost_audit_envelope(model)
  #cost_result = cost_result + costing.cost_audit_lighting(model)
  #cost_result = cost_result + costing.cost_audit_hvac(model)

  puts "Total envelope cost is $#{'%.2f' % cost_result}"

end
=end
