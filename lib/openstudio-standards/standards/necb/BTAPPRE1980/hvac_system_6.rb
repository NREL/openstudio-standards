class BTAPPRE1980
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
    # "NaturalGas","Electricity","PropaneGas","FuelOilNo1","FuelOilNO2","Coal","Diesel","Gasoline","OtherFuel1"
    # "heating_coil_type": "Electric" or "Hot Water"
    # "baseboard_type": "Electric" and "Hot Water"
    # "chiller_type": "Scroll";"Centrifugal";""Screw";"Reciprocating"
    # "fan_type": "AF_or_BI_rdg_fancurve";"AF_or_BI_inletvanes";"fc_inletvanes";"var_speed_drive"
    #
    system_data = {}
    system_data[:name] = 'Sys_6_VAV with Reheat'
    system_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_data[:CentralHeatingDesignSupplyAirTemperature] = 20.0
    system_data[:AllOutdoorAirinCooling] = false
    system_data[:AllOutdoorAirinHeating] = false
    system_data[:MinimumSystemAirFlowRatio] = 0.3

    # zone data
    system_data[:max_system_supply_air_temperature] = 43.0
    system_data[:min_system_supply_air_temperature] = 13.0
    system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference] = 11.0
    system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference] = 21.0
    system_data[:ZoneCoolingSizingFactor] = 1.1
    system_data[:ZoneHeatingSizingFactor] = 1.3
    system_data[:ZoneVAVMinFlowFactorPerFloorArea] = 0.002
    system_data[:ZoneVAVMaxReheatTemp] = 43.0
    system_data[:ZoneVAVDamperAction] = 'Normal'

    always_on = model.alwaysOnDiscreteSchedule

    # Chilled Water Plant

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Condenser System

    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Make a Packaged VAV w/ PFP Boxes for each story of the building
    model.getBuildingStorys.sort.each do |story|
      unless (BTAP::Geometry::BuildingStoreys.get_zones_from_storey(story) & zones).empty?

        air_loop = common_air_loop(model: model, system_data: system_data)
        air_loop.setName('Sys_6_VAV with Reheat')

        supply_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
        supply_fan.setName('Sys6 Supply Fan')
        return_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
        return_fan.setName('Sys6 Return Fan')

        if heating_coil_type == 'Hot Water'
          htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(htg_coil)
        end
        if heating_coil_type == 'Electric'
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        end

        clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
        chw_loop.addDemandBranchForComponent(clg_coil)

        oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
        oa_controller.autosizeMinimumOutdoorAirFlowRate

        # Set mechanical ventilation controller outdoor air to ZoneSum (used to be defaulted to ZoneSum but now should be
        # set explicitly)
        oa_controller.controllerMechanicalVentilation.setSystemOutdoorAirMethod('ZoneSum')

        oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

        # Add the components to the air loop
        # in order from closest to zone to furthest from zone
        supply_inlet_node = air_loop.supplyInletNode
        supply_outlet_node = air_loop.supplyOutletNode
        supply_fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
        oa_system.addToNode(supply_inlet_node)
        returnAirNode = oa_system.returnAirModelObject.get.to_Node.get
        return_fan.addToNode(returnAirNode)

        # Add a setpoint manager to control the supply air.  The controller will set the supply air to be the warmest
        # that can still meet the cooling load of the warmest thermal zone it services.  This differs from the NECB
        # which uses a constant 13 C supply air temperature.
        # sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        # sat_sch.setName('Supply Air Temp')
        # sat_sch.defaultDaySchedule.setName('Supply Air Temp Default')
        # sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), system_data[:system_supply_air_temperature])
        # sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
        sat_stpt_manager = OpenStudio::Model::SetpointManagerWarmest.new(model)
        sat_stpt_manager.setMaximumSetpointTemperature(system_data[:max_system_supply_air_temperature])
        sat_stpt_manager.setMinimumSetpointTemperature(system_data[:min_system_supply_air_temperature])
        sat_stpt_manager.addToNode(supply_outlet_node)

        # Make a VAV terminal with HW reheat for each zone on this story that is in intersection with the zones array.
        # and hook the reheat coil to the HW loop
        (BTAP::Geometry::BuildingStoreys.get_zones_from_storey(story) & zones).each do |zone|
          # Zone sizing parameters
          sizing_zone = zone.sizingZone
          sizing_zone.setZoneCoolingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod])
          sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference])
          sizing_zone.setZoneHeatingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod])
          sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference])
          sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
          sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

          if heating_coil_type == 'Hot Water'
            reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
            hw_loop.addDemandBranchForComponent(reheat_coil)
          elsif heating_coil_type == 'Electric'
            reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          end

          vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
          air_loop.addBranchForZone(zone, vav_terminal.to_StraightComponent)
          # NECB2011 minimum zone airflow setting
          vav_terminal.setFixedMinimumAirFlowRate(system_data[:ZoneVAVMinFlowFactorPerFloorArea] * zone.floorArea)
          vav_terminal.setMaximumReheatAirTemperature(system_data[:ZoneVAVMaxReheatTemp])
          vav_terminal.setDamperHeatingAction(system_data[:ZoneVAVDamperAction])

          # Set zone baseboards
          add_zone_baseboards(model: model,
                              zone: zone,
                              baseboard_type: baseboard_type,
                              hw_loop: hw_loop)
        end

        # Modifying airloop name.
        sys_name_pars = {}
        sys_name_pars['sys_hr'] = 'none'
        sys_name_pars['sys_htg'] = heating_coil_type
        sys_name_pars['sys_clg'] = 'Chilled Water'
        sys_name_pars['sys_sf'] = 'vv'
        sys_name_pars['zone_htg'] = baseboard_type
        sys_name_pars['zone_clg'] = 'none'
        sys_name_pars['sys_rf'] = 'vv'
        assign_base_sys_name(air_loop,
                             sys_abbr: 'sys_6',
                             sys_oa: 'mixed',
                             sys_name_pars: sys_name_pars)
      end
    end
    # next story

    # for debugging
    # puts "end add_sys6_multi_zone_built_up_with_baseboard_heating"

    return true
  end

  def new_add_sys6_multi_zone_built_up_system_with_baseboard_heating(
    model:,
    zones:,
    heating_coil_type:,
    baseboard_type:,
    chiller_type:,
    fan_type:,
    hw_loop:
  )
    # System Type 6: VAV w/ Reheat
    # This measure creates:
    # a single hot water loop with a natural gas or electric boiler or for the building
    # a single chilled water loop with water cooled chiller for the building
    # a single condenser water loop for heat rejection from the chiller
    # a VAV system w/ hot water or electric heating, chilled water cooling, and
    # hot water or electric reheat for each story of the building
    # Arguments:
    # "boiler_fueltype" choices match OS choices for boiler fuel type:
    # "NaturalGas","Electricity","PropaneGas","FuelOilNo1","FuelOilNo2","Coal","Diesel","Gasoline","OtherFuel1"
    # "heating_coil_type": "Electric" or "Hot Water"
    # "baseboard_type": "Electric" and "Hot Water"
    # "chiller_type": "Scroll";"Centrifugal";""Screw";"Reciprocating"
    # "fan_type": "AF_or_BI_rdg_fancurve";"AF_or_BI_inletvanes";"fc_inletvanes";"var_speed_drive"
    system_6_data = {}
    system_6_data[:name] = 'Sys_6_VAV with Reheat'
    system_6_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
    system_6_data[:CentralHeatingDesignSupplyAirTemperature] = 20.0
    system_6_data[:AllOutdoorAirinCooling] = false
    system_6_data[:AllOutdoorAirinHeating] = false
    system_6_data[:MinimumSystemAirFlowRatio] = 0.03
    # zone data
    system_6_data[:max_system_supply_air_temperature] = 43.0
    system_6_data[:min_system_supply_air_temperature] = 13.0
    system_6_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_6_data[:ZoneCoolingDesignSupplyAirTemperatureDifference] = 11.0
    system_6_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod] = 'TemperatureDifference'
    system_6_data[:ZoneHeatingDesignSupplyAirTemperatureDifference] = 21.0
    system_6_data[:ZoneCoolingSizingFactor] = 1.1
    system_6_data[:ZoneHeatingSizingFactor] = 1.3
    system_6_data[:ZoneVAVMinFlowFactorPerFloorArea] = 0.002
    system_6_data[:ZoneVAVMaxReheatTemp] = 43.0
    system_6_data[:ZoneVAVDamperAction] = 'Normal'
    system_data = system_6_data

    always_on = model.alwaysOnDiscreteSchedule

    # Chilled Water Plant

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Condenser System

    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Make a Packaged VAV w/ PFP Boxes for each story of the building
    model.getBuildingStorys.sort.each do |story|
      unless (BTAP::Geometry::BuildingStoreys.get_zones_from_storey(story) & zones).empty?

        air_loop = common_air_loop(model: model, system_data: system_data)
        air_loop.setName(system_data[:name])
        air_loop_sizing = air_loop.sizingSystem
        air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(system_data[:CentralCoolingDesignSupplyAirTemperature])
        air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(system_data[:CentralHeatingDesignSupplyAirTemperature])
        air_loop_sizing.setAllOutdoorAirinCooling(system_data[:AllOutdoorAirinCooling])
        air_loop_sizing.setAllOutdoorAirinHeating(system_data[:AllOutdoorAirinHeating])
        if model.version < OpenStudio::VersionString.new('2.7.0')
          air_loop_sizing.setMinimumSystemAirFlowRatio(system_data[:MinimumSystemAirFlowRatio]) unless system_data[:MinimumSystemAirFlowRatio].nil?
        else
          air_loop_sizing.setCentralHeatingMaximumSystemAirFlowRatio(system_data[:MinimumSystemAirFlowRatio]) unless system_data[:MinimumSystemAirFlowRatio].nil?
        end

        supply_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
        supply_fan.setName('Sys6 Supply Fan')
        return_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
        return_fan.setName('Sys6 Return Fan')

        if heating_coil_type == 'Hot Water'
          htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(htg_coil)
        end
        if heating_coil_type == 'Electric'
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        end

        clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
        chw_loop.addDemandBranchForComponent(clg_coil)

        oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
        oa_controller.autosizeMinimumOutdoorAirFlowRate

        # Set mechanical ventilation controller outdoor air to ZoneSum (used to be defaulted to ZoneSum but now should be
        # set explicitly)
        oa_controller.controllerMechanicalVentilation.setSystemOutdoorAirMethod('ZoneSum')

        oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

        # Add the components to the air loop
        # in order from closest to zone to furthest from zone
        supply_inlet_node = air_loop.supplyInletNode
        supply_outlet_node = air_loop.supplyOutletNode
        supply_fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
        oa_system.addToNode(supply_inlet_node)
        returnAirNode = oa_system.returnAirModelObject.get.to_Node.get
        return_fan.addToNode(returnAirNode)

        # Add a setpoint manager to control the supply air.  The controller will set the supply air to be the warmest
        # that can still meet the cooling load of the warmest thermal zone it services.  This differs from the NECB
        # which uses a constant 13 C supply air temperature.

        # sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        # sat_sch.setName('Supply Air Temp')
        # sat_sch.defaultDaySchedule.setName('Supply Air Temp Default')
        # sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), system_data[:system_supply_air_temperature])
        sat_stpt_manager = OpenStudio::Model::SetpointManagerWarmest.new(model)
        sat_stpt_manager.setMaximumSetpointTemperature(system_data[:max_system_supply_air_temperature])
        sat_stpt_manager.setMinimumSetpointTemperature(system_data[:min_system_supply_air_temperature])
        sat_stpt_manager.addToNode(supply_outlet_node)

        # Make a VAV terminal with HW reheat for each zone on this story that is in intersection with the zones array.
        # and hook the reheat coil to the HW loop
        (BTAP::Geometry::BuildingStoreys.get_zones_from_storey(story) & zones).each do |zone|
          # Zone sizing parameters
          sizing_zone = zone.sizingZone
          sizing_zone.setZoneCoolingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneCoolingDesignSupplyAirTemperatureInputMethod])
          sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(system_data[:ZoneCoolingDesignSupplyAirTemperatureDifference])
          sizing_zone.setZoneHeatingDesignSupplyAirTemperatureInputMethod(system_data[:ZoneHeatingDesignSupplyAirTemperatureInputMethod])
          sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(system_data[:ZoneHeatingDesignSupplyAirTemperatureDifference])
          sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
          sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

          if heating_coil_type == 'Hot Water'
            reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
            hw_loop.addDemandBranchForComponent(reheat_coil)
          elsif heating_coil_type == 'Electric'
            reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          end

          vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
          air_loop.addBranchForZone(zone, vav_terminal.to_StraightComponent)
          # NECB2011 minimum zone airflow setting
          vav_terminal.setFixedMinimumAirFlowRate(system_data[:ZoneVAVMinFlowFactorPerFloorArea] * zone.floorArea)
          vav_terminal.setMaximumReheatAirTemperature(system_data[:ZoneVAVMaxReheatTemp])
          vav_terminal.setDamperHeatingAction(system_data[:ZoneVAVDamperAction])

          # Set zone baseboards
          add_zone_baseboards(model: model,
                              zone: zone,
                              baseboard_type: baseboard_type,
                              hw_loop: hw_loop)
        end
      end
    end
    # next story

    # for debugging
    # puts "end add_sys6_multi_zone_built_up_with_baseboard_heating"

    return true
  end
end
