
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      # 'Basement', 'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', 'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2', 'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2', 'PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PhysTherapy_Flr_3', 'PatRoom6_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'NurseStn_Lobby_Flr_3', 'Lab_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 'Radiology_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4', 'NurseStn_Lobby_Flr_4', 'Lab_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 'Kitchen_Flr_5', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
      'Corridor' => ['Corridor_Flr_1', 'Corridor_Flr_2', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Corridor_Flr_5'],
      'Dining' => ['Dining_Flr_5', ],
      'ER_Exam' => ['ER_Exam1_Mult4_Flr_1', 'ER_Exam3_Mult4_Flr_1', ],
      'ER_NurseStn' => ['ER_NurseStn_Lobby_Flr_1', ],
      'ER_Trauma' => ['ER_Trauma1_Flr_1', 'ER_Trauma2_Flr_1', ],
      'ER_Triage' => ['ER_Triage_Mult4_Flr_1', ],
      'ICU_NurseStn' => ['ICU_NurseStn_Lobby_Flr_2', ],
      'ICU_Open' => ['ICU_Flr_2', ],
      'ICU_PatRm' => ['IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', ],
      'Kitchen' => ['Kitchen_Flr_5', ],
      'Lab' => ['Lab_Flr_3', 'Lab_Flr_4', ],
      'Lobby' => ['Lobby_Records_Flr_1', ],
      'NurseStn' => ['OR_NurseStn_Lobby_Flr_2', 'NurseStn_Lobby_Flr_3', 'NurseStn_Lobby_Flr_4', 'NurseStn_Lobby_Flr_5', ],
      'OR' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', ],
      'Office' => ['Office1_Mult4_Flr_1', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Basement', ], # I don't know where to put Basement
      # 'PatCorridor' => [],
      'PatRoom' => ['PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3', 
        'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 
        'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4', ],
      'PhysTherapy' => ['PhysTherapy_Flr_3', ],
      'Radiology' => ['Radiology_Flr_4', ]
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
          'type' => 'VAV',
          'space_names' => [
            'Basement', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 
            'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3', 
            'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 
            'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'PhysTherapy_Flr_3', 'NurseStn_Lobby_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Radiology_Flr_4', 
            'NurseStn_Lobby_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 
            'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'Lab_Flr_3', 'Lab_Flr_4'
          ]
      },
      {
          'type' => 'CAV',
          'space_names' => [
            'Kitchen_Flr_5'
          ]
      }
    ]
    return system_to_space_map
  end
     
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    chilled_water_loop = self.add_chw_loop(prototype_input, hvac_standards)

    hot_water_loop = self.add_hw_loop(prototype_input, hvac_standards)
    
    system_to_space_map.each do |system|

      #find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = self.getSpaceByName(space_name)
        if space.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      case system['type']
      when 'VAV'
        self.add_vav(prototype_input, hvac_standards, hot_water_loop, chilled_water_loop, thermal_zones)
      when 'CAV'
        self.add_psz_ac(prototype_input, hvac_standards, thermal_zones, 'DrawThrough', hot_water_loop, chilled_water_loop)
      end

    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)
    
    water_heaters.each do |water_heater|
      water_heater = water_heater.to_WaterHeaterMixed.get
      # water_heater.setAmbientTemperatureIndicator('Zone')
      # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
      water_heater.setOffCycleParasiticFuelConsumptionRate(720)
      water_heater.setOnCycleParasiticFuelConsumptionRate(720)
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
    end

    self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh    
  
  def add_refrigeration(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding Refrigeration System")

    #Schedule Ruleset
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    defrost_sch.setName("Refrigeration Defrost Schedule")
    #All other days
    defrost_sch.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default")
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,4,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,4,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,8,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,8,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,12,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,12,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,16,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,16,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,20,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,20,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0)

    space = self.getSpaceByName('Kitchen')
    if space.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called Kitchen was found in the model")
      return false
    end
    space = space.get
    thermal_zone = space.thermalZone
    if thermal_zone.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
      return false
    end
    thermal_zone = thermal_zone.get

    ref_sys1 = OpenStudio::Model::RefrigerationSystem.new(self)
    ref_sys1.addCompressor(OpenStudio::Model::RefrigerationCompressor.new(self))
    condenser1 = OpenStudio::Model::RefrigerationCondenserAirCooled.new(self)

    condenser1.setRatedFanPower(1000)

    ref_case1 = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case1.setThermalZone(thermal_zone)
    ref_case1.setRatedTotalCoolingCapacityperUnitLength(688.0)
    ref_case1.setCaseLength(2.4400)
    ref_case1.setCaseOperatingTemperature(-23.0)
    ref_case1.setStandardCaseFanPowerperUnitLength(74)
    ref_case1.setOperatingCaseFanPowerperUnitLength(74)
    ref_case1.setCaseLightingSchedule(self.add_schedule('Hospital BLDG_LIGHT_SCH'))
    ref_case1.setHumidityatZeroAntiSweatHeaterEnergy(0)
    ref_case1.setCaseDefrostPowerperUnitLength(820.0)
    ref_case1.setCaseDefrostType('Electric')
    ref_case1.setDesignEvaporatorTemperatureorBrineInletTemperature(-24.0)

    ref_sys1.addCase(ref_case1)

    ref_sys1.setRefrigerationCondenser(condenser1)
    ref_sys1.setSuctionPipingZone(thermal_zone)

    ref_sys2 = OpenStudio::Model::RefrigerationSystem.new(self)
    ref_sys2.addCompressor(OpenStudio::Model::RefrigerationCompressor.new(self))
    condenser2 = OpenStudio::Model::RefrigerationCondenserAirCooled.new(self)

    condenser2.setRatedFanPower(1000)

    ref_case2 = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case2.setThermalZone(thermal_zone)
    ref_case2.setRatedTotalCoolingCapacityperUnitLength(734.0)
    ref_case2.setCaseLength(3.05)
    ref_case2.setCaseOperatingTemperature(2.0)
    ref_case2.setStandardCaseFanPowerperUnitLength(66)
    ref_case2.setOperatingCaseFanPowerperUnitLength(66)
    ref_case2.setCaseLightingSchedule(self.add_schedule('Hospital BLDG_LIGHT_SCH'))
    ref_case2.setHumidityatZeroAntiSweatHeaterEnergy(0)
    ref_case2.setCaseDefrostType('None')

    ref_sys2.addCase(ref_case2)

    ref_sys2.setRefrigerationCondenser(condenser2)
    ref_sys2.setSuctionPipingZone(thermal_zone)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding Refrigeration System")
       
    return true
    
  end #add refrigeration
  
end
