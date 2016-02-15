
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  # Ensure that the version of OpenStudio is 1.6.0 or greater
  # because the HVACSizing .autosizedFoo methods are currently built
  # expecting the EnergyPlus 8.2 syntax.
  min_os_version = "1.6.0"
  if OpenStudio::Model::Model.new.version < OpenStudio::VersionString.new(min_os_version)
    OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "This measure requires a minimum OpenStudio version of #{min_os_version} because the HVACSizing .autosizedFoo methods expect EnergyPlus 8.2 output variable names.")
  end
  
  # Load the helper libraries for getting the autosized
  # values for each type of model object.
  require_relative 'HVACSizing.AirTerminalSingleDuctParallelPIUReheat'
  require_relative 'HVACSizing.AirTerminalSingleDuctVAVReheat'
  require_relative 'HVACSizing.AirTerminalSingleDuctUncontrolled'
  require_relative 'HVACSizing.AirLoopHVAC'
  require_relative 'HVACSizing.AirLoopHVACUnitaryHeatPumpAirToAir'
  require_relative 'HVACSizing.FanConstantVolume'
  require_relative 'HVACSizing.FanVariableVolume'
  require_relative 'HVACSizing.FanOnOff'
  require_relative 'HVACSizing.CoilHeatingElectric'
  require_relative 'HVACSizing.CoilHeatingGas'
  require_relative 'HVACSizing.CoilHeatingWater'
  require_relative 'HVACSizing.CoilHeatingDXSingleSpeed'
  require_relative 'HVACSizing.CoilCoolingDXSingleSpeed'
  require_relative 'HVACSizing.CoilCoolingDXTwoSpeed'
  require_relative 'HVACSizing.CoilCoolingWater'
  require_relative 'HVACSizing.ControllerOutdoorAir'
  require_relative 'HVACSizing.HeatExchangerAirToAirSensibleAndLatent'
  require_relative 'HVACSizing.PlantLoop'
  require_relative 'HVACSizing.PumpConstantSpeed'
  require_relative 'HVACSizing.PumpVariableSpeed'
  require_relative 'HVACSizing.BoilerHotWater'
  require_relative 'HVACSizing.ChillerElectricEIR'
  require_relative 'HVACSizing.CoolingTowerSingleSpeed'
  require_relative 'HVACSizing.ControllerWaterCoil'
  require_relative 'HVACSizing.SizingSystem'
  require_relative 'HVACSizing.ThermalZone'

  # Recently added and not fully tested
  require_relative 'HVACSizing.ZoneHVACPackagedTerminalAirConditioner'
  require_relative 'HVACSizing.ZoneHVACPackagedTerminalHeatPump'
  require_relative 'HVACSizing.ZoneHVACTerminalUnitVariableRefrigerantFlow'
  require_relative 'HVACSizing.AirConditionerVariableRefrigerantFlow'
  require_relative 'HVACSizing.CoilCoolingDXVariableRefrigerantFlow'
  require_relative 'HVACSizing.CoilHeatingDXVariableRefrigerantFlow'

  # Methods not yet implemented
  require_relative 'HVACSizing.AirTerminalSingleDuctVAVReheat'
  require_relative 'HVACSizing.AirTerminalSingleDuctUncontrolled'
  require_relative 'HVACSizing.AirLoopHVAC'
  require_relative 'HVACSizing.AirLoopHVACUnitaryHeatPumpAirToAir'
  require_relative 'HVACSizing.FanConstantVolume'
  require_relative 'HVACSizing.FanVariableVolume'
  require_relative 'HVACSizing.FanOnOff'  

  # Heating and cooling fuel methods
  require_relative 'HVACSizing.HeatingCoolingFuels'
  
  # A helper method to run a sizing run and pull any values calculated during
  # autosizing back into the self.
  def runSizingRun(sizing_run_dir = "#{Dir.pwd}/SizingRun")
    
    # Change the simulation to only run the sizing days
    sim_control = self.getSimulationControl
    sim_control.setRunSimulationforSizingPeriods(true)
    sim_control.setRunSimulationforWeatherFileRunPeriods(false)
    
    # Run the sizing run
    self.run_simulation_and_log_errors(sizing_run_dir)
    
    # Change the model back to running the weather file
    sim_control.setRunSimulationforSizingPeriods(false)
    sim_control.setRunSimulationforWeatherFileRunPeriods(true)
    
    return true

  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into all objects model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    # Ensure that the model has a sql file associated with it
    if self.sqlFile.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Failed to apply sizing values because model is missing sql file containing sizing results.')
      return false
    end
  
    # TODO Sizing methods for these types of equipment are
    # currently only stubs that need to be filled in.
    self.getAirConditionerVariableRefrigerantFlows.sort.each {|obj| obj.applySizingValues}
    self.getAirLoopHVACUnitaryHeatCoolVAVChangeoverBypasss.sort.each {|obj| obj.applySizingValues}
    self.getAirLoopHVACUnitarySystems.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctConstantVolumeCooledBeams.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctConstantVolumeFourPipeInductions.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctConstantVolumeReheats.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctSeriesPIUReheats.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctVAVHeatAndCoolNoReheats.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctVAVHeatAndCoolReheats.sort.each {|obj| obj.applySizingValues}
    self.getBoilerSteams.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingDXMultiSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingDXVariableRefrigerantFlows.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingWaterToAirHeatPumpEquationFits.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingWaterToAirHeatPumpEquationFits.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingGasMultiStages.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingDesuperheaters.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingDXVariableRefrigerantFlows.sort.each {|obj| obj.applySizingValues}
    self.getCoilWaterHeatingDesuperheaters.sort.each {|obj| obj.applySizingValues}
    self.getCoolingTowerTwoSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoolingTowerVariableSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getEvaporativeCoolerDirectResearchSpecials.sort.each {|obj| obj.applySizingValues}
    self.getEvaporativeCoolerIndirectResearchSpecials.sort.each {|obj| obj.applySizingValues}
    self.getEvaporativeFluidCoolerSingleSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getHeatExchangerFluidToFluids.sort.each {|obj| obj.applySizingValues}
    self.getHumidifierSteamElectrics.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACBaseboardConvectiveElectrics.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACBaseboardConvectiveWaters.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACFourPipeFanCoils.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACHighTemperatureRadiants.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACIdealLoadsAirSystems.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACLowTemperatureRadiantElectrics.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACLowTempRadiantConstFlows.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACLowTempRadiantVarFlows.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACPackagedTerminalAirConditioners.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACPackagedTerminalHeatPumps.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACTerminalUnitVariableRefrigerantFlows.sort.each {|obj| obj.applySizingValues}
    self.getZoneHVACWaterToAirHeatPumps.sort.each {|obj| obj.applySizingValues}
    
    # Zone equipment
    
    # Air terminals
    self.getAirTerminalSingleDuctParallelPIUReheats.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctVAVReheats.sort.each {|obj| obj.applySizingValues}
    self.getAirTerminalSingleDuctUncontrolleds.sort.each {|obj| obj.applySizingValues}
     
    # AirLoopHVAC components
    self.getAirLoopHVACs.sort.each {|obj| obj.applySizingValues}
    self.getSizingSystems.sort.each {|obj| obj.applySizingValues}
    
    # Fans
    self.getFanConstantVolumes.sort.each {|obj| obj.applySizingValues}
    self.getFanVariableVolumes.sort.each {|obj| obj.applySizingValues}
    self.getFanOnOffs.sort.each {|obj| obj.applySizingValues}
    
    # Heating coils
    self.getCoilHeatingElectrics.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingGass.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingWaters.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingDXSingleSpeeds.sort.each {|obj| obj.applySizingValues}
    
    # Cooling coils
    self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingDXTwoSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingWaters.sort.each {|obj| obj.applySizingValues}
    
    # Outdoor air
    self.getControllerOutdoorAirs.sort.each {|obj| obj.applySizingValues}
    self.getHeatExchangerAirToAirSensibleAndLatents.sort.each {|obj| obj.applySizingValues}
    
    # PlantLoop components
    self.getPlantLoops.sort.each {|obj| obj.applySizingValues}
    
    # Pumps
    self.getPumpConstantSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getPumpVariableSpeeds.sort.each {|obj| obj.applySizingValues}
    
    # Heating equipment
    self.getBoilerHotWaters.sort.each {|obj| obj.applySizingValues}
    
    # Cooling equipment
    self.getChillerElectricEIRs.sort.each {|obj| obj.applySizingValues}
    
    # Condenser equipment
    self.getCoolingTowerSingleSpeeds.sort.each {|obj| obj.applySizingValues}
    
    # Controls
    self.getControllerWaterCoils.sort.each {|obj| obj.applySizingValues}
    
    # VRF components
    
    # Refrigeration components
    
    return true
    
  end

  # Changes all hard-sized HVAC values to Autosized
  def autosize
  
    # TODO Sizing methods for these types of equipment are
    # currently only stubs that need to be filled in.
    self.getAirConditionerVariableRefrigerantFlows.sort.each {|obj| obj.autosize}
    self.getAirLoopHVACUnitaryHeatCoolVAVChangeoverBypasss.sort.each {|obj| obj.autosize}
    self.getAirLoopHVACUnitarySystems.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctConstantVolumeCooledBeams.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctConstantVolumeFourPipeInductions.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctConstantVolumeReheats.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctSeriesPIUReheats.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctVAVHeatAndCoolNoReheats.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctVAVHeatAndCoolReheats.sort.each {|obj| obj.autosize}
    self.getBoilerSteams.sort.each {|obj| obj.autosize}
    self.getCoilCoolingDXMultiSpeeds.sort.each {|obj| obj.autosize}
    self.getCoilCoolingDXVariableRefrigerantFlows.sort.each {|obj| obj.autosize}
    self.getCoilCoolingWaterToAirHeatPumpEquationFits.sort.each {|obj| obj.autosize}
    self.getCoilHeatingWaterToAirHeatPumpEquationFits.sort.each {|obj| obj.autosize}
    self.getCoilHeatingGasMultiStages.sort.each {|obj| obj.autosize}
    self.getCoilHeatingDesuperheaters.sort.each {|obj| obj.autosize}
    self.getCoilHeatingDXVariableRefrigerantFlows.sort.each {|obj| obj.autosize}
    self.getCoilWaterHeatingDesuperheaters.sort.each {|obj| obj.autosize}
    self.getCoolingTowerTwoSpeeds.sort.each {|obj| obj.autosize}
    self.getCoolingTowerVariableSpeeds.sort.each {|obj| obj.autosize}
    self.getEvaporativeCoolerDirectResearchSpecials.sort.each {|obj| obj.autosize}
    self.getEvaporativeCoolerIndirectResearchSpecials.sort.each {|obj| obj.autosize}
    self.getEvaporativeFluidCoolerSingleSpeeds.sort.each {|obj| obj.autosize}
    self.getHeatExchangerFluidToFluids.sort.each {|obj| obj.autosize}
    self.getHumidifierSteamElectrics.sort.each {|obj| obj.autosize}
    self.getZoneHVACBaseboardConvectiveElectrics.sort.each {|obj| obj.autosize}
    self.getZoneHVACBaseboardConvectiveWaters.sort.each {|obj| obj.autosize}
    self.getZoneHVACFourPipeFanCoils.sort.each {|obj| obj.autosize}
    self.getZoneHVACHighTemperatureRadiants.sort.each {|obj| obj.autosize}
    self.getZoneHVACIdealLoadsAirSystems.sort.each {|obj| obj.autosize}
    self.getZoneHVACLowTemperatureRadiantElectrics.sort.each {|obj| obj.autosize}
    self.getZoneHVACLowTempRadiantConstFlows.sort.each {|obj| obj.autosize}
    self.getZoneHVACLowTempRadiantVarFlows.sort.each {|obj| obj.autosize}
    self.getZoneHVACPackagedTerminalAirConditioners.sort.each {|obj| obj.autosize}
    self.getZoneHVACPackagedTerminalHeatPumps.sort.each {|obj| obj.autosize}
    self.getZoneHVACTerminalUnitVariableRefrigerantFlows.sort.each {|obj| obj.autosize}
    self.getZoneHVACWaterToAirHeatPumps.sort.each {|obj| obj.autosize}
    
    # Zone equipment
    
    # Air terminals
    self.getAirTerminalSingleDuctParallelPIUReheats.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctVAVReheats.sort.each {|obj| obj.autosize}
    self.getAirTerminalSingleDuctUncontrolleds.sort.each {|obj| obj.autosize}
     
    # AirLoopHVAC components
    self.getAirLoopHVACs.sort.each {|obj| obj.autosize}
    self.getSizingSystems.sort.each {|obj| obj.autosize}
    
    # Fans
    self.getFanConstantVolumes.sort.each {|obj| obj.autosize}
    self.getFanVariableVolumes.sort.each {|obj| obj.autosize}
    self.getFanOnOffs.sort.each {|obj| obj.autosize}
    
    # Heating coils
    self.getCoilHeatingElectrics.sort.each {|obj| obj.autosize}
    self.getCoilHeatingGass.sort.each {|obj| obj.autosize}
    self.getCoilHeatingWaters.sort.each {|obj| obj.autosize}
    self.getCoilHeatingDXSingleSpeeds.sort.each {|obj| obj.autosize}
    
    # Cooling coils
    self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.autosize}
    self.getCoilCoolingDXTwoSpeeds.sort.each {|obj| obj.autosize}
    self.getCoilCoolingWaters.sort.each {|obj| obj.autosize}
    
    # Outdoor air
    self.getControllerOutdoorAirs.sort.each {|obj| obj.autosize}
    self.getHeatExchangerAirToAirSensibleAndLatents.sort.each {|obj| obj.autosize}
    
    # PlantLoop components
    self.getPlantLoops.sort.each {|obj| obj.autosize}
    
    # Pumps
    self.getPumpConstantSpeeds.sort.each {|obj| obj.autosize}
    self.getPumpVariableSpeeds.sort.each {|obj| obj.autosize}
    
    # Heating equipment
    self.getBoilerHotWaters.sort.each {|obj| obj.autosize}
    
    # Cooling equipment
    self.getChillerElectricEIRs.sort.each {|obj| obj.autosize}
    
    # Condenser equipment
    self.getCoolingTowerSingleSpeeds.sort.each {|obj| obj.autosize}
    
    # Controls
    self.getControllerWaterCoils.sort.each {|obj| obj.autosize}
    
    # VRF components
    
    # Refrigeration components
    
    return true
    
  end
  
  
  # A helper method to get component sizes from the model
  # returns the autosized value as an optional double
  def getAutosizedValue(object, value_name, units)

    result = OpenStudio::OptionalDouble.new

    name = object.name.get.upcase
    
    object_type = object.iddObject.type.valueDescription.gsub('OS:','')
      
    sql = self.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      #SELECT * FROM ComponentSizes WHERE CompType = 'Coil:Heating:Gas' AND CompName = "COIL HEATING GAS 3" AND Description = "Design Size Nominal Capacity"
      query = "SELECT Value 
              FROM ComponentSizes 
              WHERE CompType='#{object_type}' 
              AND CompName='#{name}' 
              AND Description='#{value_name}' 
              AND Units='#{units}'"
              
      val = sql.execAndReturnFirstDouble(query)
      
      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        # Todo: comment following line (debugging new HVACsizing objects right now)
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "QUERY ERROR: Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end   
   
end
