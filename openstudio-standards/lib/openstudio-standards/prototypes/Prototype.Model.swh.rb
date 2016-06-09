
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  def add_swh(building_type, building_vintage, climate_zone, prototype_input)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Service Water Heating')
   
    # Add the main service water heating loop, if specified
    unless prototype_input['main_water_heater_volume'].nil?
      
      # Add the main service water loop
      main_swh_loop = self.add_swh_loop(building_vintage,
                                        'Main Service Water Loop',
                                        nil,
                                        OpenStudio.convert(prototype_input['main_service_water_temperature'],'F','C').get,
                                        prototype_input['main_service_water_pump_head'],
                                        prototype_input['main_service_water_pump_motor_efficiency'],
                                        OpenStudio.convert(prototype_input['main_water_heater_capacity'],'Btu/hr','W').get,
                                        OpenStudio.convert(prototype_input['main_water_heater_volume'],'gal','m^3').get,
                                        prototype_input['main_water_heater_fuel'],
                                        OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'],'Btu/hr','W').get,
                                        building_type) unless building_type == 'RetailStripmall' and building_vintage != 'NECB 2011'
      
      # Attach the end uses if specified in prototype inputs
      # TODO remove special logic for large office SWH end uses
      # TODO remove special logic for stripmall SWH end uses and service water loops
      # TODO remove special logic for large hotel SWH end uses
      if building_type == 'LargeOffice' and building_vintage != 'NECB 2011'
          
          # Only the core spaces have service water
          ['Core_bottom', 'Core_mid', 'Core_top'].each do |space_name|
            self.add_swh_end_uses(building_vintage,
                              'Main',
                              main_swh_loop,
                              OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'],'gal/min','m^3/s').get,
                              prototype_input['main_service_water_flowrate_schedule'],
                              OpenStudio.convert(prototype_input['main_water_use_temperature'],'F','C').get,
                              space_name,
                              building_type)
          end
      
      elsif building_type == 'RetailStripmall' and building_vintage != 'NECB 2011'

        return true if building_vintage == "DOE Ref Pre-1980" || building_vintage == "DOE Ref 1980-2004"

        # Create a separate hot water loop & water heater for each space in the list
        swh_space_names = ["LGstore1","SMstore1","SMstore2","SMstore3","LGstore2","SMstore5","SMstore6"]
        swh_sch_names = ["RetailStripmall Type1_SWH_SCH","RetailStripmall Type1_SWH_SCH","RetailStripmall Type2_SWH_SCH",
                         "RetailStripmall Type2_SWH_SCH","RetailStripmall Type3_SWH_SCH","RetailStripmall Type3_SWH_SCH",
                         "RetailStripmall Type3_SWH_SCH"]
        rated_use_rate_gal_per_min = 0.03 # in gal/min
        rated_flow_rate_m3_per_s = OpenStudio.convert(rated_use_rate_gal_per_min,'gal/min','m^3/s').get

        # Loop through all spaces
        swh_space_names.zip(swh_sch_names).each do |swh_space_name, swh_sch_name|
          swh_thermal_zone = self.getSpaceByName(swh_space_name).get.thermalZone.get
          main_swh_loop = self.add_swh_loop(building_vintage,
                                        "#{swh_thermal_zone.name} Service Water Loop",
                                        swh_thermal_zone,
                                        OpenStudio.convert(prototype_input['main_service_water_temperature'],'F','C').get,
                                        prototype_input['main_service_water_pump_head'],
                                        prototype_input['main_service_water_pump_motor_efficiency'],
                                        OpenStudio.convert(prototype_input['main_water_heater_capacity'],'Btu/hr','W').get,
                                        OpenStudio.convert(prototype_input['main_water_heater_volume'],'gal','m^3').get,
                                        prototype_input['main_water_heater_fuel'],
                                        OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'],'Btu/hr','W').get,
                                        building_type)

          
          self.add_swh_end_uses(building_vintage,
                                'Main',
                                main_swh_loop,
                                rated_flow_rate_m3_per_s,
                                swh_sch_name,
                                OpenStudio.convert(prototype_input['main_water_use_temperature'],'F','C').get,
                                swh_space_name,
                                building_type)

        end

