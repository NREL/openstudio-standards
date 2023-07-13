class Standard
  # @!group ScheduleCompact

  # Returns the min and max value in a design day (heating or cooling) from a Compact schedule
  #
  # @author Weili Xu, PNNL
  # @param schedule_compact [OpenStudio::Model::ScheduleCompact] schedule ruleset object
  # @param type [String] 'winter' will enable the winter design day search, 'summer' enables summer design day search
  # @return [Hash] Hash has two keys, min and max.
  def schedule_compact_design_day_min_max_value(schedule_compact, type = 'winter')
    vals = []
    design_day_flag = false
    prev_str = ''
    schedule_compact.extensibleGroups.each do |eg|
      if design_day_flag && prev_str.include?('until')
        val = eg.getDouble(0)
        if val.is_initialized
          vals << val.get
        end
      end

      str = eg.getString(0)
      if str.is_initialized
        prev_str = str.get.downcase
        if prev_str.include?('for:')
          # Process a new day schedule, turn the flag off.
          design_day_flag = false
          # in the same line, if there is design day label and matches the type, turn the flag back on.
          if prev_str.include?(type) || prev_str.include?('alldays')
            design_day_flag = true
          end
        end
      end
    end

    # Error if no values were found
    if vals.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio::standards::ScheduleCompact', "Could not find any value in #{schedule_compact.name} design day schedule when determining min and max.")
      result = { 'min' => 999.9, 'max' => 999.9 }
      return result
    end

    result = { 'min' => vals.min, 'max' => vals.max }

    return result
  end

  # Returns the min and max value for this schedule.
  #
  # @author Andrew Parker, NREL.
  # @param schedule_compact [OpenStudio::Model::ScheduleCompact] compact schedule object
  # return [Hash] Hash has two keys, min and max.
  def schedule_compact_annual_min_max_value(schedule_compact)
    vals = []
    prev_str = ''
    schedule_compact.extensibleGroups.each do |eg|
      if prev_str.include?('until')
        val = eg.getDouble(0)
        if val.is_initialized
          vals << eg.getDouble(0).get
        end
      end
      str = eg.getString(0)
      if str.is_initialized
        prev_str = str.get.downcase
      end
    end

    # Error if no values were found
    if vals.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleCompact', "Could not find any value in #{schedule_compact.name} when determining min and max.")
      result = { 'min' => 999.9, 'max' => 999.9 }
      return result
    end

    result = { 'min' => vals.min, 'max' => vals.max }

    return result
  end
end
