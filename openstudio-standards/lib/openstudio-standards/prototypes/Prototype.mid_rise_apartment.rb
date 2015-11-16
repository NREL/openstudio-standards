
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    
    space_type_map = {
        'Office' => ['Office'],
        'Corridor' => ['G Corridor', 'M Corridor', 'T Corridor'],
        'Apartment' => [
          'G SW Apartment',
          'G NW Apartment',
          'G NE Apartment',
          'G N1 Apartment',
          'G N2 Apartment',
          'G S1 Apartment',
          'G S2 Apartment',
          'M SW Apartment',
          'M NW Apartment',
          'M SE Apartment',
          'M NE Apartment',
          'M N1 Apartment',
          'M N2 Apartment',
          'M S1 Apartment',
          'M S2 Apartment',
          'T SW Apartment',
          'T NW Apartment',
          'T SE Apartment',
          'T NE Apartment',
          'T N1 Apartment',
          'T N2 Apartment',
          'T S1 Apartment',
          'T S2 Apartment',
        ]
      }
    
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {'type' => 'SAC',
       'space_names' => ['G SW Apartment']},
      {'type' => 'SAC',
       'space_names' => ['G NW Apartment']},
      {'type' => 'SAC',
       'space_names' => ['G NE Apartment']},
      {'type' => 'SAC',
       'space_names' => ['G N1 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['G N2 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['G S1 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['G S2 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M SW Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M NW Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M SE Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M NE Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M N1 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M N2 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M S1 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['M S2 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T SW Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T NW Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T SE Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T NE Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T N1 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T N2 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T S1 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['T S2 Apartment']},
      {'type' => 'SAC',
       'space_names' => ['Office']}
      ]

    case building_vintage
    when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
      system_to_space_map.push({'type' => 'UnitHeater', 'space_names' => ['G Corridor']})
      system_to_space_map.push({'type' => 'UnitHeater', 'space_names' => ['M Corridor']})
      system_to_space_map.push({'type' => 'UnitHeater', 'space_names' => ['T Corridor']})      
    end
    
    return system_to_space_map
  end

  def define_space_multiplier
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = {
      'M SW Apartment' => 2,
      'M NW Apartment' => 2,
      'M SE Apartment' => 2,
      'M NE Apartment' => 2,
      'M N1 Apartment' => 2,
      'M N2 Apartment' => 2,
      'M S1 Apartment' => 2,
      'M S2 Apartment' => 2,
      'M Corridor' => 2
    }
    return space_multiplier_map
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
      when 'SAC'
        self.add_split_AC(prototype_input, hvac_standards, thermal_zones)
      when 'UnitHeater'
        self.add_unitheater(prototype_input, hvac_standards, thermal_zones)
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Undefined HVAC system type called #{system['type']}")
        return false
      end

    end

    # adjust the cooling setpoint
    self.adjust_clg_setpoint(building_vintage,climate_zone)
        
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

  def adjust_clg_setpoint(building_vintage,climate_zone)
    space_name = 'Office'
    space_type_name = self.getSpaceByName(space_name).get.spaceType.get.name.get
    thermostat_name = space_type_name + ' Thermostat'
    thermostat = self.getThermostatSetpointDualSetpointByName(thermostat_name).get
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010'
      case climate_zone
      when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
        thermostat.setCoolingSetpointTemperatureSchedule(add_schedule("ApartmentMidRise CLGSETP_OFF_SCH_NO_OPTIMUM"))
      end
    end
  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    # the main service water loop except laundry
    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    
    space_type_map.each do |space_type_name, space_names|
      data = nil
      search_criteria = {
        'template' => building_vintage,
        'building_type' => building_type,
        'space_type' => space_type_name
      }
      data = find_object(self.standards['space_types'],search_criteria)
      
      if data['service_water_heating_peak_flow_rate'].nil?
        next
      else
        space_names.each do |space_name|
          space = self.getSpaceByName(space_name).get
          space_multiplier = space.multiplier
          puts "#{space_name} space_multiplier = #{space_multiplier}"
          self.add_swh_end_uses_by_space(building_type, building_vintage, climate_zone, main_swh_loop, space_type_name, space_name, space_multiplier)
        end
      end
    end


    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh    

  
end
