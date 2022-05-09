class NECB2020

  # Applies the standard efficiency ratings and typical losses and paraisitic loads to this object.
  # Efficiency and skin loss coefficient (UA)
  # Per PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
  # Appendix A: Service Water Heating
  #
  # @return [Bool] true if successful, false if not
  #
  # This was modified in PCF 1630
  #
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
    unless fuel_type == 'NaturalGas' || fuel_type == 'Electricity' || fuel_type == 'FuelOilNo2'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, fuel type of #{fuel_type} is not yet supported, standard will not be applied.")
    end

    # Calculate the water heater efficiency and
    # skin loss coefficient (UA)
    # Calculate the energy factor (EF)
    # From PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
    # Appendix A: Service Water Heating
	# and modified by PCF 1630 as noted below.
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
                 # assume bottom inlet
               end
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
      volume_l = volume_m3 / 1000
      if capacity_btu_per_hr <= 75_000
        # Fixed water heater thermal efficiency per PNNL
        water_heater_eff = 0.82
		
        # Calculate the minimum Energy Factor (EF) (This was introduced in PCF 1630)
        if volume_l < 68
          uef = 0.5982 - 0.0005 * volume_l
          ef = 1.0005 * uef + 0.0019
        elsif volume_l >= 68 and volume_l < 193
          uef = 0.6483 - 0.00045 * volume_l
          ef = 1.0005 * uef + 0.0019
        elsif volume_l >= 193 and volume_l < 284
          uef = 0.692 - 0.00034 * volume_l
          ef = 1.0005 * uef + 0.0019
        end
		
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
		
      # This capacity band was introduced in PCF 1630
      elsif capacity_btu_per_hr > 75_000 and capacity_btu_per_hr < 103977 and volume_l < 454
        water_heater_eff = 0.82
        uef = 0.8107 - 0.00021 * volume_l
        ef = 1.0005 * uef + 0.0019
        cap = 103977
        re = (Math.sqrt(6724 * ef**2 * cap**2 + 40_409_100 * ef**2 * cap - 28_080_900 * ef * cap + 29_318_000_625 * ef**2 - 58_636_001_250 * ef + 29_318_000_625) + 82 * ef * cap + 171_225 * ef - 171_225) / (200 * ef * cap)
        
		# Calculate the skin loss coefficient (UA)
        # based on the actual capacity.
        ua_btu_per_hr_per_f = (water_heater_eff - re) * capacity_btu_per_hr / 67.5
      else
        # Thermal efficiency (PCF 1630 update)
        et = 0.9
        sl_w = 0.84 * capacity_btu_per_hr / 3412.412 / 0.234 + 16.57 * (volume_l ** 0.5)
        sl_btu_per_hr = sl_w * 3.412
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
    if (fuel_type == 'NaturalGas') || (fuel_type == 'FuelOilNo2')
      plf_vs_plr_curve = model_add_curve(water_heater_mixed.model, 'SWH-EFFFPLR-NECB2011')
      water_heater_mixed.setPartLoadFactorCurve(plf_vs_plr_curve)
    end

    # Append the name with standards information
    water_heater_mixed.setName("#{water_heater_mixed.name} #{water_heater_eff.round(3)} Therm Eff")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.WaterHeaterMixed', "For #{template}: #{water_heater_mixed.name}; thermal efficiency = #{water_heater_eff.round(3)}, skin-loss UA = #{ua_btu_per_hr_per_f.round}Btu/hr")
    return true
  end
end