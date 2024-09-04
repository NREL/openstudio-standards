# *******************************************************************************
# The following notice pertains to the function below named
# convert_schedule_compact_to_schedule_ruleset
# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

ForStruct = Struct.new(:daytypes)
UntilStruct = Struct.new(:timestamp)
ThroughStruct = Struct.new(:startdate)

class ScheduleTranslator
  attr_accessor :os_schedule

  def initialize(os_model, os_schedule, name_prefix = nil)
    @os_schedule = os_schedule
    @os = os_model
    @sched_name = os_schedule.name.get.to_s
    @sched_type = os_schedule.scheduleTypeLimits.get
    @base_year = os_model.getYearDescription.assumedYear
    @schedule = []
    @name_prefix = name_prefix
  end

  # Convert from scheduleCompact to scheduleRuleset
  # @author Nicholas Long and Andrew Parker, NREL
  # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
  # @todo will fail if no limits set in source schedule
  def convert_schedule_compact_to_schedule_ruleset
    @sched_name = @os_schedule.getString(1).get
    @sched_name = "#{@name_prefix} #{@sched_name}" unless @name_prefix.nil?
    # @todo will fail if no limits set in source schedule
    @sched_type = @os_schedule.scheduleTypeLimits.get

    # puts "Translating #{@sched_name}"

    i_thru = -1
    i_for = -1
    i_until = -1
    s_until = ''

    (3..@os_schedule.numFields - 1).each do |i|
      val = @os_schedule.getString(i).get

      # Trap for interpolated schedules
      if val =~ /Interpolate/
        puts "[WARNING] Schedule #{@sched_name} is interpolated.  It will not be translated to .osm"
        return false
      end

      # add : if it doesn't already exist
      val = val.gsub(/Through\s/, 'Through: ')
      val = val.gsub(/For\s/, 'For: ')
      val = val.gsub(/Until\s/, 'Until: ')

      if val =~ /through:/i
        i_thru += 1
        i_for = -1
        i_until = -1

        str = val.split(':')[1].strip
        if @schedule.empty?
          @schedule << { start_date: '01/01', end_date: str, for: [] }
        else
          @schedule << { start_date: @schedule[@schedule.size - 1][:end_date], end_date: str, for: [] }
        end

        next
      end

      if val =~ /for[:\s]/i
        i_for += 1
        i_until = -1

        arr = val.match(/for[:\s](.*)/i)[0].strip.downcase.split
        @schedule[i_thru][:for] << { daytype: arr, until: [] }
        next
      end

      if val =~ /until:/i
        i_until += 1

        str = val.split(':')[1..2].join(':').strip
        s_until = str

        next
      end

      d_val = @os_schedule.getDouble(i).get
      # puts "thru: #{i_thru} for: #{i_for} until #{i_until}"
      @schedule[i_thru][:for][i_for][:until] << { timestamp: s_until, value: d_val }
    end

    # DEBUG spit out the schedule for quick check\
    #     puts @schedule.inspect
    #     @schedule.each do |sch|
    #      puts "#{sch[:start_date]} to #{sch[:end_date]}"
    #      sch[:for].each do |fr|
    #        puts fr[:daytype]
    #        fr[:until].each do |ut|
    #          puts "#{ut[:timestamp]} : #{ut[:value]}"
    #        end
    #      end
    #     end

    os_schedule_ruleset = OpenStudio::Model::ScheduleRuleset.new(@os)
    os_schedule_ruleset.setName(@sched_name)
    os_schedule_ruleset.setScheduleTypeLimits(@sched_type)

    i_rule = 0
    @schedule.each do |sch|
      # create a simple hash to make sure that the schedule covers all days needed
      # and that "allotherdays", can adequately be handled
      coverage = { mon: false, tue: false, wed: false, thu: false, fri: false, sat: false,
                   sun: false, sdd: false, wdd: false, hol: false }
      sch[:for].each do |fr|
        i_rule += 1
        os_schedule_rule = OpenStudio::Model::ScheduleRule.new(os_schedule_ruleset)
        os_schedule_rule.setName("#{@sched_name} Rule #{i_rule}")
        os_schedule_rule.setApplyMonday(false)
        os_schedule_rule.setApplyTuesday(false)
        os_schedule_rule.setApplyWednesday(false)
        os_schedule_rule.setApplyThursday(false)
        os_schedule_rule.setApplyFriday(false)
        os_schedule_rule.setApplySaturday(false)
        os_schedule_rule.setApplySunday(false)

        mody = sch[:start_date].split('/')
        mo = mody[0].to_i
        dy = mody[1].to_i
        osdate_start = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(mo.to_i), dy.to_i)
        if mo != 1 && dy != 1
          osdate_start += OpenStudio::Time.new(1)
        end
        os_schedule_rule.setStartDate(osdate_start)
        mody = sch[:end_date].split('/')
        mo = mody[0].to_i
        dy = mody[1].to_i
        osdate_end = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(mo.to_i), dy.to_i)
        os_schedule_rule.setEndDate(osdate_end)

        # create os day model
        # @todo break this out as a method
        if fr[:daytype].include?('monday') || fr[:daytype].include?('alldays') || fr[:daytype].include?('weekdays')
          os_schedule_rule.setApplyMonday(true)
          coverage[:mon] = true
        end
        if fr[:daytype].include?('tuesday') || fr[:daytype].include?('alldays') || fr[:daytype].include?('weekdays')
          os_schedule_rule.setApplyTuesday(true)
          coverage[:tue] = true
        end
        if fr[:daytype].include?('wednesday') || fr[:daytype].include?('alldays') || fr[:daytype].include?('weekdays')
          os_schedule_rule.setApplyWednesday(true)
          coverage[:wed] = true
        end
        if fr[:daytype].include?('thursday') || fr[:daytype].include?('alldays') || fr[:daytype].include?('weekdays')
          os_schedule_rule.setApplyThursday(true)
          coverage[:thu] = true
        end
        if fr[:daytype].include?('friday') || fr[:daytype].include?('alldays') || fr[:daytype].include?('weekdays')
          os_schedule_rule.setApplyFriday(true)
          coverage[:fri] = true
        end
        if fr[:daytype].include?('saturday') || fr[:daytype].include?('alldays')
          os_schedule_rule.setApplySaturday(true)
          coverage[:sat] = true
        end
        if fr[:daytype].include?('sunday') || fr[:daytype].include?('alldays')
          os_schedule_rule.setApplySunday(true)
          coverage[:sun] = true
        end
        if fr[:daytype].include?('allotherdays')
          # needs to be a unique rule set
          if !coverage[:mon]
            os_schedule_rule.setApplyMonday(true)
            coverage[:mon] = true
          end
          if !coverage[:tue]
            os_schedule_rule.setApplyTuesday(true)
            coverage[:tue] = true
          end
          if !coverage[:wed]
            os_schedule_rule.setApplyWednesday(true)
            coverage[:wed] = true
          end
          if !coverage[:thu]
            os_schedule_rule.setApplyThursday(true)
            coverage[:thu] = true
          end
          if !coverage[:fri]
            os_schedule_rule.setApplyFriday(true)
            coverage[:fri] = true
          end
          if !coverage[:sat]
            os_schedule_rule.setApplySaturday(true)
            coverage[:sat] = true
          end
          if !coverage[:sun]
            os_schedule_rule.setApplySunday(true)
            coverage[:sun] = true
          end
        end

        osday = os_schedule_rule.daySchedule
        osday.setName("#{@sched_name} Rule #{i_rule} Day Sch")
        # osday.setString(1, @sched_type)
        fr[:until].each do |ut|
          hr = ut[:timestamp].split(':')[0].to_i
          mn = ut[:timestamp].split(':')[1].to_i

          ostime = OpenStudio::Time.new(0, hr, mn, 0)
          osday.addValue(ostime, ut[:value])
        end

        # set the winter and summer design days
        if fr[:daytype].include?('winterdesignday') ||
           (fr[:daytype].include?('allotherdays') && !coverage[:wdd])

          # this actually clones osday
          os_schedule_ruleset.setWinterDesignDaySchedule(osday)

          coverage[:wdd] = true
        end
        if fr[:daytype].include?('summerdesignday') ||
           (fr[:daytype].include?('allotherdays') && !coverage[:sdd])

          # this actually clones osday
          os_schedule_ruleset.setSummerDesignDaySchedule(osday)

          coverage[:sdd] = true
        end

        # now check if for some reason that we have alldays for section
        # but the date/time stamp is not in the winter/summer
        if !coverage[:wdd]
          osdate_wdd = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 15)
          if fr[:daytype].include?('alldays') && (osdate_start < osdate_wdd) && (osdate_end > osdate_wdd)
            os_schedule_ruleset.setWinterDesignDaySchedule(osday)
            coverage[:wdd] = true
            # puts "[INFO] **** Setting DesignDay based on date, not by actual schedule ****"
          end
        end
        if !coverage[:sdd]
          osdate_wdd = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(7), 15)
          if fr[:daytype].include?('alldays') && (osdate_start < osdate_wdd) && (osdate_end > osdate_wdd)
            os_schedule_ruleset.setSummerDesignDaySchedule(osday)
            coverage[:sdd] = true
            # puts "[INFO] **** Setting DesignDay based on date, not by actual schedule ****"
          end
        end
      end
    end

    # Clean up tasks on the naming after all the schedule rule and days are
    # configured
    ostemp = os_schedule_ruleset.winterDesignDaySchedule
    ostemp.setName("#{@sched_name} Winter Design Day")
    # ostemp.setString(1, @sched_type)

    ostemp = os_schedule_ruleset.summerDesignDaySchedule
    ostemp.setName("#{@sched_name} Summer Design Day")
    # ostemp.setString(1, @sched_type)

    ostemp = os_schedule_ruleset.defaultDaySchedule
    ostemp.setName("#{@sched_name} Default Schedule")
    # ostemp.setString(1, @sched_type)

    # Remove rules that don't apply to any days
    os_schedule_ruleset.scheduleRules.each do |sr|
      if !sr.applySunday && !sr.applyMonday && !sr.applyTuesday &&
         !sr.applyWednesday && !sr.applyThursday && !sr.applyFriday &&
         !sr.applySaturday
        sr.daySchedule.remove
        sr.remove
      end
    end

    sched_i = 0
    os_schedule_ruleset.scheduleRules.each do |sr|
      sched_i += 1
      sr.setName("#{@sched_name} Rule #{sched_i}")
      sr.daySchedule.setName("#{@sched_name} Rule #{sched_i} Day Schedule")
    end

    # If the default profile is never used throughout the year,
    # make the most commonly used rule the default instead.

    # Get an array that shows which rule is used on each day in the date range.
    # A value of -1 means that the default profile is used on that day,
    # so if -1 never appears in the list, it isn't used.
    year = @base_year
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    rules_used_each_day = os_schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)
    rules_freq = rules_used_each_day.group_by { |n| n }
    most_freq_rule_index = rules_freq.values.max_by(&:size).first
    if !rules_used_each_day.include?(-1)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.schedule_translator', "#{os_schedule_ruleset.name} does not use the default profile, it will be replaced.")

      # Get times/values from the most commonly used rule then remove that rule.
      rule_vector = os_schedule_ruleset.scheduleRules
      new_default_day_sch = rule_vector[most_freq_rule_index].daySchedule
      new_default_day_sch_values = new_default_day_sch.values
      new_default_day_sch_times = new_default_day_sch.times
      rule_vector[most_freq_rule_index].remove

      # Reset values in default profile
      default_day_sch = os_schedule_ruleset.defaultDaySchedule
      default_day_sch.clearValues

      # Update values and times for default profile
      for i in 0..(new_default_day_sch_values.size - 1)
        default_day_sch.addValue(new_default_day_sch_times[i], new_default_day_sch_values[i])
      end
    end

    return os_schedule_ruleset
  end
end
