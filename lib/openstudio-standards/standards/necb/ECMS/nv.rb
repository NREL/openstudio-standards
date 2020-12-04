class ECMS

  def apply_nv(model:, nv_type:, nv_opening_area_m2:)

    ##### If any of users' inputs are nil/false, do nothing.
    return if nv_type.nil? || nv_type == FALSE
    return if nv_opening_area_m2.nil? || nv_opening_area_m2 == FALSE

    # model.getSpaces.sort.each do |space|
    #   puts space.name.to_s
    #   # outdoor_air = space.designSpecificationOutdoorAir.get
    #   # puts outdoor_air.outdoorAirFlowperPerson
    #   # puts outdoor_air.outdoorAirFlowperFloorArea
    #
    #   thermal_zone = space.thermalZone
    #   if !thermal_zone.empty?
    #     thermal_zone = space.thermalZone.get
    #   end
    #   puts thermal_zone
    #
    # end

    model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|  #TODO: consider zones that do not have hvac?
      # puts zone_hvac_equipment_list

      thermal_zone = zone_hvac_equipment_list.thermalZone
      puts "thermal_zone_name_is #{thermal_zone.name.to_s}"
      thermal_zone.spaces.sort.each do |space|
        puts space.name.to_s
        outdoor_air = space.designSpecificationOutdoorAir.get
        outdoor_air_flow_per_person = outdoor_air.outdoorAirFlowperPerson
        outdoor_air_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea

        # space_type = space.spaceType.get
        # space_type_name = space_type.name.get
        # puts "space_type_name is #{space_type_name}"
        # standards_building_type = space_type.standardsBuildingType.is_initialized ? space_type.standardsBuildingType.get : nil
        # standards_space_type = space_type.standardsSpaceType.is_initialized ? space_type.standardsSpaceType.get : nil
        # puts "standards_building_type is #{standards_building_type}"
        # puts "standards_space_type is #{standards_space_type}"
        # spacetype_data = @standards_data#['tables']['space_types']['table'].detect {|data| (data['building_type'] == 'Space Function') && (data['space_type'] == '- undefined -')} #TODO: standards_building_type  standards_space_type
        ## File.open("/home/osdev/openstudio-standards/lib/openstudio-standards/standards/necb/NECB2011/data/temp.json","w") do |f|
        ##   f.write(JSON.pretty_generate(spacetype_data))
        ## end
        # puts spacetype_data
        # outdoor_air_flow_per_person = spacetype_data['ventilation_per_person']
        # outdoor_air_flow_per_floor_area = spacetype_data['ventilation_per_area']

        puts "outdoor_air_flow_per_person is #{outdoor_air_flow_per_person}"
        puts "outdoor_air_flow_per_floor_area us #{outdoor_air_flow_per_floor_area}"

        zn_vent_design_flow_rate_1 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zn_vent_design_flow_rate_1.setDesignFlowRateCalculationMethod('Flow/Person')
        zn_vent_design_flow_rate_1.setFlowRateperPerson(outdoor_air_flow_per_person)
        zn_vent_design_flow_rate_1.setVentilationType('Natural')
        zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_1)

        zn_vent_design_flow_rate_2 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zn_vent_design_flow_rate_2.setDesignFlowRateCalculationMethod('Flow/Area')
        zn_vent_design_flow_rate_2.setFlowRateperZoneFloorArea(outdoor_air_flow_per_floor_area)
        zn_vent_design_flow_rate_2.setVentilationType('Natural')
        zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_2)

        zn_vent_wind_and_stack = OpenStudio::Model::ZoneVentilationWindandStackOpenArea.new(model)
        zn_vent_wind_and_stack.setOpeningArea(nv_opening_area_m2)
        zn_vent_wind_and_stack.setOpeningAreaFractionScheduleName('Constant')
        zn_vent_wind_and_stack.setOpeningEffectiveness('autocalculate')
        # E+ I/O: "The below input field value is used to calculate the angle between the wind direction and the opening outward normal to determine the opening effectiveness values when the input field Opening Effectiveness = Autocalculate."
        #TODO: find 'opening outward normal' for      zn_vent_wind_and_stack.setEffectiveAngle()
        zn_vent_wind_and_stack.setDischargeCoefficientforOpening('autocalculate')
        zone_hvac_equipment_list.addEquipment(zn_vent_wind_and_stack)

      end



    end


  end

end