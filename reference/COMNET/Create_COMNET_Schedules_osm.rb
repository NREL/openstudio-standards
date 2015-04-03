######################################################################
#  Copyright (c) 2008-2010, Alliance for Sustainable Energy.
#  All rights reserved.
#
######################################################################

######################################################################
# == Synopsis
#
#   This script takes in the COMNET_Appendix_C_Schedules.xlsx
#   spreadsheet and creates a default schedule set for each tab
#
#   This script assumes the schedules are in the following order:
#   Occ Wk, Occ Sat, Occ Sun
#   LtAndPlg Wk, Lt Plg Sat, Lt Plg Sun
#   HVAC Wk, HVAC Sat, HVAC Sun
#   SWH Wk, SWH Sat, SWH Sun
#   Elev Wk, Elev Sat, Elec Sun
#
# == Usage
#
#   ruby Create_COMNET_Schedules_osm.rb
#
######################################################################

# use openstudio plus some other ruby utilities to read the excel spreadsheet
# require 'C:/Projects/OpenStudio/build/OpenStudioCore-prefix/src/OpenStudioCore-build/ruby/Debug/openstudio.rb'
# require 'C:/Program Files (x86)/OpenStudio 0.7.6.9030/Ruby/openstudio'
require 'openstudio'
require 'win32ole'
require 'csv'

# get the data from the spreadsheet
# path to the xl file
xlsx_path = "#{Dir.pwd}/COMNET_Appendix_C_Schedules.xlsx"
# enable Excel
xl = WIN32OLE.new('Excel.Application')
# open workbook
wb = xl.workbooks.open(xlsx_path)
# specify worksheet
ws = wb.worksheets('TestSheet')
# specify data range
data = ws.range('A3:P27')['Value'].transpose
spc_typ_nm = ws.range('A2')['Value'].chomp('Occupancy').strip
# close workbook
wb.Close(1)
# quit Excel
xl.Quit

# create a new OpenStudio model to store all the space type objects in
model = OpenStudio::Model::Model.new

# make some schedule type limits to assign later
# fractional (0 to 1, continous)
frac_lim = OpenStudio::Model::ScheduleTypeLimits.new(model)
frac_lim.setName('Fractional')
frac_lim.setLowerLimitValue(0.0)
frac_lim.setUpperLimitValue(1.0)
frac_lim.setNumericType('Continuous')
# on/off (0 or 1, discrete)
on_off_lim = OpenStudio::Model::ScheduleTypeLimits.new(model)
on_off_lim.setName('OnOff')
on_off_lim.setLowerLimitValue(0.0)
on_off_lim.setUpperLimitValue(1.0)
on_off_lim.setNumericType('Discrete')
on_off_lim.setUnitType('Availability')

# create a defaultscheduleset object and assign it to the spacetype
default_schedule_set = OpenStudio::Model::DefaultScheduleSet.new(model)
default_schedule_set.setName("#{spc_typ_nm} Space Type Default Sch Set")

# list of start columns for each schedule
occ_col = 1
lts_and_plug_col = 4
hvac_col = 7
swh_col = 10
elev_col = 13

# put the schedule type start columns into an array
sch_st_cols = [occ_col, lts_and_plug_col, hvac_col, swh_col, elev_col]

