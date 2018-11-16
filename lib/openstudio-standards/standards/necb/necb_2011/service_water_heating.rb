class NECB2011
  def model_add_swh(model, building_type, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Service Water Heating')

    # Add the main service water heating loop, if specified
    unless prototype_input['main_water_heater_volume'].nil?


      swh_fueltype = self.get_canadian_system_defaults_by_weatherfile_name(model)['swh_fueltype']

      # Add the main service water loop
      unless building_type == 'RetailStripmall' && ( template != 'NECB2011' &&  template != 'NECB2015')
        main_swh_loop = model_add_swh_loop(model,
                                           'Main Service Water Loop',
                                           nil,
                                           OpenStudio.convert(prototype_input['main_service_water_temperature'], 'F', 'C').get,
                                           prototype_input['main_service_water_pump_head'],
                                           prototype_input['main_service_water_pump_motor_efficiency'],
                                           OpenStudio.convert(prototype_input['main_water_heater_capacity'], 'Btu/hr', 'W').get,
                                           OpenStudio.convert(prototype_input['main_water_heater_volume'], 'gal', 'm^3').get,
                                           swh_fueltype,
                                           OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get)
      end

      # Attach the end uses if specified in prototype inputs
      # TODO remove special logic for large office SWH end uses
      # TODO remove special logic for stripmall SWH end uses and service water loops
      # TODO remove special logic for large hotel SWH end uses

      if prototype_input['main_service_water_peak_flowrate']

        # Attaches the end uses if specified as a lump value in the prototype_input
        model_add_swh_end_uses(model,
                               'Main',
                               main_swh_loop,
                               OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                               prototype_input['main_service_water_flowrate_schedule'],
                               OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                               nil)

      else

        # Attaches the end uses if specified by space type
        space_type_map = @space_type_map
        building_type = 'Space Function'
        puts space_type_map

        space_type_map.sort.each do |space_type_name, space_names|
          search_criteria = {
            'template' => template,
            'building_type' => model_get_lookup_name(building_type),
            'space_type' => space_type_name
          }
          data = model_find_object(standards_data['space_types'], search_criteria)

          # Skip space types with no data
          next if data.nil?

          # Skip space types with no water use, unless it is a NECB archetype (these do not have peak flow rates defined)

          # Add a service water use for each space

          space_names.sort.each do |space_name|
            space = model.getSpaceByName(space_name).get
            space_multiplier = nil

            # Added this to prevent double counting of zone multipliers.. space multipliers are never used in NECB archtypes.
            space_multiplier = 1

            model_add_swh_end_uses_by_space(model,
                                            main_swh_loop,
                                            space,
                                            space_multiplier)
          end
        end
      end
    end

    # Add the booster water heater, if specified
    unless prototype_input['booster_water_heater_volume'].nil?

      # Add the booster water loop
      swh_booster_loop = model_add_swh_booster(model,
                                               main_swh_loop,
                                               OpenStudio.convert(prototype_input['booster_water_heater_capacity'], 'Btu/hr', 'W').get,
                                               OpenStudio.convert(prototype_input['booster_water_heater_volume'], 'gal', 'm^3').get,
                                               prototype_input['booster_water_heater_fuel'],
                                               OpenStudio.convert(prototype_input['booster_water_temperature'], 'F', 'C').get,
                                               0,
                                               nil)

      # Attach the end uses
      model_add_booster_swh_end_uses(model,
                                     swh_booster_loop,
                                     OpenStudio.convert(prototype_input['booster_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                                     prototype_input['booster_service_water_flowrate_schedule'],
                                     OpenStudio.convert(prototype_input['booster_water_use_temperature'], 'F', 'C').get)

    end

    # Add the laundry water heater, if specified
    unless prototype_input['laundry_water_heater_volume'].nil?

      # Add the laundry service water heating loop
      laundry_swh_loop = model_add_swh_loop(model,
                                            'Laundry Service Water Loop',
                                            nil,
                                            OpenStudio.convert(prototype_input['laundry_service_water_temperature'], 'F', 'C').get,
                                            prototype_input['laundry_service_water_pump_head'],
                                            prototype_input['laundry_service_water_pump_motor_efficiency'],
                                            OpenStudio.convert(prototype_input['laundry_water_heater_capacity'], 'Btu/hr', 'W').get,
                                            OpenStudio.convert(prototype_input['laundry_water_heater_volume'], 'gal', 'm^3').get,
                                            prototype_input['laundry_water_heater_fuel'],
                                            OpenStudio.convert(prototype_input['laundry_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get)

      # Attach the end uses if specified in prototype inputs
      model_add_swh_end_uses(model,
                             'Laundry',
                             laundry_swh_loop,
                             OpenStudio.convert(prototype_input['laundry_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                             prototype_input['laundry_service_water_flowrate_schedule'],
                             OpenStudio.convert(prototype_input['laundry_water_use_temperature'], 'F', 'C').get,
                             nil)

    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Service Water Heating')

    return true
  end

  # add swh

  # Applies the standard efficiency ratings and typical losses and paraisitic loads to this object.
  # Efficiency and skin loss coefficient (UA)
  # Per PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
  # Appendix A: Service Water Heating
  #
  # @return [Bool] true if successful, false if not
  def water_heater_mixed_apply_efficiency(water_heater_mixed)
    # Get the capacity of the water heater
    # TODO add capability to pull autosized water heater capacity
    # if the Sizing:WaterHeater object is ever implemented in OpenStudio.
    capacity_w = water_heater_mixed.heaterMaximumCapacity
    if capacity_w.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find capacity, standard will not be applied.")
      return false
    else
      capacity_w = capacity_w.get
    end
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the volume of the water heater
    # TODO add capability to pull autosized water heater volume
    # if the Sizing:WaterHeater object is ever implemented in OpenStudio.
    volume_m3 = water_heater_mixed.tankVolume
    if volume_m3.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find volume, standard will not be applied.")
      return false
    else
      volume_m3 = volume_m3.get
    end
    volume_gal = OpenStudio.convert(volume_m3, 'm^3', 'gal').get

    # Get the heater fuel type
    fuel_type = water_heater_mixed.heaterFuelType
    unless fuel_type == 'NaturalGas' || fuel_type == 'Electricity'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, fuel type of #{fuel_type} is not yet supported, standard will not be applied.")
    end

    # Calculate the water heater efficiency and
    # skin loss coefficient (UA)
    # Calculate the energy factor (EF)
    # From PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
    # Appendix A: Service Water Heating
    water_heater_eff = nil
    ua_btu_per_hr_per_f = nil
    sl_btu_per_hr = nil
    case fuel_type
      when 'Electricity'
        volume_l_per_s = volume_m3 * 1000
        if capacity_btu_per_hr <= OpenStudio.convert(12, 'kW', 'Btu/hr').get
          # Fixed water heater efficiency per PNNL
          water_heater_eff = 1
          # Calculate the max allowable standby loss (SL)
          sl_w = if volume_l_per_s < 270
                   40 + 0.2 * volume_l_per_s # assume bottom inlet
                 else
                   0.472 * volume_l_per_s - 33.5
                 end # assume bottom inlet
          sl_btu_per_hr = OpenStudio.convert(sl_w, 'W', 'Btu/hr').get
        else
          # Fixed water heater efficiency per PNNL
          water_heater_eff = 1
          # Calculate the max allowable standby loss (SL)   # use this - NECB does not give SL calculation for cap > 12 kW
          sl_btu_per_hr = 20 + (35 * Math.sqrt(volume_gal))
        end
        # Calculate the skin loss coefficient (UA)
        ua_btu_per_hr_per_f = sl_btu_per_hr / 70
      when 'NaturalGas'
        if capacity_btu_per_hr <= 75_000
          # Fixed water heater thermal efficiency per PNNL
          water_heater_eff = 0.82
          # Calculate the minimum Energy Factor (EF)
          base_ef = 0.67
          vol_drt = 0.0019
          ef = base_ef - (vol_drt * volume_gal)
          # Calculate the Recovery Efficiency (RE)
          # based on a fixed capacity of 75,000 Btu/hr
          # and a fixed volume of 40 gallons by solving
          # this system of equations:
          # ua = (1/.95-1/re)/(67.5*(24/41094-1/(re*cap)))
          # 0.82 = (ua*67.5+cap*re)/cap
          cap = 75_000.0
          re = (Math.sqrt(6724 * ef**2 * cap**2 + 40_409_100 * ef**2 * cap - 28_080_900 * ef * cap + 29_318_000_625 * ef**2 - 58_636_001_250 * ef + 29_318_000_625) + 82 * ef * cap + 171_225 * ef - 171_225) / (200 * ef * cap)
          # Calculate the skin loss coefficient (UA)
          # based on the actual capacity.
          ua_btu_per_hr_per_f = (water_heater_eff - re) * capacity_btu_per_hr / 67.5
        else
          # Thermal efficiency requirement from 90.1
          et = 0.8
          # Calculate the max allowable standby loss (SL)
          cap_adj = 800
          vol_drt = 110
          sl_btu_per_hr = (capacity_btu_per_hr / cap_adj + vol_drt * Math.sqrt(volume_gal))
          # Calculate the skin loss coefficient (UA)
          ua_btu_per_hr_per_f = (sl_btu_per_hr * et) / 70
          # Calculate water heater efficiency
          water_heater_eff = (ua_btu_per_hr_per_f * 70 + capacity_btu_per_hr * et) / capacity_btu_per_hr
        end
    end

    # Convert to SI
    ua_btu_per_hr_per_c = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get

    # Set the water heater properties
    # Efficiency
    water_heater_mixed.setHeaterThermalEfficiency(water_heater_eff)
    # Skin loss
    water_heater_mixed.setOffCycleLossCoefficienttoAmbientTemperature(ua_btu_per_hr_per_c)
    water_heater_mixed.setOnCycleLossCoefficienttoAmbientTemperature(ua_btu_per_hr_per_c)
    # TODO: Parasitic loss (pilot light)
    # PNNL document says pilot lights were removed, but IDFs
    # still have the on/off cycle parasitic fuel consumptions filled in
    water_heater_mixed.setOnCycleParasiticFuelType(fuel_type)
    # self.setOffCycleParasiticFuelConsumptionRate(??)
    water_heater_mixed.setOnCycleParasiticHeatFractiontoTank(0)
    water_heater_mixed.setOffCycleParasiticFuelType(fuel_type)
    # self.setOffCycleParasiticFuelConsumptionRate(??)
    water_heater_mixed.setOffCycleParasiticHeatFractiontoTank(0.8)

    # set part-load performance curve
    if fuel_type == 'NaturalGas'
      plf_vs_plr_curve = model_add_curve(water_heater_mixed.model, 'SWH-EFFFPLR-NECB2011')
      water_heater_mixed.setPartLoadFactorCurve(plf_vs_plr_curve)
    end

    # Append the name with standards information
    water_heater_mixed.setName("#{water_heater_mixed.name} #{water_heater_eff.round(3)} Therm Eff")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.WaterHeaterMixed', "For #{template}: #{water_heater_mixed.name}; thermal efficiency = #{water_heater_eff.round(3)}, skin-loss UA = #{ua_btu_per_hr_per_f.round}Btu/hr")

    return true
  end
end
