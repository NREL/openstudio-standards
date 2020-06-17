class NECB2011
  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model,
                                                                                        zones,
                                                                                        boiler_fueltype,
                                                                                        heating_coil_type,
                                                                                        baseboard_type,
                                                                                        hw_loop)
    raise("System 3 multi is not working right now. Please do not invoke!!!!!")
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

    always_on = model.alwaysOnDiscreteSchedule

    # TODO: Heating and cooling temperature set point schedules are set somewhere else
    # TODO: For now fetch the schedules and use them in setting up the heat pump system
    # TODO: Later on these schedules need to be passed on to this method
    htg_temp_sch = nil
    clg_temp_sch = nil
    zones.each do |izone|
      if izone.thermostat.is_initialized
        zone_thermostat = izone.thermostat.get
        if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
          dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
          htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
          clg_temp_sch = dual_thermostat.coolingSetpointTemperatureSchedule.get
          break
        end
      end
    end

    zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      air_loop.setName("Sys_3_PSZ_#{zone.name}")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      if model.version < OpenStudio::VersionString.new('2.7.0')
        air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      else
        air_loop_sizing.setCentralHeatingMaximumSystemAirFlowRatio(1.0)
      end
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption('NonCoincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      staged_thermostat = OpenStudio::Model::ZoneControlThermostatStagedDualSetpoint.new(model)
      staged_thermostat.setHeatingTemperatureSetpointSchedule(htg_temp_sch)
      staged_thermostat.setNumberofHeatingStages(4)
      staged_thermostat.setCoolingTemperatureSetpointBaseSchedule(clg_temp_sch)
      staged_thermostat.setNumberofCoolingStages(4)
      zone.setThermostat(staged_thermostat)

      # Multi-stage gas heating coil
      if heating_coil_type == 'Gas' || heating_coil_type == 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
        htg_stage_1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_3 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_4 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        if heating_coil_type == 'Gas'
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
        elsif heating_coil_type == 'Electric'
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          htg_stage_1.setNominalCapacity(0.1)
          htg_stage_2.setNominalCapacity(0.2)
          htg_stage_3.setNominalCapacity(0.3)
          htg_stage_4.setNominalCapacity(0.4)
        end

        # Multi-Stage DX or Electric heating coil
      elsif heating_coil_type == 'DX'
        htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
        htg_stage_1 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_2 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_3 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_4 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        sizing_zone.setZoneHeatingSizingFactor(1.3)
        sizing_zone.setZoneCoolingSizingFactor(1.0)
      else
        raise("#{heating_coil_type} is not a valid heating coil type.)")
      end

      # Add stages to heating coil
      htg_coil.addStage(htg_stage_1)
      htg_coil.addStage(htg_stage_2)
      htg_coil.addStage(htg_stage_3)
      htg_coil.addStage(htg_stage_4)

      # TODO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX cooling coil
      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setFuelType('Electricity')
      clg_stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_2 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_3 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_4 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_coil.addStage(clg_stage_1)
      clg_coil.addStage(clg_stage_2)
      clg_coil.addStage(clg_stage_3)
      clg_coil.addStage(clg_stage_4)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.autosizeMinimumOutdoorAirFlowRate

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.new(model, fan, htg_coil, clg_coil, supplemental_htg_coil)
      air_to_air_heatpump.setName("#{zone.name} ASHP")
      air_to_air_heatpump.setControllingZoneorThermostatLocation(zone)
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.addToNode(supply_inlet_node)
      air_to_air_heatpump.setNumberofSpeedsforHeating(4)
      air_to_air_heatpump.setNumberofSpeedsforCooling(4)

      oa_system.addToNode(supply_inlet_node)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      add_zone_baseboards(baseboard_type: baseboard_type, hw_loop: hw_loop, model: model, zone: zone)
    end # zone loop

    return true
  end

# end add_sys3_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed
end