# loop through all of the schedule types (Occ, LtsAndPlug, HVAC,
sch_st_cols.each do |sch_st_col|
  # get the schedule space type name from the spreadsheet
  # strip off "Occupancy" part because it is confusing
  sch_nm = data[sch_st_col][0].split(' ')[0]
  puts "#{data[sch_st_col][0]} = #{sch_st_col}"

  # determine the schedule limits type depending on schedule type
  case sch_nm
  when 'Occ'
    lim = frac_lim
  when 'LtAndPlg'
    lim = frac_lim
  when 'HVAC'
    lim = on_off_lim
  when 'SWH'
    lim = frac_lim
  when 'Elev'
    lim = frac_lim
  end

  # ScheduleRuleset
  sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
  sch_ruleset.setName("#{spc_typ_nm} #{sch_nm} Sch")
  sch_ruleset.setScheduleTypeLimits(lim.clone.to_ScheduleTypeLimits.get)

  # Winter Design Day
  winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
  sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
  winter_dsn_day = sch_ruleset.winterDesignDaySchedule
  winter_dsn_day.setName("#{spc_typ_nm} #{sch_nm} Sch Winter Dsn Day")
  # loop through all hours in the day, adding an entry for each one
  prev_val = ''
  24.times do |hour|
    ostime = OpenStudio::Time.new(0, 24 - hour, 0, 0)
    # use sunday sch (lowest load, max heating needed) for winter dsn day
    val = data[sch_st_col + 2][24 - hour].to_f / 100
    next if val == prev_val
    winter_dsn_day.addValue(ostime, val)
    prev_val = val
  end

  # Summer Design Day
  summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
  sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
  summer_dsn_day = sch_ruleset.summerDesignDaySchedule
  summer_dsn_day.setName("#{spc_typ_nm} #{sch_nm} Sch Summer Dsn Day")
  # loop through all hours in the day, adding an entry for each one
  prev_val = ''
  24.times do |hour|
    ostime = OpenStudio::Time.new(0, 24 - hour, 0, 0)
    # use sunday sch (lowest load, max heating needed) for winter dsn day
    val = data[sch_st_col + 1][24 - hour].to_f / 100
    next if val == prev_val
    summer_dsn_day.addValue(ostime, val)
    prev_val = val
  end

  # Weekdays
  week_day = sch_ruleset.defaultDaySchedule
  week_day.setName("#{spc_typ_nm} #{sch_nm} Sch WkDay")
  # loop through all hours in the day, adding an entry for each one
  prev_val = ''
  24.times do |hour|
    ostime = OpenStudio::Time.new(0, 24 - hour, 0, 0)
    # use sunday sch (lowest load, max heating needed) for winter dsn day
    val = data[sch_st_col][24 - hour].to_f / 100
    next if val == prev_val
    week_day.addValue(ostime, val)
    prev_val = val
  end

  # Saturdays
  saturday_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
  saturday_rule.setName("#{spc_typ_nm} #{sch_nm} Sch Sat Rule")
  saturday_rule.setApplySaturday(true)
  saturday = saturday_rule.daySchedule
  saturday.setName("#{spc_typ_nm} #{sch_nm} Sch Sat")
  # loop through all hours in the day, adding an entry for each one
  prev_val = ''
  24.times do |hour|
    ostime = OpenStudio::Time.new(0, 24 - hour, 0, 0)
    # use sunday sch (lowest load, max heating needed) for winter dsn day
    val = data[sch_st_col + 1][24 - hour].to_f / 100
    next if val == prev_val
    saturday.addValue(ostime, val)
    prev_val = val
  end

  # Sundays
  sunday_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
  sunday_rule.setName("#{spc_typ_nm} #{sch_nm} Sch Sun Rule")
  sunday_rule.setApplySunday(true)
  sunday = sunday_rule.daySchedule
  sunday.setName("#{spc_typ_nm} #{sch_nm} Sch Sun")
  # loop through all hours in the day, adding an entry for each one
  prev_val = ''
  24.times do |hour|
    ostime = OpenStudio::Time.new(0, 24 - hour, 0, 0)
    # use sunday sch (lowest load, max heating needed) for winter dsn day
    val = data[sch_st_col + 1][24 - hour].to_f / 100
    next if val == prev_val
    sunday.addValue(ostime, val)
    prev_val = val
  end

  # assign the schedule to the correct place in the default schedule set
  case sch_nm
  when 'Occ'
    default_schedule_set.setNumberofPeopleSchedule(sch_ruleset)
  when 'LtAndPlg'
    default_schedule_set.setLightingSchedule(sch_ruleset)
    default_schedule_set.setElectricEquipmentSchedule(sch_ruleset)
  when 'HVAC'
    default_schedule_set.setHoursofOperationSchedule(sch_ruleset)
  when 'SWH'
    default_schedule_set.setHotWaterEquipmentSchedule(sch_ruleset)
  when 'Elev'
    default_schedule_set.setOtherEquipmentSchedule(sch_ruleset)
  else
    puts "schedule type #{sch_nm} is not valid; skipping assingment"
  end

  # puts sch_ruleset
  # puts sch_ruleset.defaultDaySchedule
  # puts sch_ruleset.winterDesignDaySchedule
  # puts sch_ruleset.summerDesignDaySchedule
  # puts saturday_rule
  # puts saturday
  # puts sunday_rule
  # puts sunday
end

# Save the osm
Dir.chdir('..')
model.toIdfFile.save(OpenStudio::Path.new("#{Dir.pwd}/lib/COMNET_Appendix_C_Schedules.osm"), true)
puts "Schedules have been saved to #{Dir.pwd}/lib/COMNET_Appendix_C_Schedules.osm"
