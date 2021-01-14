class Standard
  # @!group ScheduleConstant

  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule
  # (always 1.0, 24/7, 365) would return a value of 8760.
  #
  # @author Andrew Parker, NREL
  # return [Double] The total number of full load hours for this schedule
  def schedule_constant_annual_equivalent_full_load_hrs(schedule_constant)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ScheduleConstant', "Calculating total annual EFLH for schedule: #{schedule_constant.name}")

    return annual_flh = schedule_constant.value * 8760
  end

  # Returns the min and max value for this schedule.
  # It doesn't evaluate design days only run-period conditions
  #
  # @author David Goldwasser, NREL.
  # return [Hash] Hash has two keys, min and max.
  def schedule_constant_annual_min_max_value(schedule_constant)
    result = { 'min' => schedule_constant.value, 'max' => schedule_constant.value }

    return result
  end
end
