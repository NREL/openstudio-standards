
# Custom changes for the SmallOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module SmallOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    # add extra infiltration for entry door
    add_door_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')

    # add extra infiltration for attic
    add_attic_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added attic infiltration')

    # Adjust the daylight sensor positions
    update_daylight_sensor_positions(model, climate_zone)

    return true
  end

  def add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Perimeter_ZN_1').get
      infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entrydoor.setName('entry door Infiltration')
      infiltration_per_zone_entrydoor = 0
      if template == '90.1-2004'
        infiltration_per_zone_entrydoor = 0.129785425
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeSmall INFIL_Door_Opening_SCH'))
      elsif template == '90.1-2007' || template == '90.1-2010'|| template == '90.1-2013'
        case climate_zone
        when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B'
          infiltration_per_zone_entrydoor = 0.129785425
          infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeSmall INFIL_Door_Opening_SCH'))
        else
          infiltration_per_zone_entrydoor = 0.076455414
          infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeSmall INFIL_Door_Opening_SCH_2013'))
        end
      end
      infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
      infiltration_entrydoor.setConstantTermCoefficient(1.0)
      infiltration_entrydoor.setTemperatureTermCoefficient(0.0)
      infiltration_entrydoor.setVelocityTermCoefficient(0.0)
      infiltration_entrydoor.setVelocitySquaredTermCoefficient(0.0)
      infiltration_entrydoor.setSpace(entry_space)
    end
  end

  def add_attic_infiltration(template, climate_zone, model)
    # add extra infiltration for attic in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Attic').get
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic.setName('attic Infiltration')
      infiltration_per_zone_attic = 0.2001
      infiltration_attic.setSchedule(model_add_schedule(model, 'Always On'))
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setConstantTermCoefficient(1.0)
      infiltration_attic.setTemperatureTermCoefficient(0.0)
      infiltration_attic.setVelocityTermCoefficient(0.0)
      infiltration_attic.setVelocitySquaredTermCoefficient(0.0)
      infiltration_attic.setSpace(entry_space)
    end
  end

  def update_daylight_sensor_positions(model, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Ajusting daylight sensor positions and fractions')

    adjustments = [
                    { 'stds_spc_type' => 'WholeBuilding - Sm Office',
                      'sensor_1_frac' => 0.2399,
                      'sensor_2_frac' => 0.0302,
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
        if adj['sensor_1_frac']
          zone.setFractionofZoneControlledbyPrimaryDaylightingControl(adj['sensor_1_frac'])
          if zone.primaryDaylightingControl.is_initialized
            pri_ctrl = zone.primaryDaylightingControl.get
            if adj['sensor_1_xyz']
              pri_ctrl.setPositionXCoordinate(adj['sensor_1_xyz'][0])
              pri_ctrl.setPositionYCoordinate(adj['sensor_1_xyz'][1])
              pri_ctrl.setPositionZCoordinate(adj['sensor_1_xyz'][2])
            end
          end
        end
        # Adjust the secondary sensor
        if adj['sensor_2_frac']
          zone.setFractionofZoneControlledbySecondaryDaylightingControl(adj['sensor_2_frac'])
          if zone.secondaryDaylightingControl.is_initialized
            sec_ctrl = zone.secondaryDaylightingControl.get
            if adj['sensor_2_xyz']
              sec_ctrl.setPositionXCoordinate(adj['sensor_2_xyz'][0])
              sec_ctrl.setPositionYCoordinate(adj['sensor_2_xyz'][1])
              sec_ctrl.setPositionZCoordinate(adj['sensor_2_xyz'][2])
            end
          end
        end

      end
    end

    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end
end
