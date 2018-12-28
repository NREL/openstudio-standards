class NECB2011
  def add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model:,
                                                                   zones:,
                                                                   heating_coil_type:,
                                                                   baseboard_type:,
                                                                   hw_loop:)
    system_4_data = Hash.new
    system_4_data[:name] = 'Sys_4_PSZ'
    system_4_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_4_data[:CentralHeatingDesignSupplyAirTemperature] = 43.0
    system_4_data[:AllOutdoorAirinCooling] = false
    system_4_data[:AllOutdoorAirinHeating] = false
    system_4_data[:TypeofLoadtoSizeOn] = 'Sensible'
    #zone
    system_4_data[:SetpointManagerSingleZoneReheatSupplyTempMax] = 43.0
    system_4_data[:SetpointManagerSingleZoneReheatSupplyTempMin] = 13.0
    system_4_data[:ZoneCoolingDesignSupplyAirTemperature] = 13.0
    system_4_data[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
    system_4_data[:ZoneCoolingSizingFactor] = 1.1
    system_4_data[:ZoneHeatingSizingFactor] = 1.3
    system_data = system_4_data

    # System Type 4: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    # NOTE: This is the same as system type 3 (single zone make-up air unit and single zone rooftop unit are both PSZ systems)
    # SHOULD WE COMBINE sys3 and sys4 into one script?

    always_on = model.alwaysOnDiscreteSchedule

    # Create a PSZ for each zone
    # TO DO: need to apply this system to space types:
    # (1) automotive area: repair/parking garage, fire engine room, indoor truck bay
    # (2) supermarket/food service: food preparation with kitchen hood/vented appliance
    # (3) warehouse area (non-refrigerated spaces)

    zones.each do |zone|
      air_loop = common_air_loop(model: model)

      air_loop.setName("#{system_data[:name]}_#{zone.name}")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn(system_data[:TypeofLoadtoSizeOn])
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(system_data[:CentralCoolingDesignSupplyAirTemperature] )
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(system_data[:CentralHeatingDesignSupplyAirTemperature] )
      air_loop_sizing.setAllOutdoorAirinCooling(system_data[:AllOutdoorAirinCooling])
      air_loop_sizing.setAllOutdoorAirinHeating(system_data[:AllOutdoorAirinHeating])

      # Zone sizing temperature
      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(system_data[:ZoneCoolingDesignSupplyAirTemperature])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(system_data[:ZoneHeatingDesignSupplyAirTemperature])
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

      clg_coil = self.add_onespeed_DX_coil(model, always_on)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.autosizeMinimumOutdoorAirFlowRate

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
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
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

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
      add_zone_baseboards(baseboard_type: baseboard_type,
                          hw_loop: hw_loop,
                          model: model,
                          zone: zone)
    end # zone loop

    return true
  end

# end add_sys4_single_zone_make_up_air_unit_with_baseboard_heating
end