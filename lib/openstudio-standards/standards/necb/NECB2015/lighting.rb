class NECB2015
  def set_lighting_per_area(space_type, definition, lighting_per_area)
    definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set LPD to #{lighting_per_area} W/ft^2.")
  end
  def apply_lighting_schedule(space_type, space_type_properties,default_sch_set)
    require 'date'
    lighting_per_area = space_type_properties['lighting_per_area'].to_f
    lights_rel_absence_occ = space_type_properties['rel_absence_occ'].to_f
    lights_personal_control = space_type_properties['personal_control'].to_f
    lights_occ_sense = space_type_properties['occ_sense'].to_f
    occupancy_schedule =space_type_properties['occupancy_schedule'].to_s
    orig_lighting_sch = space_type_properties['lighting_schedule'].to_s

    schedule_table = @standards_data['schedules']

    #checks which rules to apply based on LPD
    if lighting_per_area <= 0.799256505 #8.6 W/m2
      #do not apply occupancy sensor control
      orig_lighting_sch = space_type_properties['lighting_schedule']
      unless orig_lighting_sch.nil?
        default_sch_set.setLightingSchedule(model_add_schedule(space_type.model, orig_lighting_sch))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set lighting schedule to #{orig_lighting_sch}.")
      end

    else # LPD > 8.6 W/m2

      #apply occupancy sensor control
      #get occupancy schedule's day rules
      rules = model_find_objects(schedule_table, {'name' => occupancy_schedule}) # returns all schedules with schedule name entered
      #check if it exists
      if rules.size.zero? #does not exist -apply default lighting sched
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find data for schedule: #{occupancy_schedule}. Cannot apply occupancy sensor control for lighting for space: #{space_type.name} ")
        orig_lighting_sch = space_type_properties['lighting_schedule']
        unless orig_lighting_sch.nil?
          default_sch_set.setLightingSchedule(model_add_schedule(space_type.model, orig_lighting_sch))
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set lighting schedule to #{orig_lighting_sch}.")
        end
      else #exists

        #check if schedule exists already . # First check model and return schedule if it already exists
        space_type.model.getSchedules.sort.each do |exisiting_light_ruleset|
          if exisiting_light_ruleset.name.get.to_s == "#{occupancy_schedule}-#{orig_lighting_sch}-#{lights_rel_absence_occ}-#{lights_personal_control}-#{lights_occ_sense}-Light Ruleset"
            OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added schedule: #{exisiting_light_ruleset.name.get.to_s}")
            #set the lighting schedule
            unless exisiting_light_ruleset.nil?
              default_sch_set.setLightingSchedule(exisiting_light_ruleset)
              OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name.to_s} set lighting schedule to #{exisiting_light_ruleset}.")
              return true
            end
          end
        end

        #Create new lighting schedule
        lighting_sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(space_type.model)
        lighting_sch_ruleset.setName("#{occupancy_schedule}-#{orig_lighting_sch}-#{lights_rel_absence_occ}-#{lights_personal_control}-#{lights_occ_sense}-Light Ruleset")
        #loop through the number of day types (each occupancy schedule day)
        rules.each do|rule|
          #get day type, hourly values from the occupancy schedule day
          day_types = rule['day_types'] #Default Wkdy, Wknd, Mon, Tue, Wed, Thu, Fri, Sat, Sun, WntrDsn, SmrDsn
          occupancy_value = rule['values']
          sch_type = rule['type'] #should be 'Hourly'
          start_date = DateTime.parse(rule['start_date'])
          end_date = DateTime.parse(rule['end_date'])
          #create new array to hold occ_control values for each day-type/schedule day
          hourly_occ_control = Array.new
          #loop through hourly values to check if occupancy sensor control should apply and store the new lighting day hourly value
          hourly_index = 0
          for hourly_value in occupancy_value do
            #default light schedule hourly value
            lighting_sched_value = 999
            #get the hourly value from the .json schedule
            #get lighting schedule
            orig_lighting_rules = model_find_objects(schedule_table, {'name' => orig_lighting_sch}) # returns all schedules with schedule name
            if orig_lighting_rules.size.zero?
              OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find data for schedule: #{orig_lighting_sch}.")
            end
            if hourly_value<lights_rel_absence_occ
              #occupancy sensor control applies for this hour
              occ_control = 1-(lights_rel_absence_occ*lights_occ_sense)-lights_personal_control
              #go through lighitng schedule and adjust the value for the hour
              orig_lighting_rules.each do |orig_lighting_rule|
                if day_types == orig_lighting_rule['day_types'] #if light day schedule type matches occupancy day type
                  orig_hourly_values =orig_lighting_rule['values']
                  lighting_sched_value = (orig_hourly_values[hourly_index])*occ_control

                end
              end

            else
              #occupancy sensor control does not apply for this hour. Use default schedule value from .json file
              #go through each lighting schedule day  to find the one with the matching day type
              #assuming occupancy schedule day matches lighting schedule day
              orig_lighting_rules.each do |orig_lighting_rule|
                if day_types == orig_lighting_rule['day_types'] #if light day schedule type matches occupancy day type
                  orig_hourly_values =orig_lighting_rule['values']
                  occ_control =1
                  lighting_sched_value = orig_hourly_values[hourly_index] #set the current hourly_index's original lighting schedule day value to lighting_sched_value

                end

              end
            end # if hourly_value<lights_rel_absence_occ
            #store the lighting_sched_value factor for this hour to the array
            hourly_occ_control << lighting_sched_value
            #update index
            hourly_index = hourly_index + 1
          end #for hourly_value in occupancy_value do

          #for each schedule day, create a new day rule with the new hourly schedule values for lighting
          if day_types.include?('Default')
            day_sch = lighting_sch_ruleset.defaultDaySchedule
            day_sch.setName("#{occupancy_schedule}-#{orig_lighting_sch}-#{lights_rel_absence_occ}-#{lights_personal_control}-#{lights_occ_sense}-Light Default")
            model_add_vals_to_sch(space_type.model, day_sch, sch_type, hourly_occ_control)
          end
          if day_types.include?('Wknd') ||
              day_types.include?('Wkdy') ||
              day_types.include?('Sat') ||
              day_types.include?('Sun') ||
              day_types.include?('Mon') ||
              day_types.include?('Tue') ||
              day_types.include?('Wed') ||
              day_types.include?('Thu') ||
              day_types.include?('Fri')
            # Make the Rule
            sch_rule = OpenStudio::Model::ScheduleRule.new(lighting_sch_ruleset)
            day_sch = sch_rule.daySchedule
            day_sch.setName("#{occupancy_schedule}-#{orig_lighting_sch}-#{lights_rel_absence_occ}-#{lights_personal_control}-#{lights_occ_sense}-#{day_types}-Light Day")
            model_add_vals_to_sch(space_type.model, day_sch, sch_type, hourly_occ_control)
            # Set the dates when the rule applies
            sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_date.month.to_i), start_date.day.to_i))
            sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_date.month.to_i), end_date.day.to_i))
            # Set the days when the rule applies
            # Weekends
            if day_types.include?('Wknd')
              sch_rule.setApplySaturday(true)
              sch_rule.setApplySunday(true)
            end
            # Weekdays
            if day_types.include?('Wkdy')
              sch_rule.setApplyMonday(true)
              sch_rule.setApplyTuesday(true)
              sch_rule.setApplyWednesday(true)
              sch_rule.setApplyThursday(true)
              sch_rule.setApplyFriday(true)
            end
            # Individual Days
            sch_rule.setApplyMonday(true) if day_types.include?('Mon')
            sch_rule.setApplyTuesday(true) if day_types.include?('Tue')
            sch_rule.setApplyWednesday(true) if day_types.include?('Wed')
            sch_rule.setApplyThursday(true) if day_types.include?('Thu')
            sch_rule.setApplyFriday(true) if day_types.include?('Fri')
            sch_rule.setApplySaturday(true) if day_types.include?('Sat')
            sch_rule.setApplySunday(true) if day_types.include?('Sun')
          end
          if day_types.include?('WntrDsn')
            day_sch = OpenStudio::Model::ScheduleDay.new(space_type.model)
            lighting_sch_ruleset.setWinterDesignDaySchedule(day_sch)
            day_sch = lighting_sch_ruleset.winterDesignDaySchedule
            day_sch.setName("#{occupancy_schedule}-#{orig_lighting_sch}-#{lights_rel_absence_occ}-#{lights_personal_control}-#{lights_occ_sense}-Light Winter Design")
            model_add_vals_to_sch(space_type.model, day_sch, sch_type, hourly_occ_control)
          end
          if day_types.include?('SmrDsn')
            day_sch = OpenStudio::Model::ScheduleDay.new(space_type.model)
            lighting_sch_ruleset.setSummerDesignDaySchedule(day_sch)
            day_sch = lighting_sch_ruleset.summerDesignDaySchedule
            day_sch.setName("#{occupancy_schedule}-#{orig_lighting_sch}-#{lights_rel_absence_occ}-#{lights_personal_control}-#{lights_occ_sense}-Light Summer Design")
            model_add_vals_to_sch(space_type.model, day_sch, sch_type, hourly_occ_control)
          end
        end #rules.each do|rule|
        #set the lighting schedule
        unless lighting_sch_ruleset.nil?
          default_sch_set.setLightingSchedule(lighting_sch_ruleset)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name.to_s} set lighting schedule to #{lighting_sch_ruleset}.")
        end
      end #if rules.size.zero? #does not exist
    end #if lighting_per_area <= 0.7999256505 #8.6 W/m2
  end
end