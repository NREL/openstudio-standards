class ASHRAE901PRM2019 < ASHRAE901PRM

  # Apply the prm parameter to a water heater based on the
  # building area type.
  # @param water_heater_mixed [OpenStudio::Model::WaterHeaterMixed] water heater mixed object
  # @param building_type [String] the building type (For consistency with the standard class, not used in the method)
  # @param swh_building_type [String] the swh building are type
  # @return [Boolean] returns true if successful, false if not
  def model_apply_water_heater_prm_parameter(water_heater_mixed, building_type_swh)
    water_heater_mixed_apply_prm_fuel_type(water_heater_mixed, building_type_swh)
    water_heater_mixed_apply_efficiency(water_heater_mixed)
    # # get number of water heaters
    # comp_qty = get_additional_property_as_integer(water_heater_mixed, 'component_quantity', 1)
    #
    # # Get the capacity of the water heater
    # capacity_w = water_heater_mixed.heaterMaximumCapacity
    # if capacity_w.empty?
    #   OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find capacity, standard will not be applied.")
    #   return false
    # else
    #   capacity_w = capacity_w.get / comp_qty
    # end
    # capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    #
    # # Get the volumn of the water heater
    # volumn_m3 = water_heater_mixed.tankVolume
    # if volumn_m3.empty?
    #   OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find volumn, standard will not be applied.")
    #   return false
    # else
    #   volumn_m3 = volumn_m3.get / comp_qty
    # end
    # volumn_gal = OpenStudio.convert(volumn_m3, 'm^3', 'gal').get
    #
    # # Get the fuel type data
    # heater_prop = model_find_object(standards_data['prm_swh_bldg_type'], {'swh_building_type' => building_type_swh})
    # new_fuel_data = heater_prop['baseline_heating_method']
    # # There are only two water heater fuel type in the prm database:
    # # ("Gas Storage" and "Electric Resistance Storage")
    # # Change the prm fuel type to openstudio fuel type
    # if new_fuel_data == "Gas Storage"
    #   new_fuel = "NaturalGas"
    # else
    #   new_fuel = "Electricity"
    # end
    #
    # # Calculate the water heater properties
    # # Most electricity or natural gas "Storage" water heater use uef to
    # # calculate the efficiency and skin loss coefficient.
    # # Only two cases do not use uef, which is Electricity, capacity > 40944.01
    # # and NaturalGas, capacity > 105000.01.
    # # The efficiency and skin loss coefficient of these two cases
    # # are calculated separately.
    # # The efficiency and skin loss coefficient ua is based on 90.1-2019 Table 7.8 and
    # # PNNL-23269 "Enhancements to ASHRAE Standard 90.1 Prototype Building Models" A 1.2
    # if (new_fuel == "Electricity") and (capacity_btu_per_hr > 40944.01)
    #   water_heater_eff = 1
    #   ua_btu_per_hr_per_f = (0.3 + 27.0/volumn_gal)/70
    # elsif (new_fuel == "NaturalGas") and (capacity_btu_per_hr > 105000.01)
    #   ua_btu_per_hr_per_f = (capacity_btu_per_hr/800 + 110 * Math.sqrt(volumn_gal))*0.8/70
    #   water_heater_eff = (ua_btu_per_hr_per_f * 70 + capacity_btu_per_hr * 0.8)/capacity_btu_per_hr
    # else
    #   search_criteria = {}
    #   search_criteria['template'] = template
    #   search_criteria['fuel_type'] = new_fuel
    #   if new_fuel == "Electricity"
    #     search_criteria['product_class'] = "Water Heaters"
    #   else
    #     search_criteria['product_class'] = "Storage Water Heater"
    #   end
    #
    #   # Todo: Use 'medium' as draw_profile for now.
    #   search_criteria['draw_profile'] = "medium"
    #   wh_props = model_find_object(standards_data['water_heaters'], search_criteria, capacity = capacity_btu_per_hr, date = nil, area = nil, num_floors = nil, fan_motor_bhp = nil, volume = volumn_gal)
    #   unless wh_props
    #     OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find water heater properties, cannot apply efficiency standard.")
    #     return false
    #   end
    #   uniform_energy_factor_base = wh_props['uniform_energy_factor_base']
    #   uniform_energy_factor_volume_allowance = wh_props['uniform_energy_factor_volume_allowance']
    #   uef = uniform_energy_factor_base - uniform_energy_factor_volume_allowance * volumn_gal
    #   ef = water_heater_convert_uniform_energy_factor_to_energy_factor(fuel_type = new_fuel, uef = uef, capacity_btu_per_hr = capacity_btu_per_hr, volume_gal = volumn_gal)
    #   eff_ua = water_heater_convert_energy_factor_to_thermal_efficiency_and_ua(new_fuel, ef, capacity_btu_per_hr)
    #   water_heater_eff = eff_ua[0]
    #   ua_btu_per_hr_per_f = eff_ua[1]
    # end
    #
    # # Convert to SI
    # ua_w_per_k = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get
    # OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, skin-loss UA = #{ua_w_per_k} W/K.")
    #
    # # Set the water heater prm properties
    # # Efficiency
    # water_heater_mixed.setHeaterThermalEfficiency(water_heater_eff)
    # # Skin loss
    # water_heater_mixed.setOffCycleLossCoefficienttoAmbientTemperature(ua_w_per_k)
    # water_heater_mixed.setOnCycleLossCoefficienttoAmbientTemperature(ua_w_per_k)
    # # Fuel type
    # old_fuel = water_heater_mixed.heaterFuelType
    # unless new_fuel == old_fuel
    #   water_heater_mixed.setHeaterFuelType(new_fuel)
    #   water_heater_mixed.setOnCycleParasiticFuelType(new_fuel)
    #   water_heater_mixed.setOffCycleParasiticFuelType(new_fuel)
    #   OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, changed baseline water heater fuel from #{old_fuel} to #{new_fuel}.")
    # end
    #
    # # Append the name with prm information
    # water_heater_mixed.setName("#{water_heater_mixed.name} #{water_heater_eff.round(3)} Therm Eff")
    # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.WaterHeaterMixed', "For #{template}: #{water_heater_mixed.name}; thermal efficiency = #{water_heater_eff.round(3)}, skin-loss UA = #{ua_btu_per_hr_per_f.round}Btu/hr-R")
    # return true
  end
end

