
# Custom changes for the RetailStandalone prototype.
# These are changes that are inconsistent with other prototype
# building types.
module RetailStandalone
  # TODO: The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # TODO: There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # TODO: The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # TODO: Need to determine if WaterHeater can be alone or if we need to 'fake' it.

  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for template 2004,2007,2010,2013
    case template
    when '90.1-2004'
      entry_space = model.getSpaceByName('Front_Entry').get
      infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entry.setName('Entry door Infiltration')
      infiltration_per_zone = 1.418672682
      infiltration_entry.setDesignFlowRate(infiltration_per_zone)
      infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH'))
      infiltration_entry.setSpace(entry_space)

      # temporal solution for CZ dependent door infiltration rate.  In fact other standards need similar change as well
    when '90.1-2007', '90.1-2010', '90.1-2013'
      entry_space = model.getSpaceByName('Front_Entry').get
      infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entry.setName('Entry door Infiltration')
      case climate_zone
      when 'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2013-1A',
          'ASHRAE 169-2013-1B',
          'ASHRAE 169-2013-2A',
          'ASHRAE 169-2013-2B'
        infiltration_per_zone = 1.418672682
        infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH'))
      else
        infiltration_per_zone = 0.937286742
        infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH_2013'))
      end
      infiltration_entry.setDesignFlowRate(infiltration_per_zone)
      infiltration_entry.setSpace(entry_space)
    end

    # add these additional coefficient inputs
    if infiltration_entry
      infiltration_entry.setConstantTermCoefficient(1.0)
      infiltration_entry.setTemperatureTermCoefficient(0.0)
      infiltration_entry.setVelocityTermCoefficient(0.0)
      infiltration_entry.setVelocitySquaredTermCoefficient(0.0)
    end

    case template
    when '90.1-2013'
      # Add EMS for controlling the system serving the front entry zone
      oa_sens = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      oa_sens.setName('OAT_F')
      oa_sens.setKeyName('Environment')

      model.getFanConstantVolumes.each do |fan|
        if fan.name.to_s.include? 'Front' and fan.name.to_s.include? 'Entry'
          frt_entry_avail_fan_sch = fan.availabilitySchedule
          frt_entry_fan = OpenStudio::Model::EnergyManagementSystemActuator.new(frt_entry_avail_fan_sch, 'Schedule:Year', 'Schedule Value')
          frt_entry_fan.setName('FrontEntry_Fan')
        end
      end

      model.getCoilHeatingGass.each do |coil|
        if coil.name.to_s.include? 'Front' and coil.name.to_s.include? 'Entry'
          frt_entry_avail_coil_sch = coil.availabilitySchedule
          frt_entry_coil = OpenStudio::Model::EnergyManagementSystemActuator.new(frt_entry_avail_coil_sch, 'Schedule:Year', 'Schedule Value')
          frt_entry_coil.setName('FrontEntry_Coil')
        end
      end

      frt_entry_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      frt_entry_prg.setName('FrontEntry_HeaterControl')
      frt_entry_prg_body = <<-EMS
      SET OAT_F = (OAT_F*1.8)+32
      IF OAT_F > 45
        SET FrontEntry_Coil = 0
        SET FrontEntry_Fan = 0
      ENDIF
      EMS
      frt_entry_prg.setBody(frt_entry_prg_body)

      prg_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      prg_mgr.setName('FrontEntry_HeaterManager')
      prg_mgr.setCallingPoint('BeginTimestepBeforePredictor')
      prg_mgr.addProgram(frt_entry_prg)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

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
                        { 'stds_spc_type' => 'Core_Retail',
                          'sensor_1_frac' => 0.1724,
                          'sensor_1_xyz' => [9.144, 24.698, 0],
                        }
                    ]
                  else
                    [
                        { 'stds_spc_type' => 'Core_Retail',
                          'sensor_1_frac' => 0.25,
                          'sensor_1_xyz' => [14.2, 14.2, 0],
                          'sensor_2_frac' => 0.25,
                          'sensor_2_xyz' => [3.4, 14.2, 0],
                        }
                    ]
                  end

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
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting geometry input')
    case template
    when '90.1-2010', '90.1-2013'
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
        old_geo = load_geometry_osm('geometry/ASHRAE90120042007RetailStandalone.osm')
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
end
