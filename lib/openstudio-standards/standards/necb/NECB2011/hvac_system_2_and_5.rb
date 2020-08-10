class NECB2011


  def add_sys2_FPFC_sys5_TPFC(model:,
                              zones:,
                              chiller_type:,
                              fan_coil_type:,
                              mau_cooling_type:,
                              hw_loop:)

    #System 2 AHU data
    system_data = Hash.new
    system_data[:name] = 'Sys_2_Make-up air unit'
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

    system_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_data[:CentralHeatingDesignSupplyAirTemperature] = 13.1
    system_data[:AllOutdoorAirinCooling] = false
    system_data[:AllOutdoorAirinHeating] = false
    system_data[:TypeofLoadtoSizeOn] = 'Sensible'
    system_data[:SetpointManagerSingleZoneReheatSupplyTempMax] = 13.0
    system_data[:SetpointManagerSingleZoneReheatSupplyTempMin] = 13.1
    system_data[:MinimumSystemAirFlowRatio] = 1.0

    #System 2 Zone data
    system_data[:ZoneCoolingDesignSupplyAirTemperature] = 13.0
    system_data[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
    system_data[:ZoneCoolingSizingFactor] = 1.1
    system_data[:ZoneHeatingSizingFactor] = 1.3



    # System Type 2: FPFC or System 5: TPFC
    # This measure creates:
    # -a four pipe or a two pipe fan coil unit for each zone in the building;
    # -a make up air-unit to provide ventilation to each zone;
    # -a heating loop, cooling loop and condenser loop to serve four pipe fan coil units
    # Arguments:
    #   boiler_fueltype: "NaturalGas","Electricity","PropaneGas","FuelOilNo1","FuelOilNO2","Coal","Diesel","Gasoline","OtherFuel1"
    #   chiller_type: "Scroll";"Centrifugal";"Rotary Screw";"Reciprocating"
    #   mua_cooling_type: make-up air unit cooling type "DX";"Hydronic"
    #   fan_coil_type options are "TPFC" or "FPFC"

    # TODO: Add arguments as needed when the sizing routine is finalized. For example we will need to know the
    # required size of the boilers to decide on how many units are needed based on NECB rules.

    always_on = model.alwaysOnDiscreteSchedule

    # schedule for two-pipe fan coil operation. 3 seasons for heating/cooling.
    tpfc_clg_availability_sch, tpfc_htg_availability_sch = create_heating_cooling_on_off_availability_schedule(model)

    # Create a chilled water loop
    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = self.setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Create a condenser Loop
    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = self.setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Set up make-up air unit for ventilation
    # TO DO: Need to investigate characteristics of make-up air unit for NECB reference
    # and define them here

    air_loop = mau_air_loop = common_air_loop(model: model, system_data: system_data)
    air_loop.setName(system_data[:name])



    fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

    # Assume direct-fired gas heating coil for now; need to add logic
    # to set up hydronic or electric coil depending on proposed?

    htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)

    # Add DX or hydronic cooling coil
    if mau_cooling_type == 'DX'
      clg_coil = self.add_onespeed_DX_coil(model, tpfc_clg_availability_sch)
    elsif mau_cooling_type == 'Hydronic'
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, tpfc_clg_availability_sch)
      chw_loop.addDemandBranchForComponent(clg_coil)
    end

    # does MAU have an economizer?
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.autosizeMinimumOutdoorAirFlowRate

    # oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

    # Add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = air_loop.supplyInletNode
    fan.addToNode(supply_inlet_node)
    htg_coil.addToNode(supply_inlet_node)
    clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)

    # Add a setpoint manager single zone reheat to control the
    # supply air temperature based on the needs of default zone (OpenStudio picks one)
    # TO DO: need to have method to pick appropriate control zone?

    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMin])
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(system_data[:SetpointManagerSingleZoneReheatSupplyTempMax])
    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

    # Set up zonal FC (ZoneHVAC,cooling coil, heating coil, fan) in each zone
    zones.each do |zone|
      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(system_data[:ZoneCoolingDesignSupplyAirTemperature])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(system_data[:ZoneHeatingDesignSupplyAirTemperature])
      sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
      sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

      # fc supply fan
      fc_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      if fan_coil_type == 'FPFC'
        # heating coil
        fc_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)

        # cooling coil
        fc_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
      elsif fan_coil_type == 'TPFC'
        # heating coil
        fc_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, tpfc_htg_availability_sch)

        # cooling coil
        fc_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, tpfc_clg_availability_sch)
      end

      # connect heating coil to hot water loop and cooling coil to chw loop.
      hw_loop.addDemandBranchForComponent(fc_htg_coil)
      chw_loop.addDemandBranchForComponent(fc_clg_coil)

      #add connections to FPFC.
      zone_fc = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, always_on, fc_fan, fc_clg_coil, fc_htg_coil)
      zone_fc.addToThermalZone(zone)

      # Create a diffuser and attach the zone/diffuser pair to the air loop (make-up air unit)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end # zone loop
  end
end
