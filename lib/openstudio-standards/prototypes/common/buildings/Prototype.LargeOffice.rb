
# Custom changes for the LargeOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module LargeOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
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

    # replace EvaporativeFluidCoolerSingleSpeed with CoolingTowerTwoSpeed
    model.getPlantLoops.each do |plant_loop|
      next unless plant_loop.name.to_s.include? "Heat Pump Loop"
      sup_wtr_high_temp_f = 65.0
      sup_wtr_low_temp_f = 41.0
      sup_wtr_high_temp_c = OpenStudio.convert(sup_wtr_high_temp_f, 'F', 'C').get
      sup_wtr_low_temp_c = OpenStudio.convert(sup_wtr_low_temp_f, 'F', 'C').get
      hp_high_temp_sch = model_add_constant_schedule_ruleset(model,
                                                             sup_wtr_high_temp_c,
                                                             name = "#{plant_loop.name} High Temp - #{sup_wtr_high_temp_f.round(0)}F")
      hp_low_temp_sch = model_add_constant_schedule_ruleset(model,
                                                            sup_wtr_low_temp_c,
                                                            name = "#{plant_loop.name} Low Temp - #{sup_wtr_low_temp_f.round(0)}F")

      # add cooling tower object
      cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(model)
      cooling_tower.setName("#{plant_loop.name} Central Tower")
      plant_loop.addSupplyBranchForComponent(cooling_tower)
      #### Add SPM Scheduled Dual Setpoint to outlet of Fluid Cooler so correct Plant Operation Scheme is generated
      cooling_tower_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
      cooling_tower_stpt_manager.setName("#{plant_loop.name} Fluid Cooler Scheduled Dual Setpoint")
      cooling_tower_stpt_manager.setHighSetpointSchedule(hp_high_temp_sch)
      cooling_tower_stpt_manager.setLowSetpointSchedule(hp_low_temp_sch)
      cooling_tower_stpt_manager.addToNode(cooling_tower.outletModelObject.get.to_Node.get)

      # remove EvaporativeFluidCoolerSingleSpeed object
      model.getEvaporativeFluidCoolerSingleSpeeds.each do |fluid_cooler|
        if fluid_cooler.plantLoop.get.name.to_s == plant_loop.name.to_s
          fluid_cooler.remove
          break
        end
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

    return true
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting daylight sensor positions and fractions')

    adjustments = [
                    { '90.1-2010' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.05,
                                                                 'sensor_2_frac' => 0.51,
                                                                 'sensor_1_xyz' => [3.1242, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [36.5536, 1.6764, 0.762],
																												},
                                       'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.49,
                                                                 'sensor_2_frac' => 0.08,
                                                                 'sensor_1_xyz' => [71.4308, 24.3691, 0.762],
                                                                 'sensor_2_xyz' => [71.4308, 3.1242, 0.762],
																												},
                                       'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.51,
                                                                 'sensor_2_frac' => 0.05,
                                                                 'sensor_1_xyz' => [36.5536, 47.0617, 0.762],
                                                                 'sensor_2_xyz' => [70.0034, 47.0617, 0.762],
																												},
                                       'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.49,
                                                                 'sensor_2_frac' => 0.08,
                                                                 'sensor_1_xyz' => [1.6764, 24.3691, 0.762],
                                                                 'sensor_2_xyz' => [1.6764, 45.6194, 0.762],
																												},
                                       'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.05,
                                                                 'sensor_2_frac' => 0.51,
                                                                 'sensor_1_xyz' => [3.1242, 1.6764, 17.526],
                                                                 'sensor_2_xyz' => [36.5536, 1.6764, 17.526],
																												},
                                       'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.49,
                                                                 'sensor_2_frac' => 0.08,
                                                                 'sensor_1_xyz' => [71.4308, 24.3691, 17.526],
                                                                 'sensor_2_xyz' => [71.4308, 3.1242, 17.526],
																												},
                                       'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.51,
                                                                 'sensor_2_frac' => 0.05,
                                                                 'sensor_1_xyz' => [36.5536, 47.0617, 17.526],
                                                                 'sensor_2_xyz' => [70.0034, 47.0617, 17.526],
																												},
                                       'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.49,
                                                                 'sensor_2_frac' => 0.08,
                                                                 'sensor_1_xyz' => [1.6764, 24.3691, 17.526],
                                                                 'sensor_2_xyz' => [1.6764, 45.6194, 17.526],
																												},
                                       'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.05,
                                                                 'sensor_2_frac' => 0.51,
                                                                 'sensor_1_xyz' => [3.1242, 1.6764, 34.29],
                                                                 'sensor_2_xyz' => [36.5536, 1.6764, 34.29],
																												},
                                       'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.49,
                                                                 'sensor_2_frac' => 0.08,
                                                                 'sensor_1_xyz' => [71.4308, 24.3691, 34.29],
                                                                 'sensor_2_xyz' => [71.4308, 3.1242, 34.29],
																												},
                                       'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.51,
                                                                 'sensor_2_frac' => 0.05,
                                                                 'sensor_1_xyz' => [36.5536, 47.0617, 34.29],
                                                                 'sensor_2_xyz' => [70.0034, 47.0617, 34.29],
																												},
                                       'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.49,
                                                                 'sensor_2_frac' => 0.08,
                                                                 'sensor_1_xyz' => [1.6764, 24.3691, 34.29],
                                                                 'sensor_2_xyz' => [1.6764, 45.6194, 34.29],
																												},
                                      },
                      '90.1-2013' => { 'Perimeter_bot_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [36.576, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [36.576, 3.3528, 0.762],
																												},
                                       'Perimeter_bot_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [71.4308, 24.384, 0.762],
                                                                 'sensor_2_xyz' => [69.7544, 24.384, 0.762],
																												},
                                       'Perimeter_bot_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [36.576, 47.0617, 0.762],
                                                                 'sensor_2_xyz' => [36.576, 45.3847, 0.762],
																												},
                                       'Perimeter_bot_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [1.6764, 24.384, 0.762],
                                                                 'sensor_2_xyz' => [3.3528, 24.384, 0.762],
																												},
                                       'Perimeter_mid_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [36.576, 1.6764, 17.526],
                                                                 'sensor_2_xyz' => [36.576, 3.3528, 17.526],
																												},
                                       'Perimeter_mid_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [71.4308, 24.384, 17.526],
                                                                 'sensor_2_xyz' => [69.7544, 24.384, 17.526],
																												},
                                       'Perimeter_mid_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [36.576, 47.0617, 17.526],
                                                                 'sensor_2_xyz' => [36.576, 45.3847, 17.526],
																												},
                                       'Perimeter_mid_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [1.6764, 24.384, 17.526],
                                                                 'sensor_2_xyz' => [3.3528, 24.384, 17.526],
																												},
                                       'Perimeter_top_ZN_1' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [36.576, 1.6764, 34.29],
                                                                 'sensor_2_xyz' => [36.576, 3.3528, 34.29],
																												},
                                       'Perimeter_top_ZN_2' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [71.4308, 24.384, 34.29],
                                                                 'sensor_2_xyz' => [69.7544, 24.384, 34.29],
																												},
                                       'Perimeter_top_ZN_3' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [36.576, 47.0617, 34.29],
                                                                 'sensor_2_xyz' => [36.576, 45.3847, 34.29],
																												},
                                       'Perimeter_top_ZN_4' => { 'sensor_1_frac' => 0.3857,
                                                                 'sensor_2_frac' => 0.1385,
                                                                 'sensor_1_xyz' => [1.6764, 24.384, 34.29],
                                                                 'sensor_2_xyz' => [3.3528, 24.384, 34.29],
																												},
                                      },
										}
                  ]

    # Adjust daylight sensors in each space
    model.getSpaces.each do |space|
      if adjustments[0].keys.include? (template)
        if adjustments[0][template].keys.include? (space.name.to_s)
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
    end

    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end
end
