class NECB2011
# sys1_unitary_ac_baseboard_heating

  def add_sys1_unitary_ac_baseboard_heating_multi_speed(model:,
                                                        zones:,
                                                        mau:,
                                                        mau_heating_coil_type:,
                                                        baseboard_type:,
                                                        hw_loop:)
    raise("System 1 multi is not working right now. Please do not invoke!!!!")
    # System Type 1: PTAC with no heating (unitary AC)
    # Zone baseboards, electric or hot water depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # PSZ to represent make-up air unit (if present)
    # This measure creates:
    # a PTAC  unit for each zone in the building; DX cooling coil
    # and heating coil that is always off
    # Baseboards ("Hot Water or "Electric") in zones connected to hot water loop
    # MAU is present if argument mau == true, not present if argument mau == false
    # MAU is PSZ; DX cooling
    # MAU heating coil: hot water coil or electric, depending on argument mau_heating_coil_type
    # mau_heating_coil_type choices are "Hot Water", "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    # Some system parameters are set after system is set up; by applying method 'apply_hvac_efficiency_standard'

    always_on = model.alwaysOnDiscreteSchedule

    # define always off schedule for ptac heating coil
    always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF.always_off(model)

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

    # Create MAU
    # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)

    if mau == true

      staged_thermostat = OpenStudio::Model::ZoneControlThermostatStagedDualSetpoint.new(model)
      staged_thermostat.setHeatingTemperatureSetpointSchedule(htg_temp_sch)
      staged_thermostat.setNumberofHeatingStages(4)
      staged_thermostat.setCoolingTemperatureSetpointBaseSchedule(clg_temp_sch)
      staged_thermostat.setNumberofCoolingStages(4)

      mau_air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      mau_air_loop.setName('Sys_1_Make-up air unit')

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = mau_air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      if model.version < OpenStudio::VersionString.new('2.7.0')
        air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      else
        air_loop_sizing.setCentralHeatingMaximumSystemAirFlowRatio(1.0)
      end
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(12.8)
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

      mau_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      # Multi-stage gas heating coil
      if mau_heating_coil_type == 'Electric' || mau_heating_coil_type == 'Hot Water'

        mau_htg_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
        mau_htg_stage_1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_3 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_4 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)

        if mau_heating_coil_type == 'Electric'

          mau_supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)

        elsif mau_heating_coil_type == 'Hot Water'

          mau_supplemental_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(mau_supplemental_htg_coil)

        end

        mau_htg_stage_1.setNominalCapacity(0.1)
        mau_htg_stage_2.setNominalCapacity(0.2)
        mau_htg_stage_3.setNominalCapacity(0.3)
        mau_htg_stage_4.setNominalCapacity(0.4)

      end

      # Add stages to heating coil
      mau_htg_coil.addStage(mau_htg_stage_1)
      mau_htg_coil.addStage(mau_htg_stage_2)
      mau_htg_coil.addStage(mau_htg_stage_3)
      mau_htg_coil.addStage(mau_htg_stage_4)

      # TODO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX cooling coil
      mau_clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      mau_clg_coil.setFuelType('Electricity')
      mau_clg_stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_2 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_3 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_4 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_coil.addStage(mau_clg_stage_1)
      mau_clg_coil.addStage(mau_clg_stage_2)
      mau_clg_coil.addStage(mau_clg_stage_3)
      mau_clg_coil.addStage(mau_clg_stage_4)

      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.new(model, mau_fan, mau_htg_coil, mau_clg_coil, mau_supplemental_htg_coil)
      #              air_to_air_heatpump.setName("#{zone.name} ASHP")
      air_to_air_heatpump.setControllingZoneorThermostatLocation(zones[1])
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.setNumberofSpeedsforHeating(4)
      air_to_air_heatpump.setNumberofSpeedsforCooling(4)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      # oa_controller.setEconomizerControlType("DifferentialEnthalpy")

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = mau_air_loop.supplyInletNode
      air_to_air_heatpump.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

    end # Create MAU


    zones.each do |zone|
      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # Set up PTAC heating coil; apply always off schedule

      # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
      zero_outdoor_air = true  # flag to set outside air flow to zero
      add_ptac_dx_cooling(model, zone, zero_outdoor_air)

      # add zone baseboards
      add_zone_baseboards(baseboard_type: baseboard_type, hw_loop: hw_loop, model: model, zone: zone)

      #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
      if mau == true

        diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
        mau_air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      end # components for MAU
    end # of zone loop

    return true
  end
end