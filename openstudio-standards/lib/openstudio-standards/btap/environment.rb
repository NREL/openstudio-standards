# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

require "#{File.dirname(__FILE__)}/btap"


module BTAP
  module Environment

    #keeping data is hash/json for now. Can always export / import to csv if required automatically. 
    WeatherData1 = [   
      {:file=>"CAN_BC_Abbotsford.711080_CWEC.epw", :location_name=>" CAN-BC-Abbotsford", :energy_plus_location_name=>"Abbotsford_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Abbotsford", :hdd18=>3134, :cdd18=>33, :latitude=>49.03, :longitude=>-122.37, :elevation=>58, :deltadb=>14.3, :a90_1_2004_climate_zone=>"5C", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Bagotville.717270_CWEC.epw", :location_name=>" CAN-PQ-Bagotville", :energy_plus_location_name=>"Bagotville_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Bagotville", :hdd18=>5781, :cdd18=>49, :latitude=>48.33, :longitude=>-71, :elevation=>159, :deltadb=>32.4, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Baie.Comeau.711870_CWEC.epw", :location_name=>" CAN-PQ-Baie Comeau", :energy_plus_location_name=>"Baie Comeau_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Baie Comeau", :hdd18=>5889, :cdd18=>3, :latitude=>49.13, :longitude=>-68.2, :elevation=>22, :deltadb=>29.8, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NF_Battle.Harbour.718170_CWEC.epw", :location_name=>" CAN-NF-Battle Harbour", :energy_plus_location_name=>"Battle Harbour_NF_CAN", :country=>"CAN", :state_province_region=>"NF", :city=>"Battle Harbour", :hdd18=>6462, :cdd18=>0, :latitude=>52.3, :longitude=>-55.83, :elevation=>8, :deltadb=>21.6, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_MB_Brandon.711400_CWEC.epw", :location_name=>" CAN-MB-Brandon", :energy_plus_location_name=>"Brandon_MB_CAN", :country=>"CAN", :state_province_region=>"MB", :city=>"Brandon", :hdd18=>5912, :cdd18=>95, :latitude=>49.92, :longitude=>-99.95, :elevation=>409, :deltadb=>36.7, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_AB_Calgary.718770_CWEC.epw", :location_name=>" CAN-AB-Calgary Int'l", :energy_plus_location_name=>"Calgary Int'l_AB_CAN", :country=>"CAN", :state_province_region=>"AB", :city=>"Calgary Int'l", :hdd18=>5146, :cdd18=>40, :latitude=>51.12, :longitude=>-114.02, :elevation=>1084, :deltadb=>25, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PE_Charlottetown.717060_CWEC.epw", :location_name=>" CAN-PE-Charlottetown CDA", :energy_plus_location_name=>"Charlottetown CDA_PE_CAN", :country=>"CAN", :state_province_region=>"PE", :city=>"Charlottetown CDA", :hdd18=>4647, :cdd18=>72, :latitude=>46.28, :longitude=>-63.13, :elevation=>54, :deltadb=>25.6, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_MB_Churchill.719130_CWEC.epw", :location_name=>" CAN-MB-Churchill", :energy_plus_location_name=>"Churchill_MB_CAN", :country=>"CAN", :state_province_region=>"MB", :city=>"Churchill", :hdd18=>9114, :cdd18=>3, :latitude=>58.75, :longitude=>-94.07, :elevation=>29, :deltadb=>37.7, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Comox.718930_CWEC.epw", :location_name=>" CAN-BC-Comox", :energy_plus_location_name=>"Comox_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Comox", :hdd18=>3177, :cdd18=>30, :latitude=>49.72, :longitude=>-124.9, :elevation=>24, :deltadb=>15.2, :a90_1_2004_climate_zone=>"5C", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Cranbrook.718800_CWEC.epw", :location_name=>" CAN-BC-Cranbrook", :energy_plus_location_name=>"Cranbrook_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Cranbrook", :hdd18=>4645, :cdd18=>118, :latitude=>49.6, :longitude=>-115.78, :elevation=>940, :deltadb=>26.6, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_AB_Edmonton.711230_CWEC.epw", :location_name=>" CAN-AB-Edmonton Stony Plain", :energy_plus_location_name=>"Edmonton Stony Plain_AB_CAN", :country=>"CAN", :state_province_region=>"AB", :city=>"Edmonton Stony Plain", :hdd18=>5583, :cdd18=>22, :latitude=>53.53, :longitude=>-114.1, :elevation=>723, :deltadb=>27.5, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_SK_Estevan.718620_CWEC.epw", :location_name=>" CAN-SK-Estevan", :energy_plus_location_name=>"Estevan_SK_CAN", :country=>"CAN", :state_province_region=>"SK", :city=>"Estevan", :hdd18=>5370, :cdd18=>189, :latitude=>49.22, :longitude=>-102.97, :elevation=>581, :deltadb=>35.1, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_AB_Fort.McMurray.719320_CWEC.epw", :location_name=>" CAN-AB-Fort McMurray", :energy_plus_location_name=>"Fort McMurray_AB_CAN", :country=>"CAN", :state_province_region=>"AB", :city=>"Fort McMurray", :hdd18=>6191, :cdd18=>65, :latitude=>56.65, :longitude=>-111.22, :elevation=>369, :deltadb=>33.5, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Fort.St.John.719430_CWEC.epw", :location_name=>" CAN-BC-Fort St John", :energy_plus_location_name=>"Fort St John_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Fort St John", :hdd18=>5863, :cdd18=>25, :latitude=>56.23, :longitude=>-120.73, :elevation=>695, :deltadb=>29.1, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NB_Fredericton.717000_CWEC.epw", :location_name=>" CAN-NB-Fredericton", :energy_plus_location_name=>"Fredericton_NB_CAN", :country=>"CAN", :state_province_region=>"NB", :city=>"Fredericton", :hdd18=>4734, :cdd18=>132, :latitude=>45.87, :longitude=>-66.53, :elevation=>20, :deltadb=>29.5, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NF_Gander.718030_CWEC.epw", :location_name=>" CAN-NF-Gander Int'l", :energy_plus_location_name=>"Gander Int'l_NF_CAN", :country=>"CAN", :state_province_region=>"NF", :city=>"Gander Int'l", :hdd18=>5101, :cdd18=>25, :latitude=>48.95, :longitude=>-54.57, :elevation=>151, :deltadb=>22.6, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NF_Goose.718160_CWEC.epw", :location_name=>" CAN-NF-Goose", :energy_plus_location_name=>"Goose_NF_CAN", :country=>"CAN", :state_province_region=>"NF", :city=>"Goose", :hdd18=>6558, :cdd18=>38, :latitude=>53.32, :longitude=>-60.37, :elevation=>49, :deltadb=>33, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_AB_Grande.Prairie.719400_CWEC.epw", :location_name=>" CAN-AB-Grand Prairie", :energy_plus_location_name=>"Grand Prairie_AB_CAN", :country=>"CAN", :state_province_region=>"AB", :city=>"Grand Prairie", :hdd18=>5897, :cdd18=>26, :latitude=>55.18, :longitude=>-118.88, :elevation=>669, :deltadb=>28.9, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NS_Greenwood.713970_CWEC.epw", :location_name=>" CAN-NS-Greenwood", :energy_plus_location_name=>"Greenwood_NS_CAN", :country=>"CAN", :state_province_region=>"NS", :city=>"Greenwood", :hdd18=>4131, :cdd18=>128, :latitude=>44.98, :longitude=>-64.92, :elevation=>28, :deltadb=>23.8, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Grindstone.Island_CWEC.epw", :location_name=>" CAN-PQ-Grindstone Island", :energy_plus_location_name=>"Grindstone Island_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Grindstone Island", :hdd18=>4941, :cdd18=>18, :latitude=>47.38, :longitude=>-61.87, :elevation=>59, :deltadb=>23.8, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NT_Inuvik.719570_CWEC.epw", :location_name=>" CAN-NT-Inuvik Ua", :energy_plus_location_name=>"Inuvik Ua_NT_CAN", :country=>"CAN", :state_province_region=>"NT", :city=>"Inuvik Ua", :hdd18=>9952, :cdd18=>17, :latitude=>68.3, :longitude=>-133.48, :elevation=>68, :deltadb=>40.6, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"FuelOil#1", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Kamloops.718870_CWEC.epw", :location_name=>" CAN-BC-Kamloops", :energy_plus_location_name=>"Kamloops_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Kamloops", :hdd18=>3629, :cdd18=>287, :latitude=>50.7, :longitude=>-120.45, :elevation=>346, :deltadb=>25.6, :a90_1_2004_climate_zone=>"5B", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Kingston.716200_CWEC.epw", :location_name=>" CAN-ON-Kingston", :energy_plus_location_name=>"Kingston_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Kingston", :hdd18=>4287, :cdd18=>187, :latitude=>44.22, :longitude=>-76.6, :elevation=>93, :deltadb=>27.7, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Kuujjuarapik.719050_CWEC.epw", :location_name=>" CAN-PQ-Kuujjuarapik", :energy_plus_location_name=>"Kuujjuarapik_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Kuujjuarapik", :hdd18=>7986, :cdd18=>12, :latitude=>55.28, :longitude=>-77.77, :elevation=>12, :deltadb=>32, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Kuujuaq.719060_CWEC.epw", :location_name=>" CAN-PQ-Kuujuaq", :energy_plus_location_name=>"Kuujuaq_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Kuujuaq", :hdd18=>8491, :cdd18=>0, :latitude=>58.1, :longitude=>-68.42, :elevation=>37, :deltadb=>31.8, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_La.Grande.Riviere.718270_CWEC.epw", :location_name=>" CAN-PQ-La Grande Riviere", :energy_plus_location_name=>"La Grande Riviere_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"La Grande Riviere", :hdd18=>7616, :cdd18=>11, :latitude=>53.63, :longitude=>-77.7, :elevation=>195, :deltadb=>35.2, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Lake.Eon.714210_CWEC.epw", :location_name=>" CAN-PQ-Lake Eon", :energy_plus_location_name=>"Lake Eon_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Lake Eon", :hdd18=>7383, :cdd18=>8, :latitude=>51.87, :longitude=>-63.28, :elevation=>561, :deltadb=>33.9, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_AB_Lethbridge.712430_CWEC.epw", :location_name=>" CAN-AB-Lethbridge", :energy_plus_location_name=>"Lethbridge_AB_CAN", :country=>"CAN", :state_province_region=>"AB", :city=>"Lethbridge", :hdd18=>4432, :cdd18=>126, :latitude=>49.63, :longitude=>-112.8, :elevation=>921, :deltadb=>26.5, :a90_1_2004_climate_zone=>"6B", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_London.716230_CWEC.epw", :location_name=>" CAN-ON-London", :energy_plus_location_name=>"London_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"London", :hdd18=>4111, :cdd18=>211, :latitude=>43.03, :longitude=>-81.15, :elevation=>278, :deltadb=>27.9, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_AB_Medicine.Hat.718720_CWEC.epw", :location_name=>" CAN-AB-Medicine Hat", :energy_plus_location_name=>"Medicine Hat_AB_CAN", :country=>"CAN", :state_province_region=>"AB", :city=>"Medicine Hat", :hdd18=>4678, :cdd18=>199, :latitude=>50.02, :longitude=>-110.72, :elevation=>716, :deltadb=>31.6, :a90_1_2004_climate_zone=>"6B", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NB_Miramichi.717440_CWEC.epw", :location_name=>" CAN-NB-Miramichi", :energy_plus_location_name=>"Miramichi_NB_CAN", :country=>"CAN", :state_province_region=>"NB", :city=>"Miramichi", :hdd18=>4921, :cdd18=>141, :latitude=>47.02, :longitude=>-65.45, :elevation=>33, :deltadb=>29.6, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Mont.Joli.717180_CWEC.epw", :location_name=>" CAN-PQ-Mont Joli", :energy_plus_location_name=>"Mont Joli_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Mont Joli", :hdd18=>5522, :cdd18=>65, :latitude=>48.6, :longitude=>-68.22, :elevation=>52, :deltadb=>30.8, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Montreal.Intl.AP.716270_CWEC.epw", :location_name=>" CAN-PQ-Montreal Int'l", :energy_plus_location_name=>"Montreal Int'l_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Montreal Int'l", :hdd18=>4493, :cdd18=>234, :latitude=>45.47, :longitude=>-73.75, :elevation=>36, :deltadb=>30.2, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Montreal.Jean.Brebeuf.716278_CWEC.epw", :location_name=>" CAN-PQ-Montreal Jean Brebeuf", :energy_plus_location_name=>"Montreal Jean Brebeuf_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Montreal Jean Brebeuf", :hdd18=>4616, :cdd18=>209, :latitude=>45.5, :longitude=>-73.62, :elevation=>133, :deltadb=>31.2, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Montreal.Mirabel.716278_CWEC.epw", :location_name=>" CAN-PQ-Montreal Mirabel", :energy_plus_location_name=>"Montreal Mirabel_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Montreal Mirabel", :hdd18=>4861, :cdd18=>102, :latitude=>45.68, :longitude=>-74.03, :elevation=>82, :deltadb=>33.4, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Mount.Forest.716310_CWEC.epw", :location_name=>" CAN-ON-Mount Forest", :energy_plus_location_name=>"Mount Forest_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Mount Forest", :hdd18=>4578, :cdd18=>121, :latitude=>43.98, :longitude=>-80.75, :elevation=>415, :deltadb=>27.7, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Muskoka.716300_CWEC.epw", :location_name=>" CAN-ON-Muskoka", :energy_plus_location_name=>"Muskoka_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Muskoka", :hdd18=>4774, :cdd18=>97, :latitude=>44.97, :longitude=>-79.3, :elevation=>282, :deltadb=>29.3, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Nitchequon.CAN270_CWEC.epw", :location_name=>" CAN-PQ-Nitchequon", :energy_plus_location_name=>"Nitchequon_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Nitchequon", :hdd18=>7922, :cdd18=>6, :latitude=>53.2, :longitude=>-70.9, :elevation=>536, :deltadb=>35.8, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_SK_North.Battleford.718760_CWEC.epw", :location_name=>" CAN-SK-North Battleford", :energy_plus_location_name=>"North Battleford_SK_CAN", :country=>"CAN", :state_province_region=>"SK", :city=>"North Battleford", :hdd18=>5962, :cdd18=>75, :latitude=>52.77, :longitude=>-108.25, :elevation=>548, :deltadb=>35.4, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_North.Bay.717310_CWEC.epw", :location_name=>" CAN-ON-North Bay", :energy_plus_location_name=>"North Bay_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"North Bay", :hdd18=>5341, :cdd18=>103, :latitude=>46.35, :longitude=>-79.43, :elevation=>371, :deltadb=>32.2, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Ottawa.716280_CWEC.epw", :location_name=>" CAN-ON-Ottawa Int'l", :energy_plus_location_name=>"Ottawa Int'l_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Ottawa Int'l", :hdd18=>4664, :cdd18=>189, :latitude=>45.32, :longitude=>-75.67, :elevation=>114, :deltadb=>31.8, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Port.Hardy.711090_CWEC.epw", :location_name=>" CAN-BC-Port Hardy", :energy_plus_location_name=>"Port Hardy_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Port Hardy", :hdd18=>3712, :cdd18=>0, :latitude=>50.68, :longitude=>-127.37, :elevation=>22, :deltadb=>10.8, :a90_1_2004_climate_zone=>"5C", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Prince.George.718960_CWEC.epw", :location_name=>" CAN-BC-Prince George", :energy_plus_location_name=>"Prince George_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Prince George", :hdd18=>5070, :cdd18=>15, :latitude=>53.88, :longitude=>-122.68, :elevation=>691, :deltadb=>26, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Prince.Rupert.718980_CWEC.epw", :location_name=>" CAN-BC-Prince Rupert", :energy_plus_location_name=>"Prince Rupert_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Prince Rupert", :hdd18=>4151, :cdd18=>0, :latitude=>54.3, :longitude=>-130.43, :elevation=>34, :deltadb=>13.5, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Quebec.717140_CWEC.epw", :location_name=>" CAN-PQ-Quebec City", :energy_plus_location_name=>"Quebec City_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Quebec City", :hdd18=>4964, :cdd18=>111, :latitude=>46.8, :longitude=>-71.38, :elevation=>73, :deltadb=>31, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_SK_Regina.718630_CWEC.epw", :location_name=>" CAN-SK-Regina", :energy_plus_location_name=>"Regina_SK_CAN", :country=>"CAN", :state_province_region=>"SK", :city=>"Regina", :hdd18=>5646, :cdd18=>129, :latitude=>50.43, :longitude=>-104.67, :elevation=>577, :deltadb=>35.4, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NU_Resolute.719240_CWEC.epw", :location_name=>" CAN-NU-Resolute", :energy_plus_location_name=>"Resolute_NU_CAN", :country=>"CAN", :state_province_region=>"NU", :city=>"Resolute", :hdd18=>12570, :cdd18=>0, :latitude=>74.72, :longitude=>-94.98, :elevation=>67, :deltadb=>35.9, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"FuelOil#2", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Riviere.du.Loup.717150_CWEC.epw", :location_name=>" CAN-PQ-Riviere Du Loup", :energy_plus_location_name=>"Riviere Du Loup_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Riviere Du Loup", :hdd18=>5424, :cdd18=>82, :latitude=>47.8, :longitude=>-69.55, :elevation=>148, :deltadb=>30.1, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Roberval.717280_CWEC.epw", :location_name=>" CAN-PQ-Roberval", :energy_plus_location_name=>"Roberval_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Roberval", :hdd18=>5757, :cdd18=>97, :latitude=>48.52, :longitude=>-72.27, :elevation=>179, :deltadb=>35.6, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NS_Sable.Island.716000_CWEC.epw", :location_name=>" CAN-NS-Sable Island", :energy_plus_location_name=>"Sable Island_NS_CAN", :country=>"CAN", :state_province_region=>"NS", :city=>"Sable Island", :hdd18=>3860, :cdd18=>14, :latitude=>43.93, :longitude=>-60.02, :elevation=>4, :deltadb=>18.3, :a90_1_2004_climate_zone=>"5A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NB_Saint.John.716090_CWEC.epw", :location_name=>" CAN-NB-Saint John", :energy_plus_location_name=>"Saint John_NB_CAN", :country=>"CAN", :state_province_region=>"NB", :city=>"Saint John", :hdd18=>4695, :cdd18=>12, :latitude=>45.32, :longitude=>-65.88, :elevation=>109, :deltadb=>23.8, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Sandspit.711010_CWEC.epw", :location_name=>" CAN-BC-Sandspit", :energy_plus_location_name=>"Sandspit_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Sandspit", :hdd18=>3644, :cdd18=>0, :latitude=>53.25, :longitude=>-131.82, :elevation=>6, :deltadb=>13.1, :a90_1_2004_climate_zone=>"5C", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_SK_Saskatoon.718660_CWEC.epw", :location_name=>" CAN-SK-Saskatoon", :energy_plus_location_name=>"Saskatoon_SK_CAN", :country=>"CAN", :state_province_region=>"SK", :city=>"Saskatoon", :hdd18=>5812, :cdd18=>84, :latitude=>52.17, :longitude=>-106.68, :elevation=>504, :deltadb=>34.4, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Sault.Ste.Marie.712600_CWEC.epw", :location_name=>" CAN-ON-Sault Ste Marie", :energy_plus_location_name=>"Sault Ste Marie_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Sault Ste Marie", :hdd18=>4993, :cdd18=>75, :latitude=>46.48, :longitude=>-84.52, :elevation=>192, :deltadb=>28.3, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Schefferville.718280_CWEC.epw", :location_name=>" CAN-PQ-Schefferville", :energy_plus_location_name=>"Schefferville_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Schefferville", :hdd18=>8057, :cdd18=>7, :latitude=>54.8, :longitude=>-66.82, :elevation=>521, :deltadb=>34.6, :a90_1_2004_climate_zone=>8, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Sept-Iles.718110_CWEC.epw", :location_name=>" CAN-PQ-Sept-Iles", :energy_plus_location_name=>"Sept-Iles_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Sept-Iles", :hdd18=>6134, :cdd18=>4, :latitude=>50.22, :longitude=>-66.27, :elevation=>55, :deltadb=>30.9, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NS_Shearwater.716010_CWEC.epw", :location_name=>" CAN-NS-Shearwater", :energy_plus_location_name=>"Shearwater_NS_CAN", :country=>"CAN", :state_province_region=>"NS", :city=>"Shearwater", :hdd18=>4197, :cdd18=>58, :latitude=>44.63, :longitude=>-63.5, :elevation=>51, :deltadb=>22, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Sherbrooke.716100_CWEC.epw", :location_name=>" CAN-PQ-Sherbrooke", :energy_plus_location_name=>"Sherbrooke_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Sherbrooke", :hdd18=>5068, :cdd18=>93, :latitude=>45.43, :longitude=>-71.68, :elevation=>241, :deltadb=>28.2, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Simcoe.715270_CWEC.epw", :location_name=>" CAN-ON-Simcoe", :energy_plus_location_name=>"Simcoe_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Simcoe", :hdd18=>4066, :cdd18=>190, :latitude=>42.85, :longitude=>-80.27, :elevation=>241, :deltadb=>26.4, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Smithers.719500_CWEC.epw", :location_name=>" CAN-BC-Smithers", :energy_plus_location_name=>"Smithers_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Smithers", :hdd18=>5265, :cdd18=>22, :latitude=>54.82, :longitude=>-127.18, :elevation=>523, :deltadb=>24.2, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_St.Hubert.713710_CWEC.epw", :location_name=>" CAN-PQ-St Hubert", :energy_plus_location_name=>"St Hubert_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"St Hubert", :hdd18=>4566, :cdd18=>251, :latitude=>45.52, :longitude=>-73.42, :elevation=>27, :deltadb=>31.2, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NF_St.Johns.718010_CWEC.epw", :location_name=>" CAN-NF-St John's", :energy_plus_location_name=>"St John's_NF_CAN", :country=>"CAN", :state_province_region=>"NF", :city=>"St John's", :hdd18=>4886, :cdd18=>24, :latitude=>47.62, :longitude=>-52.73, :elevation=>140, :deltadb=>20.5, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Ste.Agathe.des.Monts.717200_CWEC.epw", :location_name=>" CAN-PQ-Ste Agathe Des Monts", :energy_plus_location_name=>"Ste Agathe Des Monts_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Ste Agathe Des Monts", :hdd18=>5350, :cdd18=>45, :latitude=>46.05, :longitude=>-74.28, :elevation=>395, :deltadb=>29.6, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NF_Stephenville.718150_CWEC.epw", :location_name=>" CAN-NF-Stephenville", :energy_plus_location_name=>"Stephenville_NF_CAN", :country=>"CAN", :state_province_region=>"NF", :city=>"Stephenville", :hdd18=>4724, :cdd18=>10, :latitude=>48.53, :longitude=>-58.55, :elevation=>26, :deltadb=>23.1, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Summerland.717680_CWEC.epw", :location_name=>" CAN-BC-Summerland", :energy_plus_location_name=>"Summerland_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Summerland", :hdd18=>3388, :cdd18=>199, :latitude=>49.57, :longitude=>-119.65, :elevation=>479, :deltadb=>21.8, :a90_1_2004_climate_zone=>"5A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_SK_Swift.Current.718700_CWEC.epw", :location_name=>" CAN-SK-Swift Current", :energy_plus_location_name=>"Swift Current_SK_CAN", :country=>"CAN", :state_province_region=>"SK", :city=>"Swift Current", :hdd18=>5227, :cdd18=>96, :latitude=>50.28, :longitude=>-107.68, :elevation=>818, :deltadb=>30.8, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NS_Sydney.717070_CWEC.epw", :location_name=>" CAN-NS-Sydney", :energy_plus_location_name=>"Sydney_NS_CAN", :country=>"CAN", :state_province_region=>"NS", :city=>"Sydney", :hdd18=>4634, :cdd18=>51, :latitude=>46.17, :longitude=>-60.05, :elevation=>62, :deltadb=>24, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_MB_The.Pas.718670_CWEC.epw", :location_name=>" CAN-MB-The Pas", :energy_plus_location_name=>"The Pas_MB_CAN", :country=>"CAN", :state_province_region=>"MB", :city=>"The Pas", :hdd18=>6442, :cdd18=>106, :latitude=>53.97, :longitude=>-101.1, :elevation=>271, :deltadb=>37.9, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Thunder.Bay.717490_CWEC.epw", :location_name=>" CAN-ON-Thunder Bay", :energy_plus_location_name=>"Thunder Bay_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Thunder Bay", :hdd18=>5624, :cdd18=>60, :latitude=>48.37, :longitude=>-89.32, :elevation=>199, :deltadb=>33.8, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Timmins.717390_CWEC.epw", :location_name=>" CAN-ON-Timmins", :energy_plus_location_name=>"Timmins_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Timmins", :hdd18=>5952, :cdd18=>63, :latitude=>48.57, :longitude=>-81.37, :elevation=>295, :deltadb=>33.8, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Toronto.716240_CWEC.epw", :location_name=>" CAN-ON-Toronto Int'l", :energy_plus_location_name=>"Toronto Int'l_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Toronto Int'l", :hdd18=>4088, :cdd18=>231, :latitude=>43.67, :longitude=>-79.63, :elevation=>173, :deltadb=>26.6, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Trenton.716210_CWEC.epw", :location_name=>" CAN-ON-Trenton", :energy_plus_location_name=>"Trenton_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Trenton", :hdd18=>4176, :cdd18=>207, :latitude=>44.12, :longitude=>-77.53, :elevation=>86, :deltadb=>27.7, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_NS_Truro.713980_CWEC.epw", :location_name=>" CAN-NS-Truro", :energy_plus_location_name=>"Truro_NS_CAN", :country=>"CAN", :state_province_region=>"NS", :city=>"Truro", :hdd18=>4537, :cdd18=>35, :latitude=>45.37, :longitude=>-63.27, :elevation=>40, :deltadb=>25.2, :a90_1_2004_climate_zone=>"6A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_PQ_Val.d.Or.717250_CWEC.epw", :location_name=>" CAN-PQ-Val d'Or", :energy_plus_location_name=>"Val d'Or_PQ_CAN", :country=>"CAN", :state_province_region=>"PQ", :city=>"Val d'Or", :hdd18=>6129, :cdd18=>79, :latitude=>48.07, :longitude=>-77.78, :elevation=>337, :deltadb=>35, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Vancouver.718920_CWEC.epw", :location_name=>" CAN-BC-Vancouver Int'l", :energy_plus_location_name=>"Vancouver Int'l_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Vancouver Int'l", :hdd18=>3019, :cdd18=>4, :latitude=>49.18, :longitude=>-123.17, :elevation=>2, :deltadb=>13.9, :a90_1_2004_climate_zone=>"5C", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_BC_Victoria.717990_CWEC.epw", :location_name=>" CAN-BC-Victoria Int'l", :energy_plus_location_name=>"Victoria Int'l_BC_CAN", :country=>"CAN", :state_province_region=>"BC", :city=>"Victoria Int'l", :hdd18=>3075, :cdd18=>8, :latitude=>48.65, :longitude=>-123.43, :elevation=>19, :deltadb=>12.3, :a90_1_2004_climate_zone=>"5C", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_YT_Whitehorse.719640_CWEC.epw", :location_name=>" CAN-YT-Whitehorse", :energy_plus_location_name=>"Whitehorse_YT_CAN", :country=>"CAN", :state_province_region=>"YT", :city=>"Whitehorse", :hdd18=>6946, :cdd18=>2, :latitude=>60.72, :longitude=>-135.07, :elevation=>703, :deltadb=>34.5, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"FuelOil#1", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_ON_Windsor.715380_CWEC.epw", :location_name=>" CAN-ON-Windsor", :energy_plus_location_name=>"Windsor_ON_CAN", :country=>"CAN", :state_province_region=>"ON", :city=>"Windsor", :hdd18=>3570, :cdd18=>367, :latitude=>42.27, :longitude=>-82.97, :elevation=>190, :deltadb=>27.1, :a90_1_2004_climate_zone=>"5A", :boiler_fueltype=>"NaturalGas", :baseboard_type=>"Hot Water", :mau_type=>true, :mau_heating_coil_type=>"Hot Water", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Gas", :heating_coil_type_sys4=>"Gas", :heating_coil_type_sys6=>"Hot Water", :fan_type=>"var_speed_drive"},
      {:file=>"CAN_MB_Winnipeg.718520_CWEC.epw", :location_name=>" CAN-MB-Winnipeg Int'l", :energy_plus_location_name=>"Winnipeg Int'l_MB_CAN", :country=>"CAN", :state_province_region=>"MB", :city=>"Winnipeg Int'l", :hdd18=>5754, :cdd18=>197, :latitude=>49.9, :longitude=>-97.23, :elevation=>239, :deltadb=>37.8, :a90_1_2004_climate_zone=>7, :boiler_fueltype=>"Electricity", :baseboard_type=>"Electric", :mau_type=>true, :mau_heating_coil_type=>"Electric", :mau_cooling_type=>"DX", :chiller_type=>"Scroll", :heating_coil_type_sys_3=>"Electric", :heating_coil_type_sys4=>"Electric", :heating_coil_type_sys6=>"Electric", :fan_type=>"var_speed_drive"}
    ]
    
    
    
    def self.get_canadian_weather_file_names()
      canadian_file_names = []
      BTAP::Environment::WeatherData1.each { |hash| canadian_file_names << hash[:file] }
      return canadian_file_names
    end
    
    def self.get_canadian_system_defaults_by_weatherfile_name(epw_file)
      if data = BTAP::Environment::WeatherData1.find { |data| data[:file] == epw_file.strip }
        
        return  data[:boiler_fueltype], data[:baseboard_type], data[:mau_type], data[:mau_heating_coil_type],  data[:mau_cooling_type], data[:chiller_type], data[:heating_coil_type_sys_3], data[:heating_coil_type_sys4],data[:heating_coil_type_sys6], data[:fan_type]
      else
        puts 'Not found!'
      end
      
      
      # :boiler_fueltype :baseboard_type :mau_type :mau_heating_coil_type  :mau_cooling_type :chiller_type :heating_coil_type_sys_3 :heating_coil_type_sys4and6 :fan_type
    end
    
    

    
    #This method will create a climate index file.
    #@author phylroy.lopez@nrcan.gc.ca
    #@param folder [String]
    #@param output_file [String]
    def self.create_climate_index_file(folder = '../weather/', output_file = "C:/test/phylroy.csv"  )
      data = ""
      counter = 0
      File.open(output_file, 'w') { |file|
        data << "file,location_name,energy_plus_location_name,country,state_province_region,city,hdd18,cdd18,latitude,longitude,elevation, deltaDB, a90_1_2004_climate_zone \n" 
        BTAP::FileIO::get_find_files_from_folder_by_extension(folder, 'epw').each do |wfile|
          wf = BTAP::Environment::WeatherFile.new(wfile)
          data << "#{File.basename(wfile)}, #{wf.location_name}\,#{wf.energy_plus_location_name},#{wf.country}, #{wf.state_province_region}, #{wf.city}, #{wf.hdd18},#{wf.cdd18},#{wf.latitude}, #{wf.longitude}, #{wf.elevation}, #{wf.delta_dry_bulb} ,#{wf.a90_1_2004_climate_zone}\n"
          
          #file.write( "\"#{File.basename(wfile)}\" => { \"location_name\"=>\"#{wf.location_name}\",\"energy_plus_location_name\"=>\"#{wf.energy_plus_location_name}\", \"country\" => \"#{wf.country}\", \"state_province\" => \"#{wf.state_province_region}\", \"city\" => \"#{wf.city}\",\"hdd18\" => #{wf.hdd18},\"cdd18\" => #{wf.cdd18},\"latitude\" => #{wf.latitude}, \"longitude\" => #{wf.longitude}, \"elevation\" => #{wf.elevation}, \"monthly_dry_bulb\" => \"#{wf.monthly_dry_bulb}\", \"delta_dry_bulb\" => #{wf.delta_dry_bulb} ,\"a90_1_2004_climate_zone\" => #{wf.a90_1_2004_climate_zone}},\n" )
          
          counter += 1
        end
        file.write(data)
        
      }
      puts "parsed #{counter} weather files."
    end
    
    


    class StatFile
      attr_accessor :path
      attr_accessor :valid
      attr_accessor :lat
      attr_accessor :lon
      attr_accessor :elevation
      attr_accessor :gmt
      attr_accessor :monthly_dry_bulb
      attr_accessor :hdd18
      attr_accessor :cdd18
      attr_accessor :hdd10
      attr_accessor :cdd10
      attr_accessor :heating_design_info
      attr_accessor :cooling_design_info
      attr_accessor :extremes_design_info
      attr_accessor :a90_1_2004_climate_zone

      #This method initializes.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param path [String]
      def initialize(path)
        @path = Pathname.new(path)
        @valid = false
        @lat = []
        @lon = []
        @gmt = []
        @elevation = []
        @hdd18 = []
        @cdd18 = []
        @hdd10 = []
        @cdd10 = []
        @monthly_dry_bulb = []
        @delta_dry_bulb = []
        @heating_design_info = []
        @cooling_design_info  = []
        @extremes_design_info = []
        @a90_1_2004_climate_zone = []
        init
      end

      def valid?
        return @valid
      end

      # the mean of the mean monthly dry bulbs
      def mean_dry_bulb
        if not @monthly_dry_bulb.empty? then
          sum = 0
          @monthly_dry_bulb.each { |db| sum += db }
          mean = sum/@monthly_dry_bulb.size
        else
          mean = ""
        end
        mean
      end

      # max - min of the mean monthly dry bulbs
      def delta_dry_bulb
        if not @monthly_dry_bulb.empty? then
          delta_t = @monthly_dry_bulb.max-@monthly_dry_bulb.min
        else
          delta_t = ""
        end

        delta_t
      end

      private

      # initialize
      def init
        if @path.exist?
          text = File.read(@path).force_encoding("iso-8859-1")
          parse(text)
          #get HDD and CDD 18 in a better manner.
          unless File.exist?(@path)
            raise 'File does not exist: ' + @path.to_s
          end
          File.open(@path).each do |l|
            line = String.new(l)
            if line.include?("HDD base 18C")
              @hdd18 = line.split(' ')[3..14].map { |x| x.to_i }.inject{|sum,x| sum + x }.to_f
            end
            if line.include?("CDD base 18C")
              @cdd18 = line.split(' ')[3..14].map { |x| x.to_i }.inject{|sum,x| sum + x }.to_f
              break
            end
          end
          raise ("Invalid Weather file: Could not determine HDD or CDD from weatherstatfile. @path") if @cdd18.nil? or @hdd18.nil?
        end
      end

      #This method  parses text.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param text [String]
      #@return [Void]
      def parse(text)

        # get lat, lon, gmt
        regex = /\{(N|S)\s*([0-9]*).\s*([0-9]*)'\}\s*\{(E|W)\s*([0-9]*).\s*([0-9]*)'\}\s*\{GMT\s*(.*)\s*Hours\}/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find lat/lon/gmt"
          return
        else

          @lat = match_data[2].to_f + (match_data[3].to_f)/60.0
          if match_data[1] == 'S'
            @lat = -@lat
          end

          @lon = match_data[5].to_f + (match_data[6].to_f)/60.0
          if match_data[4] == 'W'
            @lon = -@lon
          end

          @gmt = match_data[7]
        end

        # get elevation
        regex = /Elevation --\s*(.*)m (above|below) sea level/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find elevation"
          return
        else
          @elevation = match_data[1].to_f
          if match_data[2] == 'below'
            @elevation = -@elevation
          end
        end

        # - Climate type "7" (ASHRAE Standards 90.1-2004 and 90.2-2004 Climate Zone)**
        # get elevation
        regex = /- Climate type \"(.*)\" \(ASHRAE Standards 90\.1\-2004 and 90\.2\-2004 Climate Zone\)\*\*/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find climate zone"
          return
        else
          @a90_1_2004_climate_zone  = "#{match_data[1].strip}"
        end





        # get heating and cooling degree days
        cdd10Regex = /-\s*(.*) annual \(standard\) cooling degree-days \(10.*C baseline\)/
        match_data = text.match(cdd10Regex)
        if match_data.nil?
          puts "Can't find CDD 10"
        else
          @cdd10 = match_data[1].to_f
        end

        hdd10Regex = /-\s*(.*) annual \(standard\) heating degree-days \(10.*C baseline\)/
        match_data = text.match(hdd10Regex)
        if match_data.nil?
          puts "Can't find HDD 10"
        else
          @hdd10 = match_data[1].to_f
        end

        cdd18Regex = /-\s*(.*) annual \(standard\) cooling degree-days \(18.3.*C baseline\)/
        match_data = text.match(cdd18Regex)
        if match_data.nil?
          puts "Can't find CDD 18"
        else
          @cdd18 = match_data[1].to_f
        end
        
        hdd18Regex = /-\s*(.*) annual \(standard\) heating degree-days \(18.3.*C baseline\)/
        match_data = text.match(hdd18Regex)
        if match_data.nil?
          puts "Can't find HDD 18"
        else
          @hdd18 = match_data[1].to_f
        end
        
        
        #      Design Stat	ColdestMonth	DB996	DB990	DP996	HR_DP996	DB_DP996	DP990	HR_DP990	DB_DP990	WS004c	DB_WS004c	WS010c	DB_WS010c	WS_DB996	WD_DB996	
        #    	Units	{}	{ï¿½C}	{ï¿½C}	{ï¿½C}	{}	{ï¿½C}	{ï¿½C}	{}	{ï¿½C}	{m/s}	{ï¿½C}	{m/s}	{ï¿½C}	{m/s}	{deg}	
        #    	Heating	12	-7	-4	-13.9	1.1	-5	-9.6	1.7	-2.9	14.2	5.9	11.9	6.8	2.9	100
        #use regex to get the temperatures
        regex = /\s*Heating(\s*\d+.*)\n/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find heating design information"
        else
          # first match is outdoor air temps
          
          heating_design_info_raw = match_data[1].strip.split(/\s+/)

          # have to be 14 data points
          if heating_design_info_raw.size != 15
            puts "Can't find cooling design info, found #{heating_design_info_raw.size}"
          end

          # insert as numbers
          heating_design_info_raw.each do |value| 
            @heating_design_info << value.to_f 
          end
          #puts @heating_design_info
        end
        
        regex = /\s*Cooling(\s*\d+.*)\n/ 
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find cooling design information"
        else
          # first match is outdoor air temps
          
          design_info_raw = match_data[1].strip.split(/\s+/)

          # have to be 14 data points
          if design_info_raw.size != 32
            puts "Can't find cooling design info, found #{design_info_raw.size} "
          end

          # insert as numbers
          design_info_raw.each do |value| 
            @cooling_design_info << value 
          end
          #puts @cooling_design_info
        end
        
        regex = /\s*Extremes\s*(.*)\n/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find extremes design information"
        else
          # first match is outdoor air temps
          
          design_info_raw = match_data[1].strip.split(/\s+/)

          # have to be 14 data points
          if design_info_raw.size != 16
            #puts "Can't find extremes design info"
          end

          # insert as numbers
          design_info_raw.each do |value| 
            @extremes_design_info << value 
          end
          #puts @extremes_design_info
        end
        
        


        #use regex to get the temperatures
        regex = /Daily Avg(.*)\n/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find outdoor air temps"
        else
          # first match is outdoor air temps
          monthly_temps = match_data[1].strip.split(/\s+/)

          # have to be 12 months
          if monthly_temps.size != 12
            puts "Can't find outdoor air temps"
          end

          # insert as numbers
          monthly_temps.each { |temp| @monthly_dry_bulb << temp.to_f }
          #puts "#{@monthly_dry_bulb}"
        end

        # now we are valid
        @valid = true
      end

    end
    class WeatherFile

      attr_accessor :location_name,
        :energy_plus_location_name,
        :latitude,
        :longitude,
        :elevation,
        :city,
        :state_province_region,
        :country,
        :hdd18,
        :cdd18,
        :hdd10,
        :cdd10,
        :monthly_dry_bulb,
        :delta_dry_bulb,
        :a90_1_2004_climate_zone
      
      attr_accessor :heating_design_info
      attr_accessor :cooling_design_info
      attr_accessor :extremes_design_info

      Year = 0
      Month = 1
      Day = 2
      Hour= 3
      Minute = 4
      Data_Source = 5
      Dry_Bulb_Temperature = 6
      Dew_Point_Temperature = 7
      Relative_Humidity = 8
      Atmospheric_Station_Pressure = 9
      Extraterrestrial_Horizontal_Radiation = 10 #not used
      Extraterrestrial_Direct_Normal_Radiation = 11 #not used
      Horizontal_Infrared_Radiation_Intensity = 12
      Global_Horizontal_Radiation = 13 #not used
      Direct_Normal_Radiation = 14
      Diffuse_Horizontal_Radiation = 15
      Global_Horizontal_Illuminance = 16 #not used
      Direct_Normal_Illuminance = 17#not used
      Diffuse_Horizontal_Illuminance = 18#not used
      Zenith_Luminance = 19#not used
      Wind_Direction = 20
      Wind_Speed = 21
      Total_Sky_Cover = 22#not used
      Opaque_Sky_Cover = 23#not used
      Visibility = 24#not used
      Ceiling_Height = 25#not used
      Present_Weather_Observation = 26
      Present_Weather_Codes = 27
      Precipitable_Water = 28 #not used
      Aerosol_Optical_Depth = 29 #not used
      Snow_Depth = 30
      Days_Since_Last_Snowfall = 31#not used
      Albedo = 32 #not used
      Liquid_Precipitation_Depth = 33
      Liquid_Precipitation_Quantity = 34

      #This method initializes and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param weather_file [String]
      #@return [String] self
      def initialize(weather_file)
        # Define the openstudio-standards weather location
        top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
        weather_dir = "#{top_dir}/data/weather"
        
        # First check if the epw file exists at a full path.  If not found there,
        # check for the file in the openstudio-standards/data/weather directory.
        weather_file = weather_file.to_s
        @epw_filepath = nil
        @ddy_filepath = nil
        @stat_filepath = nil
        if File.exists?(weather_file)
          @epw_filepath = "#{weather_file}"
          @ddy_filepath = "#{weather_file.sub('epw','ddy')}"
          @stat_filepath = "#{weather_file.sub('epw','stat')}"
        elsif File.exists?("#{weather_dir}/#{weather_file}")
          @epw_filepath = "#{weather_dir}/#{weather_file}"
          @ddy_filepath = "#{weather_dir}/#{weather_file.sub('epw','ddy')}"
          @stat_filepath = "#{weather_dir}/#{weather_file.sub('epw','stat')}"
        else
          raise("Could not find weather file #{weather_file}.  Make sure file path is correct.")
        end
        
        # Ensure that epw, ddy, and stat file all exist
        raise("Weather file #{@epw_filepath} not found.") unless File.exists?(@epw_filepath) && @epw_filepath.downcase.include?('.epw')
        raise("Weather file ddy #{@ddy_filepath} not found.") unless File.exists?(@ddy_filepath) && @ddy_filepath.downcase.include?('.ddy')
        raise("Weather file stat #{@stat_filepath} not found.") unless File.exists?(@stat_filepath) && @stat_filepath.downcase.include?('.stat')

        #load file objects.
        @epw_file = OpenStudio::EpwFile.new(OpenStudio::Path.new(@epw_filepath))
        if OpenStudio::EnergyPlus.loadAndTranslateIdf(@ddy_filepath).empty?
          raise ("Unable to load ddy idf file#{@ddy_filepath}.")
        else
          @ddy_file = OpenStudio::EnergyPlus.loadAndTranslateIdf(@ddy_filepath).get
        end
        @stat_file = StatFile.new( @stat_filepath )

        #assign variables.
        
        @latitude = @epw_file.latitude
        @longitude = @epw_file.longitude
        @elevation = @epw_file.elevation
        @city = @epw_file.city
        @state_province_region =  @epw_file.stateProvinceRegion
        @country = @epw_file.country
        @hdd18 = @stat_file.hdd18
        @cdd18 = @stat_file.cdd18
        @hdd10 = @stat_file.hdd10
        @cdd10 = @stat_file.cdd10
        @monthly_dry_bulb = @stat_file.monthly_dry_bulb
        @mean_dry_bulb = @stat_file.mean_dry_bulb
        @delta_dry_bulb = @stat_file.delta_dry_bulb
        @location_name = "#{@country}-#{@state_province_region}-#{@city}"
        @energy_plus_location_name = "#{@city}_#{@state_province_region}_#{@country}"
        @heating_design_info = @stat_file.heating_design_info 
        @cooling_design_info  = @stat_file.cooling_design_info
        @extremes_design_info = @stat_file.extremes_design_info
        @a90_1_2004_climate_zone = @stat_file.a90_1_2004_climate_zone
        

        return self
      end

      #This method will set the weather file and returns a log string.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      #@return [String] log
      def set_weather_file(model, runner = nil)
        BTAP::runner_register("Info", "BTAP::Environment::WeatherFile::set_weather",runner)
        OpenStudio::Model::WeatherFile::setWeatherFile(model, @epw_file)
        BTAP::runner_register("Info", "Set model \"#{model.building.get.name}\" to weather file #{model.weatherFile.get.path.get}.\n",runner)

        # Add or update site data
        site = model.getSite
        site.setName("#{@epw_file.city}_#{@epw_file.stateProvinceRegion}_#{@epw_file.country}")
        site.setLatitude(@epw_file.latitude)
        site.setLongitude(@epw_file.longitude)
        site.setTimeZone(@epw_file.timeZone)
        site.setElevation(@epw_file.elevation)

        BTAP::runner_register("Info","Setting water main temperatures via parsing of STAT file.", runner ) 
        water_temp = model.getSiteWaterMainsTemperature
        water_temp.setAnnualAverageOutdoorAirTemperature(@stat_file.mean_dry_bulb)
        water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(@stat_file.delta_dry_bulb)
        BTAP::runner_register("Info","SiteWaterMainsTemperature.AnnualAverageOutdoorAirTemperature = #{@stat_file.mean_dry_bulb}.", runner ) 
        BTAP::runner_register("Info","SiteWaterMainsTemperature.MaximumDifferenceInMonthlyAverageOutdoorAirTemperatures = #{@stat_file.delta_dry_bulb}.", runner ) 

        # Remove all the Design Day objects that are in the file
        model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each { |d| d.remove }

        # Load in the ddy file based on convention that it is in the same directory and has the same basename as the weather
        @ddy_file.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each do |d|
          # grab only the ones that matter
          ddy_list = /(Htg 99.6. Condns DB)|(Clg .4. Condns WB=>MDB)|(Clg .4% Condns DB=>MWB)/
          if d.name.get =~ ddy_list
            BTAP::runner_register("Info","Adding design day '#{d.name}'.",runner)
            # add the object to the existing model
            model.addObject(d.clone)
          end
        end
        return true
      end

      #This method scans.
      #@author phylroy.lopez@nrcan.gc.ca
      def scan()
        @filearray = Array.new()
        file = File.new(@epw_filepath, "r")
        while (line = file.gets)
          @filearray.push(line.split(","))
        end
        file.close
      end

      #This method will sets column to a value.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param column [String]
      #@param value [Fixnum]
      def setcolumntovalue(column,value)
        @filearray.each do |line|
          unless line.first =~ /\D(.*)/
            line[column] = value
          end
        end
      end

      #This method will eliminate all radiation and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return  [String] self
      def eliminate_all_radiation()
        self.scan() if @filearray == nil
        setcolumntovalue(Extraterrestrial_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Extraterrestrial_Direct_Normal_Radiation,"0")#not used
        setcolumntovalue(Horizontal_Infrared_Radiation_Intensity,"315")
        setcolumntovalue(Global_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Direct_Normal_Radiation,"0")
        setcolumntovalue(Diffuse_Horizontal_Radiation,"0")
        setcolumntovalue(Total_Sky_Cover,"10")#not used
        setcolumntovalue(Opaque_Sky_Cover,"10")#not used
        setcolumntovalue(Visibility,"0")#not used
        setcolumntovalue(Ceiling_Height,"0")#not used
        #lux values
        setcolumntovalue(Global_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Direct_Normal_Illuminance,"0")#not used
        setcolumntovalue(Diffuse_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Zenith_Luminance,"0")#not used
        return self
      end

      #This method will eliminate solar radiation and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return  [String] self
      def eliminate_only_solar_radiation()
        self.scan() if @filearray == nil
        setcolumntovalue(Global_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Direct_Normal_Radiation,"0")
        setcolumntovalue(Diffuse_Horizontal_Radiation,"0")
        return self
      end

      #This method will eliminate all radiation except solar and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return [String] self
      def eliminate_all_radiation_except_solar()
        self.scan() if @filearray == nil
        setcolumntovalue(Extraterrestrial_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Extraterrestrial_Direct_Normal_Radiation,"0")#not used
        setcolumntovalue(Horizontal_Infrared_Radiation_Intensity,"315")
        setcolumntovalue(Total_Sky_Cover,"10")#not used
        setcolumntovalue(Opaque_Sky_Cover,"10")#not used
        setcolumntovalue(Visibility,"0")#not used
        setcolumntovalue(Ceiling_Height,"0")#not used
        #lux values
        setcolumntovalue(Global_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Direct_Normal_Illuminance,"0")#not used
        setcolumntovalue(Diffuse_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Zenith_Luminance,"0")#not used
        return self
      end

      #This method will eliminate percipitation and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return  [String] self
      def eliminate_percipitation
        self.scan() if @filearray == nil
        setcolumntovalue(Present_Weather_Observation, "0")
        setcolumntovalue(Present_Weather_Codes,"999999999") #no weather. Clear day.
        setcolumntovalue(Snow_Depth,"0")
        setcolumntovalue(Liquid_Precipitation_Depth,"0")
        setcolumntovalue(Liquid_Precipitation_Quantity,"0")
        return self
      end

      #This method eliminates wind and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return  [String] self
      def eliminate_wind
        self.scan() if @filearray == nil
        setcolumntovalue(Wind_Direction,"0")
        setcolumntovalue(Wind_Speed,"0")
        return self
      end

      #This method sets Constant Dry and Dew Point Temperature Humidity And Pressure and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param dbt [Float] dry bulb temperature
      #@param dpt [Float] dew point temperature
      #@param hum [Fixnum] humidity
      #@param press [Fixnum] pressure
      #@return [String] self
      def setConstantDryandDewPointTemperatureHumidityAndPressure(dbt = "0.0",dpt="-1.1",hum="92",press="98500")
        self.scan() if @filearray == nil
        setcolumntovalue(Dry_Bulb_Temperature,dbt)
        setcolumntovalue(Dew_Point_Temperature,dpt)
        setcolumntovalue(Relative_Humidity,hum)
        setcolumntovalue(Atmospheric_Station_Pressure,press)
        return self
      end

      #This method writes to a file.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param filename [String]
      def writetofile(filename)
        self.scan() if @filearray == nil

        begin
          FileUtils.mkdir_p(File.dirname(filename))
          file = File.open(filename, "w")
          @filearray.each do |line|
            firstvalue = true
            newline = ""
            line.each do |value|
              if firstvalue == true
                firstvalue = false
              else
                newline = newline +","
              end
              newline = newline + value
            end
            file.puts(newline)
          end
        rescue IOError => e
          #some error occur, dir not writable etc.
        ensure
          file.close unless file == nil
        end
        #copies original file
        FileUtils.cp(@ddy_filepath, "#{File.dirname(filename)}/#{File.basename(filename,'.epw')}.ddy")
        FileUtils.cp(@stat_filepath, "#{File.dirname(filename)}/#{File.basename(filename,'.epw')}.stat")
      end

    end #Environment




  end
end

