# Custom changes for the LargeOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module LargeOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific HVAC adjustments')

    # add transformer
    # efficiency based on a 500 kVA transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.979
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.987
    when '90.1-2016', '90.1-2019'
      transformer_efficiency = 0.991
    else
      transformer_efficiency = nil
    end
    return true unless !transformer_efficiency.nil?

    # rename datacenter plug loads sub categories, there should be 2 data center plug load objects in large office
    model.getElectricEquipments.sort.each do |item|
      if item.nameString.include? 'Data Center'
        item.setEndUseSubcategory('DataCenterPlugLoads')
      end
    end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0281,
                          transformer_size: 500000,
                          transformer_efficiency: transformer_efficiency,
                          excluded_interiorequip_meter: 'DataCenterPlugLoads:InteriorEquipment:Electricity')

    system_to_space_map = define_hvac_system_map(building_type, climate_zone)

    system_to_space_map.each do |system|
      # find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = model.getSpaceByName(space_name)
        if space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = model.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end
    end

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
        infiltration.setSchedule(model_add_schedule(model, 'Large Office Infil Quarter On'))
        infiltration.setConstantTermCoefficient(1.0)
        infiltration.setTemperatureTermCoefficient(0.0)
        infiltration.setVelocityTermCoefficient(0.0)
        infiltration.setVelocitySquaredTermCoefficient(0.0)
        infiltration.setSpace(space)
      else
        space.spaceInfiltrationDesignFlowRates.each do |infiltration_object|
          infiltration_object.setSchedule(model_add_schedule(model, 'OfficeLarge INFIL_SCH_PNNL'))
        end
      end
    end

    model.getPlantLoops.sort.each do |plant_loop|
      if plant_loop.name.to_s == 'Heat Pump Loop'
        plant_loop.setFluidType('EthyleneGlycol')
        plant_loop.setGlycolConcentration(40)
      end
    end

    return true
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting daylight sensor positions and fractions')

    adjustments = [
      { '90.1-2010' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.05,
                                                   'sensor_2_frac' => 0.51,
                                                   'sensor_1_xyz' => [3.1242, 1.6764, 0.762],
                                                   'sensor_2_xyz' => [36.5536, 1.6764, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.49,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [71.4308, 24.3691, 0.762],
                                                   'sensor_2_xyz' => [71.4308, 3.1242, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.51,
                                                   'sensor_2_frac' => 0.05,
                                                   'sensor_1_xyz' => [36.5536, 47.0617, 0.762],
                                                   'sensor_2_xyz' => [70.0034, 47.0617, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.49,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [1.6764, 24.3691, 0.762],
                                                   'sensor_2_xyz' => [1.6764, 45.6194, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.05,
                                                   'sensor_2_frac' => 0.51,
                                                   'sensor_1_xyz' => [3.1242, 1.6764, 17.526],
                                                   'sensor_2_xyz' => [36.5536, 1.6764, 17.526] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.49,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [71.4308, 24.3691, 17.526],
                                                   'sensor_2_xyz' => [71.4308, 3.1242, 17.526] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.51,
                                                   'sensor_2_frac' => 0.05,
                                                   'sensor_1_xyz' => [36.5536, 47.0617, 17.526],
                                                   'sensor_2_xyz' => [70.0034, 47.0617, 17.526] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.49,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [1.6764, 24.3691, 17.526],
                                                   'sensor_2_xyz' => [1.6764, 45.6194, 17.526] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.05,
                                                   'sensor_2_frac' => 0.51,
                                                   'sensor_1_xyz' => [3.1242, 1.6764, 34.29],
                                                   'sensor_2_xyz' => [36.5536, 1.6764, 34.29] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.49,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [71.4308, 24.3691, 34.29],
                                                   'sensor_2_xyz' => [71.4308, 3.1242, 34.29] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.51,
                                                   'sensor_2_frac' => 0.05,
                                                   'sensor_1_xyz' => [36.5536, 47.0617, 34.29],
                                                   'sensor_2_xyz' => [70.0034, 47.0617, 34.29] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.49,
                                                   'sensor_2_frac' => 0.08,
                                                   'sensor_1_xyz' => [1.6764, 24.3691, 34.29],
                                                   'sensor_2_xyz' => [1.6764, 45.6194, 34.29] } },
        '90.1-2013' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 0.762],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 0.762],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 0.762],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 0.762],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 17.526],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 17.526] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 17.526],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 17.526] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 17.526],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 17.526] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 17.526],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 17.526] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 34.29],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 34.29] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 34.29],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 34.29] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 34.29],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 34.29] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 34.29],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 34.29] } },
        '90.1-2016' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 0.762],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 0.762],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 0.762],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 0.762],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 17.526],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 17.526] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 17.526],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 17.526] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 17.526],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 17.526] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 17.526],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 17.526] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 34.29],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 34.29] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 34.29],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 34.29] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 34.29],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 34.29] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 34.29],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 34.29] } },
        '90.1-2019' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 0.762],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 0.762] },
                         'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 0.762],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 0.762] },
                         'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 0.762],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 0.762] },
                         'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 0.762],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 0.762] },
                         'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 17.526],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 17.526] },
                         'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 17.526],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 17.526] },
                         'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 17.526],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 17.526] },
                         'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 17.526],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 17.526] },
                         'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 1.6764, 34.29],
                                                   'sensor_2_xyz' => [36.576, 3.3528, 34.29] },
                         'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [71.4308, 24.384, 34.29],
                                                   'sensor_2_xyz' => [69.7544, 24.384, 34.29] },
                         'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [36.576, 47.0617, 34.29],
                                                   'sensor_2_xyz' => [36.576, 45.3847, 34.29] },
                         'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                   'sensor_2_frac' => 0.1385,
                                                   'sensor_1_xyz' => [1.6764, 24.384, 34.29],
                                                   'sensor_2_xyz' => [3.3528, 24.384, 34.29] } } }
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
