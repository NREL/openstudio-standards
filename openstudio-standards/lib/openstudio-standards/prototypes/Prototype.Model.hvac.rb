
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model
  def add_hvac(building_type, template, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    case template
    when 'NECB 2011'
      boiler_fueltype, baseboard_type, mau_type, mau_heating_coil_type, mua_cooling_type, chiller_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type = BTAP::Environment.get_canadian_system_defaults_by_weatherfile_name(epw_file)
      BTAP::Compliance::NECB2011.necb_autozone_and_autosystem(self, runner = nil, use_ideal_air_loads = false, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, chiller_type, mua_cooling_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type)
    else
      # Get the list of HVAC systems, as defined
      # for each building in the Prototype.building_name files.
      system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

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
          hot_water_loop = if getPlantLoopByName('Hot Water Loop').is_initialized
                             getPlantLoopByName('Hot Water Loop').get
                           else
                             add_hw_loop('NaturalGas', building_type)
                           end

          # Retrieve the existing chilled water loop
          # or add a new one if necessary.
          chilled_water_loop = nil
          if getPlantLoopByName('Chilled Water Loop').is_initialized
            chilled_water_loop = getPlantLoopByName('Chilled Water Loop').get
          else
            condenser_water_loop = nil
            number_cooling_towers = 1
            num_chillers = 1
            if building_type == 'Hospital' || building_type == 'LargeOffice' || building_type == 'LargeOfficeDetail'
              case template
              when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
                number_cooling_towers = 2
                num_chillers = 2
              end
            end
            if prototype_input['chiller_cooling_type'] == 'WaterCooled'
              condenser_water_loop = add_cw_loop(template,
                                                 'Open Cooling Tower',
                                                 'Centrifugal',
                                                 'Fan Cycling',
                                                 2,
                                                 1,
                                                 building_type)
            end

            chilled_water_loop = add_chw_loop(template,
                                              prototype_input['chw_pumping_type'],
                                              prototype_input['chiller_cooling_type'],
                                              prototype_input['chiller_condenser_type'],
                                              prototype_input['chiller_compressor_type'],
                                              'Electricity',
                                              condenser_water_loop)

          end

          # Add the VAV
          add_vav_reheat(template,
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
                         reheat_type = 'Water',
                         building_type)

        when 'CAV'

          # Retrieve the existing hot water loop
          # or add a new one if necessary.
          hot_water_loop = nil
          hot_water_loop = if getPlantLoopByName('Hot Water Loop').is_initialized
                             getPlantLoopByName('Hot Water Loop').get
                           else
                             add_hw_loop('NaturalGas', building_type)
                           end

          chilled_water_loop = nil
          if getPlantLoopByName('Chilled Water Loop').is_initialized
            chilled_water_loop = getPlantLoopByName('Chilled Water Loop').get
          elsif building_type == 'Hospital'
            condenser_water_loop = nil
            if prototype_input['chiller_cooling_type'] == 'WaterCooled'
              condenser_water_loop = add_cw_loop
            end

            chilled_water_loop = add_chw_loop(template,
                                              prototype_input['chw_pumping_type'],
                                              prototype_input['chiller_cooling_type'],
                                              prototype_input['chiller_condenser_type'],
                                              prototype_input['chiller_compressor_type'],
                                              prototype_input['chiller_capacity_guess'],
                                              condenser_water_loop)
          end

          # Add the CAV
          add_cav(template,
                  system['name'],
                  hot_water_loop,
                  thermal_zones,
                  prototype_input['vav_operation_schedule'],
                  prototype_input['vav_oa_damper_schedule'],
                  prototype_input['vav_fan_efficiency'],
                  prototype_input['vav_fan_motor_efficiency'],
                  prototype_input['vav_fan_pressure_rise'],
                  chilled_water_loop,
                  building_type)

        when 'PSZ-AC'
		
          # Retrieve the existing chilled water loop
          # or add a new one if necessary.

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
            heat_pump_loop = add_hp_loop(building_type)
          end

          add_psz_ac(template,
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
          hot_water_loop = if getPlantLoopByName('Hot Water Loop').is_initialized
                             getPlantLoopByName('Hot Water Loop').get
                           elsif building_type == 'MediumOffice'
                             nil
                           else
                             add_hw_loop('NaturalGas', building_type)
                           end

          add_pvav(template,
                   system['name'],
                   thermal_zones,
                   prototype_input['vav_operation_schedule'],
                   prototype_input['vav_oa_damper_schedule'],
                   electric_reheat = false,
                   hot_water_loop,
                   chilled_water_loop = nil,
                   return_plenum,
                   building_type)

        when 'DOAS'

          # Retrieve the existing hot water loop
          # or add a new one if necessary.
          hot_water_loop = nil
          hot_water_loop = if getPlantLoopByName('Hot Water Loop').is_initialized
                             getPlantLoopByName('Hot Water Loop').get
                           else
                             add_hw_loop('NaturalGas', building_type)
                           end

          # Retrieve the existing chilled water loop
          # or add a new one if necessary.
          chilled_water_loop = nil
          if getPlantLoopByName('Chilled Water Loop').is_initialized
            chilled_water_loop = getPlantLoopByName('Chilled Water Loop').get
          else
            condenser_water_loop = nil
            if prototype_input['chiller_cooling_type'] == 'WaterCooled'
              condenser_water_loop = add_cw_loop(template,
                                                 'Open Cooling Tower',
                                                 'Centrifugal',
                                                 'Fan Cycling',
                                                 2,
                                                 1,
                                                 building_type)
            end

            chilled_water_loop = add_chw_loop(template,
                                              prototype_input['chw_pumping_type'],
                                              prototype_input['chiller_cooling_type'],
                                              prototype_input['chiller_condenser_type'],
                                              prototype_input['chiller_compressor_type'],
                                              'Electricity',
                                              condenser_water_loop)
          end

          add_doas(template,
                   system['name'],
                   hot_water_loop,
                   chilled_water_loop,
                   thermal_zones,
                   prototype_input['vav_operation_schedule'],
                   prototype_input['doas_oa_damper_schedule'],
                   prototype_input['doas_fan_maximum_flow_rate'],
                   prototype_input['doas_economizer_control_type'],
                   building_type)

          add_four_pipe_fan_coil(template,
                                  hot_water_loop,
                                  chilled_water_loop,
                                  thermal_zones)

        when 'DC' # Data Center

          # Retrieve the existing hot water loop
          # or add a new one if necessary.
          hot_water_loop = nil
          hot_water_loop = if getPlantLoopByName('Hot Water Loop').is_initialized
                             getPlantLoopByName('Hot Water Loop').get
                           else
                             add_hw_loop('NaturalGas', building_type)
                           end

          # Retrieve the existing heat pump loop
          # or add a new one if necessary.
          heat_pump_loop = nil
          heat_pump_loop = if getPlantLoopByName('Heat Pump Loop').is_initialized
                             getPlantLoopByName('Heat Pump Loop').get
                           else
                             add_hp_loop(building_type)
                           end

          add_data_center_hvac(template,
                               nil,
                               hot_water_loop,
                               heat_pump_loop,
                               thermal_zones,
                               prototype_input['flow_fraction_schedule_name'],
                               prototype_input['flow_fraction_schedule_name'],
                               system['main_data_center'])

        when 'SAC'

          add_split_ac(template,
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

          add_unitheater(template,
                         nil,
                         thermal_zones,
                         prototype_input['unitheater_operation_schedule'],
                         prototype_input['unitheater_fan_control_type'],
                         OpenStudio.convert(prototype_input['unitheater_fan_static_pressure'], 'inH_{2}O', 'Pa').get,
                         prototype_input['unitheater_heating_type'],
                         hot_water_loop = nil,
                         building_type)

        when 'PTAC'

          add_ptac(template,
                   nil,
                   nil,
                   thermal_zones,
                   prototype_input['ptac_fan_type'],
                   prototype_input['ptac_heating_type'],
                   prototype_input['ptac_cooling_type'],
                   building_type)

        when 'Exhaust Fan'

          add_exhaust_fan(system['availability_sch_name'],
                          system['flow_rate'],
                          system['flow_fraction_schedule_name'],
                          system['balanced_exhaust_fraction_schedule_name'],
                          thermal_zones)

        when 'Zone Ventilation'

          add_zone_ventilation(system['availability_sch_name'],
                               system['flow_rate'],
                               system['ventilation_type'],
                               thermal_zones)

        when 'Refrigeration'

          add_refrigeration(template,
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
							
        # When multiple cases and walk-ins asssigned to a system        
	    	when 'Refrigeration_system'

          add_refrigeration_system(template,
                                   system['compressor_type'],
                                   system['sys_name'],
                                   system['cases'],
                                   system['walkins'],
                                   thermal_zones[0])

        else

          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "System type #{system['type']} is not recognized.  This system will not be added.")

        end
      end

    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end # add hvac

  private

  def get_zones_from_spaces_on_system(system)
    # Find all zones associated with these spaces
    thermal_zones = []
    system['space_names'].each do |space_name|
      space = getSpaceByName(space_name)
      if space.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
        next
      end
      space = space.get
      zone = space.thermalZone
      if zone.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} has no thermal zone; cannot add an HVAC system to this space.")
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
    space = getSpaceByName(system['return_plenum'])
    if space.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
      return return_plenum
    end
    space = space.get

    # Get the space's zone
    zone = space.thermalZone
    if zone.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space.name} has no thermal zone; cannot be a return plenum.")
      return return_plenum
    end

    return zone.get
  end
end
