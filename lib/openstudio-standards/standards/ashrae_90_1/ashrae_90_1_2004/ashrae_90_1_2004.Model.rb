class ASHRAE9012004 < ASHRAE901
  # @!group Model
  #
  # Determine the surface range of a baseline model.
  # The method calculates the window to wall ratio (assuming all spaces are conditioned)
  # and select the range based on the calculated window to wall ratio
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param wwr_parameter [Hash] parameters to choose min and max percent of surfaces,
  #          could be different set in different standard
  def model_get_percent_of_surface_range(model, wwr_parameter)
    wwr_range = { 'minimum_percent_of_surface' => nil, 'maximum_percent_of_surface' => nil }
    intended_surface_type = wwr_parameter['intended_surface_type']
    # Do not process surfaces other than exterior windows and glass door for 2004 standard
    if intended_surface_type == 'ExteriorWindow' || intended_surface_type == 'GlassDoor'
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