=begin      
      elsif building_type == 'LargeHotel'
      
        # Add water use equipment to each space
        guess_room_water_use_schedule = "HotelLarge GuestRoom_SWH_Sch"
        kitchen_water_use_schedule = "HotelLarge BLDG_SWH_SCH"

        water_end_uses = []
        space_type_map = self.define_space_type_map(building_type, building_vintage, climate_zone)
        space_multipliers = define_space_multiplier

        kitchen_space_types = ['Kitchen']
        kitchen_space_use_rate = 2.22 # gal/min, from PNNL prototype building

        guess_room_water_use_rate = 0.020833333 # gal/min, Reference: NREL Reference building report 5.1.6

        # Create a list of water use rates and associated room multipliers
        case building_vintage
        when "90.1-2004", "90.1-2007", "90.1-2010", "90.1-2013"
          guess_room_space_types =['GuestRoom','GuestRoom2','GuestRoom3','GuestRoom4']
        else
          guess_room_space_types =['GuestRoom','GuestRoom3']
          guess_room_space_types1 = ['GuestRoom2']
          guess_room_space_types2 = ['GuestRoom4']
          guess_room_water_use_rate1 = 0.395761032 # gal/min, Reference building
          guess_room_water_use_rate2 = 0.187465752 # gal/min, Reference building

          laundry_water_use_schedule = "HotelLarge LaundryRoom_Eqp_Elec_Sch"
          laundry_space_types = ['Laundry']
          laundry_room_water_use_rate = 2.6108244 # gal/min, Reference building
          
          guess_room_space_types1.each do |space_type|
            space_names = space_type_map[space_type]
            space_names.each do |space_name|
              space_multiplier = 1
              space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
              water_end_uses.push([space_name, guess_room_water_use_rate1 * space_multiplier,guess_room_water_use_schedule])
            end
          end

          guess_room_space_types2.each do |space_type|
            space_names = space_type_map[space_type]
            space_names.each do |space_name|
              space_multiplier = 1
              space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
              water_end_uses.push([space_name, guess_room_water_use_rate2 * space_multiplier,guess_room_water_use_schedule])
            end
          end

          laundry_space_types.each do |space_type|
            space_names = space_type_map[space_type]
            space_names.each do |space_name|
              space_multiplier = 1
              space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
              water_end_uses.push([space_name, laundry_room_water_use_rate * space_multiplier,laundry_water_use_schedule])
            end
          end
        end

        guess_room_space_types.each do |space_type|
          space_names = space_type_map[space_type]
          space_names.each do |space_name|
            space_multiplier = 1
            space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
            water_end_uses.push([space_name, guess_room_water_use_rate * space_multiplier,guess_room_water_use_schedule])
          end
        end

        kitchen_space_types.each do |space_type|
          space_names = space_type_map[space_type]
          space_names.each do |space_name|
            space_multiplier = 1
            space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
            water_end_uses.push([space_name, kitchen_space_use_rate * space_multiplier,kitchen_water_use_schedule])
          end
        end
      
        # Connect the water use equipment to the loop
        water_end_uses.each do |water_end_use|
          space_name = water_end_use[0]
          use_rate = water_end_use[1] # in gal/min
          use_schedule = water_end_use[2]
          
          self.add_swh_end_uses(building_vintage,
                              'Main',
                              main_swh_loop,
                              OpenStudio.convert(use_rate,'gal/min','m^3/s').get,
                              use_schedule,
                              OpenStudio.convert(prototype_input['main_water_use_temperature'],'F','C').get,
                              space_name,
                              building_type)
        end
