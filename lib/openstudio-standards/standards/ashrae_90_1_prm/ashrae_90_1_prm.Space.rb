class ASHRAE9012013 < ASHRAE901
  # @!group Space

  # Set the infiltration rate for this space to include
  # the impact of air leakage requirements in the standard.
  #
  # @return [Double] true if successful, false if not
  def space_apply_infiltration_rate(space, tot_infil_m3_per_s, infil_method, infil_coefficients)
    # Calculate infiltration rate
    case infil_method
      when 'flowperExteriorWallArea'
        # Spread the total infiltration rate over all above grade walls
        all_ext_infil_m3_per_s_per_m2 = tot_infil_m3_per_s / space.exteriorWallArea
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "For #{space.name}, adj infil = #{all_ext_infil_m3_per_s_per_m2.round(8)} m^3/s*m^2 of above grade wall area.")
      when 'flowperSpaceFloorArea'
        # Spread the total infiltration rate over all space floor area
        all_ext_infil_m3_per_s_per_m2 = tot_infil_m3_per_s / space.floorArea
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "For #{space.name}, adj infil = #{all_ext_infil_m3_per_s_per_m2.round(8)} m^3/s*m^2 of space floor area.")
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
    end
    
    # Create an infiltration rate object for this space
    infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
    infiltration.setName("#{space.name} Infiltration")
    case infil_method
      when 'flowperExteriorWallArea'
        infiltration.setFlowperExteriorWallArea(adj_infil_rate_m3_per_s_per_m2.round(13))
      when 'flowperSpaceFloorArea'
      infiltration.setFlowperExteriorSurfaceArea(all_ext_infil_m3_per_s_per_m2.round(13))
    end
    infiltration.setSchedule(infil_sch)
    infiltration.setConstantTermCoefficient(infil_coefficients[0])
    infiltration.setTemperatureTermCoefficient(infil_coefficients[1])
    infiltration.setVelocityTermCoefficient(infil_coefficients[2])
    infiltration.setVelocitySquaredTermCoefficient(infil_coefficients[3])

    infiltration.setSpace(space)

    return true
  end
end