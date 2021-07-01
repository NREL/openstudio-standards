
###### IMPORTANT NOTE ######
# These methods should be done via extension to OS model objects
# directly in the C++ SDK.  This Ruby implementation was done
# (for expedience only) by copying some previously written code
# If you feel like fixing the implementation,
# please contact andrew.parker@nrel.gov and he'll gladly
# point you in the right direction.
###### IMPORTANT NOTE ######

class OpenStudio::Model::Model
  
  # Get the heating fuel type of a plant loop
  # @todo If no heating equipment is found, check if there's a heat exchanger,
  # or a WaterHeater:Mixed or stratified that is connected to a heating source on the demand side
  def plant_loop_heating_fuels(plant_loop)
    fuels = []
    # Get the heating fuels for all supply components
    # on this plant loop.
    plant_loop.supplyComponents.each do |component|
       # Get the object type
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_Boiler_HotWater'
        component = component.to_BoilerHotWater.get
        fuels << component.fuelType
      when 'OS_Boiler_Steam' 
        component = component.to_BoilerHotWater.get
        fuels << component.fuelType
      when 'OS_DistrictHeating'
        fuels << 'DistrictHeating' 
      when 'OS_HeatPump_WaterToWater_EquationFit_Heating'
        fuels << 'Electricity'
      when 'OS_SolarCollector_FlatPlate_PhotovoltaicThermal'
        fuels << 'SolarEnergy'
      when 'OS_SolarCollector_FlatPlate_Water'
        fuels << 'SolarEnergy'
      when 'OS_SolarCollector_IntegralCollectorStorage'
        fuels << 'SolarEnergy'
      when 'OS_WaterHeater_HeatPump'
        fuels << 'Electricity'     
      when 'OS_WaterHeater_Mixed'
        component = component.to_WaterHeaterMixed.get

        # Check if the heater actually has a capacity (otherwise it's simply a Storage Tank)
        if component.heaterMaximumCapacity.empty? || component.heaterMaximumCapacity.get != 0
          # If it does, we add the heater Fuel Type
          fuels << component.heaterFuelType
        end
        # @todo not sure about whether it should be an elsif or not
        # Check the plant loop connection on the source side
        if component.secondaryPlantLoop.is_initialized
          fuels += self.plant_loop_heating_fuels(component.secondaryPlantLoop.get)
        end
      when 'OS_WaterHeater_Stratified'
        component = component.to_WaterHeaterStratified.get

        # Check if the heater actually has a capacity (otherwise it's simply a Storage Tank)
        if component.heaterMaximumCapacity.empty? || component.heaterMaximumCapacity.get != 0
          # If it does, we add the heater Fuel Type
          fuels << component.heaterFuelType
        end
        # @todo not sure about whether it should be an elsif or not
        # Check the plant loop connection on the source side
        if component.secondaryPlantLoop.is_initialized
          fuels += self.plant_loop_heating_fuels(component.secondaryPlantLoop.get)
        end

      when 'OS_HeatExchanger_FluidToFluid'
        hx = component.to_HeatExchangerFluidToFluid.get
        cooling_hx_control_types = ["CoolingSetpointModulated", "CoolingSetpointOnOff", "CoolingDifferentialOnOff", "CoolingSetpointOnOffWithComponentOverride"]
        cooling_hx_control_types.each {|x| x.downcase!}
        if !cooling_hx_control_types.include?(hx.controlType.downcase) && hx.secondaryPlantLoop.is_initialized
          fuels += self.plant_loop_heating_fuels(hx.secondaryPlantLoop.get)
        end
      when 'OS_Node', 'OS_Pump_ConstantSpeed', 'OS_Pump_VariableSpeed', 'OS_Connector_Splitter', 'OS_Connector_Mixer', 'OS_Pipe_Adiabatic'
        # To avoid extraneous debug messages
      else
        #OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
      end
    end
    
    return fuels.uniq.sort
 
  end

  # Get the cooling fuel type of a plant loop
  # Do not search for the fuel used for heat rejection
  # on the condenser loop.
  def plant_loop_cooling_fuels(plant_loop)
    fuels = []
    # Get the cooling fuels for all supply components
    # on this plant loop.
    plant_loop.supplyComponents.each do |component|
       # Get the object type
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type  
      when 'OS_Chiller_Absorption'
        fuels << 'NaturalGas'
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.sizing.Model', "Assuming NaturalGas as fuel for absorption chiller.")
      when 'OS_Chiller_Absorption_Indirect'
        fuels << 'NaturalGas'
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.sizing.Model', "Assuming NaturalGas as fuel for absorption chiller indirect.")
      when 'OS_Chiller_Electric_EIR'
        fuels << 'Electricity'
      when 'OS_CoolingTower_SingleSpeed'
        fuels << 'Electricity'
      when 'OS_CoolingTower_TwoSpeed'
        fuels << 'Electricity'
      when 'OS_CoolingTower_VariableSpeed'
        fuels << 'Electricity'
      when 'OS_DistrictCooling'
        fuels << 'DistrictCooling'
      when 'OS_EvaporativeFluidCooler_SingleSpeed'
        fuels << 'Electricity'
      when 'OS_EvaporativeFluidCooler_TwoSpeed'
        fuels << 'Electricity'
      when 'OS_FluidCooler_SingleSpeed'
        fuels << 'Electricity'
      when 'OS_FluidCooler_TwoSpeed'
        fuels << 'Electricity'
      when 'OS_Node', 'OS_Pump_ConstantSpeed', 'OS_Pump_VariableSpeed', 'OS_Connector_Splitter', 'OS_Connector_Mixer', 'OS_Pipe_Adiabatic'
        # To avoid extraneous debug messages  
      else
        #OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No cooling fuel types found for #{obj_type}")
      end
    end
    
    return fuels.uniq.sort
    
  end

  # Get the heating fuel type of a heating coil
  def coil_heating_fuels(heating_coil)
    fuels = []
    # Get the object type
    obj_type = heating_coil.iddObjectType.valueName.to_s
    case obj_type
    when 'OS_Coil_Heating_DX_MultiSpeed'
      fuels << 'Electricity'
    when 'OS_Coil_Heating_DX_SingleSpeed'
      fuels << 'Electricity'
    when 'OS_Coil_Heating_DX_VariableRefrigerantFlow'
      fuels << 'Electricity'
    when 'OS_Coil_Heating_DX_VariableSpeed'
      fuels << 'Electricity'
    when 'OS_Coil_Heating_Desuperheater'
      fuels << 'Electricity'
    when 'OS_Coil_Heating_Electric'
      fuels << 'Electricity'
    when 'OS_Coil_Heating_Gas'
      fuels << 'NaturalGas'
    when 'OS_Coil_Heating_Gas_MultiStage'
      fuels << 'NaturalGas'
    when 'OS_Coil_Heating_Water'
      heating_coil = heating_coil.to_CoilHeatingWater.get
      if heating_coil.plantLoop.is_initialized
        fuels += self.plant_loop_heating_fuels(heating_coil.plantLoop.get)
      end
    when 'OS_Coil_Heating_Water_BaseboardRadiant'
      heating_coil = heating_coil.to_CoilHeatingWaterBaseboardRadiant.get
        if heating_coil.plantLoop.is_initialized
        fuels += self.plant_loop_heating_fuels(heating_coil.plantLoop.get)
      end  
    when 'OS_Coil_Heating_WaterToAirHeatPump_EquationFit'
      fuels << 'Electricity'
      heating_coil = heating_coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.get
      if heating_coil.plantLoop.is_initialized
        fuels += self.plant_loop_heating_fuels(heating_coil.plantLoop.get)
      end
    when 'OS_Coil_Heating_WaterToAirHeatPump_VariableSpeedEquationFit'
      fuels << 'Electricity'
      heating_coil = heating_coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.get
      if heating_coil.plantLoop.is_initialized
        fuels += self.plant_loop_heating_fuels(heating_coil.plantLoop.get)
      end
    when 'OS_Coil_Heating_LowTemperatureRadiant_ConstantFlow'
      heating_coil = heating_coil.to_CoilHeatingLowTempRadiantConstFlow.get
      if heating_coil.plantLoop.is_initialized
        fuels += self.plant_loop_heating_fuels(heating_coil.plantLoop.get)
      end
    when 'OS_Coil_Heating_LowTemperatureRadiant_VariableFlow'
      heating_coil = heating_coil.to_CoilHeatingLowTempRadiantVarFlow.get
      if heating_coil.plantLoop.is_initialized
        fuels += self.plant_loop_heating_fuels(heating_coil.plantLoop.get)
      end
    when 'OS_Coil_WaterHeating_AirToWaterHeatPump'
      fuels << 'Electricity'
    when 'OS_Coil_WaterHeating_Desuperheater'
      fuels << 'Electricity'
    else
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
    end

    return fuels.uniq.sort 

  end

  # Get the cooling fuel type of a cooling coil
  def coil_cooling_fuels(cooling_coil)
    fuels = []
    # Get the object type
    obj_type = cooling_coil.iddObjectType.valueName.to_s
    case obj_type
    when 'OS_Coil_Cooling_DX_MultiSpeed'
    'Electricity'
    when 'OS_Coil_Cooling_DX_SingleSpeed'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_DX_TwoSpeed'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_DX_TwoStageWithHumidityControlMode'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_DX_VariableRefrigerantFlow'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_DX_VariableSpeed'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_WaterToAirHeatPump_EquationFit'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_WaterToAirHeatPump_VariableSpeed_EquationFit'
      fuels << 'Electricity'
    when 'OS_CoilSystem_Cooling_DX_HeatExchangerAssisted'
      fuels << 'Electricity'
    when 'OS_CoilSystem_Cooling_Water_HeatExchangerAssisted'
      fuels << 'Electricity'
    when 'OS_HeatPump_WaterToWater_EquationFit_Cooling'
      fuels << 'Electricity'
    when 'OS_Refrigeration_AirChiller'
      fuels << 'Electricity'
    when 'OS_Coil_Cooling_CooledBeam'
      cooling_coil = cooling_coil.to_CoilCoolingCooledBeam.get
      if cooling_coil.plantLoop.is_initialized
        fuels += self.plant_loop_cooling_fuels(cooling_coil.plantLoop.get)
      end
    when 'OS_Coil_Cooling_LowTemperatureRadiant_ConstantFlow'
      cooling_coil = cooling_coil.to_CoilCoolingLowTempRadiantConstFlow.get
      if cooling_coil.plantLoop.is_initialized
        fuels += self.plant_loop_cooling_fuels(cooling_coil.plantLoop.get)
      end
    when 'OS_Coil_Cooling_LowTemperatureRadiant_VariableFlow'
      cooling_coil = cooling_coil.to_CoilCoolingLowTempRadiantVarFlow.get
      if cooling_coil.plantLoop.is_initialized
        fuels += self.plant_loop_cooling_fuels(cooling_coil.plantLoop.get)
      end
    when 'OS_Coil_Cooling_Water'  
      cooling_coil = cooling_coil.to_CoilCoolingWater.get
      if cooling_coil.plantLoop.is_initialized
        fuels += self.plant_loop_cooling_fuels(cooling_coil.plantLoop.get)
      end    
    else
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No cooling fuel types found for #{obj_type}")
    end

    return fuels.uniq.sort
    
  end

  # Get the heating fuels for a zone
  # @ return [Array<String>] an array of fuels
  def zone_equipment_heating_fuels(zone)
    fuels = []
    # Get the heating fuels for all zone HVAC equipment
    zone.equipment.each do |equipment|
      # Get the object type
      obj_type = equipment.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirTerminal_SingleDuct_ConstantVolume_FourPipeInduction'
        equipment = equipment.to_AirTerminalSingleDuctConstantVolumeFourPipeInduction.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil)
      when 'OS_AirTerminal_SingleDuct_ConstantVolume_Reheat'
        equipment = equipment.to_AirTerminalSingleDuctConstantVolumeReheat.get
        fuels += self.coil_heating_fuels(equipment.reheatCoil)  
      when 'OS_AirTerminal_SingleDuct_InletSideMixer'
        # TODO
      when 'OS_AirTerminal_SingleDuct_ParallelPIUReheat'
        equipment = equipment.to_AirTerminalSingleDuctParallelPIUReheat.get
        fuels += self.coil_heating_fuels(equipment.reheatCoil) 
      when 'OS_AirTerminal_SingleDuct_SeriesPIUReheat'
        equipment = equipment.to_AirTerminalSingleDuctSeriesPIUReheat.get
        fuels += self.coil_heating_fuels(equipment.reheatCoil) 
      when 'OS_AirTerminal_SingleDuct_VAVHeatAndCool_Reheat'
        equipment = equipment.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
        fuels += self.coil_heating_fuels(equipment.reheatCoil) 
      when 'OS_AirTerminal_SingleDuct_VAV_Reheat'
        equipment = equipment.to_AirTerminalSingleDuctVAVReheat.get
        fuels += self.coil_heating_fuels(equipment.reheatCoil)
      when 'OS_ZoneHVAC_Baseboard_Convective_Water'
        equipment = equipment.to_ZoneHVACBaseboardConvectiveWater.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil) 
      when 'OS_ZoneHVAC_Baseboard_RadiantConvective_Water'
        equipment = equipment.to_ZoneHVACBaseboardRadiantConvectiveWater.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil) 
      when 'OS_ZoneHVAC_FourPipeFanCoil'
        equipment = equipment.to_ZoneHVACFourPipeFanCoil.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil) 
      when 'OS_ZoneHVAC_LowTemperatureRadiant_ConstantFlow'
        equipment = equipment.to_ZoneHVACLowTempRadiantConstFlow.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil) 
      when 'OS_ZoneHVAC_LowTemperatureRadiant_VariableFlow'
        equipment = equipment.to_ZoneHVACLowTempRadiantVarFlow.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil) 
      when 'OS_ZoneHVAC_UnitHeater'
        equipment = equipment.to_ZoneHVACUnitHeater.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil) 
      when 'OS_ZoneHVAC_UnitVentilator'
        equipment = equipment.to_ZoneHVACUnitVentilator.get
        if equipment.heatingCoil.is_initialized
          fuels += self.coil_heating_fuels(equipment.heatingCoil.get) 
        end 
      when 'OS_ZoneHVAC_Baseboard_Convective_Electric'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_Baseboard_RadiantConvective_Electric'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_HighTemperatureRadiant'
        equipment = equipment.to_ZoneHVACHighTemperatureRadiant.get
        fuels << equipment.fuelType
      when 'OS_ZoneHVAC_IdealLoadsAirSystem'
        fuels << 'DistrictHeating'
      when 'OS_ZoneHVAC_LowTemperatureRadiant_Electric'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_PackagedTerminalAirConditioner'
        equipment = equipment.to_ZoneHVACPackagedTerminalAirConditioner.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil)
      when 'OS_ZoneHVAC_PackagedTerminalHeatPump'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_TerminalUnit_VariableRefrigerantFlow'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_WaterToAirHeatPump'
        # We also go check what fuel serves the loop on which the WSHP heating coil is
        equipment = equipment.to_ZoneHVACWaterToAirHeatPump.get
        fuels += self.coil_heating_fuels(equipment.heatingCoil)
      else
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
      end
    end
    
    return fuels.uniq.sort
    
  end

  # Get the cooling fuels for a zone
  def zone_equipment_cooling_fuels(zone)
    fuels = []
    # Get the cooling fuels for all zone HVAC equipment
    zone.equipment.each do |equipment|
      # Get the object type
      obj_type = equipment.iddObjectType.valueName.to_s
      case obj_type    
      when 'OS_AirTerminal_SingleDuct_ConstantVolume_CooledBeam'
        equipment = equipment.to_AirTerminalSingleDuctConstantVolumeCooledBeam.get
        fuels += self.coil_cooling_fuels(equipment.coilCoolingCooledBeam)
      when 'OS_AirTerminal_SingleDuct_ConstantVolume_FourPipeInduction'      
        equipment = equipment.to_AirTerminalSingleDuctConstantVolumeFourPipeInduction.get
        if equipment.coolingCoil.is_initialized
          fuels += self.coil_cooling_fuels(equipment.coolingCoil.get) 
        end
      when 'OS_ZoneHVAC_FourPipeFanCoil'
        equipment = equipment.to_ZoneHVACFourPipeFanCoil.get
        fuels += self.coil_cooling_fuels(equipment.coolingCoil)
      when 'OS_ZoneHVAC_LowTemperatureRadiant_ConstantFlow'
        equipment = equipment.to_ZoneHVACLowTempRadiantConstFlow.get
        fuels += self.coil_cooling_fuels(equipment.coolingCoil)
      when 'OS_ZoneHVAC_LowTemperatureRadiant_VariableFlow'
        equipment = equipment.to_ZoneHVACLowTempRadiantVarFlow.get
        fuels += self.coil_cooling_fuels(equipment.coolingCoil)
      when 'OS_Refrigeration_AirChiller'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_IdealLoadsAirSystem'
        fuels << 'DistrictCooling'
      when 'OS_ZoneHVAC_PackagedTerminalAirConditioner'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_PackagedTerminalHeatPump'
        fuels << 'Electricity'
      when 'OS_ZoneHVAC_TerminalUnit_VariableRefrigerantFlow'
        fuels << 'Electricity'
      else
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No cooling fuel types found for #{obj_type}")
      end
    end

    return fuels.uniq.sort
    
  end

  # Get the heating fuels for a zones airloop
  def zone_airloop_heating_fuels(zone)
    fuels = []
    # Get the air loop that serves this zone
    air_loop = zone.airLoopHVAC
    if air_loop.empty?
      return fuels
    end
    air_loop = air_loop.get
    
    # Find fuel types of all equipment
    # on the supply side of this airloop.
    air_loop.supplyComponents.each do |component|
       # Get the object type
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirLoopHVAC_UnitaryHeatCool_VAVChangeoverBypass'
        component = component.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get
        fuels += self.coil_heating_fuels(component.heatingCoil)
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        fuels += self.coil_heating_fuels(component.heatingCoil)
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir_MultiSpeed'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        fuels += self.coil_heating_fuels(component.heatingCoil)
      when 'OS_AirLoopHVAC_UnitarySystem'
        component = component.to_AirLoopHVACUnitarySystem.get
        if component.heatingCoil.is_initialized
          fuels += self.coil_heating_fuels(component.heatingCoil.get)
        end
      when 'OS_Coil_Heating_DX_MultiSpeed'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_DX_SingleSpeed'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_DX_VariableSpeed'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Desuperheater'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Electric'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Gas'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Gas_MultiStage'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Water'
        fuels += self.coil_heating_fuels(component)  
      when 'OS_Coil_Heating_WaterToAirHeatPump_EquationFit'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_WaterToAirHeatPump_VariableSpeed_EquationFit'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_WaterHeating_AirToWaterHeatPump'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_WaterHeating_Desuperheater'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Node', 'OS_Fan_ConstantVolume', 'OS_Fan_VariableVolume', 'OS_AirLoopHVAC_OutdoorAirSystem'
        # To avoid extraneous debug messages  
      else
        #OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
      end
    end    
 
    return fuels.uniq.sort
    
  end

  # Get the cooling fuels for a zones airloop
  def zone_airloop_cooling_fuels(zone)
    fuels = []
    # Get the air loop that serves this zone
    air_loop = zone.airLoopHVAC
    if air_loop.empty?
      return fuels
    end
    air_loop = air_loop.get
    
    # Find fuel types of all equipment
    # on the supply side of this airloop.
    air_loop.supplyComponents.each do |component|
       # Get the object type
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirLoopHVAC_UnitaryHeatCool_VAVChangeoverBypass'
        component = component.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get
        fuels += self.coil_cooling_fuels(component.coolingCoil)
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        fuels += self.coil_cooling_fuels(component.coolingCoil)
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir_MultiSpeed'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        fuels += self.coil_cooling_fuels(component.coolingCoil)
      when 'OS_AirLoopHVAC_UnitarySystem'
        component = component.to_AirLoopHVACUnitarySystem.get
        if component.coolingCoil.is_initialized
          fuels += self.coil_cooling_fuels(component.coolingCoil.get)
        end
      when 'OS_EvaporativeCooler_Direct_ResearchSpecial'
        fuels << 'Electricity'
      when 'OS_EvaporativeCooler_Indirect_ResearchSpecial'
        fuels << 'Electricity'  
      when 'OS_Coil_Cooling_DX_MultiSpeed'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_DX_SingleSpeed'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_DX_TwoSpeed'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_DX_TwoStageWithHumidityControlMode'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_DX_VariableRefrigerantFlow'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_DX_VariableSpeed'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_WaterToAirHeatPump_EquationFit'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_WaterToAirHeatPump_VariableSpeed_EquationFit'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_CoilSystem_Cooling_DX_HeatExchangerAssisted'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_CoilSystem_Cooling_Water_HeatExchangerAssisted'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Coil_Cooling_Water'      
        fuels += self.coil_cooling_fuels(component)  
      when 'OS_HeatPump_WaterToWater_EquationFit_Cooling'
        fuels += self.coil_cooling_fuels(component)
      when 'OS_Node', 'OS_Fan_ConstantVolume', 'OS_Fan_VariableVolume', 'OS_AirLoopHVAC_OutdoorAirSystem'
        # To avoid extraneous debug messages  
      else
        #OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
      end
    end    
 
    return fuels.uniq.sort
    
  end     
  
end
