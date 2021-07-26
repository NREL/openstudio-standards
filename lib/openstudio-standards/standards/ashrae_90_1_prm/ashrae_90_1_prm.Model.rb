class ASHRAE901PRM < Standard
  # @!group Model

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

  # This method creates customized infiltration objects for each
  # space and removes the SpaceType-level infiltration objects.
  #
  # @return [Bool] true if successful, false if not
  def model_apply_infiltration_standard(model, climate_zone)
    # Model shouldn't use SpaceInfiltrationEffectiveLeakageArea
    # Excerpt from the EnergyPlus Input/Output reference manual:
    #     "This model is based on work by Sherman and Grimsrud (1980)
    #     and is appropriate for smaller, residential-type buildings."
    # Return an error if the model does use this object
    ela = 0
    model.getSpaceInfiltrationEffectiveLeakageAreas.sort.each do |eff_la|
      ela += 1
    end
    if ela > 0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'The current model cannot include SpaceInfiltrationEffectiveLeakageArea. These objects cannot be used to model infiltration according to the 90.1-PRM rules.')
    end

    # Get the space building envelope area
    # According to the 90.1 definition, building envelope include:
    # - "the elements of a building that separate conditioned spaces from the exterior"
    # - "the elements of a building that separate conditioned space from unconditioned
    #    space or that enclose semiheated spaces through which thermal energy may be
    #    transferred to or from the exterior, to or from unconditioned spaces or to or
    #    from conditioned spaces."
    building_envelope_area_m2 = 0
    model.getSpaces.sort.each do |space|
      building_envelope_area_m2 += space_envelope_area(space, climate_zone)
    end
    if building_envelope_area_m2 == 0.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'Calculated building envelope area is 0 m2, no infiltration will be added.')
      return 0.0
    end

    # Calculate current model air leakage rate @ 75 Pa and report it
    curr_tot_infil_m3_per_s_per_envelope_area = model_current_building_envelope_infiltration_at_75pa(model, building_envelope_area_m2)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The proposed model I_75Pa is estimated to be #{curr_tot_infil_m3_per_s_per_envelope_area} m3/s per m2 of total building envelope.")

    # Calculate building adjusted building envelope
    # air infiltration following the 90.1 PRM rules
    tot_infil_m3_per_s = model_adjusted_building_envelope_infiltration(model, building_envelope_area_m2)

    # Find infiltration method used in the model, if any.
    #
    # If multiple methods are used, use per above grade wall
    # area (i.e. exterior wall area), if air/changes per hour
    # or exterior surface area is used, use Flow/ExteriorWallArea
    infil_method = model_get_infiltration_method(model)
    infil_method = 'Flow/ExteriorWallArea' if infil_method != 'Flow/Area' || infil_method != 'Flow/ExteriorWallArea'
    infil_coefficients = model_get_infiltration_coefficients(model)

    # Set the infiltration rate at each space
    model.getSpaces.sort.each do |space|
      space_apply_infiltration_rate(space, tot_infil_m3_per_s, infil_method, infil_coefficients)
    end

    # Remove infiltration rates set at the space type
    model.getSpaceTypes.sort.each do |space_type|
      space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
    end

    return true
  end

  # This method retrieves the type of infiltration input
  # used in the model. If input is inconsitent, returns
  # Flow/Area
  #
  # @return [String] infiltration input type
  def model_get_infiltration_method(model)
    infil_method = nil
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space.spaceInfiltrationDesignFlowRates[0]
        old_infil_method = old_infil.designFlowRateCalculationMethod.to_s
        # Return flow per space floor area if method is inconsisten in proposed model
        return 'Flow/Area' if infil_method != old_infil_method && !infil_method.nil?

        infil_method = old_infil_method
      end

      # Infiltration at the space type level
      if infil_method.nil? && space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
          old_infil_method = old_infil.designFlowRateCalculationMethod.to_s
          # Return flow per space floor area if method is inconsisten in proposed model
          return 'Flow/Area' if infil_method != old_infil_method && !infil_method.nil?

          infil_method = old_infil_method
        end
      end
    end

    return infil_method
  end

  # This method retrieves the infiltration coefficients
  # used in the model. If input is inconsitent, returns
  # [0, 0, 0.224, 0] as per PRM user manual
  #
  # @return [String] infiltration input type
  def model_get_infiltration_coefficients(model)
    cst = nil
    temp = nil
    vel = nil
    vel_2 = nil
    infil_coeffs = [cst, temp, vel, vel_2]
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space.spaceInfiltrationDesignFlowRates[0]
        cst = old_infil.constantTermCoefficient
        temp = old_infil.temperatureTermCoefficient
        vel = old_infil.velocityTermCoefficient
        vel_2 = old_infil.velocitySquaredTermCoefficient
        old_infil_coeffs = [cst, temp, vel, vel_2] if !(cst.nil? && temp.nil? && vel.nil? && vel_2.nil?)
        # Return flow per space floor area if method is inconsisten in proposed model
        return [0.0, 0.0, 0.224, 0.0] if infil_coeffs != old_infil_coeffs && !(infil_coeffs[0].nil? &&
                                                                                    infil_coeffs[1].nil? &&
                                                                                    infil_coeffs[2].nil? &&
                                                                                    infil_coeffs[3].nil?)

        infil_coeffs = old_infil_coeffs
      end

      # Infiltration at the space type level
      if infil_coeffs == [nil, nil, nil, nil] && space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
          cst = old_infil.constantTermCoefficient
          temp = old_infil.temperatureTermCoefficient
          vel = old_infil.velocityTermCoefficient
          vel_2 = old_infil.velocitySquaredTermCoefficient
          old_infil_coeffs = [cst, temp, vel, vel_2] if !(cst.nil? && temp.nil? && vel.nil? && vel_2.nil?)
          # Return flow per space floor area if method is inconsisten in proposed model
          return [0.0, 0.0, 0.224, 0.0] unless infil_coeffs != old_infil_coeffs && !(infil_coeffs[0].nil? &&
                                                                                      infil_coeffs[1].nil? &&
                                                                                      infil_coeffs[2].nil? &&
                                                                                      infil_coeffs[3].nil?)

          infil_coeffs = old_infil_coeffs
        end
      end
    end
    return infil_coeffs
  end

  # This methods calculate the current model air leakage rate @ 75 Pa.
  # It assumes that the model follows the PRM methods, see G3.1.1.4
  # in 90.1-2019 for reference.
  #
  # @param [OpenStudio::Model::Model] OpenStudio Model object
  # @param [Double] Building envelope area as per 90.1 in m^2
  #
  # @return [Float] building model air leakage rate
  def model_current_building_envelope_infiltration_at_75pa(model, building_envelope_area_m2)
    bldg_air_leakage_rate = 0
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        infil_obj = space.spaceInfiltrationDesignFlowRates[0]
        unless infil_obj.designFlowRate.is_initialized
          if infil_obj.flowperSpaceFloorArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperSpaceFloorArea.get * space.floorArea
          elsif infil_obj.flowperExteriorSurfaceArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperExteriorSurfaceArea.get * space.exteriorArea
          elsif infil_obj.flowperExteriorWallArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperExteriorWallArea.get * space.exteriorWallArea
          elsif infil_obj.airChangesperHour.is_initialized
            bldg_air_leakage_rate += infil_obj.airChangesperHour.get * space.volume / 3600
          end
        end
      end

      # Infiltration at the space type level
      if space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          infil_obj = space_type.spaceInfiltrationDesignFlowRates[0]
          unless infil_obj.designFlowRate.is_initialized
            if infil_obj.flowperSpaceFloorArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperSpaceFloorArea.get * space.floorArea
            elsif infil_obj.flowperExteriorSurfaceArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperExteriorSurfaceArea.get * space.exteriorArea
            elsif infil_obj.flowperExteriorWallArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperExteriorWallArea.get * space.exteriorWallArea
            elsif infil_obj.airChangesperHour.is_initialized
              bldg_air_leakage_rate += infil_obj.airChangesperHour.get * space.volume / 3600
            end
          end
        end
      end
    end
    # adjust_infiltration_to_prototype_building_conditions(1) corresponds
    # to the 0.112 shown in G3.1.1.4
    curr_tot_infil_m3_per_s_per_envelope_area = bldg_air_leakage_rate / adjust_infiltration_to_prototype_building_conditions(1) / building_envelope_area_m2
    return curr_tot_infil_m3_per_s_per_envelope_area
  end

  # This method calculates the building envelope infiltration,
  # this approach uses the 90.1 PRM rules
  #
  # @return [Float] building envelope infiltration
  def model_adjusted_building_envelope_infiltration(model, building_envelope_area_m2)
    # Determine the total building baseline infiltration rate in cfm per ft2 of the building envelope at 75 Pa
    basic_infil_rate_cfm_per_ft2 = space_infiltration_rate_75_pa

    # Do nothing if no infiltration
    return 0.0 if basic_infil_rate_cfm_per_ft2.zero?

    # Conversion factor
    conv_fact = OpenStudio.convert(1, 'm^3/s', 'ft^3/min').to_f / OpenStudio.convert(1, 'm^2', 'ft^2').to_f

    # Adjust the infiltration rate to the average pressure for the prototype buildings.
    # adj_infil_rate_cfm_per_ft2 = 0.112 * basic_infil_rate_cfm_per_ft2
    adj_infil_rate_cfm_per_ft2 = adjust_infiltration_to_prototype_building_conditions(basic_infil_rate_cfm_per_ft2)
    adj_infil_rate_m3_per_s_per_m2 = adj_infil_rate_cfm_per_ft2 / conv_fact

    # Calculate the total infiltration
    tot_infil_m3_per_s = adj_infil_rate_m3_per_s_per_m2 * building_envelope_area_m2

    return tot_infil_m3_per_s
  end

  # Reduces the SRR to the values specified by the PRM. SRR reduction will be done by shrinking vertices toward the centroid.
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  def model_apply_prm_baseline_skylight_to_roof_ratio(model)
    # Loop through all spaces in the model, and
    # per the 90.1-2019 PRM User Manual, only
    # account for exterior roofs for enclosed
    # spaces. Include space multipliers.
    roof_m2 = 0.001 # Avoids divide by zero errors later
    sky_m2 = 0
    total_roof_m2 = 0.001
    total_subsurface_m2 = 0
    model.getSpaces.sort.each do |space|
      next if space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      roof_area_m2 = 0
      sky_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # This roof's gross area (including skylight area)
        roof_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          sky_area_m2 += ss.netArea * space.multiplier
        end
      end

      total_roof_m2 += roof_area_m2
      total_subsurface_m2 += sky_area_m2
    end

    # Calculate the SRR of each category
    srr = ((total_subsurface_m2 / total_roof_m2) * 100.0).round(1)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The skylight to roof ratios (SRRs) is: : #{srr.round}%.")

    # SRR limit
    srr_lim = model_prm_skylight_to_roof_ratio_limit(model)

    # Check against SRR limit
    red = srr > srr_lim

    # Stop here unless skylights need reducing
    return true unless red

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all skylights equally down to the limit of #{srr_lim.round}%.")

    # Determine the factors by which to reduce the skylight area
    mult = srr_lim / srr

    # Reduce the skylight area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      next if space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          # Reduce the size of the skylight
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end

    return true
  end

  #
  # Add design day schedule objects for space loads, for PRM 2019 baseline models
  # @author Xuechen (Jerry) Lei, PNNL
  # @param model [OpenStudio::model::Model] OpenStudio model object
  #
  def model_apply_prm_baseline_sizing_schedule(model)
    space_loads = model.getSpaceLoads
    loads = []
    space_loads.sort.each do |space_load|
      load_type = space_load.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      casting_method_name = "to_#{load_type}"
      if space_load.respond_to?(casting_method_name)
        casted_load = space_load.public_send(casting_method_name).get
        loads << casted_load
      else
        p 'Need Debug, casting method not found @JXL'
      end
    end

    load_schedule_name_hash = {
      'People' => 'numberofPeopleSchedule',
      'Lights' => 'schedule',
      'ElectricEquipment' => 'schedule',
      'GasEquipment' => 'schedule',
      'SpaceInfiltration_DesignFlowRate' => 'schedule'
    }

    loads.each do |load|
      load_type = load.iddObjectType.valueName.sub('OS_', '').strip
      load_schedule_name = load_schedule_name_hash[load_type]
      next unless !load_schedule_name.nil?

      # check if the load is in a dwelling space
      if load.spaceType.is_initialized
        space_type = load.spaceType.get
      elsif load.space.is_initialized && load.space.get.spaceType.is_initialized
        space_type = load.space.get.spaceType.get
      else
        space_type = nil
        puts "No hosting space/spacetype found for load: #{load.name}"
      end
      if !space_type.nil? && /apartment/i =~ space_type.standardsSpaceType.to_s
        load_in_dwelling = true
      else
        load_in_dwelling = false
      end

      load_schedule = load.public_send(load_schedule_name).get
      schedule_type = load_schedule.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      load_schedule = load_schedule.public_send("to_#{schedule_type}").get

      case schedule_type
      when 'ScheduleRuleset'
        load_schmax = get_8760_values_from_schedule(model, load_schedule).max
        load_schmin = get_8760_values_from_schedule(model, load_schedule).min
        load_schmode = get_weekday_values_from_8760(model,
                                                    Array(get_8760_values_from_schedule(model, load_schedule)),
                                                    value_includes_holiday = true).mode[0]

        # AppendixG-2019 G3.1.2.2.1
        if load_type == 'SpaceInfiltration_DesignFlowRate'
          summer_value = load_schmax
          winter_value = load_schmax
        else
          summer_value = load_schmax
          winter_value = load_schmin
        end

        # AppendixG-2019 Exception to G3.1.2.2.1
        if load_in_dwelling
          summer_value = load_schmode
        end

        # set cooling design day schedule
        summer_dd_schedule = OpenStudio::Model::ScheduleDay.new(model)
        summer_dd_schedule.setName("#{load.name} Summer Design Day")
        summer_dd_schedule.addValue(OpenStudio::Time.new(1.0), summer_value)
        load_schedule.setSummerDesignDaySchedule(summer_dd_schedule)

        # set heating design day schedule
        winter_dd_schedule = OpenStudio::Model::ScheduleDay.new(model)
        winter_dd_schedule.setName("#{load.name} Winter Design Day")
        winter_dd_schedule.addValue(OpenStudio::Time.new(1.0), winter_value)
        load_schedule.setWinterDesignDaySchedule(winter_dd_schedule)

      when 'ScheduleConstant'
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space load #{load.name} has schedule type of ScheduleConstant. Nothing to be done for ScheduleConstant")
        next
      end
    end
  end

  # Identifies non mechanically cooled ("nmc") systems, if applicable
  #
  # TODO: Zone-level evaporative cooler is not currently supported by
  #       by OpenStudio, will need to be added to the method when
  #       supported.
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @return zone_nmc_sys_type [Hash] Zone to nmc system type mapping
  def model_identify_non_mechanically_cooled_systems(model)
    # Iterate through zones to find out if they are served by nmc systems
    model.getThermalZones.sort.each do |zone|
      # Check if airloop has economizer and either:
      # - No cooling coil and/or,
      # - An evaporative cooling coil
      air_loop = zone.airLoopHVAC

      unless air_loop.empty?
        # Iterate through all the airloops assigned to a zone
        zone.airLoopHVACs.each do |airloop|
          air_loop = air_loop.get
          if (!air_loop_hvac_include_cooling_coil?(air_loop) &&
            air_loop_hvac_include_evaporative_cooler?(air_loop)) ||
             (!air_loop_hvac_include_cooling_coil?(air_loop) &&
               air_loop_hvac_include_economizer?(air_loop))
            air_loop.additionalProperties.setFeature('non_mechanically_cooled', true)
            air_loop.thermalZones.each do |thermal_zone|
              thermal_zone.additionalProperties.setFeature('non_mechanically_cooled', true)
            end
          end
        end
      end
    end
  end

  # Specify supply air temperature setpoint for unit heaters based on 90.1 Appendix G G3.1.2.8.2
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone Object
  #
  # @return [Double] for zone with unit heaters, return design supply temperature; otherwise, return nil
  def thermal_zone_prm_unitheater_design_supply_temperature(thermal_zone)
    thermal_zone.equipment.each do |eqt|
      if eqt.to_ZoneHVACUnitHeater.is_initialized
        return OpenStudio.convert(105, 'F', 'C').get
      end
    end
    return nil
  end

  # Specify supply to room delta for laboratory spaces based on 90.1 Appendix G Exception to G3.1.2.8.1
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone Object
  #
  # @return [Double] for zone with laboratory space, return 17; otherwise, return nil
  def thermal_zone_prm_lab_delta_t(thermal_zone)
    # For labs, add 17 delta-T; otherwise, add 20 delta-T
    thermal_zone.spaces.each do |space|
      space_std_type = space.spaceType.get.standardsSpaceType.get
      if space_std_type == 'laboratory'
        return 17
      end
    end
    return nil
  end

  # Provides baseline system allowable base BHP
  #
  # @param system_type [String] Baseline system type abbreviation
  # @return allowable_base_system_fan_bhp [Float] Allowable base baseline system fan BHP
  def allowable_base_system_brake_horsepower(system_type, non_mechanically_cooled_flag)
    allowable_base_system_fan_bhp = 0.0
    case system_type
    when 'PTAC', 'PTHP'
      allowable_base_system_fan_bhp = 0.0003
    when 'PSZ_HP', 'PSZ_AC' # 3, 4
      allowable_base_system_fan_bhp = 0.00094
    when
    'PVAV_Reheat', 'PVAV_PFP_Boxes', # 5, 6
      'VAV_Reheat', 'VAV_PFP_Boxes', # 7, 8
      'SZ_VAV' # 11
      allowable_base_system_fan_bhp = 0.0013
    when 'Gas_Furnace', 'Electric_Furnace' # 9, 10
      if non_mechanically_cooled_flag
        allowable_base_system_fan_bhp = 0.000054
      else
        allowable_base_system_fan_bhp = 0.0003
      end
    when
    'SZ_CAV' # 12, 13
      allowable_base_system_fan_bhp = 0.00094
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.AirLoopHVAC', "Air loop #{air_loop_hvac.name} is not associated with a baseline system.")
    end

    return allowable_base_system_fan_bhp
  end

  # Indicate if fan power breakdown (supply, return, and relief)
  # are needed
  #
  # @return [Boolean] true if necessary, false otherwise
  def model_get_fan_power_breakdown
    return true
  end
end
