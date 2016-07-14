
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ScheduleCompact

  # Returns the min and max value for this schedule.
  #
  # @author Andrew Parker, NREL.
  # return [Hash] Hash has two keys, min and max.
  def annual_min_max_value()

    vals = []
    prev_str = ''
    sch.extensibleGroups.each do |eg|
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
    if vals.size == 0
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.ScheduleCompact', "Could not find any value in #{self.name} when determining min and max.")
      result = { 'min' => 999.9, 'max' => 999.9 }
      return result
    end
  
    result = { 'min' => vals.min, 'max' => vals.max }

    return result

  end

end
