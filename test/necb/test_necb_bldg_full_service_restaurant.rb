require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

##FullServiceRestaurant
class TestNECBFullServiceRestaurant < CreateDOEPrototypeBuildingTest
  building_types = ['FullServiceRestaurant']
  templates = ['NECB2011', 'NECB2015']
  climate_zones = ['NECB HDD Method']
  epw_files = [
      'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
  ]
  create_models = true
  run_models = false
  compare_results = false
  debug = false
  TestNECBFullServiceRestaurant.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)
end

epw_files = ['CAN_AB_Banff.CS.711220_CWEC2016.epw',
             'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
             'CAN_AB_Edmonton.Intl.AP.711230_CWEC2016.epw',
             'CAN_AB_Edmonton.Stony.Plain.AP.711270_CWEC2016.epw',
             'CAN_AB_Fort.McMurray.AP.716890_CWEC2016.epw',
             'CAN_AB_Grande.Prairie.AP.719400_CWEC2016.epw',
             'CAN_AB_Lethbridge.AP.712430_CWEC2016.epw',
             'CAN_AB_Medicine.Hat.AP.710260_CWEC2016.epw',
             'CAN_BC_Abbotsford.Intl.AP.711080_CWEC2016.epw',
             'CAN_BC_Comox.Valley.AP.718930_CWEC2016.epw',
             'CAN_BC_Crankbrook-Canadian.Rockies.Intl.AP.718800_CWEC2016.epw',
             'CAN_BC_Fort.St.John-North.Peace.Rgnl.AP.719430_CWEC2016.epw',
             'CAN_BC_Hope.Rgnl.Airpark.711870_CWEC2016.epw',
             'CAN_BC_Kamloops.AP.718870_CWEC2016.epw',
             'CAN_BC_Port.Hardy.AP.711090_CWEC2016.epw',
             'CAN_BC_Prince.George.Intl.AP.718960_CWEC2016.epw',
             'CAN_BC_Smithers.Rgnl.AP.719500_CWEC2016.epw',
             'CAN_BC_Summerland.717680_CWEC2016.epw',
             'CAN_BC_Vancouver.Intl.AP.718920_CWEC2016.epw',
             'CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw',
             'CAN_MB_Brandon.Muni.AP.711400_CWEC2016.epw',
             'CAN_MB_The.Pas.AP.718670_CWEC2016.epw',
             'CAN_MB_Winnipeg-Richardson.Intl.AP.718520_CWEC2016.epw',
             'CAN_NB_Fredericton.Intl.AP.717000_CWEC2016.epw',
             'CAN_NB_Miramichi.AP.717440_CWEC2016.epw',
             'CAN_NB_Saint.John.AP.716090_CWEC2016.epw',
             'CAN_NL_Gander.Intl.AP-CFB.Gander.718030_CWEC2016.epw',
             'CAN_NL_Goose.Bay.AP-CFB.Goose.Bay.718160_CWEC2016.epw',
             'CAN_NL_St.Johns.Intl.AP.718010_CWEC2016.epw',
             'CAN_NL_Stephenville.Intl.AP.718150_CWEC2016.epw',
             'CAN_NS_CFB.Greenwood.713970_CWEC2016.epw',
             'CAN_NS_CFB.Shearwater.716010_CWEC2016.epw',
             'CAN_NS_Sable.Island.Natl.Park.716000_CWEC2016.epw',
             'CAN_NT_Inuvik-Zubko.AP.719570_CWEC2016.epw',
             'CAN_NT_Yellowknife.AP.719360_CWEC2016.epw',
             'CAN_NU_Resolute.AP.719240_CWEC2016.epw',
             'CAN_ON_Armstrong.AP.718410_CWEC2016.epw',
             'CAN_ON_CFB.Trenton.716210_CWEC2016.epw',
             'CAN_ON_Dryden.Rgnl.AP.715270_CWEC2016.epw',
             'CAN_ON_London.Intl.AP.716230_CWEC2016.epw',
             'CAN_ON_Moosonee.AP.713980_CWEC2016.epw',
             'CAN_ON_Mount.Forest.716310_CWEC2016.epw',
             'CAN_ON_North.Bay-Garland.AP.717310_CWEC2016.epw',
             'CAN_ON_Ottawa-Macdonald-Cartier.Intl.AP.716280_CWEC2016.epw',
             'CAN_ON_Sault.Ste.Marie.AP.712600_CWEC2016.epw',
             'CAN_ON_Timmins.Power.AP.717390_CWEC2016.epw',
             'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw',
             'CAN_ON_Windsor.Intl.AP.715380_CWEC2016.epw',
             'CAN_PE_Charlottetown.AP.717060_CWEC2016.epw',
             'CAN_QC_Kuujjuaq.AP.719060_CWEC2016.epw',
             'CAN_QC_Kuujuarapik.AP.719050_CWEC2016.epw',
             'CAN_QC_Lac.Eon.AP.714210_CWEC2016.epw',
             'CAN_QC_Mont-Joli.AP.717180_CWEC2016.epw',
             'CAN_QC_Montreal-Mirabel.Intl.AP.719050_CWEC2016.epw',
             'CAN_QC_Montreal-St-Hubert.Longueuil.AP.713710_CWEC2016.epw',
             'CAN_QC_Montreal-Trudeau.Intl.AP.716270_CWEC2016.epw',
             'CAN_QC_Quebec-Lesage.Intl.AP.717140_CWEC2016.epw',
             'CAN_QC_Riviere-du-Loup.717150_CWEC2016.epw',
             'CAN_QC_Roberval.AP.717280_CWEC2016.epw',
             'CAN_QC_Saguenay-Bagotville.AP-CFB.Bagotville.717270_CWEC2016.epw',
             'CAN_QC_Schefferville.AP.718280_CWEC2016.epw',
             'CAN_QC_Sept-Iles.AP.718110_CWEC2016.epw',
             'CAN_QC_Val-d-Or.Rgnl.AP.717250_CWEC2016.epw',
             'CAN_SK_Estevan.Rgnl.AP.718620_CWEC2016.epw',
             'CAN_SK_North.Battleford.AP.718760_CWEC2016.epw',
             'CAN_SK_Saskatoon.Intl.AP.718660_CWEC2016.epw',
             'CAN_YT_Whitehorse.Intl.AP.719640_CWEC2016.epw'
]


