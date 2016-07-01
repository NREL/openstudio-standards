
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::WaterHeaterMixed

  # Applies the standard efficiency ratings and typical losses and paraisitic loads to this object.
  # Efficiency and skin loss coefficient (UA)
  # Per PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
  # Appendix A: Service Water Heating
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not
  # @todo break parasitic/skin losses into a separate method in
  #   Prototype.WaterHeaterMixed because not governed by standard?
  def setStandardEfficiency(template)
  
    # Get the capacity of the water heater
    # TODO add capability to pull autosized water heater capacity
    # if the Sizing:WaterHeater object is ever implemented in OpenStudio.
    capacity_w = self.heaterMaximumCapacity
    if capacity_w.empty?
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.WaterHeaterMixed", "For #{self.name}, cannot find capacity, standard will not be applied.")
      return false
    else
      capacity_w = capacity_w.get
    end
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, "W", "Btu/hr").get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, "W", "kBtu/hr").get
    
    # Get the volume of the water heater
    # TODO add capability to pull autosized water heater volume
    # if the Sizing:WaterHeater object is ever implemented in OpenStudio. 
    volume_m3 = self.tankVolume
    if volume_m3.empty?
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.WaterHeaterMixed", "For #{self.name}, cannot find volume, standard will not be applied.")
      return false
    else
      volume_m3 = volume_m3.get
    end
    volume_gal = OpenStudio.convert(volume_m3, "m^3", "gal").get
  
    # Get the heater fuel type
    fuel_type = self.heaterFuelType
    if !(fuel_type == 'NaturalGas' || fuel_type == 'Electricity')
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.WaterHeaterMixed", "For #{self.name}, fuel type of #{fuel_type} is not yet supported, standard will not be applied.")
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
      if capacity_btu_per_hr <= OpenStudio.convert(12,'kW','Btu/hr').get  
        # Fixed water heater efficiency per PNNL
        water_heater_eff = 1
        # Calculate the minimum Energy Factor (EF)
        ef = 0.97 - (0.00132 * volume_gal)
        # Calculate the skin loss coefficient (UA)
        ua_btu_per_hr_per_f = (41094*(1/ef - 1))/(24*67.5)
      else
        # Fixed water heater efficiency per PNNL
        water_heater_eff = 1
        # Calculate the max allowable standby loss (SL)
        sl_btu_per_hr = 20 + (35*Math.sqrt(volume_gal))
        # Calculate the skin loss coefficient (UA)
        ua_btu_per_hr_per_f = sl_btu_per_hr/70
      end
    when 'NaturalGas'
      case template # TODO inconsistency; ref buildings don't calculate water heater UA the same way
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        water_heater_eff = 0.78
        ua_btu_per_hr_per_f = 11.37
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        if capacity_btu_per_hr <= 75000  
          # Fixed water heater efficiency per PNNL
          water_heater_eff = 0.82
          # Calculate the minimum Energy Factor (EF)
          ef = 0.67 - (0.0019 * volume_gal)
          # Calculate the skin loss coefficient (UA)
          # TODO solve system of equations {u = (1/.95-1/r)/(67.5*(24/41094-1/(r*75000))), 0.82 = (u*67.5+75000*r)/75000}
          # Assume recovery efficieny = 0.81 based on regression of prototype models instead
          re = 0.81
          ua_btu_per_hr_per_f = (1/ef-1/re)/(67.5*(24/41094-1/(re*capacity_btu_per_hr)))
        else
          # Thermal efficiency requirement from 90.1
          et = 0.8
          # Calculate the max allowable standby loss (SL)
          sl_btu_per_hr = (capacity_btu_per_hr/800 + 110*Math.sqrt(volume_gal))
          # Calculate the skin loss coefficient (UA)
          ua_btu_per_hr_per_f = (sl_btu_per_hr*et)/70
          # Calculate water heater efficiency
          water_heater_eff = (ua_btu_per_hr_per_f*70 + capacity_btu_per_hr*et)/capacity_btu_per_hr
        end
      end
    end
    
    # Convert to SI
    ua_btu_per_hr_per_c = OpenStudio.convert(ua_btu_per_hr_per_f, "Btu/hr*R", "W/K").get
  
    # Set the water heater properties
    # Efficiency
    self.setHeaterThermalEfficiency(water_heater_eff)
    # Skin loss
    self.setOffCycleLossCoefficienttoAmbientTemperature(ua_btu_per_hr_per_c)
    self.setOnCycleLossCoefficienttoAmbientTemperature(ua_btu_per_hr_per_c)
    # TODO Parasitic loss (pilot light)
    # PNNL document says pilot lights were removed, but IDFs
    # still have the on/off cycle parasitic fuel consumptions filled in
    self.setOnCycleParasiticFuelType(fuel_type)
    #self.setOffCycleParasiticFuelConsumptionRate(??)
    self.setOnCycleParasiticHeatFractiontoTank(0)
    self.setOffCycleParasiticFuelType(fuel_type)
    #self.setOffCycleParasiticFuelConsumptionRate(??)
    self.setOffCycleParasiticHeatFractiontoTank(0.8)
  
    # Append the name with standards information
    self.setName("#{name} #{water_heater_eff.round(3)}Eff")
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.WaterHeaterMixed', "For #{template}: #{self.name}; efficiency = #{water_heater_eff.round(3)}, skin-loss UA = #{ua_btu_per_hr_per_f.round}Btu/hr AKA #{ua_btu_per_hr_per_c.round(1)}W/K")  
  
    return true
  
  end
  
  # Applies the correct fuel type for the water heaters
  # in the baseline model.  For most standards and for most building
  # types, the baseline uses the same fuel type as the proposed.
  # However, certain standards like 90.1-2013 require a change
  # in some scenarios.
  # 
  # @param building_type [String] the building type
  # @return [Bool] returns true if successful, false if not.
  def apply_performance_rating_method_baseline_fuel_type(template, building_type)
    
    # For all standards except 90.1-2013
    # baseline is same as proposed per
    # Table G3.1 item 11.b
    unless template == '90.1-2013'
      return true
    end
  
    # Determine the building-type specific
    # fuel requirements from Table G3.1.1-2   
    new_fuel = nil
    case building_type
    when 'SecondarySchool', 'PrimarySchool', # School/university
         'SmallHotel', # Motel
         'LargeHotel', # Hotel
         'QuickServiceRestaurant', # Dining: Cafeteria/fast food
         'FullServiceRestaurant', # Dining: Family
         'MidriseApartment', 'HighriseApartment', # Multifamily
         'Hospital', # Hospital
         'Outpatient' # Health-care clinic
      new_fuel = 'NaturalGas'
    when 'SmallOffice', 'MediumOffice', 'LargeOffice', # Office
         'RetailStandalone', 'RetailStripmall', # Retail
         'Warehouse' # Warehouse
      new_fuel = 'Electricity'
    else
      new_fuel = 'NaturalGas'
    end

    # Change the fuel type if necessary
    old_fuel = self.heaterFuelType
    unless new_fuel == old_fuel
      self.setHeaterFuelType(new_fuel)
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.WaterHeaterMixed", "For #{self.name}, changed baseline water heater fuel from #{old_fuel} to #{new_fuel}.")
    end
  
    return true
  
  end
  
end
