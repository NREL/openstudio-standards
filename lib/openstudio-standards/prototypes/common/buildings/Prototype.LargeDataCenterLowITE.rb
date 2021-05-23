# Custom changes for the LargeDataCenterLowITE prototype.
# These are changes that are inconsistent with other prototype
# building types.
module LargeDataCenterLowITE
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add IT equipment (ITE object) for data center building types
    add_data_center_load(model)

    # This should be added as a retrofit measure instead of being in the prototype
    # modify CRAH supply air setpoint manager
    # modify_crah_sa_stpt_manager(model)

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

      it_fan_power_ratio = 0.4 / (1 + 0.4) # assuming IT fan power is 0.4 of total CPU load

      if space_type.name.get.downcase.include?('computer') || space_type.name.get.downcase.include?('datacenter')
        if elec_equip_have_info
          it_equipment_def = OpenStudio::Model::ElectricEquipmentITEAirCooledDefinition.new(model)
          it_equipment_def.setName('IT equipment def')
          it_equipment_def.setWattsperZoneFloorArea(OpenStudio.convert(elec_equip_per_area.to_f, 'W/ft^2', 'W/m^2').get)
          it_equipment_def.setDesignFanAirFlowRateperPowerInput(0.0001)
          it_equipment_def.setDesignFanPowerInputFraction(it_fan_power_ratio)
          it_equipment_def.setDesignEnteringAirTemperature(22.5) # recommended SAT 18-27C, use the middle T as design
          it_equipment_def.setAirFlowCalculationMethod('FlowControlWithApproachTemperatures')
          # Set the approach temperatures based on CFD simulation results
          it_equipment_def.setSupplyTemperatureDifference(9.67) # This is under fully open configuration assumption, based on the lookup table in scorecard
          it_equipment_def.setReturnTemperatureDifference(-7.36) # This is under fully open configuration assumption, based on the lookup table in scorecard
          # after the bug in OpenStudio core is fixed, this temperature schedules was enabled
          it_equipment_def.setSupplyTemperatureDifferenceSchedule(model_add_schedule(model, 'LargeDataCenterLowITE SupplyApproachTemp_SCH')) # This is under fully open configuration assumption, based on the lookup table in scorecard
          it_equipment_def.setReturnTemperatureDifferenceSchedule(model_add_schedule(model, 'LargeDataCenterLowITE ReturnApproachTemp_SCH'))

          it_equipment = OpenStudio::Model::ElectricEquipmentITEAirCooled.new(it_equipment_def)
          it_equipment.setSpaceType(space_type)
          it_equipment.setName("#{space_type.name} IT equipment")
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

  # TODO: (maybe) for large data center, if sized AHU is too big, implement multiple AHUs to the same zone.
  # def update_crah_num(building_type,prototype_input,template,model,sizing_run_dir)
  #
  #   # get the chilled water loop
  #   chilled_water_loop = nil
  #   if model.getPlantLoopByName('Chilled Water Loop').is_initialized
  #     chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
  #   else
  #     OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Chilled water loop doesn't exist for CRAH system. Failed to update CRAH number.")
  #   end
  #   # set no return plenum
  #   return_plenum = nil
  #
  #   # get thermal zones
  #   thermal_zones = []
  #   space_name = 'DataCenter'
  #   space = model.getSpaceByName(space_name)
  #   if space.empty?
  #     OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
  #   end
  #   space = space.get
  #   zone = space.thermalZone
  #   if zone.empty?
  #     OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} has no thermal zone; cannot add an HVAC system to this space.")
  #   end
  #   thermal_zones << zone.get
  #   puts "thermal_zones = #{thermal_zones}"
  #
  #   # add another CRAH
  #   model.add_crah(template,
  #                  'test_system_name',
  #                  chilled_water_loop,
  #                  thermal_zones,
  #                  prototype_input['vav_operation_schedule'],
  #                  prototype_input['vav_oa_damper_schedule'],
  #                  prototype_input['vav_fan_efficiency'],
  #                  prototype_input['vav_fan_motor_efficiency'],
  #                  prototype_input['vav_fan_pressure_rise'],
  #                  return_plenum,
  #                  building_type)
  #
  #   # Perform another sizing run to distribute air flow in multiple CRAH systems
  #   if model.runSizingRun("#{sizing_run_dir}/SR2_DC") == false
  #     return false
  #   end
  # end

  def modify_crah_sa_stpt_manager(model)
    supply_temp_sch = get_crah_supply_temp_sch(model)
    model.getSetpointManagerScheduleds.each do |stpt_manager|
      next unless stpt_manager.name.to_s.downcase == 'crah supply air setpoint manager'

      stpt_manager.setSchedule(supply_temp_sch)
    end
  end

  def get_crah_supply_temp_sch(model)
    supply_temp_diff_max = 0
    supply_temp_diff_sch = nil
    supply_temp_sch = nil
    model.getElectricEquipmentITEAirCooledDefinitions.each do |it_equip|
      # if it_equip.supplyTemperatureDifferenceSchedule.is_initialized
      #   # only if supply temperature difference schedule is defined
      #   supply_temp_diff_sch = it_equip.supplyTemperatureDifferenceSchedule.get
      #   if supply_temp_diff_sch.to_ScheduleRuleset.is_initialized
      #     # use the largest supply approach temperature schedule if multiple IT equips are using different schedules
      #     if schedule_ruleset_annual_min_max_value(supply_temp_diff_sch)['max'] <= supply_temp_diff_max
      #       next
      #     else
      #       supply_temp_diff_max = schedule_ruleset_annual_min_max_value(supply_temp_diff_sch)['max']
      #       supply_temp_diff_sch = supply_temp_diff_sch.to_ScheduleRuleset.get
      #       supply_temp_sch = supply_temp_diff_sch.clone(model).to_ScheduleRuleset.get
      #       supply_temp_sch.setName('AHU Supply Temp Sch updated')
      #       supply_temp_sch.scheduleRules.each do |rule|
      #         day_rule = rule.daySchedule()
      #         day_rule.times().each do |time|
      #           supply_temp_diff = day_rule.getValue(time)
      #           day_rule.addValue(time, it_equip.designEnteringAirTemperature-supply_temp_diff)
      #         end
      #       end
      #       next   # skip supply approach temperature if schedule is defined
      #     end
      #   end
      # end

      # Take the supply approach temperature at fully open air management scenario
      supply_temp_diff_max = it_equip.supplyTemperatureDifference if it_equip.supplyTemperatureDifference > supply_temp_diff_max
      if supply_temp_diff_max > 0
        supply_temp_sch = model_add_constant_schedule_ruleset(model,
                                                              it_equip.designEnteringAirTemperature - supply_temp_diff_max,
                                                              name = 'AHU Supply Temp Sch updated')
      end
    end

    return supply_temp_sch
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end
end
