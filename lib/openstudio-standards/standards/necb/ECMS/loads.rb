class ECMS
  # Occupancy
  def scale_occupancy_loads(model:, scale: 'NECB_Default')
    ##### Remove leading or trailing whitespace in case users add them in inputs
    if scale.instance_of?(String)
      scale = scale.strip
    end
    return model if (scale == 'NECB_Default') || scale.nil?

    ##### Convert a string to a float
    if scale.instance_of?(String)
      scale = scale.to_f
    end
    if scale == 0.0
      model.getPeoples.sort.each(&:remove)
      model.getPeopleDefinitions.sort.each(&:remove)
    else
      model.getPeoples.sort.each do |item|
        item.setMultiplier(item.multiplier * scale)
      end
    end
  end

  # Electrical
  def scale_electrical_loads(model:, scale: 'NECB_Default')
    ##### Remove leading or trailing whitespace in case users add them in inputs
    if scale.instance_of?(String)
      scale = scale.strip
    end
    return model if (scale == 'NECB_Default') || scale.nil?

    ##### Convert a string to a float
    if scale.instance_of?(String)
      scale = scale.to_f
    end
    if scale == 0.0
      model.getElectricEquipments.sort.each(&:remove)
      model.getElectricEquipmentDefinitions.sort.each(&:remove)
    else
      model.getElectricEquipments.sort.each do |item|
        item.setMultiplier(item.multiplier * scale)
      end
    end
  end

  # Outdoor Air
  def scale_oa_loads(model:, scale: 'NECB_Default')
    ##### Remove leading or trailing whitespace in case users add them in inputs
    if scale.instance_of?(String)
      scale = scale.strip
    end
    return model if (scale == 'NECB_Default') || scale.nil?

    ##### Convert a string to a float
    if scale.instance_of?(String)
      scale = scale.to_f
    end
    if scale == 0.0
      model.getDesignSpecificationOutdoorAirs.sort.each(&:remove)
    else
      model.getDesignSpecificationOutdoorAirs.sort.each do |oa_def|
        oa_def.setOutdoorAirFlowperPerson(oa_def.outdoorAirFlowperPerson * scale) unless oa_def.isOutdoorAirFlowperPersonDefaulted
        oa_def.setOutdoorAirFlowperFloorArea(oa_def.outdoorAirFlowperFloorArea * scale) unless oa_def.isOutdoorAirFlowperFloorAreaDefaulted
        oa_def.setOutdoorAirFlowRate(oa_def.outdoorAirFlowRate * scale) unless oa_def.isOutdoorAirFlowRateDefaulted
        oa_def.setOutdoorAirFlowAirChangesperHour(oa_def.outdoorAirFlowAirChangesperHour * scale) unless oa_def.isOutdoorAirFlowAirChangesperHourDefaulted
      end
    end
  end

  # Infiltration
  def scale_infiltration_loads(model:, scale: 'NECB_Default')
    ##### Remove leading or trailing whitespace in case users add them in inputs
    if scale.instance_of?(String)
      scale = scale.strip
    end
    return model if (scale == 'NECB_Default') || scale.nil?

    ##### Convert a string to a float
    if scale.instance_of?(String)
      scale = scale.to_f
    end
    if scale == 0.0
      model.getSpaceInfiltrationDesignFlowRates.sort.each(&:remove)
    else
      model.getSpaceInfiltrationDesignFlowRates.sort.each do |infiltration_load|
        infiltration_load.setDesignFlowRate(infiltration_load.designFlowRate.get * scale) unless infiltration_load.designFlowRate.empty?
        infiltration_load.setFlowperSpaceFloorArea(infiltration_load.flowperSpaceFloorArea.get * scale) unless infiltration_load.flowperSpaceFloorArea.empty?
        infiltration_load.setFlowperExteriorSurfaceArea(infiltration_load.flowperExteriorSurfaceArea.get * scale) unless infiltration_load.flowperExteriorSurfaceArea.empty?
        infiltration_load.setAirChangesperHour(infiltration_load.airChangesperHour.get * scale) unless infiltration_load.airChangesperHour.empty?
      end
    end
  end

  # Service hot water
  def scale_shw_use(model: , scale: 'NECB_Default')
    ##### Remove leading or trailing whitespace in case users add them in inputs
    if scale.instance_of?(String)
      scale = scale.strip
    end
    return model if scale == 'NECB_Default' or scale.nil?
    ##### Convert a string to a float
    if scale.instance_of?(String)
      scale = scale.to_f
    end
    model.getWaterUseEquipmentDefinitions.sort.each do |water_use_equipment_definition|
      water_use_equipment_definition_name = water_use_equipment_definition.name.to_s

      water_use_equipment_definition.setPeakFlowRate(water_use_equipment_definition.peakFlowRate * scale)
      peak_flow_rate_gal_per_min = OpenStudio.convert(water_use_equipment_definition.peakFlowRate, 'm^3/s', 'gal/min').get.round(2).to_s
      water_use_equipment_definition_name = water_use_equipment_definition_name.gsub(/#{'Service Water Use Def'}.+/, 'Service Water Use Def ' + peak_flow_rate_gal_per_min + 'gal/min')
      water_use_equipment_definition.setName(water_use_equipment_definition_name)

    end
  end

end
