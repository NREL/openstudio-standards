class ASHRAE9012019 < ASHRAE901
  # @!group hvac_systems

  # Determine which type of fan the cooling tower
  # will have.  Variable Speed Fan for ASHRAE 90.1-2019.
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_cw_loop_cooling_tower_fan_type(model)
    fan_type = 'Variable Speed Fan'
    return fan_type
  end

  # Add zone ERV
  # This function adds supply fan, exhaust fan, heat exchanger, and zone hvac
  #
  # This function is only used for nontransient dwelling units (Mid-rise and High-rise Apartment)
  def model_add_zone_erv(model, thermal_zones, search_criteria)
    ervs = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding ERV for #{zone.name}.")

      # determine the OA requirement for this zone
      min_oa_flow_m3_per_s_per_m2 = thermal_zone_outdoor_airflow_rate_per_area(zone)
      supply_fan = create_fan_by_name(model,
                                      'ERV_Supply_Fan',
                                      fan_name: "#{zone.name} ERV Supply Fan")
      impeller_eff = fan_baseline_impeller_efficiency(supply_fan)
      fan_change_impeller_efficiency(supply_fan, impeller_eff)
      exhaust_fan = create_fan_by_name(model,
                                       'ERV_Supply_Fan',
                                       fan_name: "#{zone.name} ERV Exhaust Fan")
      fan_change_impeller_efficiency(exhaust_fan, impeller_eff)

      erv_controller = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilatorController.new(model)
      erv_controller.setName("#{zone.name} ERV Controller")

      climate_zone = search_criteria['climate_zone']
      erv_err = model_find_object(standards_data['energy_recovery'], search_criteria)
      err_basis = erv_err['err_basis']
      err = erv_err['err']

      heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      heat_exchanger.setName("#{zone.name} ERV HX")
      heat_exchanger.setHeatExchangerType('Plate')
      heat_exchanger.setEconomizerLockout(false)
      heat_exchanger.setSupplyAirOutletTemperatureControl(false)
      heat_exchanger_air_to_air_sensible_and_latent_apply_prototype_efficiency(heat_exchanger, err, err_basis, climate_zone)

      zone_hvac = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilator.new(model, heat_exchanger, supply_fan, exhaust_fan)
      zone_hvac.setName("#{zone.name} ERV")
      zone_hvac.setVentilationRateperUnitFloorArea(min_oa_flow_m3_per_s_per_m2)
      zone_hvac.setController(erv_controller)
      zone_hvac.addToThermalZone(zone)

      # ensure the ERV takes priority, so ventilation load is included when treated by other zonal systems
      # From EnergyPlus I/O reference:
      # "For situations where one or more equipment types has limited capacity or limited control capability, order the
      #  sequence so that the most controllable piece of equipment runs last. For example, with a dedicated outdoor air
      #  system (DOAS), the air terminal for the DOAS should be assigned Heating Sequence = 1 and Cooling Sequence = 1.
      #  Any other equipment should be assigned sequence 2 or higher so that it will see the net load after the DOAS air
      #  is added to the zone."
      zone.setCoolingPriority(zone_hvac.to_ModelObject.get, 1)
      zone.setHeatingPriority(zone_hvac.to_ModelObject.get, 1)

      ervs << zone_hvac
      return ervs
    end
  end
end
