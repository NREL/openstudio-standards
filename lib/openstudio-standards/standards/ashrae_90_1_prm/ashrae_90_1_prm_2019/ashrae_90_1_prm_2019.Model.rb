class ASHRAE901PRM2019 < ASHRAE901PRM
  # @!group Model

  # Determine if there is a need for a proposed model sizing run.
  # A typical application of such sizing run is to determine space
  # conditioning type.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  #
  # @return [Boolean] Returns true if a sizing run is required
  def model_create_prm_baseline_building_requires_proposed_model_sizing_run(model)
    return true
  end

  # Determines the area of the building above which point
  # the non-dominant area type gets it's own HVAC system type.
  # @return [Double] the minimum area (m^2)
  def model_prm_baseline_system_group_minimum_area(model, custom)
    exception_min_area_ft2 = 20_000
    # Customization - Xcel EDA Program Manual 2014
    # 3.2.1 Mechanical System Selection ii
    if custom == 'Xcel Energy CO EDA'
      exception_min_area_ft2 = 5000
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Customization; per Xcel EDA Program Manual 2014 3.2.1 Mechanical System Selection ii, minimum area for non-predominant conditions reduced to #{exception_min_area_ft2} ft2.")
    end
    exception_min_area_m2 = OpenStudio.convert(exception_min_area_ft2, 'ft^2', 'm^2').get
    return exception_min_area_m2
  end

  # Determines which system number is used
  # for the baseline system.
  # @return [String] the system number: 1_or_2, 3_or_4,
  # 5_or_6, 7_or_8, 9_or_10
  def model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    sys_num = nil

    # Customization - Xcel EDA Program Manual 2014
    # Table 3.2.2 Baseline HVAC System Types
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 lookup for HVAC system types shall be used.')

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
          # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
          # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        # Should only be hit by Xcel EDA
        sys_num = '3_or_4'
      end

    else

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
        # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
        # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        sys_num = '3_or_4'
      end

    end

    return sys_num
  end

  # Change the fuel type based on climate zone, depending on the standard.
  # For 90.1-2013, fuel type is based on climate zone, not the proposed model.
  # @return [String] the revised fuel type
  def model_prm_baseline_system_change_fuel_type(model, fuel_type, climate_zone, custom = nil)
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 rules for heating fuel type (based on proposed model) rules apply.')
      return fuel_type
    end

    # For 90.1-2013 the fuel type is determined based on climate zone.
    # Don't change the fuel if it purchased heating or cooling.
    if fuel_type == 'electric' || fuel_type == 'fossil'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
           'ASHRAE 169-2006-2A',
           'ASHRAE 169-2006-3A',
           'ASHRAE 169-2013-1A',
           'ASHRAE 169-2013-2A',
           'ASHRAE 169-2013-3A'
        fuel_type = 'electric'
      else
        fuel_type = 'fossil'
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Heating fuel is #{fuel_type} for 90.1-2013, climate zone #{climate_zone}.  This is independent of the heating fuel type in the proposed building, per G3.1.1-3.  This is different than previous versions of 90.1.")
    end

    return fuel_type
  end

  # Determines the fan type used by VAV_Reheat and VAV_PFP_Boxes systems.
  # Variable speed fan for 90.1-2013
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_baseline_system_vav_fan_type(model)
    fan_type = 'Variable Speed Fan'
    return fan_type
  end

  # Determines the skylight to roof ratio limit for a given standard
  # 3% for 90.1-PRM-2019
  # @return [Double] the skylight to roof ratio, as a percent: 5.0 = 5%
  def model_prm_skylight_to_roof_ratio_limit(model)
    srr_lim = 3.0
    return srr_lim
  end

  # Determine the surface range of a baseline model.
  # The method calculates the window to wall ratio (assuming all spaces are conditioned)
  # and select the range based on the calculated window to wall ratio
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param wwr_parameter [Hash] parameters to choose min and max percent of surfaces,
  #            could be different set in different standard
  def model_get_percent_of_surface_range(model, wwr_parameter)
    wwr_range = { 'minimum_percent_of_surface' => nil, 'maximum_percent_of_surface' => nil }
    intended_surface_type = wwr_parameter['intended_surface_type']
    if intended_surface_type == 'ExteriorWindow' || intended_surface_type == 'GlassDoor'
      if wwr_parameter.key?('wwr_building_type')
        wwr_building_type = wwr_parameter['wwr_building_type']
        wwr_info = wwr_parameter['wwr_info']
        if wwr_info[wwr_building_type] <= 10
          wwr_range['minimum_percent_of_surface'] = 0
          wwr_range['maximum_percent_of_surface'] = 10
        elsif wwr_info[wwr_building_type] <= 20
          wwr_range['minimum_percent_of_surface'] = 10.1
          wwr_range['maximum_percent_of_surface'] = 20
        elsif wwr_info[wwr_building_type] <= 30
          wwr_range['minimum_percent_of_surface'] = 20.1
          wwr_range['maximum_percent_of_surface'] = 30
        elsif wwr_info[wwr_building_type] <= 40
          wwr_range['minimum_percent_of_surface'] = 30.1
          wwr_range['maximum_percent_of_surface'] = 40
        else
          wwr_range['minimum_percent_of_surface'] = nil
          wwr_range['maximum_percent_of_surface'] = nil
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No wwr_building_type found for ExteriorWindow or GlassDoor')
      end
    end
    return wwr_range
  end
end
