# Custom changes for the Warehouse prototype

# These are changes that are inconsistent with other prototype
# building types.
module Warehouse
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting daylight sensor positions and fractions')

    adjustments = case climate_zone
    when 'ASHRAE 169-2006-6A',
'ASHRAE 169-2006-6B',
'ASHRAE 169-2006-7A',
'ASHRAE 169-2006-8A',
'ASHRAE 169-2013-6A',
'ASHRAE 169-2013-6B',
'ASHRAE 169-2013-7A',
'ASHRAE 169-2013-8A'
      [
        { '90.1-2010' => { 'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.116,
                                                     'sensor_1_xyz' => [6.096, 45.718514, 0] },
                           'Zone1 Office' => { 'sensor_1_frac' => 0.11,
                                               'sensor_2_frac' => 0.11,
                                               'sensor_1_xyz' => [2.4384, 2.4384, 0.762],
                                               'sensor_2_xyz' => [20.4216, 1.6154, 0.762] } },
          '90.1-2013' => { 'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.116,
                                                     'sensor_1_xyz' => [6.096, 45.718514, 0] },
                           'Zone1 Office' => { 'sensor_1_frac' => 0.29,
                                               'sensor_2_frac' => 0.1,
                                               'sensor_1_xyz' => [3.2675, 4.5718, 0.762],
                                               'sensor_2_xyz' => [20.4216, 4.5718, 0.762] } },
          '90.1-2016' => { 'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.116,
                                                     'sensor_1_xyz' => [6.096, 45.718514, 0] },
                           'Zone1 Office' => { 'sensor_1_frac' => 0.29,
                                               'sensor_2_frac' => 0.1,
                                               'sensor_1_xyz' => [3.2675, 4.5718, 0.762],
                                               'sensor_2_xyz' => [20.4216, 4.5718, 0.762] } },
          '90.1-2019' => { 'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.116,
                                                     'sensor_1_xyz' => [6.096, 45.718514, 0] },
                           'Zone1 Office' => { 'sensor_1_frac' => 0.29,
                                               'sensor_2_frac' => 0.1,
                                               'sensor_1_xyz' => [3.2675, 4.5718, 0.762],
                                               'sensor_2_xyz' => [20.4216, 4.5718, 0.762] } } }
      ]
    else
      [
        { '90.1-2010' => { 'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [22.9, 48, 0],
                                                     'sensor_2_xyz' => [22.9, 34.7, 0] },
                           'Zone2 Fine Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [27.8892, 24.9936, 0.762],
                                                     'sensor_2_xyz' => [3.81, 24.9936, 0.762] } },
          '90.1-2013' => { 'Zone1 Office' => { 'sensor_1_frac' => 0.29,
                                               'sensor_2_frac' => 0.1,
                                               'sensor_1_xyz' => [3.2675, 4.5718, 0.762],
                                               'sensor_2_xyz' => [20.4216, 4.5718, 0.762] },
                           'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [22.9, 48, 0],
                                                     'sensor_2_xyz' => [22.9, 34.7, 0] },
                           'Zone2 Fine Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [27.8892, 24.9936, 0.762],
                                                     'sensor_2_xyz' => [3.81, 24.9936, 0.762] } },
          '90.1-2016' => { 'Zone1 Office' => { 'sensor_1_frac' => 0.29,
                                               'sensor_2_frac' => 0.1,
                                               'sensor_1_xyz' => [3.2675, 4.5718, 0.762],
                                               'sensor_2_xyz' => [20.4216, 4.5718, 0.762] },
                           'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [22.9, 48, 0],
                                                     'sensor_2_xyz' => [22.9, 34.7, 0] },
                           'Zone2 Fine Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [27.8892, 24.9936, 0.762],
                                                     'sensor_2_xyz' => [3.81, 24.9936, 0.762] } },
          '90.1-2019' => { 'Zone1 Office' => { 'sensor_1_frac' => 0.29,
                                               'sensor_2_frac' => 0.1,
                                               'sensor_1_xyz' => [3.2675, 4.5718, 0.762],
                                               'sensor_2_xyz' => [20.4216, 4.5718, 0.762] },
                           'Zone3 Bulk Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [22.9, 48, 0],
                                                     'sensor_2_xyz' => [22.9, 34.7, 0] },
                           'Zone2 Fine Storage' => { 'sensor_1_frac' => 0.25,
                                                     'sensor_2_frac' => 0.25,
                                                     'sensor_1_xyz' => [27.8892, 24.9936, 0.762],
                                                     'sensor_2_xyz' => [3.81, 24.9936, 0.762] } } }
      ]
