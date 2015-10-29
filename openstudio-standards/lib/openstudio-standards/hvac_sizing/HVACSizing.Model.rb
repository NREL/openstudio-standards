
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

  # Methods not yet implemented
  require_relative 'HVACSizing.AirConditionerVariableRefrigerantFlow'
  require_relative 'HVACSizing.AirTerminalSingleDuctVAVReheat'
  require_relative 'HVACSizing.AirTerminalSingleDuctUncontrolled'
  require_relative 'HVACSizing.AirLoopHVAC'
  require_relative 'HVACSizing.AirLoopHVACUnitaryHeatPumpAirToAir'
  require_relative 'HVACSizing.FanConstantVolume'
  require_relative 'HVACSizing.FanVariableVolume'
  require_relative 'HVACSizing.FanOnOff'  

  # A helper method to run a sizing run and pull any values calculated during
  # autosizing back into the self.
  def runSizingRun(sizing_run_dir = "#{Dir.pwd}/SizingRun")
    
    # If the sizing run directory is not specified
    # run the sizing run in the current working directory
    
    # Make the directory if it doesn't exist
    if !Dir.exists?(sizing_run_dir)
      Dir.mkdir(sizing_run_dir)
    end

    # Change the simulation to only run the sizing days
    sim_control = self.getSimulationControl
    sim_control.setRunSimulationforSizingPeriods(true)
    sim_control.setRunSimulationforWeatherFileRunPeriods(false)
    
    # Save the model to energyplus idf
    idf_name = 'sizing.idf'
    osm_name = 'sizing.osm'
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Starting sizing run here: #{sizing_run_dir}.")
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(self)
    idf_path = OpenStudio::Path.new("#{sizing_run_dir}/#{idf_name}")  
    osm_path = OpenStudio::Path.new("#{sizing_run_dir}/#{osm_name}")
    idf.save(idf_path,true)
    self.save(osm_path,true)
    
    # Set up the sizing simulation
    # Find the weather file
    epw_path = nil
    if self.weatherFile.is_initialized
      epw_path = self.weatherFile.get.path
      if epw_path.is_initialized
        if File.exist?(epw_path.get.to_s)
          epw_path = epw_path.get
        else
          # If this is an always-run Measure, need to check a different path
          alt_weath_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../resources"))
          alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
          if File.exist?(alt_epw_path)
            epw_path = OpenStudio::Path.new(alt_epw_path)
          else
            OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
            return false
          end
        end
      else
        OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "Model has a weather file assigned, but the weather file path has been deleted.")
        return false
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has not been assigned a weather file.')
      return false
    end
    
    # If running on a regular desktop, use RunManager.
    # If running on OpenStudio Server, use WorkFlowMananger
    # to avoid slowdown from the sizing run.   
    use_runmanager = true
    
    begin
      require 'openstudio-workflow'
      use_runmanager = false
    rescue LoadError
      use_runmanager = true
    end

    sql_path = nil
    if use_runmanager
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Running sizing run with RunManager.')

      # Find EnergyPlus
      ep_dir = OpenStudio.getEnergyPlusDirectory
      ep_path = OpenStudio.getEnergyPlusExecutable
      ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
      idd_path = OpenStudio::Path.new(ep_dir.to_s + "/Energy+.idd")
      output_path = OpenStudio::Path.new("#{sizing_run_dir}/")
      
      # Make a run manager and queue up the sizing run
      run_manager_db_path = OpenStudio::Path.new("#{sizing_run_dir}/sizing_run.db")
      # HACK: workaround for Mac with Qt 5.4, need to address in the future.
      OpenStudio::Application::instance().application(true)
      run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
      job = OpenStudio::Runmanager::JobFactory::createEnergyPlusJob(ep_tool,
                                                                   idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)
      
      run_manager.enqueue(job, true)

      # Start the sizing run and wait for it to finish.
      while run_manager.workPending
        sleep 1
        OpenStudio::Application::instance.processEvents
      end
        
      sql_path = OpenStudio::Path.new("#{sizing_run_dir}/Energyplus/eplusout.sql")
      
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished sizing run.')
      
    else # Use the openstudio-workflow gem
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Running sizing run with openstudio-workflow gem.')
      
      # Copy the weather file to this directory
      FileUtils.copy(epw_path.to_s, sizing_run_dir)

      # Run the simulation
      sim = OpenStudio::Workflow.run_energyplus('Local', sizing_run_dir)
      final_state = sim.run

      if final_state == :finished
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished sizing run.')
      end
    
      sql_path = OpenStudio::Path.new("#{sizing_run_dir}/run/eplusout.sql")
    
    end
    
    # TODO Delete the eplustbl.htm and other files created
    # by the sizing run for cleanliness.
    
    # Load the sql file created by the sizing run
    if OpenStudio::exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      if !sql.connectionOpen
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The sizing run failed, cannot create model.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
      # Attach the sql file from the run to the sizing model
      self.setSqlFile(sql)
    else 
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the sizing run couldn't be found here: #{sql_path}.")
      return false
    end
    
    # Report severe errors in the sizing run
    error_query = "SELECT ErrorMessage 
        FROM Errors 
        WHERE ErrorType='1'"

    errs = self.sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
      if errs.size > 0
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The sizing run had the following severe errors: #{errs.join('\n')}.")
      end
    end

    # Check that the sizing run completed
    completed_query = "SELECT CompletedSuccessfully FROM Simulations"

    completed = self.sqlFile.get.execAndReturnFirstDouble(completed_query)
    if completed.is_initialized
      completed = completed.get
      if errs.size == 1
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The sizing run failed.  See previous severe errors for clues.")
        return false
      end
    end
    
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
        #OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end   
   
end
