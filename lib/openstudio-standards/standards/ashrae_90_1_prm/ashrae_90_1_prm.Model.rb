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

  # Indicate if fan power breakdown (supply, return, and relief)
  # are needed
  #
  # @return [Boolean] true if necessary, false otherwise
  def model_get_fan_power_breakdown
    return true
  end

  # Template method for adding a setpoint manager for a coil control logic to a heating coil.
  # ASHRAE 90.1-2019 Appendix G.
  #
  # @param model [OpenStudio::Model::Model] Openstudio model
  # @param thermalZones Array([OpenStudio::Model::ThermalZone]) thermal zone array
  # @param coil Heating Coils
  # @return [Boolean] true
  def model_set_central_preheat_coil_spm(model, thermalZones, coil)
    # search for the highest zone setpoint temperature
    max_heat_setpoint = 0.0
    coil_name = coil.name.get.to_s
    thermalZones.each do |zone|
      tstat = zone.thermostatSetpointDualSetpoint
      if tstat.is_initialized
        tstat = tstat.get
        setpoint_sch = tstat.heatingSetpointTemperatureSchedule
        setpoint_min_max = search_min_max_value_from_design_day_schedule(setpoint_sch, 'heating')
        setpoint_c = setpoint_min_max['max']
        if setpoint_c > max_heat_setpoint
          max_heat_setpoint = setpoint_c
        end
      end
    end
    # in this situation, we hard set the temperature to be 22 F
    # (ASHRAE 90.1 Room heating stepoint temperature is 72 F)
    max_heat_setpoint = 22.2 if max_heat_setpoint == 0.0

    max_heat_setpoint_f = OpenStudio.convert(max_heat_setpoint, 'C', 'F').get
    preheat_setpoint_f = max_heat_setpoint_f - 20
    preheat_setpoint_c = OpenStudio.convert(preheat_setpoint_f, 'F', 'C').get

    # create a new constant schedule and this method will add schedule limit type
    preheat_coil_sch = model_add_constant_schedule_ruleset(model,
                                                           preheat_setpoint_c,
                                                           name = "#{coil_name} Setpoint Temp - #{preheat_setpoint_f.round}F")
    preheat_coil_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, preheat_coil_sch)
    preheat_coil_manager.setName("#{coil_name} Preheat Coil Setpoint Manager")

    if coil.to_CoilHeatingWater.is_initialized
      preheat_coil_manager.addToNode(coil.airOutletModelObject.get.to_Node.get)
    elsif coil.to_CoilHeatingElectric.is_initialized
      preheat_coil_manager.addToNode(coil.outletModelObject.get.to_Node.get)
    elsif coil.to_CoilHeatingGas.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.models.CoilHeatingGas', 'Preheat coils in baseline system shall only be electric or hydronic. Current coil type: Natural Gas')
      preheat_coil_manager.addToNode(coil.airOutletModelObject.get.to_Node.get)
    end

    return true
  end

  # A template method that handles the loading of user input data from multiple sources
  # include data source from:
  # 1. user data csv files
  # 2. data from measure and OpenStudio interface
  # @param [Openstudio:model:Model] model
  # @param [String] climate_zone
  # @param [String] default_hvac_building_type
  # @param [String] default_wwr_building_type
  # @param [String] default_swh_building_type
  # @param [Hash] bldg_type_hvac_zone_hash A hash maps building type for hvac to a list of thermal zones
  # @return True
  def handle_user_input_data(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash)
    # load the multiple building area types from user data
    handle_multi_building_area_types(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash)
    # load user data from proposed model
    handle_airloop_user_input_data(model)
    # load air loop DOAS user data from the proposed model
    handle_airloop_doas_user_input_data(model)
    # load zone HVAC user data from proposed model
    handle_zone_hvac_user_input_data(model)
  end

  # A function to load airloop data from userdata csv files
  # @param [OpenStudio::Model::Model] OpenStudio model object
  def handle_airloop_user_input_data(model)
    # ============================Process airloop info ============================================
    user_airloops = @standards_data.key?('userdata_airloop_hvac') ? @standards_data['userdata_airloop_hvac'] : nil
    model.getAirLoopHVACs.each do |air_loop|
      air_loop_name = air_loop.name.get
      if user_airloops && user_airloops.length > 1
        user_airloops.each do |user_airloop|
          if air_loop_name == user_airloop['name']
            # gas phase air cleaning is system base - add proposed hvac system name to zones
            if user_airloop.key?('economizer_exception_for_gas_phase_air_cleaning') && !user_airloop['economizer_exception_for_gas_phase_air_cleaning'].nil?
              if user_airloop['economizer_exception_for_gas_phase_air_cleaning'].downcase == 'yes'
                air_loop.thermalZones.each do |thermal_zone|
                  thermal_zone.additionalProperties.setFeature('economizer_exception_for_gas_phase_air_cleaning', air_loop_name)
                end
              end
            end
            # Open refrigerated cases is zone based - add yes or no to zones
            if user_airloop.key?('economizer_exception_for_open_refrigerated_cases') && !user_airloop['economizer_exception_for_open_refrigerated_cases'].nil?
              if user_airloop['economizer_exception_for_open_refrigerated_cases'].downcase == 'yes'
                air_loop.thermalZones.each do |thermal_zone|
                  thermal_zone.additionalProperties.setFeature('economizer_exception_for_open_refrigerated_cases', 'yes')
                end
              end
            end
            # Fan power credits
            user_airloop.keys.each do |info_key|
              if info_key.include?('fan_power_credit')
                if !user_airloop[info_key].to_s.empty?
                  if info_key.include?('has_')
                    if user_airloop[info_key].downcase == 'yes'
                      air_loop.thermalZones.each do |thermal_zone|
                        if thermal_zone.additionalProperties.hasFeature(info_key)
                          current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                          thermal_zone.additionalProperties.setFeature(info_key, current_value + 1.0)
                        else
                          thermal_zone.additionalProperties.setFeature(info_key, 1.0)
                        end
                      end
                    end
                  else
                    air_loop.thermalZones.each do |thermal_zones|
                      if thermal_zone.additionalProperties.hasFeature(info_key)
                        current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                        thermal_zone.additionalProperties.setFeature(info_key, current_value + user_airloop[info_key])
                      else
                        thermal_zone.additionalProperties.setFeature(info_key, user_airloop[info_key])
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # A function to load airloop DOAS data from userdata csv files
  # @param [OpenStudio::Model::Model] OpenStudio model object
  def handle_airloop_doas_user_input_data(model)
    # Get user data
    user_airloop_doass = @standards_data.key?('userdata_airloop_hvac_doas') ? @standards_data['userdata_airloop_hvac_doas'] : nil

    # Parse user data
    if user_airloop_doass && user_airloop_doass.length >= 1
      user_airloop_doass.each do |user_airloop_doas|
        # Get AirLoopHVACDedicatedOutdoorAirSystem
        air_loop_doas = model.getAirLoopHVACDedicatedOutdoorAirSystemByName(user_airloop_doas['name'])
        if !air_loop_doas.is_initialized
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_prm.Model', "The AirLoopHVACDedicatedOutdoorAirSystem named #{user_airloop_doass['name']} mentioned in the userdata_airloop_hvac_doas was not found in the model, user specified data associated with it will be ignored.")
          next
        else
          air_loop_doas = air_loop_doas.get
        end

        # Parse fan power credits data
        user_airloop_doas.keys.each do |info_key|
          if info_key.include?('fan_power_credit')
            if !user_airloop_doas[info_key].to_s.empty?
              # Case 1: Yes/no
              if info_key.include?('has_')
                if user_airloop_doas[info_key].downcase == 'yes'
                  air_loop_doas.airLoops.each do |air_loop|
                    air_loop.thermalZones.each do |thermal_zone|
                      if thermal_zone.additionalProperties.hasFeature(info_key)
                        current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                        thermal_zone.additionalProperties.setFeature(info_key, current_value + 1.0)
                      else
                        thermal_zone.additionalProperties.setFeature(info_key, 1.0)
                      end
                    end
                  end
                end
              else
                # Case 2: user provided value
                air_loop_doas.airLoops.each do |air_loop|
                  air_loop.thermalZones.each do |thermal_zones|
                    if thermal_zone.additionalProperties.hasFeature(info_key)
                      current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                      thermal_zone.additionalProperties.setFeature(info_key, current_value + user_airloop_doas[info_key])
                    else
                      thermal_zone.additionalProperties.setFeature(info_key, user_airloop_doas[info_key])
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # Analyze HVAC, window-to-wall ratio and SWH building (area) types from user data inputs in the @standard_data library
  # This function returns True, but the values are stored in the multi-building_data argument.
  # The hierarchy for process the building types
  # 1. Highest: PRM rules - if rules applied against user inputs, the function will use the calculated value to reset the building type
  # 2. Second: User defined building type in the csv file.
  # 3. Third: User defined userdata_building.csv file. If an object (e.g. space, thermalzone) are not defined in their correspondent userdata csv file, use the building csv file
  # 4. Fourth: Dropdown list in the measure GUI. If none presented, use the data from the dropdown list.
  # NOTE! This function will add building types to OpenStudio objects as an additional features for hierarchy 1-3
  # The object additional feature is empty when the function determined it uses fourth hierarchy.
  #
  # @param [OpenStudio::Model::Model] model
  # @param [String] climate_zone
  # @param [String] default_hvac_building_type (Fourth Hierarchy hvac building type)
  # @param [String] default_wwr_building_type (Fourth Hierarchy wwr building type)
  # @param [String] default_swh_building_type (Fourth Hierarchy swh building type)
  # @param [Hash] bldg_type_zone_hash An empty hash that maps building type for hvac to a list of thermal zones
  # @return True
  def handle_multi_building_area_types(model, climate_zone, default_hvac_building_type, default_wwr_building_type, default_swh_building_type, bldg_type_hvac_zone_hash)
    # Construct the user_building hashmap
    user_buildings = @standards_data.key?('userdata_building') ? @standards_data['userdata_building'] : nil

    # Build up a hvac_building_type : thermal zone hash map
    # =============================HVAC user data process===========================================
    user_thermal_zones = @standards_data.key?('userdata_thermal_zone') ? @standards_data['userdata_thermal_zone'] : nil
    # First construct hvac building type -> thermal Zone hash and hvac building type -> floor area
    bldg_type_zone_hash = {}
    bldg_type_zone_area_hash = {}
    model.getThermalZones.each do |thermal_zone|
      # get climate zone to check the conditioning category
      thermal_zone_condition_category = thermal_zone_conditioning_category(thermal_zone, climate_zone)
      if thermal_zone_condition_category == 'Semiheated' || thermal_zone_condition_category == 'Unconditioned'
        next
      end

      # Check for Second hierarchy
      hvac_building_type = nil
      if user_thermal_zones && user_thermal_zones.length >= 1
        user_thermal_zone_index = user_thermal_zones.index { |user_thermal_zone| user_thermal_zone['name'] == thermal_zone.name.get }
        # make sure the thermal zone has assigned a building_type_for_hvac
        unless user_thermal_zone_index.nil? || user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac'].nil?
          # Only thermal zone in the user data and have building_type_for_hvac data will be assigned.
          hvac_building_type = user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac']
        end
      end
      # Second hierarchy does not apply, check Third hierarchy
      if hvac_building_type.nil? && user_buildings && user_buildings.length >= 1
        building_name = thermal_zone.model.building.get.name.get
        user_building_index = user_buildings.index { |user_building| user_building['name'] == building_name }
        unless user_building_index.nil? || user_buildings[user_building_index]['building_type_for_hvac'].nil?
          # Only thermal zone in the buildings user data and have building_type_for_hvac data will be assigned.
          hvac_building_type = user_buildings[user_building_index]['building_type_for_hvac']
        end
      end
      # Third hierarchy does not apply, apply Fourth hierarchy
      if hvac_building_type.nil?
        hvac_building_type = default_hvac_building_type
      end
      # Add data to the hash map
      unless bldg_type_zone_hash.key?(hvac_building_type)
        bldg_type_zone_hash[hvac_building_type] = []
      end
      unless bldg_type_zone_area_hash.key?(hvac_building_type)
        bldg_type_zone_area_hash[hvac_building_type] = 0.0
      end
      # calculate floor area for the thermal zone
      part_of_floor_area = false
      thermal_zone.spaces.sort.each do |space|
        next unless space.partofTotalFloorArea

        # a space in thermal zone is part of floor area.
        part_of_floor_area = true
        bldg_type_zone_area_hash[hvac_building_type] += space.floorArea * space.multiplier
      end
      if part_of_floor_area
        # Only add the thermal_zone if it is part of the floor area
        bldg_type_zone_hash[hvac_building_type].append(thermal_zone)
      end
    end
    # Handle an edge case that all zones in the model are unconditioned.
    unless bldg_type_zone_hash.empty?
      # Calculate the total floor area.
      # If the max tie, this algorithm will pick the first encountered hvac building type as the maximum.
      total_floor_area = 0.0
      hvac_bldg_type_with_max_floor = nil
      hvac_bldg_type_max_floor_area = 0.0
      bldg_type_zone_area_hash.each do |key, value|
        if value > hvac_bldg_type_max_floor_area
          hvac_bldg_type_with_max_floor = key
          hvac_bldg_type_max_floor_area = value
        end
        total_floor_area += value
      end

      # Reset the thermal zones by going through the hierarchy 1 logics
      bldg_type_hvac_zone_hash.clear
      # Add the thermal zones for the maximum floor (primary system)
      bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor] = bldg_type_zone_hash[hvac_bldg_type_with_max_floor]
      bldg_type_zone_hash.each do |bldg_type, bldg_type_zone|
        # loop the rest bldg_types
        unless bldg_type.eql? hvac_bldg_type_with_max_floor
          if OpenStudio.convert(total_floor_area, 'm^2', 'ft^2').get <= 40000
            # Building is smaller than 40k sqft, it could only have one hvac_building_type, reset all the thermal zones.
            bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor].push(*bldg_type_zone)
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The building floor area is less than 40,000 square foot. Thermal zones under hvac building type #{bldg_type} is reset to #{hvac_bldg_type_with_max_floor}")
          else
            if OpenStudio.convert(bldg_type_zone_area_hash[bldg_type], 'm^2', 'ft^2').get < 20000
              # in this case, all thermal zones shall be categorized as the primary hvac_building_type
              bldg_type_hvac_zone_hash[hvac_bldg_type_with_max_floor].push(*bldg_type_zone)
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The floor area in hvac building type #{bldg_type} is less than 20,000 square foot. Thermal zones under this hvac building type is reset to #{hvac_bldg_type_with_max_floor}")
            else
              bldg_type_hvac_zone_hash[bldg_type] = bldg_type_zone
            end
          end
        end
      end

      # Write in hvac building type thermal zones by thermal zone
      bldg_type_hvac_zone_hash.each do |h1_bldg_type, bldg_type_zone_array|
        bldg_type_zone_array.each do |thermal_zone|
          thermal_zone.additionalProperties.setFeature('building_type_for_hvac', h1_bldg_type)
        end
      end
    end

    # =============================SPACE user data process===========================================
    user_spaces = @standards_data.key?('userdata_space') ? @standards_data['userdata_space'] : nil
    model.getSpaces.each do |space|
      type_for_wwr = nil
      # Check for 2nd level hierarchy
      if user_spaces && user_spaces.length >= 1
        user_spaces.each do |user_space|
          unless user_space['building_type_for_wwr'].nil?
            if space.name.get == user_space['name']
              type_for_wwr = user_space['building_type_for_wwr']
            end
          end
        end
      end

      if type_for_wwr.nil?
        # 2nd Hierarchy does not apply, check for 3rd level hierarchy
        building_name = space.model.building.get.name.get
        if user_buildings && user_buildings.length >= 1
          user_buildings.each do |user_building|
            unless user_building['building_type_for_wwr'].nil?
              if user_building['name'] == building_name
                type_for_wwr = user_building['building_type_for_wwr']
              end
            end
          end
        end
      end

      if type_for_wwr.nil?
        # 3rd level hierarchy does not apply, Apply 4th level hierarchy
        type_for_wwr = default_wwr_building_type
      end
      # add wwr type to space:
      space.additionalProperties.setFeature('building_type_for_wwr', type_for_wwr)
    end
    # =============================SWH user data process===========================================
    user_wateruse_equipments = @standards_data.key?('userdata_wateruse_equipment') ? @standards_data['userdata_wateruse_equipment'] : nil
    model.getWaterUseEquipments.each do |wateruse_equipment|
      type_for_swh = nil
      # Check for 2nd hierarchy
      if user_wateruse_equipments && user_wateruse_equipments.length >= 1
        user_wateruse_equipments.each do |user_wateruse_equipment|
          unless user_wateruse_equipment['building_type_for_swh'].nil?
            if wateruse_equipment.name.get == user_wateruse_equipment['name']
              type_for_swh = user_wateruse_equipment['building_type_for_swh']
            end
          end
        end
      end

      if type_for_swh.nil?
        # 2nd hierarchy does not apply, check for 3rd hierarchy
        # get space building type
        building_name = wateruse_equipment.model.building.get.name.get
        if user_buildings && user_buildings.length >= 1
          user_buildings.each do |user_building|
            unless user_building['building_type_for_swh'].nil?
              if user_building['name'] == building_name
                type_for_swh = user_building['building_type_for_swh']
              end
            end
          end
        end
      end

      if type_for_swh.nil?
        # 3rd hierarchy does not apply, apply 4th hierarchy
        type_for_swh = default_swh_building_type
      end
      # add swh type to wateruse equipment:
      wateruse_equipment.additionalProperties.setFeature('building_type_for_swh', type_for_swh)
    end
    return true
  end

  # Retrieve zone HVAC user specified compliance inputs from CSV file
  #
  # @param [OpenStudio::Model::Model] OpenStudio model object
  def handle_zone_hvac_user_input_data(model)
    user_zone_hvac = @standards_data.key?('userdata_zone_hvac') ? @standards_data['userdata_zone_hvac'] : nil
    return unless !user_zone_hvac.empty?

    zone_hvac_equipment = model.getZoneHVACComponents
    if zone_hvac_equipment.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', 'No zone HVAC equipment is present in the proposed model, user provided information cannot be used to generate the baseline building model.')
      return
    end

    user_zone_hvac.each do |zone_hvac_eqp_info|
      user_defined_zone_hvac_obj_name = zone_hvac_eqp_info['name']
      user_defined_zone_hvac_obj_type_name = zone_hvac_eqp_info['zone_hvac_object_type_name']

      # Check that the object type name do exist
      begin
        user_defined_zone_hvac_obj_type_name_idd = user_defined_zone_hvac_obj_type_name.to_IddObjectType
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "#{user_defined_zone_hvac_obj_type_name}, provided in the user zone HVAC user data, is not a valid OpenStudio model object.")
      end

      # Retrieve zone HVAC object(s) by name
      zone_hvac_eqp = model.getZoneHVACComponentsByName(user_defined_zone_hvac_obj_name, false)

      # If multiple object have the same name
      if zone_hvac_eqp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "The #{user_defined_zone_hvac_obj_type_name} object named #{user_defined_zone_hvac_obj_name} provided in the user zone HVAC user data could not be found in the model.")
      elsif zone_hvac_eqp.length == 1
        zone_hvac_eqp = zone_hvac_eqp[0]
        zone_hvac_eqp_idd = zone_hvac_eqp.iddObjectType.to_s
        if zone_hvac_eqp_idd != user_defined_zone_hvac_obj_type_name
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "The object type name provided in the zone HVAC user data (#{user_defined_zone_hvac_obj_type_name}) does not match with the one in the model: #{zone_hvac_eqp_idd}.")
        end
      else
        zone_hvac_eqp.each do |eqp|
          zone_hvac_eqp_idd = eqp.iddObjectType
          if zone_hvac_eqp_idd == user_defined_zone_hvac_obj_type_name
            zone_hvac_eqp = eqp
            break
          end
        end
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.model', "A #{user_defined_zone_hvac_obj_type_name} object named #{user_defined_zone_hvac_obj_name} (as specified in the user zone HVAC data) could not be found in the model.")
      end

      if zone_hvac_eqp.thermalZone.is_initialized
        thermal_zone = zone_hvac_eqp.thermalZone.get

        zone_hvac_eqp_info.keys.each do |info_key|
          if info_key.include?('fan_power_credit')
            if !zone_hvac_eqp_info[info_key].to_s.empty?
              if info_key.include?('has_')
                if thermal_zone.additionalProperties.hasFeature(info_key)
                  current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                  thermal_zone.additionalProperties.setFeature(info_key, current_value + 1.0)
                else
                  thermal_zone.additionalProperties.setFeature(info_key, 1.0)
                end
              else
                if thermal_zone.additionalProperties.hasFeature(info_key)
                  current_value = thermal_zone.additionalProperties.getFeatureAsDouble(info_key).to_f
                  thermal_zone.additionalProperties.setFeature(info_key, current_value + zone_hvac_eqp_info[info_key])
                else
                  thermal_zone.additionalProperties.setFeature(info_key, zone_hvac_eqp_info[info_key])
                end
              end
            end
          end
        end
      end
    end
  end

  # Calculate the window to wall ratio reduction factor
  #
  # @param multiplier [Float] multiplier of the wwr
  # @param surface [Openstudio::Model::Surface]
  # @param wwr_target [Float] target window to wall ratio
  # @param total_wall_m2 [Float] total wall area of the category in m2.
  # @param total_wall_with_fene_m2 [Float] total wall area of the category with fenestrations in m2.
  # @param total_fene_m2 [Float] total fenestration area
  # @return [Float] reduction factor
  def get_wwr_reduction_ratio(multiplier,
                              surface: nil,
                              wwr_targt: nil,
                              total_wall_m2: nil,
                              total_wall_with_fene_m2: nil,
                              total_fene_m2: nil)
    reduction_ratio = 0.0

    if multiplier < 1.0
      # Case when reduction is required
      reduction_ratio = 1.0 - multiplier
    else
      # Case when increase is required
      exist_max_wwr = total_wall_with_fene_m2 * 0.9 / total_wall_m2
      if exist_max_wwr < wwr_targt
        # In this case, it is required to add vertical fenestrations to other surfaces
        unless surface.subSurfaces.empty?
          # surface has fenestration
          return 0.9
        end
      end
    end
  end
end
