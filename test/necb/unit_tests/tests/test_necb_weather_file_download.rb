require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


#This test will check that the ERVs are added and the assignment from the erv.json library works.

class NECB_Download_Weather_Files_Test < Minitest::Test

  def test_weather_file_download()

    # File paths.
    weather_folder = File.join(Dir.pwd, "data/weather")
    weather_files = [
      {
        zip_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.zip",
        clm_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.clm",
        ddy_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.ddy",
        epw_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.epw",
        pvsyst_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.pvsyst",
        rain_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.rain",
        stat_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.stat",
        wea_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.wea",
        ashrae_ddy_file: "CAN_ON_Wiarton-Keppel.Intl.AP.716330_CWEC2016.ddy" # Redundant file added for consistency
      },
      {
        zip_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.zip",
        clm_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.clm",
        ddy_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.ddy",
        epw_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.epw",
        pvsyst_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.pvsyst",
        rain_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.rain",
        stat_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.stat",
        wea_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.wea",
        ashrae_ddy_file: "CAN_SK_Yorkton.Muni.AP.712920_TMYx.2004-2018.ddy" # Redundant file added for consistency
      },
      {
        zip_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.zip",
        clm_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.clm",
        ddy_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.ddy",
        epw_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.epw",
        pvsyst_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.pvsyst",
        rain_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.rain",
        stat_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.stat",
        wea_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5.wea",
        ashrae_ddy_file: "CAN_BC_Prince.Rupert.AP-Digby.Island.710220_NRCv12022_TMY_GW1.5_ASHRAE.ddy"
      },
      {
        zip_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.zip",
        clm_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.clm",
        ddy_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.ddy",
        epw_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.epw",
        pvsyst_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.pvsyst",
        rain_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.rain",
        stat_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.stat",
        wea_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.wea",
        ashrae_ddy_file: "CAN_QC_Cap.Tourmente.713840_NRCv12022_TRY_MaxTemp_1991-2021.ddy"
      },
    ]

    #Range of test options.
    template = 'NECB2020'

    standard = Standard.build(template)
    weather_files.each do |weather_file|
      standard.get_weather_file_from_repo(epw_file: weather_file[:epw_file])
      zip_file = File.join(weather_folder, weather_file[:zip_file])
      assert(false, "This file was not downloaded properly: #{zip_file}") unless File.exist?(zip_file)
      clm_file = File.join(weather_folder, weather_file[:clm_file])
      assert(false, "This file was not extracted properly: #{clm_file}") unless File.exist?(clm_file)
      ddy_file = File.join(weather_folder, weather_file[:ddy_file])
      assert(false, "This file was not extracted properly: #{ddy_file}") unless File.exist?(ddy_file)
      epw_file = File.join(weather_folder, weather_file[:epw_file])
      assert(false, "This file was not extracted properly: #{epw_file}") unless File.exist?(epw_file)
      pvsyst_file = File.join(weather_folder, weather_file[:pvsyst_file])
      assert(false, "This file was not extracted properly: #{pvsyst_file}") unless File.exist?(pvsyst_file)
      rain_file = File.join(weather_folder, weather_file[:rain_file])
      assert(false, "This file was not extracted properly: #{rain_file}") unless File.exist?(rain_file)
      stat_file = File.join(weather_folder, weather_file[:stat_file])
      assert(false, "This file was not extracted properly: #{stat_file}") unless File.exist?(stat_file)
      wea_file = File.join(weather_folder, weather_file[:wea_file])
      assert(false, "This file was not extracted properly: #{wea_file}") unless File.exist?(wea_file)
      ashrae_ddy_file = File.join(weather_folder, weather_file[:ashrae_ddy_file])
      assert(false, "This file was not extracted properly: #{ashrae_ddy_file}") unless File.exist?(ashrae_ddy_file)
    end
  end
end
