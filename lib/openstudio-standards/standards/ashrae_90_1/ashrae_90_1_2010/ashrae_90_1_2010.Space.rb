class ASHRAE9012010 < ASHRAE901
  # @!group Space

  # Determines the method used to extend the daylighted area horizontally
  # next to a window.  If the method is 'fixed', 2 ft is added to the
  # width of each window.  If the method is 'proportional', a distance
  # equal to half of the head height of the window is added.  If the method is 'none',
  # no additional width is added.
  #
  # @return [String] returns 'fixed' or 'proportional'
  def space_daylighted_area_window_width(space)
    method = 'fixed'
    return method
  end

  # Determine if the space requires daylighting controls for
  # toplighting, primary sidelighting, and secondary sidelighting.
  # Defaults to false for all types.
  #
  # @param space [OpenStudio::Model::Space] the space in question
  # @param areas [Hash] a hash of daylighted areas
  # @return [Array<Bool>] req_top_ctrl, req_pri_ctrl, req_sec_ctrl
  def space_daylighting_control_required?(space, areas)
    req_top_ctrl = true
    req_pri_ctrl = true
    req_sec_ctrl = false

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "primary_sidelighted_area = #{areas['primary_sidelighted_area']}")

    # Sidelighting
    # Check if the primary sidelit area < 250 ft2
    if areas['primary_sidelighted_area'] == 0.0
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, primary sidelighting control not required because primary sidelighted area = 0ft2 per 9.4.1.4.")
      req_pri_ctrl = false
    elsif areas['primary_sidelighted_area'] < OpenStudio.convert(250, 'ft^2', 'm^2').get
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, primary sidelighting control not required because primary sidelighted area less than 250ft2 per 9.4.1.4.")
      req_pri_ctrl = false
    else
      # Check effective sidelighted aperture
      sidelighted_effective_aperture = space_sidelighting_effective_aperture(space, areas['primary_sidelighted_area'])
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "sidelighted_effective_aperture_pri = #{sidelighted_effective_aperture}")
      if sidelighted_effective_aperture < 0.1 and @instvarbuilding_type.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, primary sidelighting control not required because sidelighted effective aperture less than 0.1 per 9.4.1.4 Exception b.")
        req_pri_ctrl = false
      end
    end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "toplighted_area = #{areas['toplighted_area']}")

    # Toplighting
    # Check if the toplit area < 900 ft2
    if areas['toplighted_area'] == 0.0
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, toplighting control not required because toplighted area = 0ft2 per 9.4.1.5.")
      req_top_ctrl = false
    elsif areas['toplighted_area'] < OpenStudio.convert(900, 'ft^2', 'm^2').get
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, toplighting control not required because toplighted area less than 900ft2 per 9.4.1.5.")
      req_top_ctrl = false
    else
      # Check effective sidelighted aperture
      sidelighted_effective_aperture = space_skylight_effective_aperture(space, areas['toplighted_area'])
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "sidelighted_effective_aperture_top = #{sidelighted_effective_aperture}")
      if sidelighted_effective_aperture < 0.006
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, toplighting control not required because skylight effective aperture less than 0.006 per 9.4.1.5 Exception b.")
        req_top_ctrl = false
      end
    end

    # Exceptions
    if space.spaceType.is_initialized
      case space.spaceType.get.standardsSpaceType.to_s
      # Retail spaces exception (c) to Section 9.4.1.4
      # req_sec_ctrl set to true to create a second reference point
      when 'Core_Retail'
        req_pri_ctrl = false
        req_sec_ctrl = true
      when 'Entry', 'Front_Retail', 'Point_of_Sale'
        req_pri_ctrl = false
        req_sec_ctrl = false
      # Strip mall
      when 'Strip mall - type 1', 'Strip mall - type 2', 'Strip mall - type 3'
        req_pri_ctrl = false
        req_sec_ctrl = false
      # Residential apartments
      when 'Apartment', 'Apartment_topfloor_NS', 'Apartment_topfloor_WE'
        req_top_ctrl = false
        req_pri_ctrl = false
        req_sec_ctrl = false
      end
    end

    return [req_top_ctrl, req_pri_ctrl, req_sec_ctrl]
  end

  # Determine the fraction controlled by each sensor and which
  # window each sensor should go near.
  #
  # @param space [OpenStudio::Model::Space] the space with the daylighting
  # @param sorted_windows [Hash] a hash of windows, sorted by priority
  # @param sorted_skylights [Hash] a hash of skylights, sorted by priority
  # @param req_top_ctrl [Bool] if toplighting controls are required
  # @param req_pri_ctrl [Bool] if primary sidelighting controls are required
  # @param req_sec_ctrl [Bool] if secondary sidelighting controls are required
  def space_daylighting_fractions_and_windows(space,
                                              areas,
                                              sorted_windows,
                                              sorted_skylights,
                                              req_top_ctrl,
                                              req_pri_ctrl,
                                              req_sec_ctrl)
    sensor_1_frac = 0.0
    sensor_2_frac = 0.0
    sensor_1_window = nil
    sensor_2_window = nil

    # Get the area of the space
    space_area_m2 = space.floorArea

    if req_top_ctrl && req_pri_ctrl
      # Sensor 1 controls toplighted area
      sensor_1_frac = areas['toplighted_area'] / space_area_m2
      sensor_1_window = sorted_skylights[0]
      # Sensor 2 controls primary area
      sensor_2_frac = areas['primary_sidelighted_area'] / space_area_m2
      sensor_2_window = sorted_windows[0]
    elsif req_top_ctrl && !req_pri_ctrl
      # Sensor 1 controls toplighted area
      sensor_1_frac = areas['toplighted_area'] / space_area_m2
      sensor_1_window = sorted_skylights[0]
    elsif req_top_ctrl && !req_pri_ctrl && req_sec_ctrl
      # Sensor 1 controls toplighted area
      sensor_1_frac = areas['toplighted_area'] / space_area_m2
      sensor_1_window = sorted_skylights[0]
      # Sensor 2 controls secondary area
      sensor_2_frac = (areas['secondary_sidelighted_area'] / space_area_m2)
      # sorted_skylights[0] assigned to sensor_2_window so a second reference point is added for top daylighting
      sensor_2_window = sorted_skylights[0]
    elsif !req_top_ctrl && req_pri_ctrl
      if sorted_windows.size == 1
        # Sensor 1 controls the whole primary area
        sensor_1_frac = areas['primary_sidelighted_area'] / space_area_m2
        sensor_1_window = sorted_windows[0]
      else
        # Sensor 1 controls half the primary area
        sensor_1_frac = (areas['primary_sidelighted_area'] / space_area_m2) / 2
        sensor_1_window = sorted_windows[0]
        # Sensor 2 controls the other half of primary area
        sensor_2_frac = (areas['primary_sidelighted_area'] / space_area_m2) / 2
        sensor_2_window = sorted_windows[1]
      end
    end

    return [sensor_1_frac, sensor_2_frac, sensor_1_window, sensor_2_window]
  end

  # Determine the base infiltration rate at 75 PA.
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2
  # defaults to no infiltration.
  def space_infiltration_rate_75_pa(space)
    basic_infil_rate_cfm_per_ft2 = 1.0
    return basic_infil_rate_cfm_per_ft2
  end
end
