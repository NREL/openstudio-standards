# Custom changes for the MediumOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module MediumOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific HVAC adjustments')

    # add transformer
    # efficiency based on a 45 kVA transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.961
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.977
    when '90.1-2016', '90.1-2019'
      transformer_efficiency = 0.984
    else
      transformer_efficiency = nil
    end
    return true unless !transformer_efficiency.nil?

    # Change to output variable name in E+ 9.4 (OS 3.1.0)
    excluded_interiorequip_variable = if model.version < OpenStudio::VersionString.new('3.1.0')
                                        'Electric Equipment Electric Energy'
                                      else
                                        'Electric Equipment Electricity Energy'
                                      end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0281,
                          transformer_size: 45000,
                          transformer_efficiency: transformer_efficiency,
                          excluded_interiorequip_key: '2 Elevator Lift Motors',
                          excluded_interiorequip_meter: excluded_interiorequip_variable)

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
      elsif template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019'
        case climate_zone
          when 'ASHRAE 169-2006-0A',
               'ASHRAE 169-2006-1A',
               'ASHRAE 169-2006-0B',
               'ASHRAE 169-2006-1B',
               'ASHRAE 169-2006-2A',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2013-0A',
               'ASHRAE 169-2013-1A',
               'ASHRAE 169-2013-0B',
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
      { '90.1-2010' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.08,
                                                   'sensor_2_frac' => 0.46,
                                                   'sensor_1_xyz' => [3.048, 1.524, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 1.524, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.43,
                                                   'sensor_2_frac' => 0.12,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [48.387, 3.048, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.46,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [24.9514, 31.7498, 0.762],
                                                   'sensor_2_xyz' => [46.863, 31.7498, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.43,
                                                   'sensor_2_frac' => 0.12,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [1.524, 30.2514, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.08,
                                                   'sensor_2_frac' => 0.46,
                                                   'sensor_1_xyz' => [3.048, 1.524, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 1.524, 4.7244] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.43,
                                                   'sensor_2_frac' => 0.12,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [48.387, 3.048, 4.7244] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.46,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [24.9514, 31.7498, 4.7244],
                                                   'sensor_2_xyz' => [46.863, 31.7498, 4.7244] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.43,
                                                   'sensor_2_frac' => 0.12,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [1.524, 30.2514, 4.7244] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.08,
                                                   'sensor_2_frac' => 0.46,
                                                   'sensor_1_xyz' => [3.048, 1.524, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 1.524, 8.687] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.43,
                                                   'sensor_2_frac' => 0.12,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [48.387, 3.048, 8.687] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.46,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [24.9514, 31.7498, 8.687],
                                                   'sensor_2_xyz' => [46.863, 31.7498, 8.687] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.43,
                                                   'sensor_2_frac' => 0.12,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [1.524, 30.2514, 8.687] } },
        '90.1-2013' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 4.7244] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 4.7244] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 4.7244] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 4.7244] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 8.687] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 8.687] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 8.687] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 8.687] } },
        '90.1-2016' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 4.7244] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 4.7244] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 4.7244] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 4.7244] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 8.687] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 8.687] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 8.687] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 8.687] } },
        '90.1-2019' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 0.762],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 0.762],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 4.7244] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 4.7244] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 4.7244],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 4.7244] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 4.7244],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 4.7244] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 1.524, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 3.048, 8.687] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [48.387, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [46.863, 16.6369, 8.687] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [24.9555, 31.7498, 8.687],
                                                   'sensor_2_xyz' => [24.9555, 30.2258, 8.687] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3835,
                                                   'sensor_2_frac' => 0.1395,
                                                   'sensor_1_xyz' => [1.524, 16.6369, 8.687],
                                                   'sensor_2_xyz' => [3.048, 16.6369, 8.687] } } }
    ]

    # Adjust daylight sensors in each space
    model.getSpaces.each do |space|
      if adjustments[0].keys.include? template
        if adjustments[0][template].keys.include? space.name.to_s
          adj = adjustments[0][template][space.name.to_s]
          next if space.thermalZone.empty?

          zone = space.thermalZone.get
          next if space.spaceType.empty?

          spc_type = space.spaceType.get
          next if spc_type.standardsSpaceType.empty?

          stds_spc_type = spc_type.standardsSpaceType.get
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
          if adj['sensor_2_frac']
            # Create second sensor if it doesn't exist
            if !zone.secondaryDaylightingControl.is_initialized
              sensor_2 = OpenStudio::Model::DaylightingControl.new(space.model)
              sensor_2.setName("#{space.name} Daylt Sensor 2")
              sensor_2.setSpace(space)
              sensor_2.setIlluminanceSetpoint(375)
              sensor_2.setLightingControlType('Stepped')
              sensor_2.setNumberofSteppedControlSteps(3) # all sensors 3-step per design
              sensor_2.setMinimumInputPowerFractionforContinuousDimmingControl(0.3)
              sensor_2.setMinimumLightOutputFractionforContinuousDimmingControl(0.2)
              sensor_2.setProbabilityLightingwillbeResetWhenNeededinManualSteppedControl(1.0)
              sensor_2.setMaximumAllowableDiscomfortGlareIndex(22.0)
              zone.setSecondaryDaylightingControl(sensor_2)
            end
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
    end

    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    # Set original building North axis
    model_set_building_north_axis(model, 0.0)

    return true
  end

  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, zone_oa_per_area)
    min_damper_position = template == '90.1-2010' || template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019' ? 0.2 : 0.3

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end

  # Type of SAT reset for this building type
  #
  # @param air_loop_hvac [OpenStudio::model::AirLoopHVAC] Airloop
  # @return [String] Returns type of SAT reset
  def air_loop_hvac_supply_air_temperature_reset_type(air_loop_hvac)
    return 'oa'
  end
end
