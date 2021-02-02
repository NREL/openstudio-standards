class ASHRAE9012013 < ASHRAE901
  # @!group WaterHeaterMixed

  # Applies the correct fuel type for the water heaters
  # in the baseline model. 90.1-2013 requires a change
  # from the proposed building in some scenarios.
  #
  # @param building_type [String] the building type
  # @return [Bool] returns true if successful, false if not.
  def water_heater_mixed_apply_prm_baseline_fuel_type(water_heater_mixed, building_type)
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
    when 'SmallOffice', 'MediumOffice', 'LargeOffice', 'SmallOfficeDetailed', 'MediumOfficeDetailed', 'LargeOfficeDetailed', # Office
         'RetailStandalone', 'RetailStripmall', # Retail
         'Warehouse' # Warehouse
      new_fuel = 'Electricity'
    else
      new_fuel = 'NaturalGas'
    end

    # Change the fuel type if necessary
    old_fuel = water_heater_mixed.heaterFuelType
    unless new_fuel == old_fuel
      water_heater_mixed.setHeaterFuelType(new_fuel)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, changed baseline water heater fuel from #{old_fuel} to #{new_fuel}.")
    end

    return true
  end
end
