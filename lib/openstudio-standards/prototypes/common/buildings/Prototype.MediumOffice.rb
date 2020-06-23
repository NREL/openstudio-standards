
# Custom changes for the MediumOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module MediumOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.961
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.977
    end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0281,
                          transformer_size: 45000,
                          transformer_efficiency: transformer_efficiency,
                          excluded_interiorequip_key: '2 Elevator Lift Motors',
                          excluded_interiorequip_meter: 'Electric Equipment Electric Energy')

    model.getSpaces.sort.each do |space|
      if space.name.get.to_s == 'Core_bottom'
        model_add_elevator(model,
                           space,
                           prototype_input['number_of_elevators'],
                           prototype_input['elevator_type'],
                           prototype_input['elevator_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           building_type)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    # add extra infiltration for entry door
    add_door_infiltration(climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')

    # set infiltration schedule for plenums
    # @todo remove once infil_sch in Standards.Space pulls from default building infiltration schedule
    model.getSpaces.each do |space|
      next unless space.name.get.to_s.include? 'Plenum'
      # add infiltration if DOE Ref vintage
      if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
        # Create an infiltration rate object for this space
        infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
        infiltration.setName("#{space.name} Infiltration")
        all_ext_infil_m3_per_s_per_m2 = OpenStudio.convert(0.2232, 'ft^3/min*ft^2', 'm^3/s*m^2').get
        infiltration.setFlowperExteriorSurfaceArea(all_ext_infil_m3_per_s_per_m2)
        infiltration.setSchedule(model_add_schedule(model, 'Medium Office Infil Quarter On'))
        infiltration.setConstantTermCoefficient(1.0)
        infiltration.setTemperatureTermCoefficient(0.0)
        infiltration.setVelocityTermCoefficient(0.0)
        infiltration.setVelocitySquaredTermCoefficient(0.0)
        infiltration.setSpace(space)
      else
        space.spaceInfiltrationDesignFlowRates.each do |infiltration_object|
          infiltration_object.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_SCH_PNNL'))
        end
      end
    end

    return true
  end

  # add hvac

  def add_door_infiltration(climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Perimeter_bot_ZN_1').get
      infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entrydoor.setName('entry door Infiltration')
      infiltration_per_zone_entrydoor = 0
      if template == '90.1-2004'
        infiltration_per_zone_entrydoor = 1.04300287
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_Door_Opening_SCH'))
      elsif template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A',
               'ASHRAE 169-2006-1B',
               'ASHRAE 169-2006-2A',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2013-1A',
               'ASHRAE 169-2013-1B',
               'ASHRAE 169-2013-2A',
               'ASHRAE 169-2013-2B'
            infiltration_per_zone_entrydoor = 1.04300287
            infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_Door_Opening_SCH'))
          else
            infiltration_per_zone_entrydoor = 0.678659786
            infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_Door_Opening_SCH'))
        end
      end
      infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
      infiltration_entrydoor.setSpace(entry_space)
    end
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting daylight sensor positions and fractions')

    adjustments = [
      {
        'stds_spc_type' => 'WholeBuilding - Md Office',
        'sensor_1_frac' => 0.3835,
        'sensor_2_frac' => 0.1395
      }
    ]

    # Adjust daylight sensors in each space
    model.getSpaces.each do |space|
      next if space.thermalZone.empty?
      zone = space.thermalZone.get
      next if space.spaceType.empty?
      spc_type = space.spaceType.get
      next if spc_type.standardsSpaceType.empty?
      stds_spc_type = spc_type.standardsSpaceType.get
      adjustments.each do |adj|
        next unless adj['stds_spc_type'] == stds_spc_type
        # Adjust the primary sensor
        if adj['sensor_1_frac'] && zone.primaryDaylightingControl.is_initialized
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting primary daylight sensor to control #{adj['sensor_1_frac']} of the lighting.")
          zone.setFractionofZoneControlledbyPrimaryDaylightingControl(adj['sensor_1_frac'])
          pri_ctrl = zone.primaryDaylightingControl.get
          if adj['sensor_1_xyz']
            x = adj['sensor_1_xyz'][0]
            y = adj['sensor_1_xyz'][1]
            z = adj['sensor_1_xyz'][2]
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting primary daylight sensor position to [#{x}, #{y}, #{z}].")
            pri_ctrl.setPositionXCoordinate(x)
            pri_ctrl.setPositionYCoordinate(y)
            pri_ctrl.setPositionZCoordinate(z)
          end
        end
        # Adjust the secondary sensor
        if adj['sensor_2_frac'] && zone.secondaryDaylightingControl.is_initialized
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting secondary daylight sensor to control #{adj['sensor_2_frac']} of the lighting.")
          zone.setFractionofZoneControlledbySecondaryDaylightingControl(adj['sensor_2_frac'])
          sec_ctrl = zone.secondaryDaylightingControl.get
          if adj['sensor_2_xyz']
            x = adj['sensor_2_xyz'][0]
            y = adj['sensor_2_xyz'][1]
            z = adj['sensor_2_xyz'][2]
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting secondary daylight sensor position to [#{x}, #{y}, #{z}].")
            sec_ctrl.setPositionXCoordinate(x)
            sec_ctrl.setPositionYCoordinate(y)
            sec_ctrl.setPositionZCoordinate(z)
          end
        end

      end
    end

    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end

  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, zone_oa_per_area)
    min_damper_position = template == '90.1-2010' || template == '90.1-2013' ? 0.2 : 0.3

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end
end
