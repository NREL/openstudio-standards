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


require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class UtilityTariffsTest < MiniTest::Unit::TestCase
  
  def set_weather(epw_filename)
    weather_folder = "#{File.dirname(__FILE__)}/../../../weather"
    output_folder = "#{File.dirname(__FILE__)}/output"
    # create an instance of the measure, a runner and an empty model
    measure = UtilityTariffsModelSetup.new
    runner = OpenStudio::Ruleset::OSRunner.new
    #load osm file. 
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/system_2.osm")
    BTAP::runner_register("INFO", "EPW file is #{epw_filename}", runner)

    #set weather file. 
    BTAP::Environment::WeatherFile.new("#{weather_folder}/#{epw_filename.to_s}").set_weather_file(model)
  
    # translate osm to idf
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # argument list
    args = OpenStudio::Ruleset::OSArgumentVector.new
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(args)

    # run the measure
    measure.run(workspace, runner, argument_map)
    condition = assert_equal("Success", runner.result.value.valueName)
    workspace.save("#{output_folder}/#{File.basename(epw_filename, ".epw")}.idf",true)
    #return condition of measure.
    return condition
  end

  def testCAN_AB_Calgary_718770_CWEC 
    set_weather("CAN_AB_Calgary.718770_CWEC.epw")
  end
  
  def testCAN_AB_Edmonton_711230_CWEC 
    set_weather("CAN_AB_Edmonton.711230_CWEC.epw")
  end
  def testCAN_AB_Fort_McMurray_719320_CWEC 
    set_weather("CAN_AB_Fort.McMurray.719320_CWEC.epw")
  end
  def testCAN_AB_Grande_Prairie_719400_CWEC 
    set_weather("CAN_AB_Grande.Prairie.719400_CWEC.epw")
  end
  def testCAN_AB_Lethbridge_712430_CWEC 
    set_weather("CAN_AB_Lethbridge.712430_CWEC.epw")
  end
  def testCAN_AB_Medicine_Hat_718720_CWEC 
    set_weather("CAN_AB_Medicine.Hat.718720_CWEC.epw")
  end
  def testCAN_BC_Abbotsford_711080_CWEC 
    set_weather("CAN_BC_Abbotsford.711080_CWEC.epw")
  end
  def testCAN_BC_Comox_718930_CWEC 
    set_weather("CAN_BC_Comox.718930_CWEC.epw")
  end
  def testCAN_BC_Cranbrook_718800_CWEC 
    set_weather("CAN_BC_Cranbrook.718800_CWEC.epw")
  end
  def testCAN_BC_Fort_St_John_719430_CWEC 
    set_weather("CAN_BC_Fort.St.John.719430_CWEC.epw")
  end
  def testCAN_BC_Kamloops_718870_CWEC 
    set_weather("CAN_BC_Kamloops.718870_CWEC.epw")
  end
  def testCAN_BC_Port_Hardy_711090_CWEC
    set_weather("CAN_BC_Port.Hardy.711090_CWEC.epw")
  end
  def testCAN_BC_Prince_George_718960_CWEC 
    set_weather("CAN_BC_Prince.George.718960_CWEC.epw")
  end
  def testCAN_BC_Prince_Rupert_718980_CWEC 
    set_weather("CAN_BC_Prince.Rupert.718980_CWEC.epw")
  end
  def testCAN_BC_Sandspit_711010_CWEC 
    set_weather("CAN_BC_Sandspit.711010_CWEC.epw")
  end
  def testCAN_BC_Smithers_719500_CWEC 
    set_weather("CAN_BC_Smithers.719500_CWEC.epw")
  end
  def testCAN_BC_Summerland_717680_CWEC 
    set_weather("CAN_BC_Summerland.717680_CWEC.epw")
  end
  def testCAN_BC_Vancouver_718920_CWEC 
    set_weather("CAN_BC_Vancouver.718920_CWEC.epw")
  end
  def testCAN_BC_Victoria_717990_CWEC 
    set_weather("CAN_BC_Victoria.717990_CWEC.epw")
  end
  def testCAN_MB_Brandon_711400_CWEC 
    set_weather("CAN_MB_Brandon.711400_CWEC.epw")
  end
  def testCAN_MB_Churchill_719130_CWEC 
    set_weather("CAN_MB_Churchill.719130_CWEC.epw")
  end
  def testCAN_MB_The_Pas_718670_CWEC 
    set_weather("CAN_MB_The.Pas.718670_CWEC.epw")
  end
  def testCAN_MB_Winnipeg_718520_CWEC 
    set_weather("CAN_MB_Winnipeg.718520_CWEC.epw")
  end
  def testCAN_NB_Fredericton_717000_CWEC 
    set_weather("CAN_NB_Fredericton.717000_CWEC.epw")
  end
  def testCAN_NB_Miramichi_717440_CWEC 
    set_weather("CAN_NB_Miramichi.717440_CWEC.epw")
  end
  def testCAN_NB_Saint_John_716090_CWEC 
    set_weather("CAN_NB_Saint.John.716090_CWEC.epw")
  end
  def testCAN_NF_Battle_Harbour_718170_CWEC 
    set_weather("CAN_NF_Battle.Harbour.718170_CWEC.epw")
  end
  def testCAN_NF_Gander_718030_CWEC 
    set_weather("CAN_NF_Gander.718030_CWEC.epw")
  end
  def testCAN_NF_Goose_718160_CWEC 
    set_weather("CAN_NF_Goose.718160_CWEC.epw")
  end
  def testCAN_NF_St_Johns_718010_CWEC 
    set_weather("CAN_NF_St.Johns.718010_CWEC.epw")
  end
  def testCAN_NF_Stephenville_718150_CWEC 
    set_weather("CAN_NF_Stephenville.718150_CWEC.epw")
  end
  def testCAN_NS_Greenwood_713970_CWEC 
    set_weather("CAN_NS_Greenwood.713970_CWEC.epw")
  end
  def testCAN_NS_Sable_Island_716000_CWEC 
    set_weather("CAN_NS_Sable.Island.716000_CWEC.epw")
  end
  def testCAN_NS_Shearwater_716010_CWEC 
    set_weather("CAN_NS_Shearwater.716010_CWEC.epw")
  end
  def testCAN_NS_Sydney_717070_CWEC 
    set_weather("CAN_NS_Sydney.717070_CWEC.epw")
  end
  def testCAN_NS_Truro_713980_CWEC 
    set_weather("CAN_NS_Truro.713980_CWEC.epw")
  end
  def testCAN_NT_Inuvik_719570_CWEC 
    set_weather("CAN_NT_Inuvik.719570_CWEC.epw")
  end
  def testCAN_NU_Resolute_719240_CWEC 
    set_weather("CAN_NU_Resolute.719240_CWEC.epw")
  end
  def testCAN_ON_Kingston_716200_CWEC 
    set_weather("CAN_ON_Kingston.716200_CWEC.epw")
  end
  def testCAN_ON_London_716230_CWEC 
    set_weather("CAN_ON_London.716230_CWEC.epw")
  end
  def testCAN_ON_Mount_Forest_716310_CWEC 
    set_weather("CAN_ON_Mount.Forest.716310_CWEC.epw")
  end
  def testCAN_ON_Muskoka_716300_CWEC 
    set_weather("CAN_ON_Muskoka.716300_CWEC.epw")
  end
  def testCAN_ON_North_Bay_717310_CWEC 
    set_weather("CAN_ON_North.Bay.717310_CWEC.epw")
  end
  def testCAN_ON_Ottawa_716280_CWEC 
    set_weather("CAN_ON_Ottawa.716280_CWEC.epw")
  end
  def testCAN_ON_Sault_Ste_Marie_712600_CWEC 
    set_weather("CAN_ON_Sault.Ste.Marie.712600_CWEC.epw")
  end
  def testCAN_ON_Simcoe_715270_CWEC 
    set_weather("CAN_ON_Simcoe.715270_CWEC.epw")
  end
  def testCAN_ON_Thunder_Bay_717490_CWEC 
    set_weather("CAN_ON_Thunder.Bay.717490_CWEC.epw")
  end
  def testCAN_ON_Timmins_717390_CWEC 
    set_weather("CAN_ON_Timmins.717390_CWEC.epw")
  end
  def testCAN_ON_Toronto_716240_CWEC 
    set_weather("CAN_ON_Toronto.716240_CWEC.epw")
  end
  def testCAN_ON_Trenton_716210_CWEC 
    set_weather("CAN_ON_Trenton.716210_CWEC.epw")
  end
  def testCAN_ON_Windsor_715380_CWEC 
    set_weather("CAN_ON_Windsor.715380_CWEC.epw")
  end
  def testCAN_PE_Charlottetown_717060_CWEC 
    set_weather("CAN_PE_Charlottetown.717060_CWEC.epw")
  end
  def testCAN_PQ_Bagotville_717270_CWEC 
    set_weather("CAN_PQ_Bagotville.717270_CWEC.epw")
  end
  def testCAN_PQ_Baie_Comeau_711870_CWEC 
    set_weather("CAN_PQ_Baie.Comeau.711870_CWEC.epw")
  end
  def testCAN_PQ_Grindstone_Island_CWEC 
    set_weather("CAN_PQ_Grindstone.Island_CWEC.epw")
  end
  def testCAN_PQ_Kuujjuarapik_719050_CWEC 
    set_weather("CAN_PQ_Kuujjuarapik.719050_CWEC.epw")
  end
  def testCAN_PQ_Kuujuaq_719060_CWEC 
    set_weather("CAN_PQ_Kuujuaq.719060_CWEC.epw")
  end
  def testCAN_PQ_La_Grande_Riviere_718270_CWEC 
    set_weather("CAN_PQ_La.Grande.Riviere.718270_CWEC.epw")
  end
  def testCAN_PQ_Lake_Eon_714210_CWEC 
    set_weather("CAN_PQ_Lake.Eon.714210_CWEC.epw")
  end
  def testCAN_PQ_Mont_Joli_717180_CWEC 
    set_weather("CAN_PQ_Mont.Joli.717180_CWEC.epw")
  end
  def testCAN_PQ_Montreal_Intl_AP_716270_CWEC 
    set_weather("CAN_PQ_Montreal.Intl.AP.716270_CWEC.epw")
  end
  def testCAN_PQ_Montreal_Jean_Brebeuf_716278_CWEC 
    set_weather("CAN_PQ_Montreal.Jean.Brebeuf.716278_CWEC.epw")
  end
  def testCAN_PQ_Montreal_Mirabel_716278_CWEC 
    set_weather("CAN_PQ_Montreal.Mirabel.716278_CWEC.epw")
  end
  def testCAN_PQ_Nitchequon_CAN270_CWEC
    set_weather("CAN_PQ_Nitchequon.CAN270_CWEC.epw")
  end
  def testCAN_PQ_Quebec_717140_CWEC 
    set_weather("CAN_PQ_Quebec.717140_CWEC.epw")
  end
  def testCAN_PQ_Riviere_du_Loup_717150_CWEC 
    set_weather("CAN_PQ_Riviere.du.Loup.717150_CWEC.epw")
  end
  def testCAN_PQ_Roberval_717280_CWEC 
    set_weather("CAN_PQ_Roberval.717280_CWEC.epw")
  end
  def testCAN_PQ_Schefferville_718280_CWEC 
    set_weather("CAN_PQ_Schefferville.718280_CWEC.epw")
  end
  def testCAN_PQ_Sept_Iles_718110_CWEC 
    set_weather("CAN_PQ_Sept-Iles.718110_CWEC.epw")
  end
  def testCAN_PQ_Sherbrooke_716100_CWEC 
    set_weather("CAN_PQ_Sherbrooke.716100_CWEC.epw")
  end
  def testCAN_PQ_St_Hubert_713710_CWEC 
    set_weather("CAN_PQ_St.Hubert.713710_CWEC.epw")
  end
  def testCAN_PQ_Ste_Agathe_des_Monts_717200_CWEC 
    set_weather("CAN_PQ_Ste.Agathe.des.Monts.717200_CWEC.epw")
  end
  def testCAN_PQ_Val_d_Or_717250_CWEC 
    set_weather("CAN_PQ_Val.d.Or.717250_CWEC.epw")
  end
  def testCAN_SK_Estevan_718620_CWEC 
    set_weather("CAN_SK_Estevan.718620_CWEC.epw")
  end
  def testCAN_SK_North_Battleford_718760_CWEC 
    set_weather("CAN_SK_North.Battleford.718760_CWEC.epw")
  end
  def testCAN_SK_Regina_718630_CWEC 
    set_weather("CAN_SK_Regina.718630_CWEC.epw")
  end
  def testCAN_SK_Saskatoon_718660_CWEC 
    set_weather("CAN_SK_Saskatoon.718660_CWEC.epw")
  end
  def testCAN_SK_Swift_Current_718700_CWEC 
    set_weather("CAN_SK_Swift.Current.718700_CWEC.epw")
  end
  def testCAN_YT_Whitehorse_719640_CWEC 
    set_weather("CAN_YT_Whitehorse.719640_CWEC.epw")
  end

end
