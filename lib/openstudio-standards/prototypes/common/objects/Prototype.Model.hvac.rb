class Standard
  def model_add_hvac(model, building_type, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    # Get the list of HVAC systems, as defined
    # for each building in the Prototype.building_name files.

    # Add each HVAC system
    @system_to_space_map.each do |system|
      thermal_zones = model_get_zones_from_spaces_on_system(model, system)

      return_plenum = model_get_return_plenum_from_system(model, system)

      # Add the HVAC systems
      case system['type']
      when 'VAV'

        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         else
                           model_add_hw_loop(model, 'NaturalGas', building_type)
                         end

        # Retrieve the existing chilled water loop
        # or add a new one if necessary.
        chilled_water_loop = nil
        if model.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
        else
          condenser_water_loop = nil
          if system['chiller_cooling_type'] == 'WaterCooled'
            condenser_water_loop = model_add_cw_loop(model,
                                                     'Open Cooling Tower',
                                                     'Centrifugal',
                                                     'Fan Cycling',
                                                     2,
                                                     1,
                                                     building_type)
          end

          chilled_water_loop = model_add_chw_loop(model,
                                                  system['chw_pumping_type'],
                                                  system['chiller_cooling_type'],
                                                  system['chiller_condenser_type'],
                                                  system['chiller_compressor_type'],
                                                  'Electricity',
                                                  condenser_water_loop)

        end

        # Add the VAV
        model_add_vav_reheat(model,
                             system['name'],
                             hot_water_loop,
                             chilled_water_loop,
                             thermal_zones,
                             system['operation_schedule'],
                             system['oa_damper_schedule'],
                             vav_fan_efficiency = 0.62,
                             vav_fan_motor_efficiency = 0.9,
                             vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                             return_plenum,
                             reheat_type = 'Water',
                             building_type)

      when 'CAV'

        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         else
                           model_add_hw_loop(model, 'NaturalGas', building_type)
                         end

        chilled_water_loop = nil
        if model.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
        elsif building_type == 'Hospital'
          condenser_water_loop = nil
          if system['chiller_cooling_type'] == 'WaterCooled'
            condenser_water_loop = model_add_cw_loop(model)
          end

          chilled_water_loop = model_add_chw_loop(model,
                                                  system['chw_pumping_type'],
                                                  system['chiller_cooling_type'],
                                                  system['chiller_condenser_type'],
                                                  system['chiller_compressor_type'],
                                                  'Electricity',
                                                  condenser_water_loop)
        end

        # Add the CAV
        model_add_cav(model,
                      system['name'],
                      hot_water_loop,
                      thermal_zones,
                      system['operation_schedule'],
                      system['oa_damper_schedule'],
                      vav_fan_efficiency = 0.62,
                      vav_fan_motor_efficiency = 0.9,
                      vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                      chilled_water_loop,
                      building_type)

      when 'PSZ-AC'

        # Special logic to make unitary heat pumps all blow-through
        fan_position = 'DrawThrough'
        if system['heating_type'] == 'Single Speed Heat Pump' ||
           system['heating_type'] == 'Water To Air Heat Pump'
          fan_position = 'BlowThrough'
        end

        # Special logic to make a heat pump loop if necessary
        heat_pump_loop = nil
        if system['heating_type'] == 'Water To Air Heat Pump'
          heat_pump_loop = model_add_hp_loop(model, building_type)
        end

        model_add_psz_ac(model,
                         system['name'],
                         heat_pump_loop, # Typically nil unless water source hp
                         heat_pump_loop, # Typically nil unless water source hp
                         thermal_zones,
                         system['operation_schedule'],
                         system['oa_damper_schedule'],
                         fan_position,
                         system['fan_type'],
                         system['heating_type'],
                         system['supplemental_heating_type'],
                         system['cooling_type'],
                         building_type)

      when 'PVAV'

        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         elsif building_type == 'MediumOffice'
                           nil
                         else
                           model_add_hw_loop(model, 'NaturalGas', building_type)
                         end

        model_add_pvav(model,
                       system['name'],
                       thermal_zones,
                       system['operation_schedule'],
                       system['oa_damper_schedule'],
                       electric_reheat = false,
                       hot_water_loop,
                       chilled_water_loop = nil,
                       return_plenum,
                       building_type)

      when 'DOAS'

        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         else
                           model_add_hw_loop(model, 'NaturalGas', building_type)
                         end

        # Retrieve the existing chilled water loop
        # or add a new one if necessary.
        chilled_water_loop = nil
        if model.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
        else
          condenser_water_loop = nil
          if system['chiller_cooling_type'] == 'WaterCooled'
            condenser_water_loop = model_add_cw_loop(model,
                                                     'Open Cooling Tower',
                                                     'Centrifugal',
                                                     'Fan Cycling',
                                                     2,
                                                     1,
                                                     building_type)
          end

          chilled_water_loop = model_add_chw_loop(model,
                                                  system['chw_pumping_type'],
                                                  system['chiller_cooling_type'],
                                                  system['chiller_condenser_type'],
                                                  system['chiller_compressor_type'],
                                                  'Electricity',
                                                  condenser_water_loop)
        end

        model_add_doas(model,
                       system['name'],
                       hot_water_loop,
                       chilled_water_loop,
                       thermal_zones,
                       system['operation_schedule'],
                       system['oa_damper_schedule'],
                       system['fan_maximum_flow_rate'],
                       system['economizer_control_type'],
                       building_type)

        model_add_four_pipe_fan_coil(model,
                                     hot_water_loop,
                                     chilled_water_loop,
                                     thermal_zones,
                                     ventilation=false)

      when 'DC' # Data Center

        # Retrieve the existing hot water loop
        # or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         else
                           model_add_hw_loop(model, 'NaturalGas', building_type)
                         end

        # Retrieve the existing heat pump loop
        # or add a new one if necessary.
        heat_pump_loop = nil
        heat_pump_loop = if model.getPlantLoopByName('Heat Pump Loop').is_initialized
                           model.getPlantLoopByName('Heat Pump Loop').get
                         else
                           model_add_hp_loop(model, building_type)
                         end

        model_add_data_center_hvac(model,
                                   nil,
                                   hot_water_loop,
                                   heat_pump_loop,
                                   thermal_zones,
                                   system['flow_fraction_schedule'],
                                   system['flow_fraction_schedule'],
                                   system['main_data_center'])

      when 'SAC'

        model_add_split_ac(model,
                           nil,
                           thermal_zones,
                           system['operation_schedule'],
                           system['oa_damper_schedule'],
                           system['fan_type'],
                           system['heating_type'],
                           system['heating_type'],
                           system['cooling_type'],
                           building_type)

      when 'UnitHeater'

        model_add_unitheater(model,
                             nil,
                             thermal_zones,
                             system['operation_schedule'],
                             system['fan_type'],
                             OpenStudio.convert(system['fan_static_pressure'], 'inH_{2}O', 'Pa').get,
                             system['heating_type'],
                             hot_water_loop = nil,
                             building_type)

      when 'PTAC'

        model_add_ptac(model,
                       nil,
                       nil,
                       thermal_zones,
                       system['fan_type'],
                       system['heating_type'],
                       system['cooling_type'],
                       building_type)

      when 'PTHP'

          model_add_pthp(model,
                         nil,
                         thermal_zones,
                         system['fan_type'])

      when 'Exhaust Fan'

        model_add_exhaust_fan(model, system['operation_schedule'],
                              system['flow_rate'],
                              system['flow_fraction_schedule'],
                              system['balanced_exhaust_fraction_schedule'],
                              thermal_zones)

      when 'Zone Ventilation'

        model_add_zone_ventilation(model, system['operation_schedule'],
                                   system['flow_rate'],
                                   system['ventilation_type'],
                                   thermal_zones)

      when 'Refrigeration'

        model_add_refrigeration(model,
                                system['case_type'],
                                system['cooling_capacity_per_length'],
                                system['length'],
                                system['evaporator_fan_pwr_per_length'],
                                system['lighting_per_length'],
                                system['lighting_schedule'],
                                system['defrost_pwr_per_length'],
                                system['restocking_schedule'],
                                system['cop'],
                                system['cop_f_of_t_curve_name'],
                                system['condenser_fan_pwr'],
                                system['condenser_fan_pwr_curve_name'],
                                thermal_zones[0])

      # When multiple cases and walk-ins asssigned to a system
      when 'Refrigeration_system'

        model_add_refrigeration_system(model,
                                       system['compressor_type'],
                                       system['name'],
                                       system['cases'],
                                       system['walkins'],
                                       thermal_zones[0])

      when 'WSHP'
        condenser_loop = case system['heating_type']
                         when 'Gas'
                           model_get_or_add_heat_pump_loop(model)
                         else
                           model_get_or_add_ambient_water_loop(model)
                         end

        model_add_water_source_hp(model,
                                  condenser_loop,
                                  thermal_zones,
                                  ventilation=true)

      when 'Fan Coil'
        case system['heating_type']
        when 'Gas', 'DistrictHeating', 'Electricity'
          hot_water_loop = model_get_or_add_hot_water_loop(model, system['heating_type'])
        when nil
          hot_water_loop = nil
        end

        case system['cooling_type']
        when 'Electricity', 'DistrictCooling'
          chilled_water_loop = model_get_or_add_chilled_water_loop(model, system['cooling_type'], air_cooled = true)
        when nil
          chilled_water_loop = nil
        end

        model_add_four_pipe_fan_coil(model,
                                     hot_water_loop,
                                     chilled_water_loop,
                                     thermal_zones,
                                     ventilation=true)

      when 'Baseboards'
        case system['heating_type']
        when 'Gas', 'DistrictHeating'
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
        when 'Electricity'
          hot_water_loop = nil
        when nil
          # TODO: Error, Baseboard systems must have a main_heat_fuel
          # return ??
        end

        model_add_baseboard(model,
                            hot_water_loop,
                            thermal_zones)

      else

        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "System type '#{system['type']}' is not recognized for system named '#{system['name']}'.  This system will not be added.")

      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end # add hvac

  private

  def model_get_zones_from_spaces_on_system(model, system)
    # Find all zones associated with these spaces
    thermal_zones = []
    system['space_names'].each do |space_name|
      space = model.getSpaceByName(space_name)
      if space.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model, cannot be added to HVAC system.")
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

  def model_get_return_plenum_from_system(model, system)
    # Find the zone associated with the return plenum space name
    return_plenum = nil

    # Return nil if no return plenum
    return return_plenum if system['return_plenum'].nil?

    # Get the space
    space = model.getSpaceByName(system['return_plenum'])
    if space.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model, cannot be a return plenum.")
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
