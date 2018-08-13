require 'singleton'
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
  require_relative "#{stds}/necb/NECB2011/necb_2011"
  require_relative "#{stds}/necb/NECB2015/necb_2015"
  require_relative "#{stds}/necb/NECB2011/building_envelope"
  require_relative "#{stds}/necb/NECB2011/lighting"
  require_relative "#{stds}/necb/NECB2011/hvac_systems"
  require_relative "#{stds}/necb/NECB2015/hvac_systems"
  require_relative "#{stds}/necb/NECB2011/service_water_heating"
  require_relative "#{stds}/necb/NECB2011/electrical_power_systems_and_motors"
  require_relative "#{stds}/necb/NECB2011/beps_compliance_path"

  # NECB QAQC
  require_relative "#{stds}/necb/NECB2011/qaqc/necb_qaqc.rb"
  require_relative "#{stds}/necb/NECB2015/qaqc/necb_2015_qaqc.rb"
  
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1"
  require_relative "#{stds}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980"
  require_relative "#{stds}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2004/ashrae_90_1_2004"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2007/ashrae_90_1_2007"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017"

  require_relative "#{stds}/deer/deer"
  require_relative "#{stds}/deer/deer_pre_1975/deer_pre_1975"
  require_relative "#{stds}/deer/deer_1985/deer_1985"
  require_relative "#{stds}/deer/deer_1996/deer_1996"
  require_relative "#{stds}/deer/deer_2003/deer_2003"
  require_relative "#{stds}/deer/deer_2007/deer_2007"
  require_relative "#{stds}/deer/deer_2011/deer_2011"
  require_relative "#{stds}/deer/deer_2014/deer_2014"
  require_relative "#{stds}/deer/deer_2015/deer_2015"
  require_relative "#{stds}/deer/deer_2017/deer_2017"

  require_relative "#{stds}/oeesc/oeesc"
  require_relative "#{stds}/oeesc/oeesc_2014/oeesc_2014"  

  require_relative "#{stds}/icc_iecc/icc_iecc"
  require_relative "#{stds}/icc_iecc/icc_iecc_2015/icc_iecc_2015"

  # Files with modules
  require_relative "#{stds}/Standards.Fan"
  require_relative "#{stds}/Standards.CoilDX"
  require_relative "#{stds}/Standards.Pump"
  require_relative "#{stds}/Standards.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2010/ashrae_90_1_2010.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/ashrae_90_1_2013/ashrae_90_1_2013.CoolingTower"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.CoolingTower"
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
  require_relative "#{stds}/Standards.CoilDX"
  require_relative "#{stds}/Standards.CoilHeatingDXMultiSpeed"
  require_relative "#{stds}/Standards.CoilHeatingDXSingleSpeed"
  require_relative "#{stds}/Standards.CoilHeatingGasMultiStage"
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
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.Space"
  require_relative "#{stds}/ashrae_90_1/nrel_zne_ready_2017/nrel_zne_ready_2017.ThermalZone"
  # DEER Common
  require_relative "#{stds}/deer/deer.Model"
  require_relative "#{stds}/deer/deer.AirLoopHVAC"
  require_relative "#{stds}/deer/deer.Space"

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

  # NECB Building Types
  require_relative "#{proto}/common/prototype_metaprogramming.rb"
  create_meta_classes

  # Model Objects
  require_relative "#{proto}/common/objects/Prototype.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/common/objects/Prototype.CoilHeatingGas"
  require_relative "#{proto}/common/objects/Prototype.ControllerWaterCoil"
  require_relative "#{proto}/common/objects/Prototype.Fan"
  require_relative "#{proto}/common/objects/Prototype.FanConstantVolume"
  require_relative "#{proto}/common/objects/Prototype.FanOnOff"
  require_relative "#{proto}/common/objects/Prototype.FanVariableVolume"
  require_relative "#{proto}/common/objects/Prototype.FanZoneExhaust"
  require_relative "#{proto}/common/objects/Prototype.HeatExchangerAirToAirSensibleAndLatent"
  require_relative "#{proto}/common/objects/Prototype.Model.elevators"
  require_relative "#{proto}/common/objects/Prototype.Model.exterior_lights"
  require_relative "#{proto}/common/objects/Prototype.Model.hvac"
  require_relative "#{proto}/common/objects/Prototype.Model"
  require_relative "#{proto}/common/objects/Prototype.Model.swh"
  require_relative "#{proto}/common/objects/Prototype.hvac_systems"
  require_relative "#{proto}/common/objects/Prototype.refrigeration"
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
  require_relative "#{proto}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.hvac_systems"
  require_relative "#{proto}/ashrae_90_1/doe_ref_1980_2004/doe_ref_1980_2004.refrigeration"
  # DOE Ref Pre-1980
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.CoilHeatingGas"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.hvac_systems"
  require_relative "#{proto}/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980.refrigeration"
  # NREL ZNE Ready 2017
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.AirTerminalSingleDuctVAVReheat"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.FanConstantVolume"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.FanOnOff"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.FanVariableVolume"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.Model"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.Model.elevators"
  require_relative "#{proto}/ashrae_90_1/nrel_nze_ready_2017/nrel_zne_ready_2017.hvac_systems"
  # DEER
  require_relative "#{proto}/deer/deer.Model"
end
