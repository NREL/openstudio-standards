
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      'Dining' => ['Dining'],
      'Kitchen' => ['Kitchen']
      # ,
      # 'Attic' => ['attic']
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
          'type' => 'CAV',
          'space_names' => ['Dining', 'Kitchen']
      }
    ]
    return system_to_space_map
  end
     
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    # hot_water_loop = self.add_hw_loop(prototype_input, hvac_standards)
    
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
      when 'CAV'
        self.add_psz_ac(prototype_input, hvac_standards, thermal_zones)
      end

    end

    ['Dining', 'Kitchen'].each do |space_name|
      space = self.getSpaceByName(space_name)
      if space.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
        return false
      end
      space = space.get
      thermal_zone = space.thermalZone
      if thermal_zone.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
        return false
      end
      thermal_zone = thermal_zone.get

      zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(self)
      zone_exhaust_fan.setAvailabilitySchedule(self.add_schedule('RestaurantSitDown Hours_of_operation'))
      zone_exhaust_fan.setFanEfficiency(1)
      zone_exhaust_fan.setMaximumFlowRate(1.33143208408505)
      zone_exhaust_fan.addToThermalZone(thermal_zone)
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

    condenser1.setRatedFanPower(330)

    ref_case1 = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case1.setThermalZone(thermal_zone)
    ref_case1.setRatedTotalCoolingCapacityperUnitLength(688.0)
    ref_case1.setCaseLength(2.4400)
    ref_case1.setCaseOperatingTemperature(-23.0)
    ref_case1.setStandardCaseFanPowerperUnitLength(74)
    ref_case1.setOperatingCaseFanPowerperUnitLength(74)
    ref_case1.setCaseLightingSchedule(self.add_schedule('RestaurantSitDown BLDG_LIGHT_SCH'))
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

    condenser2.setRatedFanPower(330)

    ref_case2 = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case2.setThermalZone(thermal_zone)
    ref_case2.setRatedTotalCoolingCapacityperUnitLength(734.0)
    ref_case2.setCaseLength(3.05)
    ref_case2.setCaseOperatingTemperature(2.0)
    ref_case2.setStandardCaseFanPowerperUnitLength(66)
    ref_case2.setOperatingCaseFanPowerperUnitLength(66)
    ref_case2.setCaseLightingSchedule(self.add_schedule('RestaurantSitDown BLDG_LIGHT_SCH'))
    ref_case2.setHumidityatZeroAntiSweatHeaterEnergy(0)
    ref_case2.setCaseDefrostType('None')

    ref_sys2.addCase(ref_case2)

    ref_sys2.setRefrigerationCondenser(condenser2)
    ref_sys2.setSuctionPipingZone(thermal_zone)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding Refrigeration System")
       
    return true
    
  end #add refrigeration
  
end
