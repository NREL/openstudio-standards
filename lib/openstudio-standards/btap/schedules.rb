# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

require "#{File.dirname(__FILE__)}/btap"


module BTAP
  module Resources #Resources


    # This module contains methods that relate to Materials, Constructions and Construction Sets

    module Schedules # BTAP::Resources::Schedules



      #Test Schedules Module
      if __FILE__ == $0
        require 'test/unit'
        class SchedulesTests < Test::Unit::TestCase

          def test_create_all_schedule_types()
            model = OpenStudio::Model::Model.new()
            schedule_struct =
              [
              [
                #Start and stop date of schedule in gregorian format.
                ["Jan-01","May-31"],
                # Days of the week that it applies
                ["M","T","W","TH","F","S","SN"],# Days of the week are "M","T","W","TH","F","S","SN", or wild cards for weekend and weekdays "WKD","WKE"
                # value up until the hour and minute for each block.
                [
                  [ "9:00",  13.0], #time, value_until_this_time
                  [ "17:00", 21.0]  #time, value_until_this_time
                ]
              ],
              [
                #Start and stop date of schedule in gregorian format.
                ["Jun-01","Sep-30"],
                # Days of the week that it applies
                ["M","T","W","TH","F","S","SN"], # Days of the week are "M","T","W","TH","F","S","SN", or wild cards for weekend and weekdays "WKD","WKE"
                # value up until the hour and minute for each block.
                [
                  ["24:00", 13.0]  #time, value_until_this_time
                ]
              ],
              [
                #Period for schedule in gregorian format.
                [ "Oct-01","Dec-31"],
                # Days of the week that it applies
                ["M","T","W","TH","F","S","SN"], # Days of the week are "M","T","W","TH","F","S","SN", or wild cards for weekend and weekdays "WKD","WKE"
                # value up until the hour and minute for each block.
                [
                  [ "9:00",  1], #time, value_until_this_time
                  [ "17:00", 2]  #time, value_until_this_time
                ]
              ]
            ]


            temperature_array =
              [
              Array.new(24){21}, #Weekday
              Array.new(24){21}, #Sat
              Array.new(24){21}, #Sun
            ]

            fraction_array =
              [
              Array.new(24){0.5}, #Weekday
              Array.new(24){0.5}, #Sat
              Array.new(24){0.5}, #Sun
            ]

            on_off_array =
              [
              Array.new(24){1}, #Weekday
              Array.new(24){0}, #Sat
              Array.new(24){0}, #Sun
            ]
            #Check to see if the objects were really created.
            temperature_ruleset_sched = BTAP::Resources::Schedules::create_annual_ruleset_schedule(model,"test schedule ruleset","TEMPERATURE",temperature_array)
            assert( !(temperature_ruleset_sched.to_ScheduleRuleset.empty?))

            BTAP::Resources::Schedules::modify_schedule!(model, temperature_ruleset_sched, 0.90 , "*")
            temperature_ruleset_sched.scheduleRules.each do |week_rule|
              week_rule.daySchedule().values.each do |value|
                assert_in_delta(21.0 * 0.90,value,0.000001)
              end
            end
            fraction_ruleset_sched = BTAP::Resources::Schedules::create_annual_ruleset_schedule(model,"test schedule ruleset","FRACTION",fraction_array)
            assert( !(fraction_ruleset_sched.to_ScheduleRuleset.empty?))

            on_off_ruleset_sched = BTAP::Resources::Schedules::create_annual_ruleset_schedule(model,"test schedule ruleset","ON_OFF",on_off_array)
            assert( !(on_off_ruleset_sched.to_ScheduleRuleset.empty?))

            constant_ruleset_sched = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model,"test constant schedule","TEMPERATURE",21)
            assert( !(constant_ruleset_sched.to_ScheduleRuleset.empty?))
            dual_setpoint_schedule = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model,"dual setpoint test",constant_ruleset_sched,constant_ruleset_sched)
            assert( !(dual_setpoint_schedule.to_ThermostatSetpointDualSetpoint.empty?))

            detailed_ruleset_schedule = BTAP::Resources::Schedules::create_annual_ruleset_schedule_detailed(model,"test detailed schedule","FRACTION",schedule_struct  )
            assert( !(detailed_ruleset_schedule.to_ScheduleRuleset.empty?))

          end
        end
      end # End Test Schedules

      module StandardScheduleTypeLimits
        def self.get_fraction(model)
          name = "FRACTION"
          fraction_schedule_type_limits = model.getScheduleTypeLimitsByName(name)
          if fraction_schedule_type_limits.empty?
            #fraction
            fraction_schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            fraction_schedule_type_limits.setName(name)
            fraction_schedule_type_limits.setNumericType("CONTINUOUS")
            fraction_schedule_type_limits.setUnitType("Dimensionless")
            fraction_schedule_type_limits.setLowerLimitValue(0.0)
            fraction_schedule_type_limits.setUpperLimitValue(1.0)
            return fraction_schedule_type_limits
          else
            return fraction_schedule_type_limits.get
          end
        end

        def self.get_on_off(model)
          name = "ON_OFF"
          onoff_schedule_type_limits = model.getScheduleTypeLimitsByName(name)
          if onoff_schedule_type_limits.empty?
            #onoff
            onoff_schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            onoff_schedule_type_limits.setName(name)
            onoff_schedule_type_limits.setNumericType("DISCRETE")
            onoff_schedule_type_limits.setUnitType("Dimensionless")
            onoff_schedule_type_limits.setLowerLimitValue(0)
            onoff_schedule_type_limits.setUpperLimitValue(1)
            return onoff_schedule_type_limits
          else
            return onoff_schedule_type_limits.get
          end
        end

        def self.get_temperature(model)
          name = "TEMPERATURE"

          #temperature
          temperature_schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
          temperature_schedule_type_limits.setName(name)
          temperature_schedule_type_limits.setNumericType("Continuous")
          temperature_schedule_type_limits.setUnitType("Temperature")
          #temperature_schedule_type_limits.setLowerLimitValue(-200.0)
          #temperature_schedule_type_limits.setUpperLimitValue(200.0)
          return temperature_schedule_type_limits

        end

        def self.get_activity(model)
          name = "ACTIVITY"
          temperature_schedule_type_limits = model.getScheduleTypeLimitsByName(name)
          if temperature_schedule_type_limits.empty?
            #temperature
            temperature_schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            temperature_schedule_type_limits.setName(name)
            temperature_schedule_type_limits.setNumericType("Continuous")
            temperature_schedule_type_limits.setUnitType("W/person")
            temperature_schedule_type_limits.setLowerLimitValue(70.0)
            temperature_schedule_type_limits.setUpperLimitValue(1000.0)
            return temperature_schedule_type_limits
          else
            return temperature_schedule_type_limits.get
          end
        end

      end



      module StandardSchedules

        module Fraction


          def self.always_off(model)
            fraction_always_off_name = "FRACTION_ALWAYS_OFF"
            schedule = model.getScheduleRulesetByName(fraction_always_off_name)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(
                fraction_always_off_name,
                "FRACTION",
                0.0)
            else
              return schedule.get
            end
          end
          def self.always_on(model)
            fraction_always_on_name  = "FRACTION_ALWAYS_ON"
            schedule = model.getScheduleRulesetByName(fraction_always_on_name)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(
                model,
                fraction_always_on_name,
                "FRACTION",
                1.0)
            else
              return schedule.get
            end
          end
        end
        module ON_OFF


          def self.always_off(model)
            on_off_always_off   = "ON_OFF_ALWAYS_OFF"
            schedule = model.getScheduleRulesetByName(on_off_always_off)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(
                model,
                on_off_always_off,
                "ON_OFF",
                0)
            else
              return schedule.get
            end
          end
          def self.always_on(model)
            on_off_always_on   = "ON_OFF_ALWAYS_ON"
            schedule = model.getScheduleRulesetByName(on_off_always_on)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(
                model,
                on_off_always_on,
                "ON_OFF",
                1)
            else
              return schedule.get
            end
          end
        end
        module Temperature
          def self.no_heating(model)
            no_heating = "NO_HEATING_SETPOINT"
            schedule = model.getScheduleRulesetByName(no_heating)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(
                model,
                no_heating,
                "TEMPERATURE",
                -200.0)
            else
              return schedule.get
            end
          end
          def self.no_cooling(model)
            no_cooling = "NO_COOLING_SETPOINT"
            schedule = model.getScheduleRulesetByName(no_cooling)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(
                model,
                no_cooling,
                "TEMPERATURE",
                200.0)
            else
              return schedule.get
            end
          end
          def self.no_heating_cooling_dual_setpoint_schedule(model)
            dual_setpoint_name = "FREE_FLOATING_DUAL_SETPOINT_THERMOSTAT"
            schedule = model.getScheduleRulesetByName(dual_setpoint_name)
            if schedule.empty?
              #create Schedule
              return BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint( model, dual_setpoint_name, self.heating_setpoint_off, self.cooling_setpoint_off)
            else
              return schedule.getThermostatSetpointDualSetpointByName()
            end
          end
        end
      end


      def self.remove_all_schedules(model)
        model.getScheduleBases.sort.each { |item| item.remove }
      end


      def self.create_zonal_occupancy_schedule_on_off(model, thermal_zone)

        model.getFanZoneExhausts.sort.each {|zfe| puts "Fan Ex:#{zfe}"}

        #Create new timeseries object to keep track of on/off states. Default to 30min intervals.
        timeseries  = OpenStudio::TimeSeries.new
        thermal_zone.spaces.sort.each do |space|
          #Iterate through the people object in the space.
          space.spaceType.get.people.each do |people|
            if people.numberofPeopleSchedule.is_initialized() and people.numberofPeopleSchedule.get.to_ScheduleRuleset.is_initialized
              #Get the occupancy schedule.
              occ_schedule = people.numberofPeopleSchedule.get
              #Convert schedule to timeseries and sum up timeseries objects for this space / zone.
              occ_time_series = create_timeseries_from_schedule_ruleset(model,occ_schedule)
              timeseries = timeseries + occ_time_series
            end
          end
        end
        #return the timeseries converted to
        return create_schedule_variable_interval_from_time_series(model,timeseries)
      end


      #This method will only work with a single occupancy definition.
      def self.set_exhaust_fans_availability_to_building_default_occ_schedule(model)
        # get occupancy schedule if possible.
        if  model.building.get.defaultScheduleSet.is_initialized and
            model.building.get.defaultScheduleSet.get.numberofPeopleSchedule.is_initialized and
            model.building.get.defaultScheduleSet.get.numberofPeopleSchedule.get.to_ScheduleRuleset.is_initialized
          occ_schedule = model.building.get.defaultScheduleSet.get.numberofPeopleSchedule.get
          #get building default occupancy schedule.
          model.getFanZoneExhausts.sort.each do |zfe|
            zfe.setAvailabilitySchedule(occ_schedule)
            zfe.setBalancedExhaustFractionSchedule(occ_schedule)
          end
        else
          raise ("Default occupancy schedule has not been set in model! Unsure what to set exhaust fans to. Exiting.")
        end
        return model.getFanZoneExhausts
      end


      def self.modify_schedule( model, schedule_ruleset, a_coef = 0.0 ,b_coef = 0.0 ,c_coef= 0.0 ,time_shift = nil,time_sign = nil)
        new_schedule = schedule_ruleset.clone( model ).to_ScheduleRuleset.get
        self.modify_schedule!(model, new_schedule, a_coef,b_coef,c_coef ,time_shift,time_sign)
      end


      def self.modify_schedule!(model, schedule_ruleset, a_coef = 0.0 ,b_coef = 0.0 ,c_coef= 0.0 ,time_shift = nil,time_sign = nil)
        schedule_ruleset.scheduleRules.each do |week_rule|
          day_rule = week_rule.daySchedule()
          times = day_rule.times()
          times.each do |time|
            old_value = day_rule.getValue(time)
            day_rule.removeValue(time)
            new_value = "error"
            new_time = "error"
            #set the new value according to Ax2+Bx+C.
            new_value = a_coef * old_value ** 2.0 + b_coef * old_value + c_coef
            unless time_shift.nil? or time_sign.nil?
              command = "new_time = time #{time_sign} #{BTAP::Common::get_time_from_string(time_shift)}"
              eval(command)
              #make sure time is not past 24 hours.
              new_time = new_time - BTAP::Common::get_time_from_string("24:00") if new_time > BTAP::Common::get_time_from_string("24:00")
            end
            day_rule.addValue(time, new_value)
          end
        end
      end

      def self.create_availability_schedule_based_on_another_schedule(model, occupancy_schedule, threshold = 0.05)
        #create new On-Off schedule ruleset.
        availability_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
        availability_ruleset.setName("availabilty_based_on_occupancy")
        #iterate though all rules.
        occupancy_schedule.scheduleRules.each do |occ_rule|
          #Create new hourly rule to populate availability schedule hourly data.
          hourly_data = OpenStudio::Model::ScheduleDay.new(model)
          #set schedule type to availabilty.
          hourly_data.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model))
          #iterate though hour / value pairs for 24 hour period.
          occ_rule.daySchedule().times().each do |time|
            #check if time value is greater or equal to the threshold. If true set hour value to 1, else 0.
            occ_rule.daySchedule().getValue(time) >= threshold ? hourly_data.addValue(time, 1.0) : hourly_data.addValue(time, 0.0)
          end
          #create new rule with hourly data and add to availablity ruleset.
          avail_rule = OpenStudio::Model::ScheduleRule.new(availability_ruleset,hourly_data)
          #Set same start and end date.
          avail_rule.setStartDate(occ_rule.getStartDate)
          avail_rule.setEndDate(occ_rule.getEndDate)
        end #loop occ_rule
        #Make sure to set the default schedule to be the same as well.
        avail_default_day = availability_ruleset.defaultDaySchedule()
        avail_default_day.clearValues()
        #iterate though hour / value pairs for 24 hour period.
        occupancy_schedule.defaultDaySchedule().times().each do |time|
          #check if time value is greater or equal to the threshold. If true set hour value to 1, else 0.
          occupancy_schedule.defaultDaySchedule().getValue(time) >= threshold ? avail_default_day.addValue(time, 1.0) : avail_default_day.addValue(time, 0.0)
        end
        return availability_ruleset
      end


      def self.create_setback_schedule_based_on_another_schedule(
          model,
          occupancy_schedule,
          threshold = 0.05,
          heat_setpoint = 22.0,
          heat_setback = 17.0,
          cool_setpoint = 24.0,
          cool_setback =99.0)
        #create new On-Off schedule ruleset.
        heating_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
        heating_ruleset.setName("heat_thermostat_based_on_occupancy")
        cooling_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
        cooling_ruleset.setName("cool_thermostat_based_on_occupancy")
        #iterate though all rules.
        occupancy_schedule.to_ScheduleRuleset.get.scheduleRules.each do |occ_rule|
          #Create new hourly rule to populate heat/cold schedule hourly data.
          heating_hourly_data = OpenStudio::Model::ScheduleDay.new(model)
          cooling_hourly_data = OpenStudio::Model::ScheduleDay.new(model)
          #set schedule type to availabilty.
          heating_hourly_data.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_temperature(model))
          cooling_hourly_data.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_temperature(model))
          #iterate though hour / value pairs for 24 hour period.
          occ_rule.daySchedule().times().each do |time|
            #check if time value is greater or equal to the threshold. If true set hour value to 1, else 0.
            occ_rule.daySchedule().getValue(time) >= threshold ? heating_hourly_data.addValue(time, heat_setpoint) : heating_hourly_data.addValue(time,heat_setback)
            occ_rule.daySchedule().getValue(time) >= threshold ? cooling_hourly_data.addValue(time, cool_setpoint) : cooling_hourly_data.addValue(time,cool_setback)
          end
          #create new rule with hourly data and add to availablity ruleset.
          heating_avail_rule = OpenStudio::Model::ScheduleRule.new(heating_ruleset,heating_hourly_data)
          cooling_avail_rule = OpenStudio::Model::ScheduleRule.new(cooling_ruleset,cooling_hourly_data)
          #Set same start and end date.
          heating_avail_rule.setStartDate(occ_rule.startDate.get)
          heating_avail_rule.setEndDate(occ_rule.endDate.get)
          cooling_avail_rule.setStartDate(occ_rule.startDate.get)
          cooling_avail_rule.setEndDate(occ_rule.endDate.get)
          #set days enforced.
          heating_avail_rule.setApplySunday(occ_rule.applySunday)
          heating_avail_rule.setApplyMonday(occ_rule.applyMonday)
          heating_avail_rule.setApplyTuesday(occ_rule.applyTuesday)
          heating_avail_rule.setApplyWednesday(occ_rule.applyWednesday)
          heating_avail_rule.setApplyThursday(occ_rule.applyThursday)
          heating_avail_rule.setApplyFriday(occ_rule.applyFriday)
          heating_avail_rule.setApplySaturday(occ_rule.applySaturday)

          cooling_avail_rule.setApplySunday(occ_rule.applySunday)
          cooling_avail_rule.setApplyMonday(occ_rule.applyMonday)
          cooling_avail_rule.setApplyTuesday(occ_rule.applyTuesday)
          cooling_avail_rule.setApplyWednesday(occ_rule.applyWednesday)
          cooling_avail_rule.setApplyThursday(occ_rule.applyThursday)
          cooling_avail_rule.setApplyFriday(occ_rule.applyFriday)
          cooling_avail_rule.setApplySaturday(occ_rule.applySaturday)


        end #loop occ_rule
        #Make sure to set the default schedule to be the same as well.
        heating_default_day = heating_ruleset.defaultDaySchedule()
        heating_default_day.clearValues()
        cooling_default_day = cooling_ruleset.defaultDaySchedule()
        cooling_default_day.clearValues()

        #iterate though hour / value pairs for 24 hour period.
        occupancy_schedule.to_ScheduleRuleset.get.defaultDaySchedule().times().each do |time|
          #check if time value is greater or equal to the threshold. If true set hour value to 1, else 0.
          occupancy_schedule.to_ScheduleRuleset.get.defaultDaySchedule().getValue(time) >= threshold ? heating_default_day.addValue(time, heat_setpoint) : heating_default_day.addValue(time, heat_setback)
          occupancy_schedule.to_ScheduleRuleset.get.defaultDaySchedule().getValue(time) >= threshold ? cooling_default_day.addValue(time, cool_setpoint) : cooling_default_day.addValue(time, cool_setback)
        end
        return heating_ruleset,cooling_ruleset
      end





      #Sets all values in a schedule less than min_value to min_value.
      def self.apply_schedule_minimum(min_value,schedule)
        schedule_ruleset = schedule.to_ScheduleRuleset.get unless schedule.to_ScheduleRuleset.empty?
        schedule_ruleset.scheduleRules.each do |week_rule|
          day_rule = week_rule.daySchedule()
          times = day_rule.times()
          times.each do |time|
            old_value = day_rule.getValue(time).to_f
            day_rule.removeValue(time)
            new_value = old_value
            new_value = min_value if old_value < min_value
            day_rule.addValue(time, new_value)
          end
        end

      end

      #Sets all values in a schedule greater than max_value to max_value.
      def self.apply_schedule_maximum(max_value,schedule)
        schedule_ruleset = schedule.to_ScheduleRuleset.get unless schedule.to_ScheduleRuleset.empty?
        schedule_ruleset.scheduleRules.each do |week_rule|
          day_rule = week_rule.daySchedule()
          times = day_rule.times()
          times.each do |time|
            old_value = day_rule.getValue(time).to_f
            day_rule.removeValue(time)
            new_value = old_value
            new_value = max_value if old_value > max_value
            day_rule.addValue(time, new_value)
          end
        end
      end

      #Creates a new ruleset schedule object. This is the basic schedule component
      #used in openstudio.
      #name = string: name of schedule
      #type = TEMPERATURE, ON_OFF, FRACTION
      #hourArrayValues = a 3 x 24 array representing week, sat and sun hours.
      #examples:
      #hourArrayValues =
      #    [
      #      [18,18,18,18,21,21,21,21,23,23,23,23,23,23,21,21,21,18,18,18,18,18,18,18],#Weekday
      #      [18,18,18,18,21,21,21,21,23,23,23,23,23,23,21,21,21,18,18,18,18,18,18,18],#Saturday
      #      [18,18,18,18,21,21,21,21,23,23,23,23,23,23,21,21,21,18,18,18,18,18,18,18] #Sun
      #    ]
      # or if you need a constant temperature you can use this shorthand method.
      #    heat_setpoint_array =
      #      [
      #      Array.new(24){21}, #Weekday
      #      Array.new(24){21}, #Sat
      #      Array.new(24){21}, #Sun
      #    ]
      def self.create_annual_ruleset_schedule(model,name,type,hourArrayValues,start_date = "Jan-1",end_date = "Dec-31" )
        raise("array size not 3x24. Please verify your hourly array") if hourArrayValues.size != 3 or hourArrayValues[0].size != 24 or hourArrayValues[1].size != 24 or hourArrayValues[2].size != 24
        start_date = BTAP::Common::get_date_from_string(start_date)
        end_date   = BTAP::Common::get_date_from_string(end_date)


        #create new ruleset
        ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
        ruleset.setName(name)



        #set types limits
        case type.downcase
        when "FRACTION".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_fraction(model)
        when "ON_OFF".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model)
        when "TEMPERATURE".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_temperature(model)

        when "ACTIVITY".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_activity(model)
        else
          #if schedule type could not be found raise an exception.
          raise "could  not find schedule limits type :" + type
        end



        #Add days
        weekday = OpenStudio::Model::ScheduleDay.new(model)
        saturday = OpenStudio::Model::ScheduleDay.new(model)
        sunday = OpenStudio::Model::ScheduleDay.new(model)

        weekday.setName(  "wkd" + name )
        saturday.setName( "sat" + name )
        sunday.setName(   "sun" + name )
        if not weekday.setScheduleTypeLimits(scheduletype) or
            not saturday.setScheduleTypeLimits(scheduletype) or
            not sunday.setScheduleTypeLimits(scheduletype)
          raise "unable to set ScheduleDay type limits"
        end

        (0..23).each do|hour|
          weekday.addValue(OpenStudio::Time.new(0,hour+1), hourArrayValues[0][hour] )
          saturday.addValue(OpenStudio::Time.new(0,hour+1), hourArrayValues[1][hour] )
          sunday.addValue(OpenStudio::Time.new(0,hour+1), hourArrayValues[2][hour] )
        end

        #create weekday rule
        weekday_rule = OpenStudio::Model::ScheduleRule.new(ruleset,weekday)
        weekday_rule.setName("wkd" + name + " rule")
        weekday_rule.setApplySunday(false)
        weekday_rule.setApplyMonday(true)
        weekday_rule.setApplyTuesday(true)
        weekday_rule.setApplyWednesday(true)
        weekday_rule.setApplyThursday(true)
        weekday_rule.setApplyFriday(true)
        weekday_rule.setApplySaturday(false)
        weekday_rule.setStartDate(start_date)
        weekday_rule.setEndDate(end_date)

        saturday_rule = OpenStudio::Model::ScheduleRule.new(ruleset,saturday)
        saturday_rule.setName("sat" + name + "rule" )
        saturday_rule.setApplySunday(false)
        saturday_rule.setApplyMonday(false)
        saturday_rule.setApplyTuesday(false)
        saturday_rule.setApplyWednesday(false)
        saturday_rule.setApplyThursday(false)
        saturday_rule.setApplyFriday(false)
        saturday_rule.setApplySaturday(true)
        saturday_rule.setStartDate(start_date)
        saturday_rule.setEndDate(end_date)

        sunday_rule = OpenStudio::Model::ScheduleRule.new(ruleset,sunday)
        sunday_rule.setName("sun" + name + "rule")
        sunday_rule.setApplySunday(true)
        sunday_rule.setApplyMonday(false)
        sunday_rule.setApplyTuesday(false)
        sunday_rule.setApplyWednesday(false)
        sunday_rule.setApplyThursday(false)
        sunday_rule.setApplyFriday(false)
        sunday_rule.setApplySaturday(false)
        sunday_rule.setStartDate(start_date)
        sunday_rule.setEndDate(end_date)

        #set default schedule to be the same as the week schedule.
        default_day =  ruleset.defaultDaySchedule
        default_day.clearValues()
        weekday.times.each_index {|counter| default_day.addValue(weekday.times[counter],weekday.values[counter])}


        return ruleset
      end


      # This method will create a detailed schedule using a "compact format"
      # @param model [OpenStudio::Model::Model]  The building model you wish to add the schedule to.
      # @param name  [String]                    The name of the schedule (Can be left as a blank string "" if you wish.
      # @param type  [String] either "TEMPERATURE", "ON_OFF", "FRACTION"
      # @param schedule_struct [Array<Array>] This is a complex nested array to contain the minimal information required for a detailed schedule.
      [
        [
          #Start and stop date of schedule in gregorian format.
          ["Jan-01","May-31"],
          # Days of the week that it applies
          ["M","T","W","TH","F","S","SN"],# Days of the week are "M","T","W","TH","F","S","SN", or wild cards for weekend and weekdays "WKD","WKE"
          # value up until the hour and minute for each block.
          [
            [ "9:00",  13.0 ], #time, value_until_this_time
            [ "17:00", 21.0 ],  #time, value_until_this_time
            [ "24:00", 13.0 ]  #time, value_until_this_time
          ]
        ],
        [
          #Start and stop date of schedule in gregorian format.
          ["Jun-01","Sep-30"],
          # Days of the week that it applies
          ["M","T","W","TH","F","S","SN"], # Days of the week are "M","T","W","TH","F","S","SN", or wild cards for weekend and weekdays "WKD","WKE"
          # value up until the hour and minute for each block.
          [
            ["24:00", 13.0]  #time, value_until_this_time
          ]
        ],
        [
          #Period for schedule in gregorian format.
          [ "Oct-01","Dec-31"],
          # Days of the week that it applies
          ["M","T","W","TH","F","S","SN"], # Days of the week are "M","T","W","TH","F","S","SN", or wild cards for weekend and weekdays "WKD","WKE"
          # value up until the hour and minute for each block.
          [
            [ "9:00",  13.0], #time, value_until_this_time
            [ "17:00", 22.0], #time, value_until_this_time
            [ "24:00", 13.0]  #time, value_until_this_time
          ]
        ]
      ]

      def self.create_annual_ruleset_schedule_detailed(model,name,type,schedule_struct  )
        #create new ruleset
        ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
        ruleset.setName(name)
        default_day =  ruleset.defaultDaySchedule


        #set types limits
        scheduletype = ""
        case type.downcase
        when "FRACTION".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_fraction(model)
        when "ON_OFF".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model)
        when "TEMPERATURE".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_temperature(model)
          # this will set the default day for temperatures to 23.5C
          default_day.clearValues()
          raise "unable to set ScheduleDay type limits" unless default_day.setScheduleTypeLimits(scheduletype)
          default_day.addValue(BTAP::Common::get_time_from_string( "24:00"), 23.5 )
        when "ACTIVITY".downcase
          scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_activity(model)
          # this will set the default day for temperatures to 23.5C
          default_day.clearValues()
          raise "unable to set ScheduleDay type limits" unless default_day.setScheduleTypeLimits(scheduletype)
          default_day.addValue(BTAP::Common::get_time_from_string( "24:00"), 120.0 )
        else
          #if schedule type could not be found raise an exception.
          raise "could  not find schedule limits type :" + type
        end



        #loop through each schedule ruleset.
        schedule_struct.each do |run_period_profile|

          start_end_dates = run_period_profile[0]
          days_of_the_week = run_period_profile[1]
          hourly_schedule =  run_period_profile[2]

          day_rule = OpenStudio::Model::ScheduleDay.new(model)
          day_rule.setName(  name )
          if not day_rule.setScheduleTypeLimits(scheduletype)
            raise "unable to set ScheduleDay type limits"
          end

          hourly_schedule.each do |hour|
            day_rule.addValue(BTAP::Common::get_time_from_string( hour[0]), hour[1] )
          end

          #create weekday rule
          week_rule = OpenStudio::Model::ScheduleRule.new(ruleset,day_rule)
          #Set Default to false
          week_rule.setApplySunday(false)
          week_rule.setApplyMonday(false)
          week_rule.setApplyTuesday(false)
          week_rule.setApplyWednesday(false)
          week_rule.setApplyThursday(false)
          week_rule.setApplyFriday(false)
          week_rule.setApplySaturday(false)
          # Now set actual days it is applied.
          week_rule.setApplySunday(true) if days_of_the_week.include?("Su") or days_of_the_week.include?("Wke") or days_of_the_week.include?("All")
          week_rule.setApplyMonday(true) if days_of_the_week.include?("M") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
          week_rule.setApplyTuesday(true) if days_of_the_week.include?("T") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
          week_rule.setApplyWednesday(true) if days_of_the_week.include?("W") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
          week_rule.setApplyThursday(true) if days_of_the_week.include?("Th") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
          week_rule.setApplyFriday(true) if days_of_the_week.include?("F") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
          week_rule.setApplySaturday(true) if days_of_the_week.include?("S") or days_of_the_week.include?("Wke") or days_of_the_week.include?("All")

          #Set Period Rule
          week_rule.setStartDate( BTAP::Common::get_date_from_string(start_end_dates[0] ) )
          week_rule.setEndDate( BTAP::Common::get_date_from_string(start_end_dates[1] ) )
        end
        return ruleset
      end

      def self.create_annual_fraction_ruleset_schedule(model,name,hourArrayValues)
        self.create_annual_ruleset_schedule(model,name,"FRACTION",hourArrayValues)
      end

      def self.create_annual_on_off_ruleset_schedule(model,name,hourArrayValues)
        self.create_annual_ruleset_schedule(model,name,"ON_OFF",hourArrayValues)
      end

      def self.create_annual_temperature_ruleset_schedule(model,name,hourArrayValues)
        self.create_annual_ruleset_schedule(model,name,"TEMPERATURE",hourArrayValues)
      end


      # This method will create a detailed schedule using a "compact format"
      # @param model [OpenStudio::Model::Model]  The building model you wish to add the schedule to.
      # @param json_string_data [String] This is a json format to contain the minimal information required for a detailed schedule.
      #   '{"sch":{"name":"always 21C",
      #                  "type":"TEMPERATURE",
      #                  "period_rules":[ {  "start":"Jan-31","end":"Dec-31",
      #                                      "day_rules":[
      #                                                   { "days"      :"M,T,W,T,F,S,SN",
      #                                                     "hour_rules":[ { "value":"21.0", "until":"24:00"},
      #                                                                    { "value":"21.0", "until":"24:00"} ]
      #                                }
      #                              ]
      #                    }
      #                  ]
      #          }}'

      # def self.create_annual_ruleset_schedule_detailed_json(model,json_string_data)
        # #create new ruleset
        # ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
        # json_hash_data = JSON.parse(json_string_data)
        # ruleset.setName(json_hash_data["sch"]["name"])
        # type = json_hash_data["sch"]["type"]
        # default_day =  ruleset.defaultDaySchedule


        # #set types limits
        # scheduletype = ""
        # case type.downcase
        # when "FRACTION".downcase
          # scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_fraction(model)
        # when "ON_OFF".downcase
          # scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model)
        # when "TEMPERATURE".downcase
          # scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_temperature(model)
          # # this will set the default day for temperatures to 23.5C
          # default_day.clearValues()
          # raise "unable to set ScheduleDay type limits" unless default_day.setScheduleTypeLimits(scheduletype)
          # default_day.addValue(BTAP::Common::get_time_from_string( "24:00"), 23.5 )
        # when "ACTIVITY".downcase
          # scheduletype = BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_activity(model)
          # # this will set the default day for activity level  to 120
          # default_day.clearValues()
          # raise "unable to set ScheduleDay type limits" unless default_day.setScheduleTypeLimits(scheduletype)
          # default_day.addValue(BTAP::Common::get_time_from_string( "24:00"), 120.0 )
        # else
          # #if schedule type could not be found raise an exception.
          # raise "could  not find schedule limits type :" + type
        # end

        # scheduletype =  OpenStudio::Model::ScheduleTypeLimits.new( model )
        # #        raise "unable to set ScheduleDay type limits" unless ruleset.setScheduleTypeLimits(scheduletype)


        # #loop through each schedule ruleset Top level Period
        # json_hash_data["sch"]["period_rules"].each do |period_profile|

          # #
          # start_date = period_profile["start"]
          # end_date = period_profile["end"]
          # period_profile[1]

          # period_profile["day_rules"].each do |day_rules|
            # days_of_the_week = day_rules["days"]
            # #Create Day rule.
            # day_rule = OpenStudio::Model::ScheduleDay.new(model)
            # #            if not day_rule.setScheduleTypeLimits(scheduletype)
            # #              raise "unable to set ScheduleDay type limits"
            # #            end

            # day_rules["hour_rules"].each do |hour_rules|
              # day_rule.addValue(BTAP::Common::get_time_from_string( hour_rules["until"]), hour_rules["value"].to_f )
            # end

            # #create weekday rule
            # week_rule = OpenStudio::Model::ScheduleRule.new(ruleset,day_rule)
            # #Set Default to false
            # week_rule.setApplySunday(false)
            # week_rule.setApplyMonday(false)
            # week_rule.setApplyTuesday(false)
            # week_rule.setApplyWednesday(false)
            # week_rule.setApplyThursday(false)
            # week_rule.setApplyFriday(false)
            # week_rule.setApplySaturday(false)
            # # Now set actual days it is applied.
            # week_rule.setApplySunday(true) if days_of_the_week.include?("Su") or days_of_the_week.include?("Wke") or days_of_the_week.include?("All")
            # week_rule.setApplyMonday(true) if days_of_the_week.include?("M") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
            # week_rule.setApplyTuesday(true) if days_of_the_week.include?("T") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
            # week_rule.setApplyWednesday(true) if days_of_the_week.include?("W") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
            # week_rule.setApplyThursday(true) if days_of_the_week.include?("Th") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
            # week_rule.setApplyFriday(true) if days_of_the_week.include?("F") or days_of_the_week.include?("Wkd") or days_of_the_week.include?("All")
            # week_rule.setApplySaturday(true) if days_of_the_week.include?("S") or days_of_the_week.include?("Wke") or days_of_the_week.include?("All")

            # #Set Period Rule
            # week_rule.setStartDate( BTAP::Common::get_date_from_string(start_date ) )
            # week_rule.setEndDate( BTAP::Common::get_date_from_string(end_date ) )
          # end
        # end
        # return ruleset
      # end



      # This method creates a new dual setpoint schedule using pre-created heating and cooling schedules.
      # name - name of schedule.
      # type - type of schedule (FRACTION, ON_OFF, TEMPERATURE)
      # heating_schedule - an heating schedule ruleset object.
      # cooling_schedule - a cooling schedule ruleset object
      def self.create_annual_thermostat_setpoint_dual_setpoint(model,name,heating_schedule,cooling_schedule)

        heating_schedule = BTAP::Common::validate_array(model,heating_schedule,"ScheduleRuleset").first
        cooling_schedule = BTAP::Common::validate_array(model,cooling_schedule,"ScheduleRuleset").first
        dual_setpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
        dual_setpoint.setName(name)
        unless dual_setpoint.setCoolingSchedule(cooling_schedule) and dual_setpoint.setHeatingSchedule(heating_schedule)
          raise "dual setpoint could not be created"
        end
        return dual_setpoint
      end

      # This method creates a new constant schedule.
      # name - name of schedule.
      # type - type of schedule (FRACTION, ON_OFF, TEMPERATURE)
      # value - value to be used over 24 hours.
      def self.create_annual_constant_ruleset_schedule(model, name,type,value)
        return create_annual_ruleset_schedule(model, name,type, [Array.new(24){value}, Array.new(24){value},Array.new(24){value}])
      end

      # Creates TimeSeries from ScheduleRuleset
      # @author david.goldwasser@nrel.gov
      # @param model [OpenStudio::Model::Model] A model object
      # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] A schedule ruleset
      # @return [OpenStudio::TimeSeries] A TimeSeries object
      def self.create_timeseries_from_schedule_ruleset(model, schedule_ruleset)
        yd = model.getYearDescription
        start_date = yd.makeDate(1, 1)
        end_date = yd.makeDate(12, 31)

        values = OpenStudio::DoubleVector.new
        day = OpenStudio::Time.new(1.0)
        interval = OpenStudio::Time.new(1.0 / 48.0)
        day_schedules = schedule_ruleset.to_ScheduleRuleset.get.getDaySchedules(start_date, end_date)
        day_schedules.each do |day_schedule|
          time = interval
          while time < day
            values << day_schedule.getValue(time)
            time += interval
          end
        end
        time_series = OpenStudio::TimeSeries.new(start_date, interval, OpenStudio.createVector(values), "")
      end

      # Creates ScheduleVariableInterval from TimeSeries
      # @author david.goldwasser@nrel.gov
      # @param model [OpenStudio::model::Model] A model object
      # @param time_series [OpenStudio::TimeSeries] A TimeSeries object
      # @return [OpenStudio::Model::ScheduleInterval] An interval schedule
      def self.create_schedule_variable_interval_from_time_series(model, time_series)
        result = OpenStudio::Model::ScheduleInterval.fromTimeSeries(time_series, model).get
      end

    end #module Schedules

  end #module Resources
end
