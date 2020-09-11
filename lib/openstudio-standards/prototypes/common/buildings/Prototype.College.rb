
# Custom changes for the College prototype.
# These are changes that are inconsistent with other prototype
# building types.
module College
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)


  end

  def model_custom_internal_load_tweaks(building_type, climate_zone, prototype_input, model)
    #   SpaceInfiltration		"Peak: 0.2016 cfm/sf of above grade exterior wall surface area, adjusted by wind (when fans turn off)
    # Off Peak: 25% of peak infiltration rate (when fans turn on)
    # Additional infiltration through building entrance"
    infil_schedule = model.getScheduleRulesetByName("College INFIL_SCH_PNNL")
    model.getSpaceTypes.sort.each do |space_type|
      infil_flow_rates = space_type.getSpaceInfiltrationDesignFlowRates
      unless infil_flow_rates.empty?
        infil_flow_rates.each do |infil_flow_rate|
          infil_flow_rate.setSpaceInfiltrationDesignFlowRate(0.2016)
          infil_flow_rate.setSchedule(infil_schedule)
        end
      else # create a new infiltration object for the spacetypes without any infiltration defined
        infil_flow_rate = Openstudio::Model::getSpaceInfiltrationDesignFlowRate.new(model)
        infil_flow_rate.setSpaceInfiltrationDesignFlowRate(0.2016)
        infil_flow_rate.setSchedule(infil_schedule)
        infil.infil_flow_rate.setSpaceType(space_type)
      end
    end

    building_entrance_lobby = model.getSpaceByName("CB_ Entrance Lobby_F0")
    lobby_door_leakage_area = Openstudio::Model::getSpaceInfiltrationEffectiveLeakageArea.new(model)
    lobby_door_leakage_area.setEffectiveAirLeakageArea(5) # Need modification
    lobby_door_leakage_area.setSpace(building_entrance_lobby)

    #Plugload:Average power density (W/ft2)		See under Zone Summary (MISSING)
    #Schedule		See under Schedules
    #Zone Control Type: minimum supply air at 30% of the zone design peak supply air
  end

 # def model_custom_elevator_tweaks(building_type, climate_zone, prototype_input, model)
    #     Rated Pump Head CW: 75 ft HW: 60 ft


  #  pumps = model.getPumpVariableSpeeds
    #unless pumps.empty?
   #   pumps.each do |pump|
    #    unless pump.plantLoop.get.nil?
     #     plant_loop = pump.plantLoop.get # distinguish different loops by loop temperature
      #    if plant_loop.maximumLoopTemperature > 80 # hot water loop: 180F/82C
       #     pump.setRatedPumpHead(224180.0175) # 75ft-head to Pa
        #  elsif plant_loop.minimumLoopTemperature < 10 # chilled water loop: 44F/6.7C
         #   pump.setRatedPumpHead(179344.014) # 60ft-head to Pa
          #end

        #end
      #end
    #end
    #"    Peak Motor Power
        #(W/elevator)"		16,055
    #     Heat Gain to Building		Interior
    # "    Peak Fan/lights Power
    #     (W/elevator)"		161.9

 # end


  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end
end