end

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
          if adj['sensor_1_frac']
            # Create primary sensor if it doesn't exist
            if !zone.primaryDaylightingControl.is_initialized
              puts zone
              sensor_1 = OpenStudio::Model::DaylightingControl.new(space.model)
              sensor_1.setName("#{space.name} Daylt Sensor 2")
              sensor_1.setSpace(space)
              sensor_1.setIlluminanceSetpoint(375)
              sensor_1.setLightingControlType('Stepped')
              sensor_1.setNumberofSteppedControlSteps(3) # all sensors 3-step per design
              sensor_1.setMinimumInputPowerFractionforContinuousDimmingControl(0.3)
              sensor_1.setMinimumLightOutputFractionforContinuousDimmingControl(0.2)
              sensor_1.setProbabilityLightingwillbeResetWhenNeededinManualSteppedControl(1.0)
              sensor_1.setMaximumAllowableDiscomfortGlareIndex(22.0)
              zone.setPrimaryDaylightingControl(sensor_1)
            end
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
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    # Set original building North axis
    model_set_building_north_axis(model, 90.0)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting geometry input')
    case template
      when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        case climate_zone
          when 'ASHRAE 169-2006-6A',
               'ASHRAE 169-2006-6B',
               'ASHRAE 169-2006-7A',
               'ASHRAE 169-2006-8A',
               'ASHRAE 169-2013-6A',
               'ASHRAE 169-2013-6B',
               'ASHRAE 169-2013-7A',
               'ASHRAE 169-2013-8A'
            # Remove existing skylights
            model.getSubSurfaces.each do |subsurf|
              if subsurf.subSurfaceType.to_s == 'Skylight'
                subsurf.remove
              end
            end
            # Load older geometry corresponding to older code versions
            old_geo = load_geometry_osm('geometry/ASHRAE90120042007Warehouse.osm')
            # Clone the skylights from the older geometry
            old_geo.getSubSurfaces.each do |subsurf|
              if subsurf.subSurfaceType.to_s == 'Skylight'
                new_skylight = subsurf.clone(model).to_SubSurface.get
                old_roof = subsurf.surface.get
                # Assign surfaces to skylights
                model.getSurfaces.each do |model_surf|
                  if model_surf.name.to_s == old_roof.name.to_s
                    new_skylight.setSurface(model_surf)
                  end
                end
              end
            end
        end
    end
    return true
  end

  # Get building door information to update infiltration
  #
  # return [Hash] Door infiltration information
  def get_building_door_info(model)
    # Get Bulk storage space infiltration schedule name
    sch = ''
    model.getSpaces.sort.each do |space|
      if space.spaceType.get.standardsSpaceType.get.to_s == 'Bulk'
        space.spaceInfiltrationDesignFlowRates.each do |infil|
          infil_sch = infil.schedule.get.to_ScheduleRuleset.get
          if infil_sch.initialized
            sch = infil_sch
          end
        end
      end
    end

    if !sch.initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.Warehouse', 'Could not find Bulk storage schedule.')
      return false
    end

    get_building_door_info = {
      'Metal coiling' => {
        'number_of_doors' => 2.95,
        'door_area_ft2' => 80.0, # 8'-0" by 10'-0"
        'schedule' => sch,
        'space' => 'Zone3 Bulk Storage'
      },
      'Rollup' => {
        'number_of_doors' => 8.85,
        'door_area_ft2' => 80.0, # 8'-0" by 10'-0"
        'schedule' => sch,
        'space' => 'Zone3 Bulk Storage'
      },
      'Open' => {
        'number_of_doors' => 3.2,
        'door_area_ft2' => 80.0, # 8'-0" by 10'-0"
        'schedule' => sch,
        'space' => 'Zone3 Bulk Storage'
      }
    }

    return get_building_door_info
  end
end
