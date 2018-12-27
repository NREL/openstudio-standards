class NECB2011

def add_sys1_unitary_ac_baseboard_heating(model:,
                                          zones:,
                                          mau_type:,
                                          mau_heating_coil_type:,
                                          baseboard_type:,
                                          hw_loop:,
                                          multi_speed: false)

  # Keep all data and assumptions for both systems on the top here for easy reference.
  system_1_single = Hash.new
  system_1_single[:name] = 'Sys_1_Make-up air unit'
  system_1_single[:CentralCoolingDesignSupplyAirTemperature] = 13.0
  system_1_single[:CentralHeatingDesignSupplyAirTemperature] = 43.0
  system_1_single[:AllOutdoorAirinCooling] = true
  system_1_single[:AllOutdoorAirinHeating] = true
  system_1_single[:TypeofLoadtoSizeOn] = 'VentilationRequirement'
  system_1_single[:system_supply_air_temperature] = 20.0
  system_1_single[:ZoneCoolingDesignSupplyAirTemperature] = 13.0
  system_1_single[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
  system_1_single[:ZoneCoolingSizingFactor] = 1.1
  system_1_single[:ZoneHeatingSizingFactor] = 1.3
  system_data = system_1_single




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
  always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF.always_off(model)


  # Create MAU
  # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)

  if mau_type == true
    mau_air_loop = common_air_loop(model: model)
    mau_air_loop.setName(system_data[:name])
    air_loop_sizing = mau_air_loop.sizingSystem
    air_loop_sizing.setTypeofLoadtoSizeOn(system_data[:TypeofLoadtoSizeOn])
    air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(system_data[:CentralCoolingDesignSupplyAirTemperature] )
    air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(system_data[:CentralHeatingDesignSupplyAirTemperature] )
    air_loop_sizing.setAllOutdoorAirinCooling(system_data[:AllOutdoorAirinCooling])
    air_loop_sizing.setAllOutdoorAirinHeating(system_data[:AllOutdoorAirinHeating])
    mau_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)
    #MAU Heating type selection.
    if mau_heating_coil_type == 'Electric' # electric coil
      mau_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
    end

    if mau_heating_coil_type == 'Hot Water'
      mau_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
      hw_loop.addDemandBranchForComponent(mau_htg_coil)
    end

    # Set up Single Speed DX coil with
    mau_clg_coil = self.add_onespeed_DX_coil(model, always_on)

    # Set up OA system
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.autosizeMinimumOutdoorAirFlowRate
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

    # Add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = mau_air_loop.supplyInletNode
    mau_fan.addToNode(supply_inlet_node)
    mau_htg_coil.addToNode(supply_inlet_node)
    mau_clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)

    # Add a setpoint manager to control the supply air temperature
    sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sat_sch.setName('Makeup-Air Unit Supply Air Temp')
    sat_sch.defaultDaySchedule.setName('Makeup Air Unit Supply Air Temp Default')
    sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), system_data[:system_supply_air_temperature])
    setpoint_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
    setpoint_mgr.addToNode(mau_air_loop.supplyOutletNode)
  end


  zones.each do |zone|
    # Zone sizing temperature
    sizing_zone = zone.sizingZone
    sizing_zone.setZoneCoolingDesignSupplyAirTemperature(system_data[:ZoneCoolingDesignSupplyAirTemperature])
    sizing_zone.setZoneHeatingDesignSupplyAirTemperature(system_data[:ZoneHeatingDesignSupplyAirTemperature])
    sizing_zone.setZoneCoolingSizingFactor(system_data[:ZoneCoolingSizingFactor])
    sizing_zone.setZoneHeatingSizingFactor(system_data[:ZoneHeatingSizingFactor])

    # Create a PTAC for each zone:
    # PTAC DX Cooling with electric heating coil; electric heating coil is always off
    # TO DO: need to apply this system to space types:
    # (1) data processing area: control room, data centre
    # when cooling capacity <= 20kW and
    # (2) residential/accommodation: murb, hotel/motel guest room
    # when building/space heated only (this as per NECB; apply to
    # all for initial work? CAN-QUEST limitation)

    # TO DO: PTAC characteristics: sizing, fan schedules, temperature setpoints, interaction with MAU

    # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
    add_ptac_dx_cooling(model, zone)

    # add zone baseboards
    add_zone_baseboards(baseboard_type: baseboard_type, hw_loop: hw_loop, model: model, zone: zone)

    #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
    if mau_type == true
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      mau_air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end # components for MAU
  end # of zone loop

  return true
end



end