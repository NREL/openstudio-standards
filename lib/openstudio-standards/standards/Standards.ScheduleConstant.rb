class Standard
  # @!group ScheduleConstant

  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule
  # (always 1.0, 24/7, 365) would return a value of 8760.
  #
  # @author Andrew Parker, NREL
  # @param schedule_constant [OpenStudio::Model::ScheduleConstant] constant schedule object
  # return [Double] The total number of full load hours for this schedule
  def schedule_constant_annual_equivalent_full_load_hrs(schedule_constant)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ScheduleConstant', "Calculating total annual EFLH for schedule: #{schedule_constant.name}")

    return annual_flh = schedule_constant.value * 8760
  end

  # Returns the min and max value for this schedule.
  # It doesn't evaluate design days only run-period conditions
  #
  # @author David Goldwasser, NREL.
  # @param schedule_constant [OpenStudio::Model::ScheduleConstant] constant schedule object
  # return [Hash] Hash has two keys, min and max.
  def schedule_constant_annual_min_max_value(schedule_constant)
    result = { 'min' => schedule_constant.value, 'max' => schedule_constant.value }

    return result
  end
end

# Create a sequential array of values from a ScheduleConstant object
# Will actually include 24 extra values if model year is a leap year
# Will also include 24 values at end of array representing the holiday day schedule
# Intended use is for storing fan schedules to hash of ZoneName:SchedArray so schedules
# can be saved when HVAC objects are deleted
# @author Doug Maddox, PNNL
# @param [object] model
# @param [Object] schedule_ruleset
# @return [Array<Double>] Array of sequential hourly values for year + 24 hours at end for holiday
def get_8760_values_from_schedule_constant(model, schedule_constant)
  yd = model.getYearDescription
  start_date = yd.makeDate(1, 1)
  sch_value = schedule_constant.value

  # Start with 365 days + 24 hrs for holiday
  hrs_per_year = 8759 + 24
  # Add 24 hours if leap year
  hrs_per_year += 24 if start_date.isLeapYear

  values = []
  (0..hrs_per_year).each do |ihr|
    values << sch_value
  end

  return values
end
