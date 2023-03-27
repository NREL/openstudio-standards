class BTAPPRE1980
  def add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model:,
                                                                   zones:,
                                                                   heating_coil_type:,
                                                                   baseboard_type:,
                                                                   hw_loop:,
                                                                   necb_reference_hp:false,
                                                                   necb_reference_hp_supp_fuel:'DefaultFuel')
    system_data = {}
    system_data[:name] = 'Sys_4_PSZ'
    system_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_data[:CentralHeatingDesignSupplyAirTemperature] = 43.0
    system_data[:AllOutdoorAirinCooling] = false
    system_data[:AllOutdoorAirinHeating] = false
    # Setting system 4 airloops in BTAPPRE1980 and BTAP1980TO2010 buildings to size by ventilation requirement rather
    # than cooling or heating load.
    system_data[:TypeofLoadtoSizeOn] = 'VentilationRequirement'
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

    # zone
    system_data[:SetpointManagerSingleZoneReheatSupplyTempMax] = 43.0
    system_data[:SetpointManagerSingleZoneReheatSupplyTempMin] = 13.0
    system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference] = 11.0
    system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference] = 21.0
    system_data[:ZoneCoolingSizingFactor] = 1.1
    system_data[:ZoneHeatingSizingFactor] = 1.3

    # System Type 4: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOilNo1","FuelOilNo2","Coal","Diesel","Gasoline","OtherFuel1"
    # NOTE: This is the same as system type 3 (single zone make-up air unit and single zone rooftop unit are both PSZ systems)
    # SHOULD WE COMBINE sys3 and sys4 into one script?
    #
    # control_zone = determine_control_zone(zones)
    # Todo change this when control zone method is working.
    control_zone = zones.first

    always_on = model.alwaysOnDiscreteSchedule

    # Create a PSZ for each zone
    # TO DO: need to apply this system to space types:
    # (1) automotive area: repair/parking garage, fire engine room, indoor truck bay
    # (2) supermarket/food service: food preparation with kitchen hood/vented appliance
    # (3) warehouse area (non-refrigerated spaces)

    air_loop = common_air_loop(model: model, system_data: system_data)
    air_loop.setName("#{system_data[:name]}_#{control_zone.name}")

    # Zone sizing temperature
    sizing_zone = control_zone.sizingZone
    sizing_zone.setZoneCoolingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod])
    sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference])
    sizing_zone.setZoneHeatingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod])
    sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference])
    sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
    sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

    fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

    if heating_coil_type == 'Electric' # electric coil
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
    end

    if heating_coil_type == 'Gas'
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
    end

    # TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

    # Set up DX coil with NECB performance curve characteristics;

    clg_coil = add_onespeed_DX_coil(model, always_on)
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
    fan.addToNode(supply_inlet_node)
    htg_coil.addToNode(supply_inlet_node)
    clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)

    # Add a setpoint manager single zone reheat to control the
    # supply air temperature based on the needs of this zone
    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setControlZone(control_zone)
    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMin])
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMax])
    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

    # Create sensible heat exchanger
    #              heat_exchanger = BTAP::Resources::HVAC::Plant::add_hrv(model)
    #              heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.5)
    #              heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.5)
    #              heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.5)
    #              heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.5)
    #              heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.0)
    #              heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.0)
    #              heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.0)
    #              heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.0)
    #              heat_exchanger.setSupplyAirOutletTemperatureControl(false)
    #
    #              Connect heat exchanger
    #              oa_node = oa_system.outboardOANode
    #              heat_exchanger.addToNode(oa_node.get)

    exhaust_fan_name = 'Sys_4_zone_exhaust_fan'
    zones.each do |zone|
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod])
      sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference])
      sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
      sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])
      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
      add_zone_baseboards(baseboard_type: baseboard_type,
                          hw_loop: hw_loop,
                          model: model,
                          zone: zone)
      add_exhaust_fan(zone: zone, model: model, name: exhaust_fan_name)
    end
    # zone loop

    # Modifying airloop name
    sys_name_pars = {}
    sys_name_pars['sys_hr'] = 'none'
    sys_name_pars['sys_clg'] = 'dx'
    sys_name_pars['sys_htg'] = heating_coil_type
    sys_name_pars['sys_sf'] = 'cv'
    sys_name_pars['zone_htg'] = baseboard_type
    sys_name_pars['zone_clg'] = 'none'
    sys_name_pars['sys_rf'] = 'none'
    assign_base_sys_name(air_loop,
                         sys_abbr: 'sys_4',
                         sys_oa: 'mixed',
                         sys_name_pars: sys_name_pars)

    return true
  end
end
