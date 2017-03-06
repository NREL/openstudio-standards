require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'

class TestNECBWeatherThermalZoneCustom < CreateDOEPrototypeBuildingTest
  folder_path = "#{File.dirname(__FILE__)}/../data/weather"
  epwfiles = BTAP::FileIO::get_find_files_from_folder_by_extension(folder_path,'.epw')
  #puts epwfiles
  out =[]
  epwfiles.each do |epw|
    wf = BTAP::Environment::WeatherFile.new(epw)
    out << "#{wf.a169_2006_climate_zone}    \t #{File.basename(epw)} hdd18  #{wf.hdd18} cdd10  #{wf.cdd10} "
  end
  puts out.sort
end
