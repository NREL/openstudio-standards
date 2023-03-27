class BTAPPRE1980
  # Some tests still require a simple way to set up a system without sizing.. so we are keeping the auto_zoner flag for this  method.

  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model:,
                                                                                         zones:,
                                                                                         heating_coil_type:,
                                                                                         baseboard_type:,
                                                                                         hw_loop:,
                                                                                         new_auto_zoner: true,
                                                                                         necb_reference_hp: false,
                                                                                         necb_reference_hp_supp_fuel: 'DefaultFuel')

    system_data = {}
    system_data[:name] = 'Sys_3_PSZ'
    system_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_data[:CentralHeatingDesignSupplyAirTemperature] = 43.0
    system_data[:AllOutdoorAirinCooling] = false
    system_data[:AllOutdoorAirinHeating] = false
    system_data[:TypeofLoadtoSizeOn] = 'Sensible'
    system_data[:MinimumSystemAirFlowRatio] = 1.0

    system_data[:PreheatDesignTemperature] = 7.0
    system_data[:PreheatDesignHumidityRatio] = 0.008
    system_data[:PrecoolDesignTemperature] = 13.0
    system_data[:PrecoolDesignHumidityRatio] = 0.008
    system_data[:SizingOption] = 'NonCoincident'
    system_data[:CoolingDesignAirFlowMethod] = 'DesignDay'
    system_data[:CoolingDesignAirFlowRate] = 0.0
    system_data[:HeatingDesignAirFlowMethod] = 'DesignDay'
    system_data[:HeatingDesignAirFlowRate] = 0.0
    system_data[:SystemOutdoorAirMethod] = 'ZoneSum'
    system_data[:CentralCoolingDesignSupplyAirHumidityRatio] = 0.0085
    system_data[:CentralHeatingDesignSupplyAirHumidityRatio] = 0.0080

    # System 3 Zone data
    system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference] = 11.0
    system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference] = 21.0
    system_data[:SetpointManagerSingleZoneReheatSupplyTempMin] = 13.0
    system_data[:SetpointManagerSingleZoneReheatSupplyTempMax] = 43.0
    system_data[:ZoneDXCoolingSizingFactor] = 1.0
    system_data[:ZoneDXHeatingSizingFactor] = 1.3
    system_data[:ZoneCoolingSizingFactor] = 1.1
    system_data[:ZoneHeatingSizingFactor] = 1.3
    system_data[:MinimumOutdoorDryBulbTemperatureforCompressorOperation] = -10.0

    if new_auto_zoner == true
      # Create system airloop

      # Add Air Loop
      air_loop = add_system_3_and_8_airloop(heating_coil_type,
                                            model,
                                            system_data,
                                            determine_control_zone(zones))
      # Add Zone equipment
      zones.each do |zone| # Zone sizing temperature
        sizing_zone = zone.sizingZone
        sizing_zone.setZoneCoolingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod])
        sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference])
        sizing_zone.setZoneHeatingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod])
        sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference])
        sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
        sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])
        add_sys3_and_8_zone_equip(air_loop,
                                  baseboard_type,
                                  hw_loop,
                                  model,
                                  zone)
      end
    else
      zones.each do |zone|
        air_loop = add_system_3_and_8_airloop(heating_coil_type, model, system_data, zone)
        add_sys3_and_8_zone_equip(air_loop,
                                  baseboard_type,
                                  hw_loop,
                                  model,
                                  zone)
      end
    end

    # Modifying airloop name.
    sys_name_pars = {}
    sys_name_pars['sys_hr'] = 'none'
    sys_name_pars['sys_clg'] = 'dx'
    sys_name_pars['sys_htg'] = heating_coil_type
    sys_name_pars['sys_sf'] = 'cv'
    sys_name_pars['zone_htg'] = baseboard_type
    sys_name_pars['zone_clg'] = 'none'
    sys_name_pars['sys_rf'] = 'none'
    assign_base_sys_name(air_loop,
                         sys_abbr: 'sys_3',
                         sys_oa: 'mixed',
                         sys_name_pars: sys_name_pars)
    return true
  end

  def add_system_3_and_8_airloop(heating_coil_type, model, system_data, control_zone)
    # System Type 3: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas", "DX"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOilNo1","FuelOilNo2","Coal","Diesel","Gasoline","OtherFuel1"
    # For BTAPPRE1980 (and BTAP1980TO2010 which is created from BTAPPRE1980) add a constant speed return fan

    always_on = model.alwaysOnDiscreteSchedule
    air_loop = common_air_loop(model: model, system_data: system_data)
    air_loop.setName("#{system_data[:name]} #{control_zone.name}")

    # Zone sizing temperature
    sizing_zone = control_zone.sizingZone
    sizing_zone.setZoneCoolingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod])
    sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference])
    sizing_zone.setZoneHeatingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod])
    sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference])
    sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
    sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

    fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

    # Create a return fan for BTAPPRE1980 system 3 systems
    return_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)
    return_fan.setName('Sys3 Return Fan')
    return_fan.setEndUseSubcategory('Return_Fan')

    case heating_coil_type
    when 'Electric' # electric coil
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
    when 'Gas'
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
    when 'DX'
      htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(system_data[:MinimumOutdoorDryBulbTemperatureforCompressorOperation])
      sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneDXHeatingSizingFactor])
      sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneDXCoolingSizingFactor])
    else
      raise("#{heating_coil_type} is not a valid heating coil type.)")
    end

    # TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

    # Set up DX coil with NECB performance curve characteristics;
    clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)
    clg_coil.setName('CoilCoolingDXSingleSpeed_dx')

    # oa_controller
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.autosizeMinimumOutdoorAirFlowRate

    # Set mechanical ventilation controller outdoor air to ZoneSum (used to be defaulted to ZoneSum but now should be
    # set explicitly)
    oa_controller.controllerMechanicalVentilation.setSystemOutdoorAirMethod('ZoneSum')

    # oa_system
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

    # Add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = air_loop.supplyInletNode
    if heating_coil_type == 'DX'
      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(model, always_on, fan, htg_coil, clg_coil, supplemental_htg_coil)
      air_to_air_heatpump.setName("#{control_zone.name} ASHP")
      air_to_air_heatpump.setControllingZone(control_zone)
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.addToNode(supply_inlet_node)
    else
      fan.addToNode(supply_inlet_node)
      htg_coil.addToNode(supply_inlet_node)
      clg_coil.addToNode(supply_inlet_node)
    end
    oa_system.addToNode(supply_inlet_node)

    # Find return air node and add a return air fan to it for BTAPPRE1980 system 3 airloops.
    returnAirNode = oa_system.returnAirModelObject.get.to_Node.get
    return_fan.addToNode(returnAirNode)

    # Add a setpoint manager single zone reheat to control the
    # supply air temperature based on the needs of this zone
    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setControlZone(control_zone)
    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMin])
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMax])
    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)
    return air_loop
  end

  def add_sys3_and_8_zone_equip(air_loop,
                                baseboard_type,
                                hw_loop, model,
                                zone)
    always_on = model.alwaysOnDiscreteSchedule
    diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
    air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    add_zone_baseboards(baseboard_type: baseboard_type, hw_loop: hw_loop, model: model, zone: zone)
  end
end
