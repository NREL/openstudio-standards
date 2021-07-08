class NECB2011

  # end add_sys4_single_zone_make_up_air_unit_with_baseboard_heating

  def add_sys6_multi_zone_built_up_system_with_baseboard_heating(model:,
                                                                 zones:,
                                                                 heating_coil_type:,
                                                                 baseboard_type:,
                                                                 chiller_type:,
                                                                 fan_type:,
                                                                 hw_loop:)

    system_data = Hash.new
    system_data[:name] = 'Sys_6_VAV with Reheat'
    system_data[:CentralCoolingDesignSupplyAirTemperature] = 12.8
    system_data[:CentralHeatingDesignSupplyAirTemperature] = 21.1
    system_data[:AllOutdoorAirinCooling] = false
    system_data[:AllOutdoorAirinHeating] = false
    system_data[:MinimumSystemAirFlowRatio] = 0.3

    system_data[:system_supply_air_temperature] = 13.0
    system_data[:ZoneCoolingDesignSupplyAirTemperature] = 13.0
    system_data[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
    system_data[:ZoneCoolingSizingFactor] = 1.1
    system_data[:ZoneHeatingSizingFactor] = 1.3
    system_data[:ZoneVAVMinFlowFactorPerFloorArea] = 0.002
    system_data[:ZoneVAVMaxReheatTemp] = 43.0
    system_data[:ZoneVAVDamperAction] = 'Normal'

    always_on = model.alwaysOnDiscreteSchedule

    air_loop = common_air_loop( model: model, system_data: system_data)
    air_loop.setName('Sys_6_VAV with Reheat')

    supply_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
    supply_fan.setName('Sys6 Supply Fan')

    htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
    htg_coil.setGasBurnerEfficiency(0.8)
    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)

    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.autosizeMinimumOutdoorAirFlowRate

    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

    supply_inlet_node = air_loop.supplyInletNode
    supply_outlet_node = air_loop.supplyOutletNode
    supply_fan.addToNode(supply_inlet_node)
    htg_coil.addToNode(supply_inlet_node)
    clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)

    sat_stpt_manager = OpenStudio::Model::SetpointManagerWarmest.new(model)
    sat_stpt_manager.setMaximumSetpointTemperature(21.1)
    sat_stpt_manager.setMinimumSetpointTemperature(12.8)
    sat_stpt_manager.addToNode(supply_outlet_node)

    model.getThermalZones.each do |zone|
       sizing_zone = zone.sizingZone
       sizing_zone.setZoneCoolingDesignSupplyAirTemperature(system_data[:ZoneCoolingDesignSupplyAirTemperature])
       sizing_zone.setZoneHeatingDesignSupplyAirTemperature(system_data[:ZoneHeatingDesignSupplyAirTemperature])
       sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
       sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

       reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
       hw_loop.addDemandBranchForComponent(reheat_coil)

       vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
       air_loop.addBranchForZone(zone, vav_terminal.to_StraightComponent)
       vav_terminal.setDamperHeatingAction(system_data[:ZoneVAVDamperAction])

       add_zone_baseboards(model: model,
                             zone: zone,
                             baseboard_type: baseboard_type,
                             hw_loop: hw_loop)
    end

    sys_name_pars = {}
    sys_name_pars["sys_hr"] = "none"
    sys_name_pars["sys_htg"] = heating_coil_type
    sys_name_pars["sys_clg"] = "Chilled Water"
    sys_name_pars["sys_sf"] = "vv"
    sys_name_pars["zone_htg"] = baseboard_type
    sys_name_pars["zone_clg"] = "none"
    sys_name_pars["sys_rf"] = "vv"
    assign_base_sys_name(air_loop,
                           sys_abbr: "sys_6",
                           sys_oa: "mixed",
                           sys_name_pars: sys_name_pars)

    return true
  end
end

