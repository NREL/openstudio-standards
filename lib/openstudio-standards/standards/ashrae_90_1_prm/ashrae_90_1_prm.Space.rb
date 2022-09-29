class ASHRAE901PRM < Standard
  # @!group Space

  # Set the infiltration rate for this space to include
  # the impact of air leakage requirements in the standard.
  #
  # @return [Double] true if successful, false if not
  def space_apply_infiltration_rate(space, tot_infil_m3_per_s, infil_method, infil_coefficients)
    # get the climate zone
    climate_zone = model_standards_climate_zone(space.model)

    # Calculate infiltration rate
    case infil_method.to_s
      when 'Flow/ExteriorWallArea'
        # Spread the total infiltration rate
        total_exterior_wall_area = 0
        space.model.getSpaces.sort.each do |spc|
          # Get the space conditioning type
          space_cond_type = space_conditioning_category(spc)
          total_exterior_wall_area += spc.exteriorWallArea unless space_cond_type == 'Unconditioned'
        end
        adj_infil_flow_ext_wall_area = tot_infil_m3_per_s / total_exterior_wall_area
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "For #{space.name}, adj infil = #{adj_infil_flow_ext_wall_area.round(8)} m^3/s*m^2 of above grade wall area.")
      when 'Flow/Area'
        # Spread the total infiltration rate
        total_floor_area = 0
        space.model.getSpaces.sort.each do |spc|
          # Get the space conditioning type
          space_cond_type = space_conditioning_category(spc)
          total_floor_area += spc.floorArea unless space_cond_type == 'Unconditioned' || space.exteriorArea == 0
        end
        adj_infil_flow_area = tot_infil_m3_per_s / total_floor_area
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "For #{space.name}, adj infil = #{adj_infil_flow_area.round(8)} m^3/s*m^2 of space floor area.")
    end

    # Get any infiltration schedule already assigned to this space or its space type
    # If not, the always on schedule will be applied.
    # TODO-PRM: Infiltration schedules should be based on HVAC operation
    infil_sch = nil
    unless space.spaceInfiltrationDesignFlowRates.empty?
      old_infil = space.spaceInfiltrationDesignFlowRates[0]
      if old_infil.schedule.is_initialized
        infil_sch = old_infil.schedule.get
      end
    end

    if infil_sch.nil? && space.spaceType.is_initialized
      space_type = space.spaceType.get
      unless space_type.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
        if old_infil.schedule.is_initialized
          infil_sch = old_infil.schedule.get
        end
      end
    end

    if infil_sch.nil?
      infil_sch = space.model.alwaysOnDiscreteSchedule
    else
      # Add specific schedule type object to insure compatibility with the OpenStudio infiltration object
      infil_sch_limit_type = model_add_schedule_type_limits(space.model,
                                                            name: 'Infiltration Schedule Type Limits',
                                                            lower_limit_value: 0.0,
                                                            upper_limit_value: 1.0,
                                                            numeric_type: 'Continuous',
                                                            unit_type: 'Dimensionless')
      infil_sch.setScheduleTypeLimits(infil_sch_limit_type)
    end

    # Remove all pre-existing space infiltration objects
    space.spaceInfiltrationDesignFlowRates.each(&:remove)

    # Get the space conditioning type
    space_cond_type = space_conditioning_category(space)
    if space_cond_type != 'Unconditioned'
      # Create an infiltration rate object for this space
      infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
      infiltration.setName("#{space.name} Infiltration")
      case infil_method.to_s
        when 'Flow/ExteriorWallArea'
          infiltration.setFlowperExteriorWallArea(adj_infil_flow_ext_wall_area.round(13)) if space.exteriorWallArea > 0
        when 'Flow/Area'
          infiltration.setFlowperSpaceFloorArea(adj_infil_flow_area.round(13)) if space.exteriorArea > 0
      end
      infiltration.setSchedule(infil_sch)
      infiltration.setConstantTermCoefficient(infil_coefficients[0])
      infiltration.setTemperatureTermCoefficient(infil_coefficients[1])
      infiltration.setVelocityTermCoefficient(infil_coefficients[2])
      infiltration.setVelocitySquaredTermCoefficient(infil_coefficients[3])

      infiltration.setSpace(space)
    end

    return true
  end

  # For stable baseline, remove all daylighting controls (sidelighting and toplighting)
  # @param space [OpenStudio::Model::Space] the space with daylighting
  # @param remove_existing_controls [Bool] if true, will remove existing controls then add new ones
  # @param draw_daylight_areas_for_debugging [Bool] If this argument is set to true,
  # @return [boolean] true if successful
  def space_set_baseline_daylighting_controls(space, remove_existing = false, draw_areas_for_debug = false)
    removed = space_remove_daylighting_controls(space)
    return removed
  end
end
