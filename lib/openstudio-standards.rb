require 'singleton'
require 'open3'
require_relative 'openstudio-standards/version'

module OpenstudioStandards
  require 'json' # Used to load standards JSON files

  # HVAC sizing
  require_relative 'openstudio-standards/hvac_sizing/Siz.Model'

  # Weather data
  require_relative 'openstudio-standards/weather/Weather.Model'

  # HVAC standards
  require_relative 'openstudio-standards/standards/Standards.Model'

  # BTAP (Natural Resources Canada)
  require_relative 'openstudio-standards/btap/btap'

  # Utilities
  require_relative 'openstudio-standards/utilities/logging'
  require_relative 'openstudio-standards/utilities/simulation'
  require_relative 'openstudio-standards/utilities/hash'
  require_relative 'openstudio-standards/utilities/sqlfile'

  stds = 'openstudio-standards/standards'
  proto = 'openstudio-standards/prototypes'

  ### Standards ###
  # Standards classes
  require_relative "#{stds}/standard"
  # NECB2011 Code
  require_relative "#{stds}/necb/NECB2011/necb_2011"
  require_relative "#{stds}/necb/NECB2011/building_envelope"
  require_relative "#{stds}/necb/NECB2011/lighting"
  require_relative "#{stds}/necb/NECB2011/hvac_systems"
  require_relative "#{stds}/necb/NECB2011/autozone"
  require_relative "#{stds}/necb/NECB2011/hvac_system_1_single_speed"
  require_relative "#{stds}/necb/NECB2011/hvac_system_2_and_5"
  require_relative "#{stds}/necb/NECB2011/hvac_system_3_and_8_single_speed"
  require_relative "#{stds}/necb/NECB2011/hvac_system_4"
  require_relative "#{stds}/necb/NECB2011/hvac_system_6"
  require_relative "#{stds}/necb/NECB2011/service_water_heating"
  require_relative "#{stds}/necb/NECB2011/electrical_power_systems_and_motors"
  require_relative "#{stds}/necb/NECB2011/beps_compliance_path"
  # NECB2015 Code
  require_relative "#{stds}/necb/NECB2015/necb_2015"
  require_relative "#{stds}/necb/NECB2015/lighting"
  require_relative "#{stds}/necb/NECB2015/hvac_systems"
  # NECB2017 Code
  require_relative "#{stds}/necb/NECB2017/necb_2017"
  require_relative "#{stds}/necb/NECB2017/hvac_systems"

  # BTAPPRE1980
  require_relative "#{stds}/necb/BTAPPRE1980/btap_pre1980"
  require_relative "#{stds}/necb/BTAPPRE1980/building_envelope"
  require_relative "#{stds}/necb/BTAPPRE1980/hvac_systems"
  require_relative "#{stds}/necb/BTAPPRE1980/hvac_system_3_and_8_single_speed"
  require_relative "#{stds}/necb/BTAPPRE1980/hvac_system_4"
  require_relative "#{stds}/necb/BTAPPRE1980/hvac_system_6"

  # BTAP1980TO2010
  require_relative "#{stds}/necb/BTAP1980TO2010/btap_1980to2010"

  # NECB QAQC
  require_relative "#{stds}/necb/NECB2011/qaqc/necb_qaqc.rb"
  require_relative "#{stds}/necb/NECB2015/qaqc/necb_2015_qaqc.rb"
  
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1"
  require_relative "#{stds}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980"
  require_relative "#{stds}/ashrae_90_1/doe_ref_pre_1980/comstock_doe_ref_pre_1980/comstock_doe_ref_pre_1980"
  require_relative "#{stds}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004"
  require_relative "#{stds}/ashrae_90_1/doe_ref_1980_2004/comstock_doe_ref_1980_2004/comstock_doe_ref_1980_2004"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/comstock_ashrae_90_1_2004/comstock_ashrae_90_1_2004"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/comstock_ashrae_90_1_2007/comstock_ashrae_90_1_2007"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/comstock_ashrae_90_1_2010/comstock_ashrae_90_1_2010"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/comstock_ashrae_90_1_2013/comstock_ashrae_90_1_2013"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily"

  require_relative "#{stds}/deer/deer"
  require_relative "#{stds}/deer/deer_pre_1975/deer_pre_1975"
  require_relative "#{stds}/deer/deer_pre_1975/comstock_deer_pre_1975/comstock_deer_pre_1975"
  require_relative "#{stds}/deer/deer_1985/deer_1985"
  require_relative "#{stds}/deer/deer_1985/comstock_deer_1985/comstock_deer_1985"
  require_relative "#{stds}/deer/deer_1996/deer_1996"
  require_relative "#{stds}/deer/deer_1996/comstock_deer_1996/comstock_deer_1996"
  require_relative "#{stds}/deer/deer_2003/deer_2003"
  require_relative "#{stds}/deer/deer_2003/comstock_deer_2003/comstock_deer_2003"
  require_relative "#{stds}/deer/deer_2007/deer_2007"
  require_relative "#{stds}/deer/deer_2007/comstock_deer_2007/comstock_deer_2007"
  require_relative "#{stds}/deer/deer_2011/deer_2011"
  require_relative "#{stds}/deer/deer_2011/comstock_deer_2011/comstock_deer_2011"
  require_relative "#{stds}/deer/deer_2014/deer_2014"
  require_relative "#{stds}/deer/deer_2014/comstock_deer_2014/comstock_deer_2014"
  require_relative "#{stds}/deer/deer_2015/deer_2015"
  require_relative "#{stds}/deer/deer_2015/comstock_deer_2015/comstock_deer_2015"
  require_relative "#{stds}/deer/deer_2017/deer_2017"
  require_relative "#{stds}/deer/deer_2017/comstock_deer_2017/comstock_deer_2017"
  require_relative "#{stds}/deer/deer_2020/deer_2020"
  require_relative "#{stds}/deer/deer_2020/comstock_deer_2020/comstock_deer_2020"
  require_relative "#{stds}/deer/deer_2025/deer_2025"
  require_relative "#{stds}/deer/deer_2025/comstock_deer_2025/comstock_deer_2025"
  require_relative "#{stds}/deer/deer_2030/deer_2030"
  require_relative "#{stds}/deer/deer_2030/comstock_deer_2030/comstock_deer_2030"
  require_relative "#{stds}/deer/deer_2035/deer_2035"
  require_relative "#{stds}/deer/deer_2035/comstock_deer_2035/comstock_deer_2035"
  require_relative "#{stds}/deer/deer_2040/deer_2040"
  require_relative "#{stds}/deer/deer_2040/comstock_deer_2040/comstock_deer_2040"
  require_relative "#{stds}/deer/deer_2045/deer_2045"
  require_relative "#{stds}/deer/deer_2045/comstock_deer_2045/comstock_deer_2045"
  require_relative "#{stds}/deer/deer_2050/deer_2050"
  require_relative "#{stds}/deer/deer_2050/comstock_deer_2050/comstock_deer_2050"
  require_relative "#{stds}/deer/deer_2055/deer_2055"
  require_relative "#{stds}/deer/deer_2055/comstock_deer_2055/comstock_deer_2055"
  require_relative "#{stds}/deer/deer_2060/deer_2060"
  require_relative "#{stds}/deer/deer_2060/comstock_deer_2060/comstock_deer_2060"
  require_relative "#{stds}/deer/deer_2065/deer_2065"
  require_relative "#{stds}/deer/deer_2065/comstock_deer_2065/comstock_deer_2065"
  require_relative "#{stds}/deer/deer_2070/deer_2070"
  require_relative "#{stds}/deer/deer_2070/comstock_deer_2070/comstock_deer_2070"
  require_relative "#{stds}/deer/deer_2075/deer_2075"
  require_relative "#{stds}/deer/deer_2075/comstock_deer_2075/comstock_deer_2075"

  require_relative "#{stds}/oeesc/oeesc"
  require_relative "#{stds}/oeesc/oeesc_2014/oeesc_2014"

  require_relative "#{stds}/icc_iecc/icc_iecc"
  require_relative "#{stds}/icc_iecc/icc_iecc_2015/icc_iecc_2015"

  require_relative "#{stds}/cbes/cbes"
  require_relative "#{stds}/cbes/cbes_pre_1978/cbes_pre_1978"
  require_relative "#{stds}/cbes/cbes_t24_1978/cbes_t24_1978"
  require_relative "#{stds}/cbes/cbes_t24_1992/cbes_t24_1992"
  require_relative "#{stds}/cbes/cbes_t24_2001/cbes_t24_2001"
  require_relative "#{stds}/cbes/cbes_t24_2005/cbes_t24_2005"
  require_relative "#{stds}/cbes/cbes_t24_2008/cbes_t24_2008"

  # Files with modules
  require_relative "#{stds}/Standards.Fan"
  require_relative "#{stds}/Standards.CoilDX"
  require_relative "#{stds}/Standards.Pump"
  require_relative "#{stds}/Standards.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.CoolingTower"

  # Model Objects
  require_relative "#{stds}/Standards.AirLoopHVAC"
  require_relative "#{stds}/Standards.AirTerminalSingleDuctParallelPIUReheat"
  require_relative "#{stds}/Standards.AirTerminalSingleDuctVAVReheat"
  require_relative "#{stds}/Standards.BoilerHotWater"
  require_relative "#{stds}/Standards.BuildingStory"
  require_relative "#{stds}/Standards.ChillerElectricEIR"
  require_relative "#{stds}/Standards.CoilCoolingDXMultiSpeed"
  require_relative "#{stds}/Standards.CoilCoolingDXSingleSpeed"
  require_relative "#{stds}/Standards.CoilCoolingDXTwoSpeed"
  require_relative "#{stds}/Standards.CoilCoolingWaterToAirHeatPumpEquationFit"
  require_relative "#{stds}/Standards.CoilDX"
  require_relative "#{stds}/Standards.CoilHeatingDXMultiSpeed"
  require_relative "#{stds}/Standards.CoilHeatingDXSingleSpeed"
  require_relative "#{stds}/Standards.CoilHeatingGasMultiStage"
  require_relative "#{stds}/Standards.CoilHeatingGas"
  require_relative "#{stds}/Standards.CoilHeatingWaterToAirHeatPumpEquationFit"
  require_relative "#{stds}/Standards.Construction"
  require_relative "#{stds}/Standards.CoolingTower"
  require_relative "#{stds}/Standards.CoolingTowerSingleSpeed"
  require_relative "#{stds}/Standards.CoolingTowerTwoSpeed"
  require_relative "#{stds}/Standards.CoolingTowerVariableSpeed"
  require_relative "#{stds}/Standards.Fan"
  require_relative "#{stds}/Standards.FanConstantVolume"
  require_relative "#{stds}/Standards.FanOnOff"
  require_relative "#{stds}/Standards.FanVariableVolume"
  require_relative "#{stds}/Standards.FanZoneExhaust"
  require_relative "#{stds}/Standards.FluidCooler"
  require_relative "#{stds}/Standards.HeaderedPumpsConstantSpeed"
  require_relative "#{stds}/Standards.HeaderedPumpsVariableSpeed"
  require_relative "#{stds}/Standards.HeatExchangerSensLat"
  require_relative "#{stds}/Standards.Model"
  require_relative "#{stds}/Standards.PlanarSurface"
  require_relative "#{stds}/Standards.PlantLoop"
  require_relative "#{stds}/Standards.Pump"
  require_relative "#{stds}/Standards.PumpConstantSpeed"
  require_relative "#{stds}/Standards.PumpVariableSpeed"
  require_relative "#{stds}/Standards.ScheduleCompact"
  require_relative "#{stds}/Standards.ScheduleConstant"
  require_relative "#{stds}/Standards.ScheduleRuleset"
  require_relative "#{stds}/Standards.Space"
  require_relative "#{stds}/Standards.SpaceType"
  require_relative "#{stds}/Standards.SubSurface"
  require_relative "#{stds}/Standards.Surface"
  require_relative "#{stds}/Standards.ThermalZone"
  require_relative "#{stds}/Standards.WaterHeaterMixed"
  require_relative "#{stds}/Standards.ZoneHVACComponent"
  # 90.1 Common
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1.Standards.FanVariableVolume"
  # 90.1-2004
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.FanVariableVolume"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.Model"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.PlantLoop"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.Space"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.ThermalZone"
  # 90.1-2007
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.FanVariableVolume"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.Model"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.Space"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.ThermalZone"
  # 90.1-2010
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.AirTerminalSingleDuctVAVReheat"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.CoolingTowerSingleSpeed"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.CoolingTowerTwoSpeed"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.CoolingTowerVariableSpeed"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.FanVariableVolume"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.Model"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.Space"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.ThermalZone"
  # 90.1-2013
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.AirTerminalSingleDuctVAVReheat"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTowerSingleSpeed"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTowerTwoSpeed"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTowerVariableSpeed"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.FanVariableVolume"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.Model"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.PlantLoop"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.Space"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.ThermalZone"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.WaterHeaterMixed"
  # DOE 1980-2004
  require_relative "#{stds}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.Model"
  require_relative "#{stds}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.PlantLoop"
  # DOE Pre-1980
  require_relative "#{stds}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.Model"
  require_relative "#{stds}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.PlantLoop"
  # NREL ZNE Ready 2017
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.AirTerminalSingleDuctVAVReheat"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTowerSingleSpeed"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTowerTwoSpeed"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTowerVariableSpeed"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.FanVariableVolume"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.HeatExchangerSensLat"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.Model"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.PlantLoop"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.Space"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.ThermalZone"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.ZoneHVACComponent"
  # ZE AEDG Multifamily
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.AirLoopHVAC"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.AirTerminalSingleDuctVAVReheat"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.CoolingTowerSingleSpeed"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.CoolingTowerTwoSpeed"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.CoolingTowerVariableSpeed"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.FanVariableVolume"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.HeatExchangerSensLat"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.Model"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.PlantLoop"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.Space"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.ThermalZone"
  require_relative "#{stds}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.ZoneHVACComponent"
  # DEER Common
  require_relative "#{stds}/deer/deer.Model"
  require_relative "#{stds}/deer/deer.AirLoopHVAC"
  require_relative "#{stds}/deer/deer.Space"
  require_relative "#{stds}/deer/deer.PlanarSurface"
  # CBES Common
  require_relative "#{stds}/cbes/cbes.AirLoopHVAC"
  require_relative "#{stds}/cbes/cbes.Model"
  require_relative "#{stds}/cbes/cbes.PlantLoop"
  require_relative "#{stds}/cbes/cbes.Space"
  # CBES T24 2005
  require_relative "#{stds}/cbes/cbes_t24_2005/cbes_t24_2005.Space"
  # CBES T24 2008
  require_relative "#{stds}/cbes/cbes_t24_2008/cbes_t24_2008.Space"

  ### Prototypes ###
  # Building Types
  require_relative "#{proto}/common/buildings/Prototype.FullServiceRestaurant"
  require_relative "#{proto}/common/buildings/Prototype.HighRiseApartment"
  require_relative "#{proto}/common/buildings/Prototype.Hospital"
  require_relative "#{proto}/common/buildings/Prototype.LargeHotel"
  require_relative "#{proto}/common/buildings/Prototype.LargeOffice"
  require_relative "#{proto}/common/buildings/Prototype.MediumOffice"
  require_relative "#{proto}/common/buildings/Prototype.MidriseApartment"
  require_relative "#{proto}/common/buildings/Prototype.Outpatient"
  require_relative "#{proto}/common/buildings/Prototype.PrimarySchool"
  require_relative "#{proto}/common/buildings/Prototype.QuickServiceRestaurant"
  require_relative "#{proto}/common/buildings/Prototype.RetailStandalone"
  require_relative "#{proto}/common/buildings/Prototype.RetailStripmall"
  require_relative "#{proto}/common/buildings/Prototype.SecondarySchool"
  require_relative "#{proto}/common/buildings/Prototype.SmallHotel"
  require_relative "#{proto}/common/buildings/Prototype.SmallOffice"
  require_relative "#{proto}/common/buildings/Prototype.SuperMarket"
  require_relative "#{proto}/common/buildings/Prototype.Warehouse"
  require_relative "#{proto}/common/buildings/Prototype.SmallDataCenterLowITE"
  require_relative "#{proto}/common/buildings/Prototype.SmallDataCenterHighITE"
  require_relative "#{proto}/common/buildings/Prototype.LargeDataCenterLowITE"
  require_relative "#{proto}/common/buildings/Prototype.LargeDataCenterHighITE"
  require_relative "#{proto}/common/buildings/Prototype.LargeOfficeDetailed"
  require_relative "#{proto}/common/buildings/Prototype.MediumOfficeDetailed"
  require_relative "#{proto}/common/buildings/Prototype.SmallOfficeDetailed"
  require_relative "#{proto}/common/buildings/Prototype.Laboratory"

  # NECB Building Types
  require_relative "#{proto}/common/prototype_metaprogramming.rb"
  create_meta_classes

  # Model Objects
  require_relative "#{proto}/common/objects/Prototype.AirConditionerVariableRefrigerantFlow"
  require_relative "#{proto}/common/objects/Prototype.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/common/objects/Prototype.BoilerHotWater"
  require_relative "#{proto}/common/objects/Prototype.CentralAirSourceHeatPump"
  require_relative "#{proto}/common/objects/Prototype.CoilCoolingDXSingleSpeed"
  require_relative "#{proto}/common/objects/Prototype.CoilCoolingDXTwoSpeed"
  require_relative "#{proto}/common/objects/Prototype.CoilCoolingWater"
  require_relative "#{proto}/common/objects/Prototype.CoilCoolingWaterToAirHeatPumpEquationFit"
  require_relative "#{proto}/common/objects/Prototype.CoilHeatingDXSingleSpeed"
  require_relative "#{proto}/common/objects/Prototype.CoilHeatingElectric"
  require_relative "#{proto}/common/objects/Prototype.CoilHeatingGas"
  require_relative "#{proto}/common/objects/Prototype.CoilHeatingWater"
  require_relative "#{proto}/common/objects/Prototype.CoilHeatingWaterToAirHeatPumpEquationFit"
  require_relative "#{proto}/common/objects/Prototype.ControllerWaterCoil"
  require_relative "#{proto}/common/objects/Prototype.radiant_system_controls"
  require_relative "#{proto}/common/objects/Prototype.Fan"
  require_relative "#{proto}/common/objects/Prototype.FanConstantVolume"
  require_relative "#{proto}/common/objects/Prototype.FanOnOff"
  require_relative "#{proto}/common/objects/Prototype.FanVariableVolume"
  require_relative "#{proto}/common/objects/Prototype.FanZoneExhaust"
  require_relative "#{proto}/common/objects/Prototype.HeatExchangerAirToAirSensibleAndLatent"
  require_relative "#{proto}/common/objects/Prototype.hvac_systems"
  require_relative "#{proto}/common/objects/Prototype.Model.elevators"
  require_relative "#{proto}/common/objects/Prototype.Model.exterior_lights"
  require_relative "#{proto}/common/objects/Prototype.Model.hvac"
  require_relative "#{proto}/common/objects/Prototype.Model"
  require_relative "#{proto}/common/objects/Prototype.Model.swh"
  require_relative "#{proto}/common/objects/Prototype.refrigeration"
  require_relative "#{proto}/common/objects/Prototype.ServiceWaterHeating"
  require_relative "#{proto}/common/objects/Prototype.SizingSystem"
  require_relative "#{proto}/common/objects/Prototype.utilities"
  # 90.1-2004
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004.AirTerminalSingleDuctVAVReheat"
  # 90.1-2007
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.FanConstantVolume"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.FanOnOff"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.FanVariableVolume"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007.AirTerminalSingleDuctVAVReheat"
  # 90.1-2010
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.FanConstantVolume"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.FanOnOff"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.FanVariableVolume"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.Model"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.AirTerminalSingleDuctVAVReheat"
  # 90.1-2013
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.FanConstantVolume"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.FanOnOff"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.FanVariableVolume"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.Model"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.hvac_systems"
  require_relative "#{proto}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.AirTerminalSingleDuctVAVReheat"
  # DOE Ref 1980-2004
  require_relative "#{proto}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.refrigeration"
  # DOE Ref Pre-1980
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.CoilHeatingGas"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.refrigeration"
  # NREL ZNE Ready 2017
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.FanConstantVolume"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.FanOnOff"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.FanVariableVolume"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.HeatExchangerAirToAirSensibleAndLatent"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.Model"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.hvac_systems"
  # ZE AEDG Multifamily
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.FanConstantVolume"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.FanOnOff"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.FanVariableVolume"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.HeatExchangerAirToAirSensibleAndLatent"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.Model"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/ze_aedg_multifamily/ze_aedg_multifamily.hvac_systems"
  # DEER
  require_relative "#{proto}/deer/deer.Model"
  # CBES Common
  require_relative "#{proto}/cbes/cbes.Model.elevators"
  require_relative "#{proto}/cbes/cbes.refrigeration"
  # CBES T24 2008
  require_relative "#{proto}/cbes/cbes_t24_2008/cbes_t24_2008.FanConstantVolume"
  require_relative "#{proto}/cbes/cbes_t24_2008/cbes_t24_2008.FanOnOff"
  require_relative "#{proto}/cbes/cbes_t24_2008/cbes_t24_2008.FanVariableVolume"

  # DLM: not sure where this code should go
  def self.get_run_env()
    # blank out bundler and gem path modifications, will be re-setup by new call
    new_env = {}
    new_env['BUNDLER_ORIG_MANPATH'] = nil
    new_env['BUNDLER_ORIG_PATH'] = nil
    new_env['BUNDLER_VERSION'] = nil
    new_env['BUNDLE_BIN_PATH'] = nil
    new_env['RUBYLIB'] = nil
    new_env['RUBYOPT'] = nil

    # DLM: preserve GEM_HOME and GEM_PATH set by current bundle because we are not supporting bundle
    # requires to ruby gems will work, will fail if we require a native gem
    new_env['GEM_PATH'] = nil
    new_env['GEM_HOME'] = nil

    # DLM: for now, ignore current bundle in case it has binary dependencies in it
    #bundle_gemfile = ENV['BUNDLE_GEMFILE']
    #bundle_path = ENV['BUNDLE_PATH']
    #if bundle_gemfile.nil? || bundle_path.nil?
      new_env['BUNDLE_GEMFILE'] = nil
      new_env['BUNDLE_PATH'] = nil
      new_env['BUNDLE_WITHOUT'] = nil
    #else
    #  new_env['BUNDLE_GEMFILE'] = bundle_gemfile
    #  new_env['BUNDLE_PATH'] = bundle_path
    #end

    return new_env
  end

  def self.run_command(command)
    stdout_str, stderr_str, status = Open3.capture3(get_run_env(), command)
    if status.success?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.command', "Successfully ran command: '#{command}'")
      #puts "stdout: #{stdout_str}"
      #puts "stderr: #{stderr_str}"
      return true
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.command', "Error running command: '#{command}'")
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.command', "stdout: #{stdout_str}")
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.command', "stderr: #{stderr_str}")

      # Print the ENV for debugging
      final_env = []
      env_changes = get_run_env()
      ENV.each do |env_var, val|
        next if env_changes.key?(env_var) && env_changes[env_var].nil?
        final_env << "#{env_var} = #{val}"
      end
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.command', "command's modified ENV: \n #{final_env.join("\n")}")

      # List the gems available to openstudio at this point
      cli_path = OpenStudio.getOpenStudioCLI
      cmd = "\"#{cli_path}\" gem_list"
      stdout_str_2, stderr_str_2, status_2 = Open3.capture3(get_run_env(), cmd)
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.command', "Gems available to openstudio cli according to (openstudio gem_list): \n #{stdout_str_2}")

      return false
    end
  end

end
