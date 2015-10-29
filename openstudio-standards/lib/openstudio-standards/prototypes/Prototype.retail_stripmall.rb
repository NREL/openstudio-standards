
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      'Strip mall - type 1' => [
        'LGstore1', 'SMstore1'
      ],
      'Strip mall - type 2' => [
        'SMstore2', 'SMstore3', 'SMstore4'
      ],
      'Strip mall - type 3' => [
        'LGstore2', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'
      ]
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
          'type' => 'CAV',
          'name' => 'PSZ-AC_1',
          'space_names' => ['LGSTORE1']
      },
      {
          'type' => 'CAV',
          'name' => 'PSZ-AC_2',
          'space_names' => ['SMstore1']
      },
      {
        'type' => 'CAV2',
        'name' => 'PSZ-AC_3',
        'space_names' => ['SMstore2']
      },
      {
        'type' => 'CAV2',
        'name' => 'PSZ-AC_4',
        'space_names' => ['SMstore3']
      },
      {
        'type' => 'CAV2',
        'name' => 'PSZ-AC_5',
        'space_names' => ['SMstore4']
      },{
        'type' => 'CAV3',
        'name' => 'PSZ-AC_6',
        'space_names' => ['LGSTORE2']
      },
      {
        'type' => 'CAV3',
        'name' => 'PSZ-AC_7',
        'space_names' => ['SMstore5']
      },
      {
        'type' => 'CAV3',
        'name' => 'PSZ-AC_8',
        'space_names' => ['SMstore6']
      },
      {
        'type' => 'CAV3',
        'name' => 'PSZ-AC_9',
        'space_names' => ['SMstore7']
      },
      {
        'type' => 'CAV3',
        'name' => 'PSZ-AC_10',
        'space_names' => ['SMstore8']
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
          self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones)
        when 'CAV2'
          self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones,"DrawThrough",nil,nil,"_2")
        when 'CAV3'
          self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones,"DrawThrough",nil,nil,"_3")
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "HVAC system type (#{system['type']}) was not defined for strip mall.")
          return false
      end
    end

    # Add infiltration door opening
    # Spaces names to design infiltration rates (m3/s)
    case building_vintage
      when '90.1-2004','90.1-2007','90.1-2010', '90.1-2013'
        door_infiltration_map = { ['LGstore1','LGstore2'] => 0.388884328,
                                  ['SMstore1','SMstore2', 'SMstore3', 'SMstore4','SMstore5', 'SMstore6', 'SMstore7', 'SMstore8']=>0.222287037}

        door_infiltration_map.each_pair do |space_names, infiltration_design_flowrate|
          space_names.each do |space_name|
            space = self.getSpaceByName(space_name).get
            # Create the infiltration object and hook it up to the space type
            infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
            infiltration.setName("#{space_name} Door Open Infiltration")
            infiltration.setSpace(space)
            infiltration.setDesignFlowRate(infiltration_design_flowrate)
            infiltration_schedule = self.add_schedule('RetailStripmall INFIL_Door_Opening_SCH')
            if infiltration_schedule.nil?
              OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Can't find schedule (RetailStripmall INFIL_Door_Opening_SCH).")
              return false
            else
              infiltration.setSchedule(infiltration_schedule)
            end
          end
        end
      else
        # do nothing for the old vintage
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    return true
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
    return true if building_vintage == "DOE Ref Pre-1980" or building_vintage == "DOE Ref 1980-2004"
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")
    # Add the main service hot water loop
    swh_space_names = ["LGstore1","SMstore1","SMstore2","SMstore3","LGstore2","SMstore5","SMstore6"]
    swh_sch_names = ["RetailStripmall Type1_SWH_SCH","RetailStripmall Type1_SWH_SCH","RetailStripmall Type2_SWH_SCH",
                     "RetailStripmall Type2_SWH_SCH","RetailStripmall Type3_SWH_SCH","RetailStripmall Type3_SWH_SCH",
                     "RetailStripmall Type3_SWH_SCH"]
    use_rate = 0.03 # in gal/min

    for i in 0...swh_space_names.size
      swh_space_name = swh_space_names[i]
      swh_sch_name = swh_sch_names[i]
      swh_thermal_zone = self.getSpaceByName(swh_space_name).get.thermalZone.get
      swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main', swh_thermal_zone)

      water_heaters = swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)

      water_heaters.each do |water_heater|
        water_heater = water_heater.to_WaterHeaterMixed.get
        water_heater.setOffCycleParasiticFuelConsumptionRate(173)
        water_heater.setOffCycleParasiticHeatFractiontoTank(0)
        water_heater.setOnCycleParasiticFuelConsumptionRate(173)
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.205980747)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.205980747)
      end

      # Water use connection
      swh_connection = OpenStudio::Model::WaterUseConnections.new(self)
      swh_connection.setName(swh_space_name + "Water Use Connections")
      # Water fixture definition
      water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
      rated_flow_rate_m3_per_s = OpenStudio.convert(use_rate,'gal/min','m^3/s').get
      water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
      water_fixture_def.setName("#{swh_space_name} Service Water Use Def #{use_rate.round(2)}gal/min")

      sensible_fraction = 0.2
      latent_fraction = 0.05

      # Target mixed water temperature
      mixed_water_temp_f = prototype_input["main_water_use_temperature"]
      mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),OpenStudio.convert(mixed_water_temp_f,'F','C').get)
      water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

      sensible_fraction_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      sensible_fraction_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),sensible_fraction)
      water_fixture_def.setSensibleFractionSchedule(sensible_fraction_sch)

      latent_fraction_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      latent_fraction_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),latent_fraction)
      water_fixture_def.setSensibleFractionSchedule(latent_fraction_sch)

      # Water use equipment
      water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
      schedule = self.add_schedule(swh_sch_name)
      water_fixture.setFlowRateFractionSchedule(schedule)
      water_fixture.setName("#{swh_space_name} Service Water Use #{use_rate.round(2)}gal/min")
      swh_connection.addWaterUseEquipment(water_fixture)

      # Connect the water use connection to the SWH loop
      swh_loop.addDemandBranchForComponent(swh_connection)

    end

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    return true
    
  end #add swh    
  
  def add_refrigeration(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
       
    return false
    
  end #add refrigeration
  
end
