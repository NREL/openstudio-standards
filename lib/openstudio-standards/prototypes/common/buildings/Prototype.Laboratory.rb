# Custom changes for the Laboratory prototype.
# These are changes that are inconsistent with other prototype
# building types.
module Laboratory
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    reset_fume_hood_oa(model)
    adjust_doas_sizing_system(model)
    set_oa_control_for_lab_terminals(model)

    # TODO
    # # Add exhaust fan to fume hood zone
    # search_criteria = ...
    # fume_hood_space = model_find_object(standards_data['Space Types'], search_criteria)
    # fume_hood_zone_volume = fume_hood_space.getVolume...
    # flow_rate_fume_hood = fume_hood_zone_volume * fume_hood_space['Ventilation_Air_Changes...']
    # model_add_exhaust_fan(model, thermal_zones, flow_rate=flow_rate_fume_hood,  flow_fraction_schedule_name='Lab_FumeHood_Sch')

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # For fume hood, the OA rate varies with the fume hood schedule
  # So add "Proportional Control Minimum Outdoor Air Flow Rate Schedule"
  # at the mean time, modify "Outdoor Air Method" to "ProportionalControlBasedOnDesignOARate" in Controller:MechanicalVentilation of the DOAS
  def reset_fume_hood_oa(model)
    fume_hood_spaces = []
    model.getSpaces.each do |space|
      next unless space.name.get.to_s.include? 'fumehood'

      ventilation = space.designSpecificationOutdoorAir.get
      ventilation.setOutdoorAirFlowRateFractionSchedule(model_add_schedule(model, 'Lab_FumeHood_Sch'))
    end
  end

  def adjust_doas_sizing_system(model)
    model.getAirLoopHVACs.each do |air_loop|
      if air_loop.name.to_s.include? 'OA'
        # system sizing
        sizing_system = air_loop.sizingSystem
        sizing_system.setTypeofLoadtoSizeOn('Sensible')
      end
    end
  end

  def set_oa_control_for_lab_terminals(model)
    model.getAirTerminalSingleDuctVAVReheats.sort.each do |air_terminal|
      air_terminal_name = air_terminal.name.get
      if air_terminal_name.include?('Lab')
        air_terminal.setControlForOutdoorAir(true)
      end
    end
  end

  # lab zones don't have economizer, the air flow rate is determined by the ventilation requirement
  def model_modify_oa_controller(model)
    model.getAirLoopHVACs.sort.each do |air_loop|
      oa_sys = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_control = oa_sys.getControllerOutdoorAir
      if air_loop.name.get.include?('DOAS')
        oa_control.setEconomizerControlType('NoEconomizer')
      end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end
end
