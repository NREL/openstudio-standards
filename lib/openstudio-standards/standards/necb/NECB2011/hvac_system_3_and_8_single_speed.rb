class NECB2011

  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model:,
                                                                                         zones:,
                                                                                         heating_coil_type:,
                                                                                         baseboard_type:,
                                                                                         hw_loop:)


    system_3_data = Hash.new
    system_3_data[:name] = 'Sys_3_PSZ'
    system_3_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_3_data[:CentralHeatingDesignSupplyAirTemperature] = 43.0
    system_3_data[:AllOutdoorAirinCooling] = false
    system_3_data[:AllOutdoorAirinHeating] = false
    system_3_data[:TypeofLoadtoSizeOn] = 'Sensible'

    #System 3 Zone data
    system_3_data[:ZoneCoolingDesignSupplyAirTemperature] = 13.0
    system_3_data[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
    system_3_data[:SetpointManagerSingleZoneReheatSupplyTempMin] = 13.0
    system_3_data[:SetpointManagerSingleZoneReheatSupplyTempMax] = 43.0
    system_3_data[:ZoneDXCoolingSizingFactor] = 1.0
    system_3_data[:ZoneDXHeatingSizingFactor] = 1.3
    system_3_data[:ZoneCoolingSizingFactor] = 1.1
    system_3_data[:ZoneHeatingSizingFactor] = 1.3
    system_3_data[:MinimumOutdoorDryBulbTemperatureforCompressorOperation] = -10.0
    system_data = system_3_data
    # System Type 3: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas", "DX"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    always_on = model.alwaysOnDiscreteSchedule

    zones.each do |zone|
      air_loop = common_air_loop(model: model)

      air_loop.setName("Sys_3_PSZ #{zone.name}")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop.setName("#{system_data[:name]} #{zone.name}")
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn(system_data[:TypeofLoadtoSizeOn])
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(system_data[:CentralCoolingDesignSupplyAirTemperature])
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(system_data[:CentralHeatingDesignSupplyAirTemperature])
      air_loop_sizing.setAllOutdoorAirinCooling(system_data[:AllOutdoorAirinCooling])
      air_loop_sizing.setAllOutdoorAirinHeating(system_data[:AllOutdoorAirinHeating])


      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(system_data[:ZoneCoolingDesignSupplyAirTemperature])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(system_data[:ZoneHeatingDesignSupplyAirTemperature])
      sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
      sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

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

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.autosizeMinimumOutdoorAirFlowRate

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode
      #              fan.addToNode(supply_inlet_node)
      #              supplemental_htg_coil.addToNode(supply_inlet_node) if heating_coil_type == "DX"
      #              htg_coil.addToNode(supply_inlet_node)
      #              clg_coil.addToNode(supply_inlet_node)
      #              oa_system.addToNode(supply_inlet_node)
      if heating_coil_type == 'DX'
        air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(model, always_on, fan, htg_coil, clg_coil, supplemental_htg_coil)
        air_to_air_heatpump.setName("#{zone.name} ASHP")
        air_to_air_heatpump.setControllingZone(zone)
        air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
        air_to_air_heatpump.addToNode(supply_inlet_node)
      else
        fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
      end
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMin])
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMax])
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
      add_zone_baseboards(baseboard_type: baseboard_type, hw_loop: hw_loop, model: model, zone: zone)
    end # zone loop

    return true
  end

end