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

  # @!group Model
  #
  # Determine the surface range of a baseline model.
  # The method calculates the window to wall ratio (assuming all spaces are conditioned)
  # and select the range based on the calculated window to wall ratio
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param intended_surface_type [String] intended surface type
  def model_get_percent_of_surface_range(model, intended_surface_type)
    wwr_range = {}

    # Do not process surfaces other than exterior windows and glass door for 2004 standard
    if intended_surface_type != 'ExteriorWindow' && intended_surface_type != 'GlassDoor'
      wwr_range['minimum_percent_of_surface'] = nil
      wwr_range['maximum_percent_of_surface'] = nil
    else
      wwr = model_get_window_area_info(model, true)
      if wwr <= 10
        wwr_range['minimum_percent_of_surface'] = 1.0
        wwr_range['maximum_percent_of_surface'] = 10.0
      elsif wwr <= 20
        wwr_range['minimum_percent_of_surface'] = 10.001
        wwr_range['maximum_percent_of_surface'] = 20
      elsif wwr <= 30
        wwr_range['minimum_percent_of_surface'] = 20.001
        wwr_range['maximum_percent_of_surface'] = 30
      elsif wwr <= 40
        wwr_range['minimum_percent_of_surface'] = 30.001
        wwr_range['maximum_percent_of_surface'] = 40
      else
        wwr_range['minimum_percent_of_surface'] = 40.001
        wwr_range['maximum_percent_of_surface'] = 100.0
      end
    end
    return wwr_range
  end
end
