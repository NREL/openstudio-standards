class ASHRAE9012004 < ASHRAE901
  # @!group Model

  # Determine which climate zone to use.
  # Uses the most specific climate zone set for most
  # climate zones, except for ClimateZone 3, which
  # uses the least specific climate zone.
  def model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)
    climate_zone_set = if possible_climate_zone_sets.include? 'ClimateZone 3'
                         possible_climate_zone_sets.max
                       else
                         possible_climate_zone_sets.min
                       end
    return climate_zone_set
  end
end
