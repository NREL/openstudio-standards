
# Custom changes for the QuickServiceRestaurant prototype.
# These are changes that are inconsistent with other prototype
# building types.
module LargeDataCenterHighITE
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add IT equipment (ITE object) for data center building types
    add_data_center_load(model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add IT equipment (ITE object) for data center building types
  # Normal electric equipment has been added in model_add_load prior to this
  # will replace with ITE object here
  def add_data_center_load(model)

    model.getSpaceTypes.each do |space_type|
      # Get the standards data
      space_type_properties = space_type_get_standards_data(space_type)

      elec_equip_have_info = false
      elec_equip_per_area = space_type_properties['electric_equipment_per_area'].to_f
      elec_equip_sch = space_type_properties['electric_equipment_schedule']
      elec_equip_have_info = true unless elec_equip_per_area.zero?

      # The way ITE object is designed can't input the CPU load and IT fan power separately
      # calculation below is to indirectly address this
      total_power_input_per_area = elec_equip_per_area.to_f * (1 + 0.4)  # assuming IT fan power is 0.4 of total CPU load
      it_fan_power_ratio = elec_equip_per_area.to_f * 0.4/total_power_input_per_area

      if (space_type.name.get.downcase.include?('computer')) || (space_type.name.get.downcase.include?('datacenter'))
        if elec_equip_have_info
          it_equipment_def = OpenStudio::Model::ElectricEquipmentITEAirCooledDefinition.new(model)
          it_equipment_def.setName("IT equipment def")
          it_equipment_def.setWattsperZoneFloorArea(OpenStudio.convert(total_power_input_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          it_equipment_def.setDesignFanAirFlowRateperPowerInput(0.0001*(1-it_fan_power_ratio))
          it_equipment_def.setDesignFanPowerInputFraction(it_fan_power_ratio)
          it_equipment_def.setDesignEnteringAirTemperature(27)    # recommended SAT 18-27C, use the middle T as design
          it_equipment_def.setAirFlowCalculationMethod("FlowControlWithApproachTemperatures")
          # TODO Set the approach temperatures based on CFD simulation results
          it_equipment_def.setSupplyTemperatureDifference(7.2)   # This is under fully open configuration assumption, based on the lookup table in scorecard
          it_equipment_def.setReturnTemperatureDifference(-6.1)   # This is under fully open configuration assumption, based on the lookup table in scorecard

          it_equipment = OpenStudio::Model::ElectricEquipmentITEAirCooled.new(it_equipment_def)
          it_equipment.setSpaceType(space_type)
          it_equipment.setName("#{space_type.name.to_s} IT equipment")
          unless elec_equip_sch.nil?
            it_equipment.setDesignPowerInputSchedule(model_add_schedule(model, elec_equip_sch))
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set Design Power Input Schedule to #{elec_equip_sch}.")
          end
          it_equipment.setCPULoadingSchedule(model.alwaysOnDiscreteSchedule)
        end
      end
    end
    # remove normal electric equipment
    model.getElectricEquipments.each(&:remove)
  end



  # TODO (maybe not): for large data center, if sized AHU is too big, implement multiple AHUs to the same zone.
=begin
  def update_crah_num(building_type,prototype_input,template,model,sizing_run_dir)

    # get the chilled water loop
    chilled_water_loop = nil
    if model.getPlantLoopByName('Chilled Water Loop').is_initialized
      chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Chilled water loop doesn't exist for CRAH system. Failed to update CRAH number.")
    end
    # set no return plenum
    return_plenum = nil

    # get thermal zones
    thermal_zones = []
    space_name = 'DataCenter'
    space = model.getSpaceByName(space_name)
    if space.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
    end
    space = space.get
    zone = space.thermalZone
    if zone.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} has no thermal zone; cannot add an HVAC system to this space.")
    end
    thermal_zones << zone.get
    puts "thermal_zones = #{thermal_zones}"

    # add another CRAH
    model.add_crah(template,
                   'test_system_name',
                   chilled_water_loop,
                   thermal_zones,
                   prototype_input['vav_operation_schedule'],
                   prototype_input['vav_oa_damper_schedule'],
                   prototype_input['vav_fan_efficiency'],
                   prototype_input['vav_fan_motor_efficiency'],
                   prototype_input['vav_fan_pressure_rise'],
                   return_plenum,
                   building_type)

    # Perform another sizing run to distribute air flow in multiple CRAH systems
    if model.runSizingRun("#{sizing_run_dir}/SR2_DC") == false
      return false
    end

  end
=end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end
end
