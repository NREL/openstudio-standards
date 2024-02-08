# Methods to create and modify parametric schedules
module OpenstudioStandards
  module Schedules
    # @!group Parametric

    # @!group Parametric:Model

    # This method looks at occupancy profiles for the building as a whole and generates an hours of operation default
    # schedule for the building. It also clears out any higher level hours of operation schedule assignments.
    # Spaces are organized by res and non_res. Whichever of the two groups has higher design level of people is used for building hours of operation
    # Resulting hours of operation can have as many rules as necessary to describe the operation.
    # Each ScheduleDay should be an on/off schedule with only values of 0 and 1. There should not be more than one on/off cycle per day.
    # In future this could create different hours of operation for residential vs. non-residential, by building type, story, or space type.
    # However this measure is a stop gap to convert old generic schedules to parametric schedules.
    # Future new schedules should be designed as paramtric from the start and would not need to run through this inference process
    #
    # @author David Goldwasser
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param fraction_of_daily_occ_range [Double] fraction above/below daily min range required to start and end hours of operation
    # @param invert_res [Boolean] if true will reverse hours of operation for residential space types
    # @param gen_occ_profile [Boolean] if true creates a merged occupancy schedule for diagnostic purposes. This schedule is added to the model but no specifically returned by this method
    # @return [ScheduleRuleset] schedule that is assigned to the building as default hours of operation
    def self.model_infer_hours_of_operation_building(model, fraction_of_daily_occ_range: 0.25, invert_res: true, gen_occ_profile: false)
      # create an array of non-residential and residential spaces
      res_spaces = []
      non_res_spaces = []
      res_people_design = 0
      non_res_people_design = 0
      model.getSpaces.sort.each do |space|
        if OpenstudioStandards::Space.space_residential?(space)
          res_spaces << space
          res_people_design += space.numberOfPeople * space.multiplier
        else
          non_res_spaces << space
          non_res_people_design += space.numberOfPeople * space.multiplier
        end
      end
      OpenStudio.logFree(OpenStudio::Info, 'Openstudio.standards.Schedules', "Model has design level of #{non_res_people_design} people in non residential spaces and #{res_people_design} people in residential spaces.")

      # create merged schedule for prevalent type (not used but can be generated for diagnostics)
      if gen_occ_profile
        res_prevalent = false
        if res_people_design > non_res_people_design
          occ_merged = OpenStudioStandards::Space.spaces_get_occupancy_schedule(res_spaces, sch_name: 'Calculated Occupancy Fraction Residential Merged')
          res_prevalent = true
        else
          occ_merged = OpenStudioStandards::Space.spaces_get_occupancy_schedule(non_res_spaces, sch_name: 'Calculated Occupancy Fraction NonResidential Merged')
        end
      end

      # re-run spaces_get_occupancy_schedule with x above min occupancy to create on/off schedule
      if res_people_design > non_res_people_design
        hours_of_operation = OpenStudioStandards::Space.spaces_get_occupancy_schedule(res_spaces,
                                                          sch_name: 'Building Hours of Operation Residential',
                                                          occupied_percentage_threshold: fraction_of_daily_occ_range,
                                                          threshold_calc_method: 'normalized_daily_range')
        res_prevalent = true
      else
        hours_of_operation = OpenStudioStandards::Space.spaces_get_occupancy_schedule(non_res_spaces,
                                                          sch_name: 'Building Hours of Operation NonResidential',
                                                          occupied_percentage_threshold: fraction_of_daily_occ_range,
                                                          threshold_calc_method: 'normalized_daily_range')
      end

      # remove gaps resulting in multiple on off cycles for each rule in schedule so it will be valid hours of operation
      profiles = []
      profiles << hours_of_operation.defaultDaySchedule
      hours_of_operation.scheduleRules.each do |rule|
        profiles << rule.daySchedule
      end
      profiles.sort.each do |profile|
        times = profile.times
        values = profile.values
        next if times.size <= 3 # length of 1-3 should produce valid hours_of_operation profiles

        # Find the latest time where the value == 1
        latest_time = nil
        times.zip(values).each do |time, value|
          if value > 0
            latest_time = time
          end
        end
        # Skip profiles that are zero all the time
        next if latest_time.nil?

        # Calculate the duration from this point to midnight
        wrap_dur_left_hr = 0
        if values.first == 0 && values.last == 0
          wrap_dur_left_hr = 24.0 - latest_time.totalHours
        end
        occ_gap_hash = {}
        prev_time = 0
        prev_val = nil
        times.each_with_index do |time, i|
          next if time.totalHours == 0.0 # should not see this
          next if values[i] == prev_val # check if two 0 until time next to each other

          if values[i] == 0 # only store vacant segments
            if time.totalHours == 24
              occ_gap_hash[prev_time] = time.totalHours - prev_time + wrap_dur_left_hr
            else
              occ_gap_hash[prev_time] = time.totalHours - prev_time
            end
          end
          prev_time = time.totalHours
          prev_val = values[i]
        end
        profile.clearValues
        max_occ_gap_start = occ_gap_hash.key(occ_gap_hash.values.max)
        max_occ_gap_end_hr = max_occ_gap_start + occ_gap_hash[max_occ_gap_start] # can't add time and duration in hours
        if max_occ_gap_end_hr > 24.0 then max_occ_gap_end_hr -= 24.0 end

        # time for gap start
        target_start_hr = max_occ_gap_start.truncate
        target_start_min = ((max_occ_gap_start - target_start_hr) * 60.0).truncate
        max_occ_gap_start = OpenStudio::Time.new(0, target_start_hr, target_start_min, 0)

        # time for gap end
        target_end_hr = max_occ_gap_end_hr.truncate
        target_end_min = ((max_occ_gap_end_hr - target_end_hr) * 60.0).truncate
        max_occ_gap_end = OpenStudio::Time.new(0, target_end_hr, target_end_min, 0)

        profile.addValue(max_occ_gap_start, 1)
        profile.addValue(max_occ_gap_end, 0)
        os_time_24 = OpenStudio::Time.new(0, 24, 0, 0)
        if max_occ_gap_start > max_occ_gap_end
          profile.addValue(os_time_24, 0)
        else
          profile.addValue(os_time_24, 1)
        end
      end

      # reverse 1 and 0 values for res_prevalent building
      # currently spaces_get_occupancy_schedule doesn't use defaultDayProflie, so only inspecting rules for now.
      if invert_res && res_prevalent
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', 'Per argument passed in hours of operation are being inverted for buildings with more people in residential versus non-residential spaces.')
        hours_of_operation.scheduleRules.each do |rule|
          profile = rule.daySchedule
          times = profile.times
          values = profile.values
          profile.clearValues
          times.each_with_index do |time, i|
            orig_val = values[i]
            new_value = nil
            if orig_val == 0 then new_value = 1 end
            if orig_val == 1 then new_value = 0 end
            profile.addValue(time, new_value)
          end
        end
      end

      # set hours of operation for building level hours of operation
      model.getDefaultScheduleSets.each(&:resetHoursofOperationSchedule)
      if model.getBuilding.defaultScheduleSet.is_initialized
        default_sch_set = model.getBuilding.defaultScheduleSet.get
      else
        default_sch_set = OpenStudio::Model::DefaultScheduleSet.new(model)
        default_sch_set.setName('Building Default Schedule Set')
        model.getBuilding.setDefaultScheduleSet(default_sch_set)
      end
      default_sch_set.setHoursofOperationSchedule(hours_of_operation)

      return hours_of_operation
    end

    # This method users the hours of operation for a space and the existing ScheduleRuleset profiles to setup parametric schedule
    # inputs. Inputs include one or more load profile formulas. Data is stored in model attributes for downstream
    # application. This should impact all ScheduleRuleset objects in the model. Plant and Air loop hoours of operations
    # should be traced back to a space or spaces.
    #
    # @author David Goldwasser
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param step_ramp_logic [String] type of step logic to use
    # @param infer_hoo_for_non_assigned_objects [Boolean] attempt to get hoo for objects like swh with and exterior lighting
    # @param gather_data_only [Boolean] false (stops method before changes made if true)
    # @param hoo_var_method [String] accepts hours and fractional. Any other value value will result in hoo variables not being applied
    # @return [Hash] schedule is key, value is hash of number of objects
    def self.model_setup_parametric_schedules(model, step_ramp_logic: nil, infer_hoo_for_non_assigned_objects: true, gather_data_only: false, hoo_var_method: 'hours')
      parametric_inputs = {}
      default_sch_type = OpenStudio::Model::DefaultScheduleType.new('HoursofOperationSchedule')
      # thermal zones, air loops, plant loops will require some logic if they refer to more than one hours of operaiton schedule.
      # for initial use case while have same horus of operaiton so this can be pretty simple, but will have to re-visit it sometime
      # possible solution A: choose hoo that contributes the largest fraction of floor area
      # possible solution B: expand the hours of operation for a given day to include combined range of hoo objects
      # whatever approach is used for gathering parametric inputs for existing ruleset schedules should also be used for model_apply_parametric_schedules

      # loop through spaces (trace hours of operation back to space)
      gather_inputs_parametric_space_space_type_schedules(model.getSpaces, parametric_inputs, gather_data_only)

      # loop through space types (trace hours of operation back to space type).
      gather_inputs_parametric_space_space_type_schedules(model.getSpaceTypes, parametric_inputs, gather_data_only)

      # loop through thermal zones (trace hours of operation back to spaces in thermal zone)
      thermal_zone_hash = {} # key is zone and hash is hours of operation
      model.getThermalZones.sort.each do |zone|
        # identify hours of operation
        hours_of_operation = spaces_hours_of_operation(zone.spaces)
        thermal_zone_hash[zone] = hours_of_operation
        # get thermostat setpoint schedules
        if zone.thermostatSetpointDualSetpoint.is_initialized
          thermostat = zone.thermostatSetpointDualSetpoint.get
          if thermostat.heatingSetpointTemperatureSchedule.is_initialized && thermostat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.is_initialized
            schedule = thermostat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
            gather_inputs_parametric_schedules(schedule, thermostat, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
          end
          if thermostat.coolingSetpointTemperatureSchedule.is_initialized && thermostat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.is_initialized
            schedule = thermostat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
            gather_inputs_parametric_schedules(schedule, thermostat, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
          end
        end
      end

      # loop through air loops (trace hours of operation back through spaces served by air loops)
      air_loop_hash = {} # key is zone and hash is hours of operation
      model.getAirLoopHVACs.sort.each do |air_loop|
        # identify hours of operation
        air_loop_spaces = []
        air_loop.thermalZones.sort.each do |zone|
          air_loop_spaces += zone.spaces
          air_loop_spaces += zone.spaces
        end
        hours_of_operation = spaces_hours_of_operation(air_loop_spaces)
        air_loop_hash[air_loop] = hours_of_operation
        if air_loop.availabilitySchedule.to_ScheduleRuleset.is_initialized
          schedule = air_loop.availabilitySchedule.to_ScheduleRuleset.get
          gather_inputs_parametric_schedules(schedule, air_loop, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
        end
        avail_mgrs = air_loop.availabilityManagers
        avail_mgrs.sort.each do |avail_mgr|
          # @todo I'm finding availability mangers, but not any resources for them, even if I use OpenStudio::Model.getRecursiveChildren(avail_mgr)
          resources = avail_mgr.resources
          resources = OpenStudio::Model.getRecursiveResources(avail_mgr)
          resources.sort.each do |resource|
            if resource.to_ScheduleRuleset.is_initialized
              schedule = resource.to_ScheduleRuleset.get
              gather_inputs_parametric_schedules(schedule, avail_mgr, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
            end
          end
        end
      end

      # look through all model HVAC components find scheduleRuleset objects, resources, that use them and zone or air loop for hours of operation
      hvac_components = model.getHVACComponents
      hvac_components.sort.each do |component|
        # identify zone, or air loop it refers to, some may refer to plant loop, OA or other component
        thermal_zone = nil
        air_loop = nil
        plant_loop = nil
        schedules = []
        if component.to_ZoneHVACComponent.is_initialized && component.to_ZoneHVACComponent.get.thermalZone.is_initialized
          thermal_zone = component.to_ZoneHVACComponent.get.thermalZone.get
        end
        if component.airLoopHVAC.is_initialized
          air_loop = component.airLoopHVAC.get
        end
        if component.plantLoop.is_initialized
          plant_loop = component.plantLoop.get
        end
        component.resources.sort.each do |resource|
          if resource.to_ThermalZone.is_initialized
            thermal_zone = resource.to_ThermalZone.get
          elsif resource.to_ScheduleRuleset.is_initialized
            schedules << resource.to_ScheduleRuleset.get
          end
        end

        # inspect resources for children of objects found in thermal zone or plant loop
        # get objects like OA controllers and unitary object components
        next if thermal_zone.nil? && air_loop.nil?

        children = OpenStudio::Model.getRecursiveChildren(component)
        children.sort.each do |child|
          child.resources.sort.each do |sub_resource|
            if sub_resource.to_ScheduleRuleset.is_initialized
              schedules << sub_resource.to_ScheduleRuleset.get
            end
          end
        end

        # process schedules found for this component
        schedules.sort.each do |schedule|
          hours_of_operation = nil
          if !thermal_zone.nil?
            hours_of_operation = thermal_zone_hash[thermal_zone]
          elsif !air_loop.nil?
            hours_of_operation = air_loop_hash[air_loop]
          elsif !plant_loop.nil?
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "#{schedule.name.get} is associated with plant loop, will not gather parametric inputs")
            next
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Cannot identify where #{component.name.get} is in system. Will not gather parametric inputs for #{schedule.name.get}")
            next
          end
          gather_inputs_parametric_schedules(schedule, component, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
        end
      end

      # @todo Service Water Heating supply side (may or may not be associated with a space)
      # @todo water use equipment definitions (temperature, sensible, latent) may be in multiple spaces, need to identify hoo, but typically constant schedules

      # water use equipment (flow rate fraction)
      # @todo address common schedules used across multiple instances
      model.getWaterUseEquipments.sort.each do |water_use_equipment|
        if water_use_equipment.flowRateFractionSchedule.is_initialized && water_use_equipment.flowRateFractionSchedule.get.to_ScheduleRuleset.is_initialized
          schedule = water_use_equipment.flowRateFractionSchedule.get.to_ScheduleRuleset.get
          next if parametric_inputs.key?(schedule)

          opt_space = water_use_equipment.space
          if opt_space.is_initialized
            space = space.get
            hours_of_operation = space_hours_of_operation(space)
            gather_inputs_parametric_schedules(schedule, water_use_equipment, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
          else
            hours_of_operation = spaces_hours_of_operation(model.getSpaces)
            if !hours_of_operation.nil?
              gather_inputs_parametric_schedules(schedule, water_use_equipment, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
            end
          end

        end
      end
      # @todo Refrigeration (will be associated with thermal zone)
      # @todo exterior lights (will be astronomical, but like AEDG's may have reduction later at night)

      return parametric_inputs
    end

    # This method applies the hours of operation for a space and the load profile formulas in the overloaded ScheduleRulset
    # objects to update time value pairs for ScheduleDay objects. Object type specific logic will be used to generate profiles
    # for summer and winter design days.
    #
    # @note This measure will replace any prior chagnes made to ScheduleRule objects with new ScheduleRule values from
    # profile formulas
    # @author David Goldwasser
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param ramp_frequency [Double] ramp frequency in minutes. If nil method will match simulation timestep
    # @param infer_hoo_for_non_assigned_objects [Boolean] # attempt to get hoo for objects like swh with and exterior lighting
    # @param error_on_out_of_order [Boolean] true will error if applying formula creates out of order values
    # @return [Array] of modified ScheduleRuleset objects
    def self.model_apply_parametric_schedules(model, ramp_frequency: nil, infer_hoo_for_non_assigned_objects: true, error_on_out_of_order: true)
      # get ramp frequency (fractional hour) from timestep
      if ramp_frequency.nil?
        steps_per_hour = if model.getSimulationControl.timestep.is_initialized
                          model.getSimulationControl.timestep.get.numberOfTimestepsPerHour
                        else
                          6 # default OpenStudio timestep if none specified
                        end
        ramp_frequency = 1.0 / steps_per_hour.to_f
      end

      # Go through model and create parametric formulas for all schedules
      parametric_inputs = model_setup_parametric_schedules(model, gather_data_only: true)

      parametric_schedules = []
      model.getScheduleRulesets.sort.each do |sch|
        if !sch.hasAdditionalProperties || !sch.additionalProperties.hasFeature('param_sch_ver')
          # for now don't look at schedules without targets, in future can alter these by looking at building level hours of operation
          next if sch.directUseCount <= 0 # won't catch if used for space type load instance, but that space type isn't used

          # @todo address schedules that fall into this category, if they are used in the model
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "For #{sch.sources.first.name}, #{sch.name} is not setup as parametric schedule. It has #{sch.sources.size} sources.")
          next
        end

        # apply parametric inputs
        schedule_ruleset_apply_parametric_inputs(sch, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order, parametric_inputs)

        # add schedule to array
        parametric_schedules << sch
      end

      return parametric_schedules
    end

    # @!endgroup Parametric:Model

    # @!group Parametric:ScheduleRuleset

    # Apply specified hours of operation values to rules in this schedule.
    # Weekday values will be applied to the default profile.
    # Weekday values will be applied to any rules that are used on a weekday.
    # Saturday values will be applied to any rules that are used on a Saturday.
    # Sunday values will be applied to any rules that are used on a Sunday.
    # If a rule applies to Weekdays, Saturdays, and/or Sundays, values will be applied in that order of precedence.
    # If a rule does not apply to any of these days, it is unused and will not be modified.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
    # @param wkdy_start_time [OpenStudio::Time] Weekday start time. If nil, no change will be made to this day.
    # @param wkdy_end_time [OpenStudio::Time] Weekday end time.  If greater than 24:00, hours of operation will wrap over midnight.
    # @param sat_start_time [OpenStudio::Time] Saturday start time. If nil, no change will be made to this day.
    # @param sat_end_time [OpenStudio::Time] Saturday end time.  If greater than 24:00, hours of operation will wrap over midnight.
    # @param sun_start_time [OpenStudio::Time] Sunday start time.  If nil, no change will be made to this day.
    # @param sun_end_time [OpenStudio::Time] Sunday end time.  If greater than 24:00, hours of operation will wrap over midnight.
    # @return [Boolean] returns true if successful, false if not
    def self.schedule_ruleset_set_hours_of_operation(schedule_ruleset, wkdy_start_time: nil, wkdy_end_time: nil, sat_start_time: nil, sat_end_time: nil, sun_start_time: nil, sun_end_time: nil)
      # Default day is assumed to represent weekdays
      if wkdy_start_time && wkdy_end_time
        schedule_day_set_hours_of_operation(schedule_ruleset.defaultDaySchedule, wkdy_start_time, wkdy_end_time)
        # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set default operating hours to #{wkdy_start_time}-#{wkdy_end_time}.")
      end

      # Modify each rule
      schedule_ruleset.scheduleRules.each do |rule|
        if rule.applyMonday || rule.applyTuesday || rule.applyWednesday || rule.applyThursday || rule.applyFriday
          if wkdy_start_time && wkdy_end_time
            schedule_day_set_hours_of_operation(rule.daySchedule, wkdy_start_time, wkdy_end_time)
            # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set Saturday rule operating hours to #{wkdy_start_time}-#{wkdy_end_time}.")
          end
        elsif rule.applySaturday
          if sat_start_time && sat_end_time
            schedule_day_set_hours_of_operation(rule.daySchedule, sat_start_time, sat_end_time)
            # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set Saturday rule operating hours to #{sat_start_time}-#{sat_end_time}.")
          end
        elsif rule.applySunday
          if sun_start_time && sun_end_time
            schedule_day_set_hours_of_operation(rule.daySchedule, sun_start_time, sun_end_time)
            # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set Sunday rule operating hours to #{sun_start_time}-#{sun_end_time}.")
          end
        end
      end

      return true
    end

    # this will use parametric inputs contained in schedule and profiles along with inferred hours of operation to generate updated ruleset schedule profiles
    #
    # @author David Goldwasser
    # @param schedule [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
    # @param ramp_frequency [Double] ramp frequency in minutes
    # @param infer_hoo_for_non_assigned_objects [Boolean] attempt to get hoo for objects like swh with and exterior lighting
    # @param error_on_out_of_order [Boolean] true will error if applying formula creates out of order values
    # @return [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
    def self.schedule_ruleset_apply_parametric_inputs(schedule_ruleset, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order, parametric_inputs = nil)
      # Check if parametric inputs were supplied and generate them if not
      if parametric_inputs.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, no parametric inputs were not supplied so they will be generated now.")
        parametric_inputs = model_setup_parametric_schedules(schedule.model, gather_data_only: true)
      end

      # Check that parametric inputs exist for this schedule after generation
      if parametric_inputs[schedule_ruleset].nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, no parametric inputs exists so schedule will not be changed.")
        return schedule_ruleset
      end

      # Check that an hours of operation schedule is associated with this schedule
      if parametric_inputs[schedule_ruleset][:hoo_inputs].nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, no associated hours of operation schedule was found so schedule will not be changed.")
        return schedule_ruleset
      end

      # Get the hours of operation schedule
      hours_of_operation = parametric_inputs[schedule_ruleset][:hoo_inputs]
      # OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name} hours_of_operation = #{hours_of_operation.name}.")

      starting_aeflh = OpenstudioStandards::Schedules.schedule_ruleset_get_equivalent_full_load_hours(schedule_ruleset)

      # store floor and ceiling value
      val_flr = nil
      if schedule_ruleset.hasAdditionalProperties && schedule_ruleset.additionalProperties.hasFeature('param_sch_floor')
        val_flr = schedule_ruleset.additionalProperties.getFeatureAsDouble('param_sch_floor').get
      end
      val_clg = nil
      if schedule_ruleset.hasAdditionalProperties && schedule_ruleset.additionalProperties.hasFeature('param_sch_ceiling')
        val_clg = schedule_ruleset.additionalProperties.getFeatureAsDouble('param_sch_ceiling').get
      end

      # loop through schedule days from highest to lowest priority (with default as lowest priority)
      # if rule needs to be split to address hours of operation rules add new rule next to relevant existing rule
      profiles = {}
      schedule_ruleset.scheduleRules.each do |rule|
        # remove any use manually generated non parametric rules or any auto-generated rules from prior application of formulas and hoo
        sch_day = rule.daySchedule
        if !sch_day.hasAdditionalProperties || !sch_day.additionalProperties.hasFeature('param_day_tag') || (sch_day.additionalProperties.getFeatureAsString('param_day_tag').get == 'autogen')
          sch_day.remove # remove day schedule for this rule
          rule.remove # remove the rule
        elsif !sch_day.additionalProperties.hasFeature('param_day_profile')
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "#{schedule.name} doesn't have a parametric formula for #{rule.name} This profile will not be altered.")
          next
        else
          profiles[sch_day] = rule
        end
      end
      profiles[schedule_ruleset.defaultDaySchedule] = nil

      # get indices for current schedule
      year_description = schedule_ruleset.model.yearDescription.get
      year = year_description.assumedYear
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
      indices_vector = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)

      # process profiles
      profiles.each do |sch_day, rule|
        # for current profile index identify hours of operation index that contains all days
        if rule.nil?
          current_rule_index = -1
        else
          current_rule_index = rule.ruleIndex
        end

        # loop through indices looking of rule in hoo that contains days in the rule
        hoo_target_index = nil
        days_used = []
        indices_vector.each_with_index do |profile_index, i|
          if profile_index == current_rule_index then days_used << i + 1 end
        end
        # find days_used in hoo profiles that contains all days used from this profile
        hoo_profile_match_hash = {}
        best_fit_check = {}
        hours_of_operation.each do |profile_index, value|
          days_for_rule_not_in_hoo_profile = days_used - value[:days_used]
          hoo_profile_match_hash[profile_index] = days_for_rule_not_in_hoo_profile
          best_fit_check[profile_index] = days_for_rule_not_in_hoo_profile.size
          if days_for_rule_not_in_hoo_profile.empty?
            hoo_target_index = profile_index
          end
        end
        clone_needed = false
        hoo_target_index = best_fit_check.key(best_fit_check.values.min)
        if best_fit_check[hoo_target_index] > 0
          clone_needed = true
        end

        # get hours of operation for this specific profile
        hoo_start = hours_of_operation[hoo_target_index][:hoo_start]
        hoo_end = hours_of_operation[hoo_target_index][:hoo_end]

        # update scheduleDay
        process_hrs_of_operation_hash(sch_day, hoo_start, hoo_end, val_flr, val_clg, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order)

        # clone new rule if needed
        if clone_needed

          # make list of new rules needed as has or array
          autogen_rules = {}
          days_to_fill = hoo_profile_match_hash[hoo_target_index]
          hours_of_operation.each do |profile_index, value|
            remainder = days_to_fill - value[:days_used]
            day_for_rule = days_to_fill - remainder
            if remainder.size < days_to_fill.size
              autogen_rules[profile_index] = { days_to_fill: day_for_rule, hoo_start: hoo_start, hoo_end: hoo_end }
            end
            days_to_fill = remainder
          end

          # loop through new rules to make and process
          autogen_rules.each do |autogen_rule, hash|
            # generate new rule
            sch_rule_autogen = OpenStudio::Model::ScheduleRule.new(schedule)
            if current_rule_index
              target_index = schedule.scheduleRules.size - 1 # just above default
            else
              target_index = current_rule_index - 1 # confirm just above orig rule
            end
            current_rule_index = target_index
            if rule.nil?
              sch_rule_autogen.setName("autogen #{schedule.name} #{target_index}")
            else
              sch_rule_autogen.setName("autogen #{rule.name} #{target_index}")
            end
            schedule_ruleset.setScheduleRuleIndex(sch_rule_autogen, target_index)
            # @todo confirm this is higher priority than the non-auto-generated rule
            hash[:days_to_fill].each do |day|
              date = OpenStudio::Date.fromDayOfYear(day, year)
              sch_rule_autogen.addSpecificDate(date)
            end
            sch_rule_autogen.setApplySunday(true)
            sch_rule_autogen.setApplyMonday(true)
            sch_rule_autogen.setApplyTuesday(true)
            sch_rule_autogen.setApplyWednesday(true)
            sch_rule_autogen.setApplyThursday(true)
            sch_rule_autogen.setApplyFriday(true)
            sch_rule_autogen.setApplySaturday(true)

            # match profile from source rule (don't add time/values need a formula to process)
            sch_day_auto_gen = sch_rule_autogen.daySchedule
            sch_day_auto_gen.setName("#{sch_rule_autogen.name}_day_sch")
            sch_day_auto_gen.additionalProperties.setFeature('param_day_tag', 'autogen')
            val = sch_day.additionalProperties.getFeatureAsString('param_day_profile').get
            sch_day_auto_gen.additionalProperties.setFeature('param_day_profile', val)
            val = sch_day.additionalProperties.getFeatureAsString('param_day_secondary_logic').get
            sch_day_auto_gen.additionalProperties.setFeature('param_day_secondary_logic', val)
            val = sch_day.additionalProperties.getFeatureAsString('param_day_secondary_logic_arg_val').get
            sch_day_auto_gen.additionalProperties.setFeature('param_day_secondary_logic_arg_val', val)

            # get hours of operation for this specific profile
            hoo_start = hash[:hoo_start]
            hoo_end = hash[:hoo_end]

            # process new rule
            process_hrs_of_operation_hash(sch_day_auto_gen, hoo_start, hoo_end, val_flr, val_clg, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order)
          end

        end
      end

      # @todo create summer and winter design day profiles (make sure scheduleDay objects parametric)
      # @todo should they have their own formula, or should this be hard coded logic by schedule type

      # check orig vs. updated aeflh
      final_aeflh = OpenstudioStandards::Schedules.schedule_ruleset_get_equivalent_full_load_hours(schedule_ruleset)
      percent_change = ((starting_aeflh - final_aeflh) / starting_aeflh) * 100.0
      if percent_change.abs > 0.05
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule.name}, applying parametric schedules made a #{percent_change.round(1)}% change in annual equivalent full load hours. (from #{starting_aeflh.round(2)} to #{final_aeflh.round(2)})")
      end

      return schedule_ruleset
    end

    # @!endgroup Parametric:ScheduleRuleset

    # @!group Parametric:ScheduleDay

    # Set the hours of operation (0 or 1) for a ScheduleDay.
    # Clears out existing time/value pairs and sets to supplied values.
    #
    # @author Andrew Parker
    # @param schedule_day [OpenStudio::Model::ScheduleDay] The day schedule to set.
    # @param start_time [OpenStudio::Time] Start time.
    # @param end_time [OpenStudio::Time] End time.  If greater than 24:00, hours of operation will wrap over midnight.
    #
    # @return [Void]
    # @api private
    def self.schedule_day_set_hours_of_operation(schedule_day, start_time, end_time)
      schedule_day.clearValues
      twenty_four_hours = OpenStudio::Time.new(0, 24, 0, 0)
      if end_time < twenty_four_hours
        # Operating hours don't wrap over midnight
        schedule_day.addValue(start_time, 0) # 0 until start time
        schedule_day.addValue(end_time, 1) # 1 from start time until end time
        schedule_day.addValue(twenty_four_hours, 0) # 0 after end time
      else
        # Operating hours start on previous day
        schedule_day.addValue(end_time - twenty_four_hours, 1) # 1 for hours started on the previous day
        schedule_day.addValue(start_time, 0) # 0 from end of previous days hours until start of today's
        schedule_day.addValue(twenty_four_hours, 1) # 1 from start of today's hours until midnight
      end
    end

    # @!endgroup Parametric:ScheduleDay










  end
end
