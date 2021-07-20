class NECB2011
  # end add_sys4_single_zone_make_up_air_unit_with_baseboard_heating

  def add_sys6_multi_zone_built_up_system_with_baseboard_heating(model:,
                                                                 zones:,
                                                                 heating_coil_type:,
                                                                 baseboard_type:,
                                                                 chiller_type:,
                                                                 fan_type:,
                                                                 hw_loop:)
    # System Type 6: VAV w/ Reheat
    # This measure creates:
    # a single hot water loop with a natural gas or electric boiler or for the building
    # a single chilled water loop with water cooled chiller for the building
    # a single condenser water loop for heat rejection from the chiller
    # a VAV system w/ hot water or electric heating, chilled water cooling, and
    # hot water or electric reheat for each story of the building
    # Arguments:
    # "boiler_fueltype" choices match OS choices for boiler fuel type:
    # "NaturalGas","Electricity","PropaneGas","FuelOilNo1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    # "heating_coil_type": "Electric" or "Hot Water"
    # "baseboard_type": "Electric" and "Hot Water"
    # "chiller_type": "Scroll";"Centrifugal";""Screw";"Reciprocating"
    # "fan_type": "AF_or_BI_rdg_fancurve";"AF_or_BI_inletvanes";"fc_inletvanes";"var_speed_drive"
    #
    system_data = {}
    system_data[:name] = 'Sys_6_VAV with Reheat'
    system_data[:CentralCoolingDesignSupplyAirTemperature] = 12.8
    system_data[:CentralHeatingDesignSupplyAirTemperature] = 26.7
    system_data[:AllOutdoorAirinCooling] = false
    system_data[:AllOutdoorAirinHeating] = false
    system_data[:MinimumSystemAirFlowRatio] = 0.2

    # zone data
    system_data[:system_supply_air_temperature] = 13.0
    system_data[:ZoneCoolingDesignSupplyAirTemperature] = 12.8
    system_data[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
    system_data[:ZoneCoolingSizingFactor] = 1.1
    system_data[:ZoneHeatingSizingFactor] = 1.3
    system_data[:ZoneVAVMinFlowFactorPerFloorArea] = 0.002
    system_data[:ZoneVAVMaxReheatTemp] = 43.0
    system_data[:ZoneVAVDamperAction] = 'Normal'

    always_on = model.alwaysOnDiscreteSchedule

    air_loop = common_air_loop(model: model, system_data: system_data)
    air_loop.setName('Sys_6_VAV with Reheat')

    supply_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
    supply_fan.setName('Sys6 Supply Fan')
    supply_fan.setMaximumFlowRate(0.991)
    supply_fan.setMotorEfficiency(0.95)


    if heating_coil_type == 'Hot Water'
      htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
      hw_loop.addDemandBranchForComponent(htg_coil)
    end
    if heating_coil_type == 'Electric'
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
    end

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
      sizing_zone.setZoneCoolingSizingFactor(1.0)
      sizing_zone.setZoneHeatingSizingFactor(1.0)

#      if heating_coil_type == 'Hot Water'
#        reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
#        hw_loop.addDemandBranchForComponent(reheat_coil)
#      elsif heating_coil_type == 'Electric'
#        reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
#      end

      vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, always_on)
#      vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
      air_loop.addBranchForZone(zone, vav_terminal.to_StraightComponent)
#      vav_terminal.setMaximumReheatAirTemperature(system_data[:ZoneVAVMaxReheatTemp])
#      vav_terminal.setDamperHeatingAction(system_data[:ZoneVAVDamperAction])

      add_zone_baseboards(model: model,
                          zone: zone,
                          baseboard_type: baseboard_type,
                          hw_loop: hw_loop)
      sys_name_pars = {}
      sys_name_pars['sys_hr'] = 'none'
      sys_name_pars['sys_htg'] = heating_coil_type
      sys_name_pars['sys_clg'] = 'dx'
      sys_name_pars['sys_sf'] = 'vv'
      sys_name_pars['zone_htg'] = baseboard_type
      sys_name_pars['zone_clg'] = 'none'
      sys_name_pars['sys_rf'] = 'none'
      assign_base_sys_name(air_loop,
                             sys_abbr: 'sys_6',
                             sys_oa: 'mixed',
                             sys_name_pars: sys_name_pars)
    end

    return true
  end
end
