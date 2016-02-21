
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  def add_hvac(building_type, building_vintage, climate_zone, prototype_input)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    # Get the list of HVAC systems, as defined
    # for each building in the Prototype.building_name files.
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    # Add each HVAC system
    system_to_space_map.each do |system|

      thermal_zones = get_zones_from_spaces_on_system(system)

      return_plenum = get_return_plenum_from_system(system)
      
      # Add the HVAC systems
      case system['type']
      when 'VAV'
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end

        # Retrieve the existing chilled water loop
        # or add a new one if necessary.
        chilled_water_loop = nil
        if self.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = self.getPlantLoopByName('Chilled Water Loop').get
        else
          condenser_water_loop = nil
          if prototype_input['chiller_condenser_type'] == 'WaterCooled'
            condenser_water_loop = self.add_cw_loop()
          end
          
          chilled_water_loop = self.add_chw_loop(building_vintage,
                                                prototype_input['chw_pumping_type'],
                                                prototype_input['chiller_cooling_type'],
                                                prototype_input['chiller_condenser_type'],
                                                prototype_input['chiller_compressor_type'],
                                                prototype_input['chiller_capacity_guess'],
                                                condenser_water_loop)
                                 
        end
      
        # Add the VAV
        self.add_vav_reheat(building_vintage, 
            system['name'], 
            hot_water_loop, 
            chilled_water_loop,
            thermal_zones,
            prototype_input['vav_operation_schedule'],
            prototype_input['vav_oa_damper_schedule'],
            prototype_input['vav_fan_efficiency'],
            prototype_input['vav_fan_motor_efficiency'],
            prototype_input['vav_fan_pressure_rise'],
            return_plenum,
            building_type)
          
      when 'CAV'
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end
        
        # Add the CAV
        self.add_cav(building_vintage,
                    system['name'],
                    hot_water_loop,
                    thermal_zones,
                    prototype_input['vav_operation_schedule'],
                    prototype_input['vav_oa_damper_schedule'],
                    prototype_input['vav_fan_efficiency'],
                    prototype_input['vav_fan_motor_efficiency'],
                    prototype_input['vav_fan_pressure_rise'],
                    building_type)
        
      when 'PSZ-AC'
      
        # Special logic to differentiate between operation schedules
        # that vary even inside of a system type for stripmall.
        hvac_op_sch = nil
        oa_sch = nil
        if system['hvac_op_sch_index'].nil? || system['hvac_op_sch_index'] == 1
          hvac_op_sch = prototype_input['pszac_operation_schedule']
          oa_sch = prototype_input['pszac_oa_damper_schedule']
        elsif system['hvac_op_sch_index'] == 2
          hvac_op_sch = prototype_input['pszac_operation_schedule_2']
          oa_sch = prototype_input['pszac_oa_damper_schedule_2']
        elsif system['hvac_op_sch_index'] == 3
          hvac_op_sch = prototype_input['pszac_operation_schedule_3']
          oa_sch = prototype_input['pszac_oa_damper_schedule_3']
        end
      
        # Special logic to make unitary heat pumps all blow-through
        fan_position = 'DrawThrough'
        if prototype_input['pszac_heating_type'] == 'Single Speed Heat Pump' ||
          prototype_input['pszac_heating_type'] == 'Water To Air Heat Pump'
          fan_position = 'BlowThrough'
        end
      
        # Special logic to make a heat pump loop if necessary
        heat_pump_loop = nil
        if prototype_input['pszac_heating_type'] == 'Water To Air Heat Pump'
          heat_pump_loop = add_hp_loop(prototype_input)
        end
      
        self.add_psz_ac(building_vintage, 
                        system['name'], 
                        heat_pump_loop, # Typically nil unless water source hp
                        heat_pump_loop, # Typically nil unless water source hp
                        thermal_zones, 
                        hvac_op_sch,
                        oa_sch,
                        fan_position, 
                        prototype_input['pszac_fan_type'],
                        prototype_input['pszac_heating_type'],
                        prototype_input['pszac_supplemental_heating_type'],
                        prototype_input['pszac_cooling_type'],
                        building_type)
          
      when 'PVAV'
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end      

        self.add_pvav(building_vintage, 
                      system['name'], 
                      thermal_zones, 
                      prototype_input['vav_operation_schedule'],
                      prototype_input['vav_oa_damper_schedule'],
                      hot_water_loop,
                      return_plenum)
      
      when 'DOAS'
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end

        # Retrieve the existing chilled water loop
        # or add a new one if necessary.
        chilled_water_loop = nil
        if self.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = self.getPlantLoopByName('Chilled Water Loop').get
        else
          condenser_water_loop = nil
          if prototype_input['chiller_condenser_type'] == 'WaterCooled'
            condenser_water_loop = self.add_cw_loop()
          end
          
          chilled_water_loop = self.add_chw_loop(building_vintage,
                                                prototype_input['chw_pumping_type'],
                                                prototype_input['chiller_cooling_type'],
                                                prototype_input['chiller_condenser_type'],
                                                prototype_input['chiller_compressor_type'],
                                                prototype_input['chiller_capacity_guess'],
                                                condenser_water_loop)
        end      

        self.add_doas(building_vintage, 
                    system['name'], 
                    hot_water_loop, 
                    chilled_water_loop,
                    thermal_zones,
                    prototype_input['vav_operation_schedule'],
                    prototype_input['doas_oa_damper_schedule'],
                    prototype_input['doas_fan_maximum_flow_rate'],
                    prototype_input['doas_economizer_control_type'],
                    building_type)       

      when 'DC' # Data Center
      
        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        if self.getPlantLoopByName('Hot Water Loop').is_initialized
          hot_water_loop = self.getPlantLoopByName('Hot Water Loop').get
        else
          hot_water_loop = self.add_hw_loop('NaturalGas')
        end      
      
        # Retrieve the existing heat pump loop
        # or add a new one if necessary.
        heat_pump_loop = nil
        if self.getPlantLoopByName('Heat Pump Loop').is_initialized
          heat_pump_loop = self.getPlantLoopByName('Heat Pump Loop').get
        else
          heat_pump_loop = self.add_hp_loop()
        end
      
        self.add_data_center_hvac(building_vintage,
                                nil,
                                hot_water_loop,
                                heat_pump_loop,
                                thermal_zones,
                                prototype_input['flow_fraction_schedule_name'],
                                prototype_input['flow_fraction_schedule_name'],
                                system['main_data_center'])
      
      when 'SAC'
      
        self.add_split_AC(building_vintage, 
                          nil,
                          thermal_zones, 
                          prototype_input['sac_operation_schedule'],
                          prototype_input['sac_operation_schedule_meeting'],
                          prototype_input['sac_oa_damper_schedule'],
                          prototype_input['sac_fan_type'],
                          prototype_input['sac_heating_type'],
                          prototype_input['sac_heating_type'],
                          prototype_input['sac_cooling_type'],
                          building_type)

      when 'UnitHeater'
      
        self.add_unitheater(building_vintage, 
                            nil,
                            thermal_zones, 
                            prototype_input['unitheater_operation_schedule'],
                            prototype_input['unitheater_fan_control_type'],
                            prototype_input['unitheater_fan_static_pressure'],
                            prototype_input['unitheater_heating_type'],
                            building_type)

      when 'PTAC'

        self.add_ptac(building_vintage, 
                      nil,
                      nil,
                      thermal_zones,
                      prototype_input['ptac_fan_type'],
                      prototype_input['ptac_heating_type'],
                      prototype_input['ptac_cooling_type'],
                      building_type)      
                            
      when 'Exhaust Fan'
      
        self.add_exhaust_fan(system['availability_sch_name'],
                            system['flow_rate'],
                            system['flow_fraction_schedule_name'],
                            system['balanced_exhaust_fraction_schedule_name'],
                            thermal_zones)

      when 'Refrigeration'
      
        self.add_refrigeration(building_vintage,
                              system['case_type'],
                              system['cooling_capacity_per_length'],
                              system['length'],
                              system['evaporator_fan_pwr_per_length'],
                              system['lighting_per_length'],
                              system['lighting_sch_name'],
                              system['defrost_pwr_per_length'],
                              system['restocking_sch_name'],
                              system['cop'],
                              system['cop_f_of_t_curve_name'],
                              system['condenser_fan_pwr'],
                              system['condenser_fan_pwr_curve_name'],
                              thermal_zones[0])
      else
      
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "System type #{system['type']} is not recognized.  This system will not be added.")
      
      end

    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

  private
  
  def get_zones_from_spaces_on_system(system)
  
    # Find all zones associated with these spaces
    thermal_zones = []
    system['space_names'].each do |space_name|
      space = self.getSpaceByName(space_name)
      if space.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
        next
      end
      space = space.get
      zone = space.thermalZone
      if zone.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} has no thermal zone; cannot add an HVAC system to this space.")
        next
      end    
      thermal_zones << zone.get
    end  

    return thermal_zones
  
  end
  
  def get_return_plenum_from_system(system)

    # Find the zone associated with the return plenum space name
    return_plenum = nil
    
    # Return nil if no return plenum
    return return_plenum if system['return_plenum'].nil?
    
    # Get the space
    space = self.getSpaceByName(system['return_plenum'])
    if space.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
      return return_plenum
    end
    space = space.get
    
    # Get the space's zone
    zone = space.thermalZone
    if zone.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} has no thermal zone; cannot be a return plenum.")   
      return return_plenum
    end  

    return zone.get
  
  end
  
end
