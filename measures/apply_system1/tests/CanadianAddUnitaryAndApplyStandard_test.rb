$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

require 'json'
require 'rubygems'
require 'zip'

class CanadianAddUnitaryAndApplyStandardTest < MiniTest::Unit::TestCase


=begin
  def test_system_1()
    boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
    mau_types = [true, false]
    mau_heating_coil_types = ["Hot Water", "Electric"]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    heating_coil_types_sys4and6 = ["Electric", "Gas"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("#{File.dirname(__FILE__)}/../../../weather/CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(model, model.getThermalZones, boiler_fueltypes[0], mau_types[0], mau_heating_coil_types[0], baseboard_types[0])
    run_the_measure(model)
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/system_1.osm")
  end
=end

=begin  
  def test_system_2()
    boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
    mau_types = [true, false]
    mau_heating_coil_types = ["Hot Water", "Electric"]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    heating_coil_types_sys4and6 = ["Electric", "Gas"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("#{File.dirname(__FILE__)}/../../../weather/CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(model, model.getThermalZones, boiler_fueltypes[0], chiller_types[0], mua_cooling_types[0])
    run_the_measure(model)
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/system_2.osm")
  end
=end
  
=begin
    def test_system_3()
      boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
      mau_types = [true, false]
      mau_heating_coil_types = ["Hot Water", "Electric"]
      baseboard_types = ["Hot Water" , "Electric"]
      chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
      mua_cooling_types = ["DX","Hydronic"]
      heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
      heating_coil_types_sys4and6 = ["Electric", "Gas"]
      fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
      model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
      weather_file = "CAN_ON_Toronto.716240_CWEC.epw"
      puts "in test, weather_file = #{weather_file}"
      BTAP::Environment::WeatherFile.new(weather_file).set_weather_file(model)
      BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys3(model, model.getThermalZones, boiler_fueltypes[0], heating_coil_types_sys3[2], baseboard_types[0])
      run_the_measure(model)
      BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/output/system_3.osm")
    end
=end
  
=begin  
  def test_system_4()
    boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
    mau_types = [true, false]
    mau_heating_coil_types = ["Hot Water", "Electric"]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    heating_coil_types_sys4and6 = ["Electric", "Gas"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("#{File.dirname(__FILE__)}/../../../weather/CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys4(model, model.getThermalZones, boiler_fueltypes[0], heating_coil_types_sys4and6[1], baseboard_types[0])
    run_the_measure(model)
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/system_4.osm")
  end
=end
  
=begin  
  def test_system_5()
    boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
    mau_types = [true, false]
    mau_heating_coil_types = ["Hot Water", "Electric"]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    heating_coil_types_sys4and6 = ["Electric", "Gas"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("#{File.dirname(__FILE__)}/../../../weather/CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys5(model, model.getThermalZones, boiler_fueltypes[0], chiller_types[0], mua_cooling_types[0])
    run_the_measure(model)
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/system_5.osm")
  end
=end

begin
  def test_system_6()
    boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
    mau_types = [true, false]
    mau_heating_coil_types = ["Hot Water", "Electric"]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    heating_coil_types_sys4and6 = ["Electric", "Gas"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    weather_file = "CAN_ON_Toronto.716240_CWEC.epw"
    puts "in test, weather_file = #{weather_file}"
    BTAP::Environment::WeatherFile.new(weather_file).set_weather_file(model)
#    BTAP::Environment::WeatherFile.new("#{File.dirname(__FILE__)}/../../../weather/CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys6(model, model.getThermalZones, boiler_fueltypes[0], heating_coil_types_sys4and6[0], baseboard_types[0], chiller_types[0], fan_types[0])
    run_the_measure(model)
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/system_6.osm")
  end
end

=begin  
  def test_system_7()
    boiler_fueltypes = ["NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"]
    mau_types = [true, false]
    mau_heating_coil_types = ["Hot Water", "Electric"]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    heating_coil_types_sys4and6 = ["Electric", "Gas"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("#{File.dirname(__FILE__)}/../../../weather/CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(model, model.getThermalZones, boiler_fueltypes[0], chiller_types[0], mua_cooling_types[0])
    run_the_measure(model)
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/system_7.osm")
  end
=end  

  def run_the_measure(model)   
    # create an instance of the measure, a runner and an empty model
    measure = CanadianAddUnitaryAndApplyStandard.new
    runner = OpenStudio::Ruleset::OSRunner.new

    #might need arg variables but they are empty. 
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(OpenStudio::Ruleset::OSArgumentVector.new())

    # run the measure
    measure.run(model, runner, argument_map)
    #return condition of measure.
    assert_equal("Success", runner.result.value.valueName)
  end 
end

#def test_auto_zoner()
#  #try loading the file. 
#  BTAP::FileIO::get_find_files_from_folder_by_extension( "#{File.dirname(__FILE__)}/../../../weather/resources/models/DOEArchetypes/OSM_NECB_Space_Types", '.osm' ).each do |file|
#    model = BTAP::FileIO::load_osm( file )
#    #suto zone it and assign systems. 
#    BTAP::Compliance::NECB2011::necb_autozoner( model )
#    #save file under new name
#    new_file = "#{File.dirname(file)}/auto_zoned/#{File.basename(file,".osm")}.osm"
#    BTAP::FileIO::save_osm( model, new_file )
#  end
#end
