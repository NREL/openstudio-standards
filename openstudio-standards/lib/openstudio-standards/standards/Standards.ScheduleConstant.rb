
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ScheduleConstant

  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule 
  # (always 1.0, 24/7, 365) would return a value of 8760. 
  #
  # @author Andrew Parker, NREL
  # return [Double] The total number of full load hours for this schedule
  def annual_equivalent_full_load_hrs()

    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating total annual EFLH for schedule: #{self.name}")

    return annual_flh = self.value * 8760

  end		

end
