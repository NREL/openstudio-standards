# require 'openstudio'
require 'C:\Program Files (x86)\OpenStudio 0.9.3\Ruby\openstudio'

def safe_load_model(model_path_string)
  puts "loading #{model_path_string}"
  model_path = OpenStudio::Path.new(model_path_string)
  if OpenStudio.exists(model_path)
    versionTranslator = OpenStudio::OSVersion::VersionTranslator.new
    model = versionTranslator.loadModel(model_path)
    if model.empty?
      puts "Version translation failed for #{model_path_string}"
      exit
    else
      model = model.get
    end
  else
    puts "#{model_path_string} couldn't be found"
    exit
  end
  return model
end

model = safe_load_model('C:/Projects/Utilities/OpenStudio/on-demand/space_types/nrel_ref_bldg_space_type/lib/Master_Schedules_new.osm')

osm_save_path = OpenStudio::Path.new('C:/Projects/Utilities/OpenStudio/on-demand/space_types/nrel_ref_bldg_space_type/lib/Master_Schedules_new_new.osm')

msgs = []
errs = []
profiles_changed = 0
# reporting initial condition of model
schedule_rulesets = model.getScheduleRulesets
msgs << "The model has #{schedule_rulesets.size} ScheduleRulesets."

# set start and end dates
start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1)
end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31)
# year does matter, but I'm not setting it here

# counter for removed default profiles
default_profiles_removed = 0

# loop through all ScheduleRuleset objects
schedule_rulesets.each do |schedule_ruleset|
  indices_vector = schedule_ruleset.getActiveRuleIndices(start_date, end_date)

  # line below lets you see the indices if for diagnostic purposes
  # msgs << "#{schedule_ruleset.name}: #{indices_vector}"

  unless indices_vector.include? -1

    msgs << "#{schedule_ruleset.name} does not used the default profile, it will be replaced."

    # reset values in default ScheduleDay
    old_default_schedule_day = schedule_ruleset.defaultDaySchedule
    old_default_schedule_day.clearValues

    # get values for new default profile
    rule_vector = schedule_ruleset.scheduleRules
    new_default_daySchedule = rule_vector.reverse[0].daySchedule
    new_default_daySchedule_values = new_default_daySchedule.values
    new_default_daySchedule_times = new_default_daySchedule.times

    # update values and times for default profile
    for i in 0..(new_default_daySchedule_values.size - 1)
      old_default_schedule_day.addValue(new_default_daySchedule_times[i], new_default_daySchedule_values[i])
    end
    # note - I'm not looking at interpolatetoTimestep field.

    # confirm that changes were made
    msgs << "Default values for #{schedule_ruleset.name}: #{old_default_schedule_day.values}"

    # remove rule object that has become the default. Also try to remove the ScheduleDay
    rule_vector.reverse[0].remove  # this seems to also remove the ScheduleDay associated with the rule
    # new_default_daySchedule.remove
    default_profiles_removed += 1
  end

  # report warning if schedule is missing type limits
  if schedule_ruleset.scheduleTypeLimits.empty?
    errs << "WARNING - #{schedule_ruleset.name} does not have a type limits assigned."
  else
    # store schedule type limits object
    desired_type_limit = schedule_ruleset.scheduleTypeLimits.get

    # set type limit for summer and winter design day objects
    default_day = schedule_ruleset.defaultDaySchedule
    summer_design_day = schedule_ruleset.summerDesignDaySchedule
    winter_design_day = schedule_ruleset.winterDesignDaySchedule

    default_day_type_limit = default_day.setScheduleTypeLimits(desired_type_limit)
    summer_design_day_type_limit = summer_design_day.setScheduleTypeLimits(desired_type_limit)
    winter_design_type_limit = winter_design_day.setScheduleTypeLimits(desired_type_limit)

    if !default_day_type_limit  || !summer_design_day_type_limit || !winter_design_type_limit
      errs << "ERROR - Failed to set type limit for default or design day for #{schedule_ruleset.name}"
    else
      profiles_changed += 1
    end

    # get day schedules for schedule_ruleset
    schedule_rules = schedule_ruleset.scheduleRules
    schedule_rules.each do |schedule_rule|
      day_schedule = schedule_rule.daySchedule
      day_type_limit = day_schedule.setScheduleTypeLimits(desired_type_limit)
      unless day_type_limit
        errs << "ERROR - Failed to set type limit for #{day_schedule.name}, child of #{schedule_ruleset.name}."
      end
    end

  end  # end of schedule_ruleset.scheduleTypeLimits.empty?
end  # end of schedule_rulesets.each do |schedule_ruleset|

# reporting final condition of model
msgs << "#{default_profiles_removed} RuleSetSchedules had unused default profiles."

# Save the osm
model.toIdfFile.save(osm_save_path, true)

msgs.each do |msg|
  puts msg
end

errs.each do |err|
  puts err
end

puts "profiles where type limits changed = #{profiles_changed}"