=end
 
      elsif prototype_input['main_service_water_peak_flowrate']
        
        # Attaches the end uses if specified as a lump value in the prototype_input
        self.add_swh_end_uses(building_vintage,
                              'Main',
                              main_swh_loop,
                              OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'],'gal/min','m^3/s').get,
                              prototype_input['main_service_water_flowrate_schedule'],
                              OpenStudio.convert(prototype_input['main_water_use_temperature'],'F','C').get,
                              nil,
                              building_type)
                              
      else                    
        
        # Attaches the end uses if specified by space type 
        
        if building_vintage == 'NECB 2011'
          building_type = 'Space Function'
        end
        
        space_type_map = self.define_space_type_map(building_type, building_vintage, climate_zone)
        space_type_map.each do |space_type_name, space_names|
          search_criteria = {
            'template' => building_vintage,
            'building_type' => get_lookup_name(building_type),
            'space_type' => space_type_name
          }
          data = find_object($os_standards['space_types'],search_criteria)
          
          # Skip space types with no data
          next if data.nil?
          
          # Skip space types with no water use, unless it is a NECB archetype (these do not have peak flow rates defined)
          next if data['service_water_heating_peak_flow_rate'].nil? unless building_vintage == 'NECB 2011'

          # Add a service water use for each space
          space_names.each do |space_name|
            
            space = self.getSpaceByName(space_name).get
            space_multiplier = space.multiplier
            self.add_swh_end_uses_by_space(get_lookup_name(building_type),
                                          building_vintage,
                                          climate_zone,
                                          main_swh_loop,
                                          space_type_name,
                                          space_name,
                                          space_multiplier)
          end

        end

      end  

    end
      
    # Add the booster water heater, if specified
    unless prototype_input['booster_water_heater_volume'].nil?
    
      # Add the booster water loop
      swh_booster_loop = self.add_swh_booster(building_vintage,
                                              main_swh_loop,
                                              OpenStudio.convert(prototype_input['booster_water_heater_capacity'],'Btu/hr','W').get,
                                              OpenStudio.convert(prototype_input['booster_water_heater_volume'],'gal','m^3').get,
                                              prototype_input['booster_water_heater_fuel'],
                                              OpenStudio.convert(prototype_input['booster_water_temperature'],'F','C').get,
                                              0,
                                              nil,
                                              building_type)
    
      # Attach the end uses
      self.add_booster_swh_end_uses(building_vintage,
                                    swh_booster_loop,
                                    OpenStudio.convert(prototype_input['booster_service_water_peak_flowrate'],'gal/min','m^3/s').get,
                                    prototype_input['booster_service_water_flowrate_schedule'],
                                    OpenStudio.convert(prototype_input['booster_water_use_temperature'],'F','C').get,
                                    building_type) 

    end
    
    # Add the laundry water heater, if specified
    unless prototype_input['laundry_water_heater_volume'].nil?
    
      # Add the laundry service water heating loop
      laundry_swh_loop = self.add_swh_loop(building_vintage,
                                        'Laundry Service Water Loop',
                                        nil,
                                        OpenStudio.convert(prototype_input['laundry_service_water_temperature'],'F','C').get,
                                        prototype_input['laundry_service_water_pump_head'],
                                        prototype_input['laundry_service_water_pump_motor_efficiency'],
                                        OpenStudio.convert(prototype_input['laundry_water_heater_capacity'],'Btu/hr','W').get,
                                        OpenStudio.convert(prototype_input['laundry_water_heater_volume'],'gal','m^3').get,
                                        prototype_input['laundry_water_heater_fuel'],
                                        OpenStudio.convert(prototype_input['laundry_service_water_parasitic_fuel_consumption_rate'],'Btu/hr','W').get,
                                        building_type)
    
      # Attach the end uses if specified in prototype inputs
      self.add_swh_end_uses(building_vintage,
                            'Laundry',
                            laundry_swh_loop,
                            OpenStudio.convert(prototype_input['laundry_service_water_peak_flowrate'],'gal/min','m^3/s').get,
                            prototype_input['laundry_service_water_flowrate_schedule'],
                            OpenStudio.convert(prototype_input['laundry_water_use_temperature'],'F','C').get,
                            nil,
                            building_type)

    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Service Water Heating')
    
    return true
    
  end #add swh
  
end
