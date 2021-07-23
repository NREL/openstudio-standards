
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
  require_relative 'Siz.AirTermSnglDuctParallelPIUReheat'
  require_relative 'Siz.AirTermSnglDuctVAVReheat'
  require_relative 'Siz.AirTermSnglDuctUncontrolled'
  require_relative 'Siz.AirLoopHVAC'
  require_relative 'Siz.AirLoopHVACUnitaryHeatPumpAirToAir'
  require_relative 'Siz.AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed'
  require_relative 'Siz.FanConstantVolume'
  require_relative 'Siz.FanVariableVolume'
  require_relative 'Siz.FanOnOff'
  require_relative 'Siz.CoilHeatingElectric'
  require_relative 'Siz.CoilHeatingGas'
  require_relative 'Siz.CoilHeatingGasMultiStage'
  require_relative 'Siz.CoilHeatingWater'
  require_relative 'Siz.CoilHeatingDXSingleSpeed'
  require_relative 'Siz.CoilHeatingDXMultiSpeed'
  require_relative 'Siz.CoilHeatingWaterToAirHeatPumpEquationFit'
  require_relative 'Siz.CoilCoolingWaterToAirHeatPumpEquationFit'
  require_relative 'Siz.CoilCoolingDXMultiSpeed'
  require_relative 'Siz.CoilCoolingDXSingleSpeed'
  require_relative 'Siz.CoilCoolingDXTwoSpeed'
  require_relative 'Siz.CoilCoolingWater'
  require_relative 'Siz.ControllerOutdoorAir'
  require_relative 'Siz.DistrictHeating'
  require_relative 'Siz.DistrictCooling'
  require_relative 'Siz.HeatExchangerAirToAirSensibleAndLatent'
  require_relative 'Siz.PlantLoop'
  require_relative 'Siz.PumpConstantSpeed'
  require_relative 'Siz.PumpVariableSpeed'
  require_relative 'Siz.BoilerHotWater'
  require_relative 'Siz.ChillerElectricEIR'
  require_relative 'Siz.CoolingTowerSingleSpeed'
  require_relative 'Siz.CoolingTowerTwoSpeed'
  require_relative 'Siz.CoolingTowerVariableSpeed'
  require_relative 'Siz.ControllerWaterCoil'
  require_relative 'Siz.SizingSystem'
  require_relative 'Siz.ThermalZone'
  require_relative 'Siz.ZoneHVACPackagedTerminalAirConditioner'
  require_relative 'Siz.ZoneHVACPackagedTerminalHeatPump'
  require_relative 'Siz.ZoneHVACTerminalUnitVariableRefrigerantFlow'
  require_relative 'Siz.AirConditionerVariableRefrigerantFlow'
  require_relative 'Siz.CoilCoolingDXVariableRefrigerantFlow'
  require_relative 'Siz.CoilHeatingDXVariableRefrigerantFlow'
  require_relative 'Siz.HeaderedPumpsConstantSpeed'
  require_relative 'Siz.HeaderedPumpsVariableSpeed'

  # Heating and cooling fuel methods
  require_relative 'Siz.HeatingCoolingFuels'
  
  # Component quantity methods
  require_relative 'Siz.HVACComponent'
  
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
    self.getCoilCoolingDXVariableRefrigerantFlows.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingWaterToAirHeatPumpEquationFits.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingWaterToAirHeatPumpEquationFits.sort.each {|obj| obj.applySizingValues}
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
    self.getCoilHeatingGasMultiStages.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingWaters.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingDXSingleSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoilHeatingDXMultiSpeeds.sort.each {|obj| obj.applySizingValues}
    
    # Cooling coils
    self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingDXTwoSpeeds.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingWaters.sort.each {|obj| obj.applySizingValues}
    self.getCoilCoolingDXMultiSpeeds.sort.each {|obj| obj.applySizingValues}
    
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

    # Special logic for two coil types which are inconsistently
    # uppercase in the sqlfile:
    object_type = object_type.upcase if object_type == 'Coil:Cooling:WaterToAirHeatPump:EquationFit'
    object_type = object_type.upcase if object_type == 'Coil:Heating:WaterToAirHeatPump:EquationFit'
		object_type = 'Coil:Heating:GasMultiStage' if object_type == 'Coil:Heating:Gas:MultiStage'
		object_type = 'Coil:Heating:Fuel' if object_type == 'Coil:Heating:Gas'

    sql = self.sqlFile

    if sql.is_initialized
      sql = sql.get

      #SELECT * FROM ComponentSizes WHERE CompType = 'Coil:Heating:Gas' AND CompName = "COIL HEATING GAS 3" AND Description = "Design Size Nominal Capacity"
      query = "SELECT Value 
              FROM ComponentSizes 
              WHERE CompType='#{object_type}' 
              AND CompName='#{name}' 
              AND Description='#{value_name.strip}' 
              AND Units='#{units}'"
              
      val = sql.execAndReturnFirstDouble(query)

      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        # TODO: comment following line (debugging new HVACsizing objects right now)
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "QUERY ERROR: Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end

  # A helper method to get component sizes from the Equipment Summary of the TabularDataWithStrings Report
  # returns the autosized value as an optional double
  def getAutosizedValueFromEquipmentSummary(object, table_name, value_name, units)

    result = OpenStudio::OptionalDouble.new

    name = object.name.get.upcase

    sql = self.sqlFile

    if sql.is_initialized
      sql = sql.get

      #SELECT * FROM ComponentSizes WHERE CompType = 'Coil:Heating:Gas' AND CompName = "COIL HEATING GAS 3" AND Description = "Design Size Nominal Capacity"
      query = "Select Value FROM TabularDataWithStrings WHERE
      ReportName = 'EquipmentSummary' AND
      TableName = '#{table_name}' AND
      RowName = '#{name}' AND
      ColumnName = '#{value_name}' AND
      Units = '#{units}'"

      val = sql.execAndReturnFirstDouble(query)

      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        # TODO: comment following line (debugging new HVACsizing objects right now)
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "QUERY ERROR: Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end


  # Helper function to output the fan power for each fan in the model
  # @param [String] csv_path: if given, will output a csv file
  # @return [Array of Hash] each row is a fan, with its name, type, rated watts per cfm, and the airloop or hvac component or zonehvac component it serves
  # Todo: output actual bhp and allowable bhp for systems 3-4 and 5-8
  # Todo: remove maybe later?
  def output_fan_report(csv_path = nil)

    table = []

    # Deal with all the constant volume fans
    self.getFanConstantVolumes.each do |fan|
      row = {:name=>fan.name.to_s, :type=>'Constant Volume', :rated_w_per_cfm=>fan.rated_w_per_cfm.round(2), :air_loop=>'', :hvac_component=>'', :zone_hvac_component=>''}
      if fan.airLoopHVAC.is_initialized
        row[:air_loop] = fan.airLoopHVAC.get.name.to_s
      elsif fan.containingHVACComponent.is_initialized
        row[:hvac_component] = fan.containingHVACComponent.get.name.to_s
      elsif fan.containingZoneHVACComponent.is_initialized
        row[:zone_hvac_component] = fan.containingZoneHVACComponent.get.name.to_s
      end
      # Add to table
      table << row
    end

    # Deal with all the constant volume fans
    self.getFanVariableVolumes.each do |fan|
      row = {:name=>fan.name.to_s, :type=>'Variable Volume', :rated_w_per_cfm=>fan.rated_w_per_cfm.round(2), :air_loop=>'', :hvac_component=>'', :zone_hvac_component=>''}
      if fan.airLoopHVAC.is_initialized
        row[:air_loop] = fan.airLoopHVAC.get.name.to_s
      elsif fan.containingHVACComponent.is_initialized
        row[:hvac_component] = fan.containingHVACComponent.get.name.to_s
      elsif fan.containingZoneHVACComponent.is_initialized
        row[:zone_hvac_component] = fan.containingZoneHVACComponent.get.name.to_s
      end
      # Add to table
      table << row
    end

    # Deal with all the constant volume fans
    self.getFanOnOffs.each do |fan|
      row = {:name=>fan.name.to_s, :type=>'On Off', :rated_w_per_cfm=>fan.rated_w_per_cfm.round(2), :air_loop=>'', :hvac_component=>'', :zone_hvac_component=>''}
      if fan.airLoopHVAC.is_initialized
        row[:air_loop] = fan.airLoopHVAC.get.name.to_s
      elsif fan.containingHVACComponent.is_initialized
        row[:hvac_component] = fan.containingHVACComponent.get.name.to_s
      elsif fan.containingZoneHVACComponent.is_initialized
        row[:zone_hvac_component] = fan.containingZoneHVACComponent.get.name.to_s
      end
      # Add to table
      table << row
    end

    # If a csv path is given, output
    if !csv_path.nil? && !table.first.nil?
      CSV.open(csv_path, "wb") do |csv|
        csv << table.first.keys # adds the attributes name on the first line
        table.each do |hash|
          csv << hash.values
        end
      end
    end

    return table

  end

end
