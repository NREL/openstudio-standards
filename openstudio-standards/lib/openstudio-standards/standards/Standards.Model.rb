
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::Model

  # Attach the standards to the model as a instance variable
  #self.standards = {}
  attr_accessor :standards

  # Load the helper libraries for getting the autosized
  # values for each type of model object.
  require_relative 'Standards.Fan'
  require_relative 'Standards.FanConstantVolume'
  require_relative 'Standards.FanVariableVolume'
  require_relative 'Standards.FanOnOff'
  require_relative 'Standards.FanZoneExhaust'
  require_relative 'Standards.ChillerElectricEIR'
  require_relative 'Standards.CoilCoolingDXTwoSpeed'
  require_relative 'Standards.CoilCoolingDXSingleSpeed'
  require_relative 'Standards.CoilHeatingDXSingleSpeed'
  require_relative 'Standards.BoilerHotWater'
  require_relative 'Standards.AirLoopHVAC'
  require_relative 'Standards.WaterHeaterMixed'
  require_relative 'Standards.Space'
  require_relative 'Standards.Construction'
  require_relative 'Standards.ThermalZone'
  require_relative 'Standards.Surface'
  require_relative 'Standards.SubSurface'
  require_relative 'Standards.SpaceType'

  # Applies the multi-zone VAV outdoor air sizing requirements
  # to all applicable air loops in the model.
  #
  # @note This must be performed before the sizing run because
  # it impacts component sizes, which in turn impact efficiencies.
  def apply_multizone_vav_outdoor_air_sizing()

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying HVAC efficiency standards.')

    # Multi-zone VAV outdoor air sizing
    self.getAirLoopHVACs.sort.each {|obj| obj.apply_multizone_vav_outdoor_air_sizing(self.template)}

  end

  # Applies the HVAC parts of the standard to all objects in the model
  # using the the template/standard specified in the model.
  def applyHVACEfficiencyStandard()

    sql_db_vars_map = Hash.new()

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying HVAC efficiency standards.')

    # Air Loop Controls
    self.getAirLoopHVACs.sort.each {|obj| obj.apply_standard_controls(self.template, self.climate_zone)}

    ##### Apply equipment efficiencies

    # Fans
    self.getFanVariableVolumes.sort.each {|obj| obj.setStandardEfficiency(self.template, self.standards)}
    self.getFanConstantVolumes.sort.each {|obj| obj.setStandardEfficiency(self.template, self.standards)}
    self.getFanOnOffs.sort.each {|obj| obj.setStandardEfficiency(self.template, self.standards)}
    self.getFanZoneExhausts.sort.each {|obj| obj.setStandardEfficiency(self.template, self.standards)}

    # Unitary ACs
    self.getCoilCoolingDXTwoSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| sql_db_vars_map = obj.setStandardEfficiencyAndCurves(self.template, self.standards, sql_db_vars_map)}

    # Unitary HPs
    self.getCoilHeatingDXSingleSpeeds.sort.each {|obj| sql_db_vars_map = obj.setStandardEfficiencyAndCurves(self.template, self.standards, sql_db_vars_map)}

    # Chillers
    self.getChillerElectricEIRs.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

    # Boilers
    self.getBoilerHotWaters.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

    # Water Heaters
    self.getWaterHeaterMixeds.sort.each {|obj| obj.setStandardEfficiency(self.template, self.standards)}

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying HVAC efficiency standards.')

  end

  # Applies daylighting controls to each space in the model
  # per the standard.
  def addDaylightingControls()

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding daylighting controls.')

    # Add daylighting controls to each space
    self.getSpaces.sort.each do |space|
      added = space.addDaylightingControls(self.template, false, false)
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding daylighting controls.')

  end

  # Apply the air leakage requirements to the model,
  # as described in PNNL section 5.2.1.6.
  #
  # base infiltration rates off of.
  # @return [Bool] true if successful, false if not
  # @todo This infiltration method is not used by the Reference
  # buildings, fix this inconsistency.
  def apply_infiltration_standard()

    # Set the infiltration rate at each space
    self.getSpaces.sort.each do |space|
      space.set_infiltration_rate(self.template)
    end

    case self.template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        #"For 'DOE Ref Pre-1980' and 'DOE Ref 1980-2004', infiltration rates are not defined using this method, no changes have been made to the model.
      else
        # Remove infiltration rates set at the space type
        self.getSpaceTypes.each do |space_type|
          space_type.spaceInfiltrationDesignFlowRates.each do |infil|
            infil.remove
          end
        end
      end
  end

  # Loads the openstudio standards dataset and attach it to the model
  # via the :standards instance variable.
  #
  # @todo test to verify that standards were loaded properly.
  def load_openstudio_standards_json()

    standards_files = []
    standards_files << 'OpenStudio_Standards_boilers.json'
    standards_files << 'OpenStudio_Standards_chillers.json'
    standards_files << 'OpenStudio_Standards_climate_zone_sets.json'
    standards_files << 'OpenStudio_Standards_climate_zones.json'
    standards_files << 'OpenStudio_Standards_construction_properties.json'
    standards_files << 'OpenStudio_Standards_construction_sets.json'
    standards_files << 'OpenStudio_Standards_constructions.json'
    standards_files << 'OpenStudio_Standards_curve_bicubics.json'
    standards_files << 'OpenStudio_Standards_curve_biquadratics.json'
    standards_files << 'OpenStudio_Standards_curve_cubics.json'
    standards_files << 'OpenStudio_Standards_curve_quadratics.json'
    standards_files << 'OpenStudio_Standards_ground_temperatures.json'
    standards_files << 'OpenStudio_Standards_heat_pumps_heating.json'
    standards_files << 'OpenStudio_Standards_heat_pumps.json'
    standards_files << 'OpenStudio_Standards_materials.json'
    standards_files << 'OpenStudio_Standards_motors.json'
    standards_files << 'OpenStudio_Standards_prototype_inputs.json'
    standards_files << 'OpenStudio_Standards_schedules.json'
    standards_files << 'OpenStudio_Standards_space_types.json'
    standards_files << 'OpenStudio_Standards_templates.json'
    standards_files << 'OpenStudio_Standards_unitary_acs.json'
#    standards_files << 'OpenStudio_Standards_unitary_hps.json'

    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"
    standards_hash = {}
    standards_files.sort.each do |standards_file|
      temp = File.open("#{standards_data_dir}/#{standards_file}", 'r:UTF-8')
      file_hash = JSON.load(temp)
      standards_hash = standards_hash.merge(file_hash)
    end

    self.standards = standards_hash

    # TODO check that the data was loaded correctly

    @created_names = []
  end

  # Method to search through a hash for the objects that meets the
  # desired search criteria, as passed via a hash.
  # Returns an Array (empty if nothing found) of matching objects.
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between
  #   the minimum_capacity and maximum_capacity values.
  # @return [Array] returns an array of hashes, one hash per object.  Array is empty if no results.
  # @example Find all the schedule rules that match the name
  #   rules = self.find_objects(self.standards['schedules'], {'name'=>schedule_name})
  #   if rules.size == 0
  #     OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
  #     return false #TODO change to return empty optional schedule:ruleset?
  #   end
  def find_objects(hash_of_objects, search_criteria, capacity = nil)

    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []

    # Compare each of the objects against the search criteria
    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.has_key?(key)
        # Stop as soon as one of the search criteria is not met
        if object[key] != value
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next if meets_all_search_criteria == false
      # If made it here, object matches all search criteria
      search_criteria_matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    if capacity.nil?
      matching_objects = search_criteria_matching_objects
    else
      # Round up if capacity is an integer
      if capacity = capacity.round
        capacity = capacity + (capacity * 0.01)
      end
      search_criteria_matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.has_key?('minimum_capacity') || !object.has_key?('maximum_capacity')
        # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
        next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
        # Skip objects whose the minimum capacity is below the specified capacity
        next if capacity <= object['minimum_capacity']
        # Skip objects whose max
        next if capacity > object['maximum_capacity']
        # Found a matching object
        matching_objects << object
      end
    end

    # Check the number of matching objects found
    if matching_objects.size == 0
      desired_object = nil
      #OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find objects search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}.")
    end

    return matching_objects

  end

  # Method to search through a hash for an object that meets the
  # desired search criteria, as passed via a hash.  If capacity is supplied,
  # the object will only be returned if the specified capacity is between
  # the minimum_capacity and maximum_capacity values.
  #
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between
  #   the minimum_capacity and maximum_capacity values.
  # @return [Hash] Return tbe first matching object hash if successful, nil if not.
  # @example Find the motor that meets these size criteria
  #   search_criteria = {
  #   'template' => template,
  #   'number_of_poles' => 4.0,
  #   'type' => 'Enclosed',
  #   }
  #   motor_properties = self.model.find_object(motors, search_criteria, 2.5)
  def find_object(hash_of_objects, search_criteria, capacity = nil)

    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []

    # Compare each of the objects against the search criteria
    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.has_key?(key)
        # Stop as soon as one of the search criteria is not met
        if object[key] != value
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next if !meets_all_search_criteria
      # If made it here, object matches all search criteria
      search_criteria_matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    if capacity.nil?
      matching_objects = search_criteria_matching_objects
    else
      # Round up if capacity is an integer
      if capacity == capacity.round
        capacity = capacity + (capacity * 0.01)
      end
      search_criteria_matching_objects.each do |object|
        # Skip objects that don't have fields for minimum_capacity and maximum_capacity
        next if !object.has_key?('minimum_capacity') || !object.has_key?('maximum_capacity')
        # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
        next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
        # Skip objects whose the minimum capacity is below the specified capacity
        next if capacity <= object['minimum_capacity'].to_f
        # Skip objects whose max
        next if capacity > object['maximum_capacity'].to_f
        # Found a matching object
        matching_objects << object
      end
    end

    # Check the number of matching objects found
    if matching_objects.size == 0
      desired_object = nil
      #OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}")
    elsif matching_objects.size == 1
      desired_object = matching_objects[0]
    else
      desired_object = matching_objects[0]
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Called from #{caller(0)[1]}. \n Search criteria: \n #{search_criteria} \n  All results: \n #{matching_objects.join("\n")}")
    end

    return desired_object

  end

  # Create a schedule from the openstudio standards dataset and
  # add it to the model.
  #
  # @param schedule_name [String} name of the schedule
  # @return [ScheduleRuleset] the resulting schedule ruleset
  # @todo make return an OptionalScheduleRuleset
  def add_schedule(schedule_name)
    return nil if schedule_name == nil or schedule_name == ""
    # First check model and return schedule if it already exists
    self.getSchedules.each do |schedule|
      if schedule.name.get.to_s == schedule_name
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added schedule: #{schedule_name}")
        return schedule
      end
    end

    require 'date'

    #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding schedule: #{schedule_name}")

    # Find all the schedule rules that match the name
    rules = self.find_objects(self.standards['schedules'], {'name'=>schedule_name})
    if rules.size == 0
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
      return false #TODO change to return empty optional schedule:ruleset?
    end

    # Helper method to fill in hourly values
    def add_vals_to_sch(day_sch, sch_type, values)
      if sch_type == "Constant"
        day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), values[0])
      elsif sch_type == "Hourly"
        for i in 0..23
          next if values[i] == values[i + 1]
          day_sch.addValue(OpenStudio::Time.new(0, i + 1, 0, 0), values[i])
        end
      else
        OpenStudio::logFree(OpenStudio::Error, "Schedule type: #{sch_type} is not recognized.  Valid choices are 'Constant' and 'Hourly'.")
      end
    end

    # Make a schedule ruleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(self)
    sch_ruleset.setName("#{schedule_name}")

    # Loop through the rules, making one for each row in the spreadsheet
    rules.each do |rule|
      day_types = rule['day_types']
      start_date = DateTime.parse(rule['start_date'])
      end_date = DateTime.parse(rule['end_date'])
      sch_type = rule['type']
      values = rule['values']

      #Day Type choices: Wkdy, Wknd, Mon, Tue, Wed, Thu, Fri, Sat, Sun, WntrDsn, SmrDsn, Hol

      # Default
      if day_types.include?('Default')
        day_sch = sch_ruleset.defaultDaySchedule
        day_sch.setName("#{schedule_name} Default")
        add_vals_to_sch(day_sch, sch_type, values)
      end

      # Winter Design Day
      if day_types.include?('WntrDsn')
        day_sch = OpenStudio::Model::ScheduleDay.new(self)
        sch_ruleset.setWinterDesignDaySchedule(day_sch)
        day_sch = sch_ruleset.winterDesignDaySchedule
        day_sch.setName("#{schedule_name} Winter Design Day")
        add_vals_to_sch(day_sch, sch_type, values)
      end

      # Summer Design Day
      if day_types.include?('SmrDsn')
        day_sch = OpenStudio::Model::ScheduleDay.new(self)
        sch_ruleset.setSummerDesignDaySchedule(day_sch)
        day_sch = sch_ruleset.summerDesignDaySchedule
        day_sch.setName("#{schedule_name} Summer Design Day")
        add_vals_to_sch(day_sch, sch_type, values)
      end

      # Other days (weekdays, weekends, etc)
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
        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{schedule_name} #{day_types} Day")
        add_vals_to_sch(day_sch, sch_type, values)

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

    end # Next rule

    return sch_ruleset

  end

  # Create a space type from the openstudio standards dataset.
  # @todo make return an OptionalSpaceType
  def add_space_type(template, clim, building_type, spc_type)

    # Get the space type data
    data = self.find_object(self.standards['space_types'], {'template'=>template, 'building_type'=>building_type, 'space_type'=>spc_type})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for space type: #{template}-#{clim}-#{building_type}-#{spc_type}, will not be created.")
      return false #TODO change to return empty optional schedule:ruleset?
    end

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Adding space type: #{template}-#{clim}-#{building_type}-#{spc_type}")

    name = make_name(template, clim, building_type, spc_type)
    puts "name = #{name}"

    # Create a new space type and name it
    space_type = OpenStudio::Model::SpaceType.new(self)
    space_type.setName(name)

    # Set the standards building type and space type for this new space type
    space_type.setStandardsBuildingType(building_type)
    space_type.setStandardsSpaceType(spc_type)

    # Set the rendering color of the space type
    rgb = data['rgb']
    rgb = rgb.split('_')
    r = rgb[0].to_i
    g = rgb[1].to_i
    b = rgb[2].to_i
    rendering_color = OpenStudio::Model::RenderingColor.new(self)
    rendering_color.setRenderingRedValue(r)
    rendering_color.setRenderingGreenValue(g)
    rendering_color.setRenderingBlueValue(b)
    space_type.setRenderingColor(rendering_color)

    # Create the schedule set for the space type
    default_sch_set = OpenStudio::Model::DefaultScheduleSet.new(self)
    default_sch_set.setName("#{name} Schedule Set")
    space_type.setDefaultScheduleSet(default_sch_set)

    # Lighting
    make_lighting = false
    lighting_per_area = data['lighting_per_area']
    lighting_per_person = data['lighting_per_person']
    unless lighting_per_area.to_f == 0 || lighting_per_area.nil? then make_lighting = true end
    unless lighting_per_person.to_f == 0 || lighting_per_person.nil? then make_lighting = true end

    if make_lighting == true

      # Create the lighting definition
      lights_def = OpenStudio::Model::LightsDefinition.new(self)
      lights_def.setName("#{name} Lights Definition")
      lights_frac_to_return_air = data['lighting_fraction_to_return_air']
      lights_frac_radiant = data['lighting_fraction_radiant']
      lights_frac_visible = data['lighting_fraction_visible']
      unless  lighting_per_area.to_f == 0 || lighting_per_area.nil?
        lights_def.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f, 'W/ft^2', 'W/m^2').get)
        lights_def.setReturnAirFraction(lights_frac_to_return_air)
        lights_def.setFractionRadiant(lights_frac_radiant)
        lights_def.setFractionVisible(lights_frac_visible)
      end
      unless lighting_per_person.to_f == 0 || lighting_per_person.nil?
        lights_def.setWattsperPerson(OpenStudio.convert(lighting_per_person, 'W/person', 'W/person').get)
        lights_def.setReturnAirFraction(lights_frac_to_return_air)
        lights_def.setFractionRadiant(lights_frac_radiant)
        lights_def.setFractionVisible(lights_frac_visible)
      end

      # Create the lighting instance and hook it up to the space type
      lights = OpenStudio::Model::Lights.new(lights_def)
      lights.setName("#{name} Lights")
      lights.setSpaceType(space_type)

      # Additional Lighting
      additional_lighting_per_area = data['additional_lighting_per_area']
      if additional_lighting_per_area != nil
        # Create the lighting definition
        additional_lights_def = OpenStudio::Model::LightsDefinition.new(self)
        additional_lights_def.setName("#{name} Additional Lights Definition")
        additional_lights_def.setWattsperSpaceFloorArea(OpenStudio.convert(additional_lighting_per_area, 'W/ft^2', 'W/m^2').get)
        additional_lights_def.setReturnAirFraction(lights_frac_to_return_air)
        additional_lights_def.setFractionRadiant(lights_frac_radiant)
        additional_lights_def.setFractionVisible(lights_frac_visible)

        # Create the lighting instance and hook it up to the space type
        additional_lights = OpenStudio::Model::Lights.new(additional_lights_def)
        additional_lights.setName("#{name} Additional Lights")
        additional_lights.setSpaceType(space_type)
      end

      # Get the lighting schedule and set it as the default
      lighting_sch = data['lighting_schedule']
      unless lighting_sch.nil?
        default_sch_set.setLightingSchedule(add_schedule(lighting_sch))
      end
    end

    # Ventilation

    make_ventilation = false
    ventilation_per_area = data['ventilation_per_area']
    ventilation_per_person = data['ventilation_per_person']
    ventilation_ach = data['ventilation_air_changes']
    unless ventilation_per_area.to_f  == 0 || ventilation_per_area.nil? then make_ventilation = true  end
    unless ventilation_per_person.to_f == 0 || ventilation_per_person.nil? then make_ventilation = true end
    unless ventilation_ach.to_f == 0 || ventilation_ach.nil? then make_ventilation = true end

    if make_ventilation == true

      # Create the ventilation object and hook it up to the space type
      ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new(self)
      ventilation.setName("#{name} Ventilation")
      space_type.setDesignSpecificationOutdoorAir(ventilation)
      ventilation.setOutdoorAirMethod('Sum')
      unless ventilation_per_area.nil? || ventilation_per_area.to_f  == 0
        ventilation.setOutdoorAirFlowperFloorArea(OpenStudio.convert(ventilation_per_area.to_f, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
      end
      unless  ventilation_per_person.nil? || ventilation_per_person.to_f == 0
        ventilation.setOutdoorAirFlowperPerson(OpenStudio.convert(ventilation_per_person.to_f, 'ft^3/min*person', 'm^3/s*person').get)
      end
      unless ventilation_ach.nil? || ventilation_ach.to_f == 0
        ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach.to_f)
      end
    end

    # Occupancy

    make_people = false
    occupancy_per_area = data['occupancy_per_area']
    unless occupancy_per_area.to_f == 0 || occupancy_per_area.nil? then make_people = true end

    if make_people == true
      # create the people definition
      people_def = OpenStudio::Model::PeopleDefinition.new(self)
      people_def.setName("#{name} People Definition")
      unless  occupancy_per_area == 0 || occupancy_per_area.nil?
        people_def.setPeopleperSpaceFloorArea(OpenStudio.convert(occupancy_per_area / 1000.0, 'people/ft^2', 'people/m^2').get)
      end

      # create the people instance and hook it up to the space type
      people = OpenStudio::Model::People.new(people_def)
      people.setName("#{name} People")
      people.setSpaceType(space_type)

      # get the occupancy and occupant activity schedules from the library and set as the default
      occupancy_sch = data['occupancy_schedule']
      unless occupancy_sch.nil?
        default_sch_set.setNumberofPeopleSchedule(add_schedule(occupancy_sch))
      end
      occupancy_activity_sch = data['occupancy_activity_schedule']
      unless occupancy_activity_sch.nil?
        default_sch_set.setPeopleActivityLevelSchedule(add_schedule(occupancy_activity_sch))
      end

      # clothing schedule for thermal comfort metrics
      clothing_sch = self.getScheduleRulesetByName("Clothing Schedule")
      if clothing_sch.is_initialized
        clothing_sch = clothing_sch.get
      else
        clothing_sch = OpenStudio::Model::ScheduleRuleset.new(self)
        clothing_sch.setName("Clothing Schedule")
        clothing_sch.defaultDaySchedule.setName("Clothing Schedule Default Winter Clothes")
        clothing_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 1.0)
        sch_rule = OpenStudio::Model::ScheduleRule.new(clothing_sch)
        sch_rule.daySchedule.setName("Clothing Schedule Summer Clothes")
        sch_rule.daySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0.5)
        sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(5), 1))
        sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(9), 30))
      end
      people.setClothingInsulationSchedule(clothing_sch)

      # air velocity schedule for thermal comfort metrics
      air_velo_sch = self.getScheduleRulesetByName("Air Velocity Schedule")
      if air_velo_sch.is_initialized
        air_velo_sch = air_velo_sch.get
      else
        air_velo_sch = OpenStudio::Model::ScheduleRuleset.new(self)
        air_velo_sch.setName("Air Velocity Schedule")
        air_velo_sch.defaultDaySchedule.setName("Air Velocity Schedule Default")
        air_velo_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0.2)
      end
      people.setAirVelocitySchedule(air_velo_sch)

      # work efficiency schedule for thermal comfort metrics
      work_efficiency_sch = self.getScheduleRulesetByName("Work Efficiency Schedule")
      if work_efficiency_sch.is_initialized
        work_efficiency_sch = work_efficiency_sch.get
      else
        work_efficiency_sch = OpenStudio::Model::ScheduleRuleset.new(self)
        work_efficiency_sch.setName("Work Efficiency Schedule")
        work_efficiency_sch.defaultDaySchedule.setName("Work Efficiency Schedule Default")
        work_efficiency_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0)
      end
      people.setWorkEfficiencySchedule(work_efficiency_sch)

    end

    # Infiltration

    make_infiltration = false
    infiltration_per_area_ext = data['infiltration_per_exterior_area']
    infiltration_per_area_ext_wall = data['infiltration_per_exterior_wall_area']
    infiltration_ach = data['infiltration_air_changes']
    unless (infiltration_per_area_ext.to_f == 0 || infiltration_per_area_ext.nil?) && (infiltration_per_area_ext_wall.to_f == 0 || infiltration_per_area_ext_wall.nil?) && (infiltration_ach.to_f == 0 || infiltration_ach.nil?)
      then make_infiltration = true
    end

    if make_infiltration == true

      # Create the infiltration object and hook it up to the space type
      infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
      infiltration.setName("#{name} Infiltration")
      infiltration.setSpaceType(space_type)
      unless infiltration_per_area_ext == 0 || infiltration_per_area_ext.nil?
        infiltration.setFlowperExteriorSurfaceArea(OpenStudio.convert(infiltration_per_area_ext, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
      end
      unless infiltration_per_area_ext_wall == 0 || infiltration_per_area_ext_wall.nil?
        infiltration.setFlowperExteriorWallArea(OpenStudio.convert(infiltration_per_area_ext_wall, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
      end
      unless infiltration_ach == 0 || infiltration_ach.nil?
        infiltration.setAirChangesperHour(infiltration_ach)
      end

      # Get the infiltration schedule from the library and set as the default
      infiltration_sch = data['infiltration_schedule']
      unless infiltration_sch.nil?
        default_sch_set.setInfiltrationSchedule(add_schedule(infiltration_sch))
      end

    end

    # Electric equipment

    make_electric_equipment = false
    elec_equip_per_area = data['electric_equipment_per_area']
    elec_equip_frac_latent = data['electric_equipment_fraction_latent']
    elec_equip_frac_radiant = data['electric_equipment_fraction_radiant']
    elec_equip_frac_lost = data['electric_equipment_fraction_lost']
    unless elec_equip_per_area.to_f == 0 || elec_equip_per_area.nil? then make_electric_equipment = true end

    if make_electric_equipment == true

      # Create the electric equipment definition
      elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
      elec_equip_def.setName("#{name} Electric Equipment Definition")
      unless  elec_equip_per_area == 0 || elec_equip_per_area.nil?
        elec_equip_def.setWattsperSpaceFloorArea(OpenStudio.convert(elec_equip_per_area, 'W/ft^2', 'W/m^2').get)
        elec_equip_def.setFractionLatent(elec_equip_frac_latent)
        elec_equip_def.setFractionRadiant(elec_equip_frac_radiant)
        elec_equip_def.setFractionLost(elec_equip_frac_lost)
      end

      # Create the electric equipment instance and hook it up to the space type
      elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
      elec_equip.setName("#{name} Electric Equipment")
      elec_equip.setSpaceType(space_type)

      # Get the electric equipment schedule from the library and set as the default
      elec_equip_sch = data['electric_equipment_schedule']
      unless elec_equip_sch.nil?
        default_sch_set.setElectricEquipmentSchedule(add_schedule(elec_equip_sch))
      end

    end

    # Gas equipment

    make_gas_equipment = false
    gas_equip_per_area = data['gas_equipment_per_area']
    gas_equip_frac_latent = data['gas_equipment_fraction_latent']
    gas_equip_frac_radiant = data['gas_equipment_fraction_radiant']
    gas_equip_frac_lost = data['gas_equipment_fraction_lost']

    unless  gas_equip_per_area.to_f == 0 || gas_equip_per_area.nil? then make_gas_equipment = true end

    if make_gas_equipment == true

      # Create the gas equipment definition
      gas_equip_def = OpenStudio::Model::GasEquipmentDefinition.new(self)
      gas_equip_def.setName("#{name} Gas Equipment Definition")
      gas_equip_def.setFractionLatent(gas_equip_frac_latent)
      gas_equip_def.setFractionRadiant(gas_equip_frac_radiant)
      gas_equip_def.setFractionLost(gas_equip_frac_lost)
      unless  gas_equip_per_area == 0 || gas_equip_per_area.nil?
        gas_equip_def.setWattsperSpaceFloorArea(OpenStudio.convert(gas_equip_per_area, 'Btu/hr*ft^2', 'W/m^2').get)
      end

      # Create the gas equipment instance and hook it up to the space type
      gas_equip = OpenStudio::Model::GasEquipment.new(gas_equip_def)
      gas_equip.setName("#{name} Gas Equipment")
      gas_equip.setSpaceType(space_type)

      # Get the gas equipment schedule from the library and set as the default
      gas_equip_sch = data['gas_equipment_schedule']
      unless gas_equip_sch.nil?
        default_sch_set.setGasEquipmentSchedule(add_schedule(gas_equip_sch))
      end

    end

    thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(self)
    thermostat.setName("#{name} Thermostat")

    heating_setpoint_sch = data['heating_setpoint_schedule']
    unless heating_setpoint_sch.nil?
      thermostat.setHeatingSetpointTemperatureSchedule(add_schedule(heating_setpoint_sch))
    end

    cooling_setpoint_sch = data['cooling_setpoint_schedule']
    unless cooling_setpoint_sch.nil?
      thermostat.setCoolingSetpointTemperatureSchedule(add_schedule(cooling_setpoint_sch))
    end

    # componentize the space type
    space_type_component = space_type.createComponent

    #   #TODO make this return BCL component space types?
    #
    #   #setup the file names and save paths that will be used
    #   file_name = "nrel_ref_bldg_space_type"
    #   component_dir = "#{Dir.pwd}/#{component_name}"
    #   osm_file_path = OpenStudio::Path.new("#{component_dir}/files/#{file_name}.osm")
    #   osc_file_path = OpenStudio::Path.new("#{component_dir}/files/#{file_name}.osc")
    #
    #   #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "component_dir = #{component_dir}")
    #
    #   OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "creating directories")
    #   FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
    #   FileUtils.mkdir_p(component_dir)
    #   FileUtils.mkdir_p("#{component_dir}/files/")
    #
    #   #save the space type as a .osm
    #   #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "saving osm to #{osm_file_path}")
    #   model.toIdfFile().save(osm_file_path,true)
    #
    #   #save the componentized space type as a .osc
    #   #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "saving osc to #{osc_file_path}")
    #   space_type_component.toIdfFile().save(osc_file_path,true)
    #
    #   #make the BCL component
    #   OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "creating BCL component")
    #   component = BCL::Component.new(component_dir)
    #   OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "created uid = #{component.uuid}")
    #
    #   #add component information
    #   component.name = component_name
    #   component.description = "This space type represent spaces in typical commercial buildings in the United States.  The information to create these space types was taken from the DOE Commercial Reference Building Models, which can be found at http://www1.eere.energy.gov/buildings/commercial_initiative/reference_buildings.html.  These space types include plug loads, gas equipment loads (cooking, etc), occupancy, infiltration, and ventilation rates, as well as schedules.  These space types should be viewed as starting points, and should be reviewed before being used to make decisions."
    #   component.source_manufacturer = "DOE"
    #   component.source_url = "http://www1.eere.energy.gov/buildings/commercial_initiative/reference_buildings.html"
    #   component.add_provenance("dgoldwas", Time.now.gmtime.strftime('%Y-%m-%dT%H:%M:%SZ'), "")
    #   component.add_tag("Space Types") # todo: what is the taxonomy string for space type? is there one?
    #
    #   #add arguments as attributes
    #   component.add_attribute("NREL_reference_building_vintage", template, "")
    #   component.add_attribute("Climate_zone", clim, "")
    #   component.add_attribute("NREL_reference_building_primary_space_type", building_type, "")
    #   component.add_attribute("NREL_reference_building_secondary_space_type", spc_type, "")
    #
    #   #openstudio type attribute
    #   component.add_attribute("OpenStudio Type", space_type.iddObjectType.valueDescription, "")
    #
    #   #add other attributes
    #   component.add_attribute("Lighting Standard",  data["lighting_standard"], "")
    #   component.add_attribute("Lighting Primary Space Type",  data["lighting_pri_spc_type"], "")
    #   component.add_attribute("Lighting Secondary Space Type",  data["lighting_sec_spc_type"], "")
    #
    #   component.add_attribute("Ventilation Standard",  data["ventilation_standard"], "")
    #   component.add_attribute("Ventilation Primary Space Type",  data["ventilation_pri_spc_type"], "")
    #   component.add_attribute("Ventilation Secondary Space Type",  data["ventilation_sec_spc_type"], "")
    #
    #   component.add_attribute("Occupancy Standard",  "NREL reference buildings", "")
    #   component.add_attribute("Occupancy Primary Space Type",  building_type, "")
    #   component.add_attribute("Occupancy Secondary Space Type",  spc_type, "")
    #
    #   component.add_attribute("Infiltration, Gas Equipment, Electric Equipment, and Schedules Standard",  "NREL reference buildings", "")
    #   component.add_attribute("Infiltration, Gas Equipment, Electric Equipment, and Schedules Primary Space Type",  building_type, "")
    #   component.add_attribute("Infiltration, Gas Equipment, Electric Equipment, and Schedules Secondary Space Type",  spc_type, "")
    #
    #   #add the osm and osc files to the component
    #   component.add_file("OpenStudio", "0.9.3",  osm_file_path.to_s, "#{file_name}.osm", "osm")
    #   component.add_file("OpenStudio", "0.9.3",  osc_file_path.to_s, "#{file_name}.osc", "osc")
    #
    #   #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "saving component to #{component_dir}")
    #   component.save_component_xml(component_dir)
    #
    # =e
    # return the space type and the componentized space type

    return space_type

  end # end generate_space_type

  # Create a material from the openstudio standards dataset.
  # @todo make return an OptionalMaterial
  def add_material(material_name)
    # First check model and return material if it already exists
    self.getMaterials.each do |material|
      if material.name.get.to_s == material_name
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added material: #{material_name}")
        return material
      end
    end

    #OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding material: #{material_name}")

    # Get the object data
    data = self.find_object(self.standards['materials'], {'name'=>material_name})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for material: #{material_name}, will not be created.")
      return false #TODO change to return empty optional material
    end

    material = nil
    material_type = data['material_type']

    if material_type == 'StandardOpaqueMaterial'
      material = OpenStudio::Model::StandardOpaqueMaterial.new(self)
      material.setName(material_name)

      material.setRoughness(data['roughness'].to_s)
      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDensity(OpenStudio.convert(data['density'].to_f, 'lb/ft^3', 'kg/m^3').get)
      material.setSpecificHeat(OpenStudio.convert(data['specific_heat'].to_f, 'Btu/lb*R', 'J/kg*K').get)
      material.setThermalAbsorptance(data['thermal_absorptance'].to_f)
      material.setSolarAbsorptance(data['solar_absorptance'].to_f)
      material.setVisibleAbsorptance(data['visible_absorptance'].to_f)

    elsif material_type == 'MasslessOpaqueMaterial'
      material = OpenStudio::Model::MasslessOpaqueMaterial.new(self)
      material.setName(material_name)
      material.setThermalResistance(OpenStudio.convert(data['resistance'].to_f, 'hr*ft^2*R/Btu', 'm^2*K/W').get)

      material.setConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDensity(OpenStudio.convert(data['density'].to_f, 'lb/ft^3', 'kg/m^3').get)
      material.setSpecificHeat(OpenStudio.convert(data['specific_heat'].to_f, 'Btu/lb*R', 'J/kg*K').get)
      material.setThermalAbsorptance(data['thermal_absorptance'].to_f)
      material.setSolarAbsorptance(data['solar_absorptance'].to_f)
      material.setVisibleAbsorptance(data['visible_absorptance'].to_f)

    elsif material_type == 'AirGap'
      material = OpenStudio::Model::AirGap.new(self)
      material.setName(material_name)

      material.setThermalResistance(OpenStudio.convert(data['resistance'].to_f, 'hr*ft^2*R/Btu*in', 'm*K/W').get)

    elsif material_type == 'Gas'
      material = OpenStudio::Model::Gas.new(self)
      material.setName(material_name)

      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setGasType(data['gas_type'].to_s)

    elsif material_type == 'SimpleGlazing'
      material = OpenStudio::Model::SimpleGlazing.new(self)
      material.setName(material_name)

      material.setUFactor(OpenStudio.convert(data['u_factor'].to_f, 'Btu/hr*ft^2*R', 'W/m^2*K').get)
      material.setSolarHeatGainCoefficient(data['solar_heat_gain_coefficient'].to_f)
      material.setVisibleTransmittance(data['visible_transmittance'].to_f)

    elsif material_type == 'StandardGlazing'
      material = OpenStudio::Model::StandardGlazing.new(self)
      material.setName(material_name)

      material.setOpticalDataType(data['optical_data_type'].to_s)
      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setSolarTransmittanceatNormalIncidence(data['solar_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideSolarReflectanceatNormalIncidence(data['front_side_solar_reflectance_at_normal_incidence'].to_f)
      material.setBackSideSolarReflectanceatNormalIncidence(data['back_side_solar_reflectance_at_normal_incidence'].to_f)
      material.setVisibleTransmittanceatNormalIncidence(data['visible_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideVisibleReflectanceatNormalIncidence(data['front_side_visible_reflectance_at_normal_incidence'].to_f)
      material.setBackSideVisibleReflectanceatNormalIncidence(data['back_side_visible_reflectance_at_normal_incidence'].to_f)
      material.setInfraredTransmittanceatNormalIncidence(data['infrared_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideInfraredHemisphericalEmissivity(data['front_side_infrared_hemispherical_emissivity'].to_f)
      material.setBackSideInfraredHemisphericalEmissivity(data['back_side_infrared_hemispherical_emissivity'].to_f)
      material.setConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDirtCorrectionFactorforSolarandVisibleTransmittance(data['dirt_correction_factor_for_solar_and_visible_transmittance'].to_f)
      if /true/i.match(data['solar_diffusing'].to_s)
        material.setSolarDiffusing(true)
      else
        material.setSolarDiffusing(false)
      end

    else
      puts "Unknown material type #{material_type}"
      exit
    end

    return material

  end

  # Create a construction from the openstudio standards dataset.
  # If construction_props are specified, modifies the insulation layer accordingly.
  # @todo make return an OptionalConstruction
  def add_construction(construction_name, construction_props = nil)

    # First check model and return construction if it already exists
    self.getConstructions.each do |construction|
      if construction.name.get.to_s == construction_name
        OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added construction: #{construction_name}")
        return construction
      end
    end

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Adding construction: #{construction_name}")

    # Get the object data
    data = self.find_object(self.standards['constructions'], {'name'=>construction_name})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for construction: #{construction_name}, will not be created.")
      return false #TODO change to return empty optional material
    end

    # Make a new construction and set the standards details
    construction = OpenStudio::Model::Construction.new(self)
    construction.setName(construction_name)
    standards_info = construction.standardsInformation

    intended_surface_type = data['intended_surface_type']
    unless intended_surface_type
      intended_surface_type = ''
    end
    standards_info.setIntendedSurfaceType(intended_surface_type)

    standards_construction_type = data['standards_construction_type']
    unless standards_construction_type
      standards_construction_type = ''
    end
    standards_info.setStandardsConstructionType(standards_construction_type)

    # TODO: could put construction rendering color in the spreadsheet

    # Add the material layers to the construction
    layers = OpenStudio::Model::MaterialVector.new
    data['materials'].each do |material_name|
      material = add_material(material_name)
      if material
        layers << material
      end
    end
    construction.setLayers(layers)

    # Modify the R value of the insulation to hit the specified U-value, C-Factor, or F-Factor.
    # Doesn't currently operate on glazing constructions
    if construction_props
      # Determine the target U-value, C-factor, and F-factor
      target_u_value_ip = construction_props['assembly_maximum_u_value']
      target_f_factor_ip = construction_props['assembly_maximum_f_factor']
      target_c_factor_ip = construction_props['assembly_maximum_c_factor']

      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "#{data['intended_surface_type']} u_val #{target_u_value_ip} f_fac #{target_f_factor_ip} c_fac #{target_c_factor_ip}")

      if target_u_value_ip && !(data['intended_surface_type'] == 'ExteriorWindow' || data['intended_surface_type'] == 'Skylight')

        # Set the U-Value
        construction.set_u_value(target_u_value_ip.to_f, data['insulation_layer'], data['intended_surface_type'], true)

      elsif target_f_factor_ip && data['intended_surface_type'] == 'GroundContactFloor'

        # Set the F-Factor (only applies to slabs on grade)
        # TODO figure out what the prototype buildings did about ground heat transfer
        #construction.set_slab_f_factor(target_f_factor_ip.to_f, data['insulation_layer'])
        construction.set_u_value(0.0, data['insulation_layer'], data['intended_surface_type'], true)

      elsif target_c_factor_ip && data['intended_surface_type'] == 'GroundContactWall'

        # Set the C-Factor (only applies to underground walls)
        # TODO figure out what the prototype buildings did about ground heat transfer
        #construction.set_underground_wall_c_factor(target_c_factor_ip.to_f, data['insulation_layer'])
        construction.set_u_value(0.0, data['insulation_layer'], data['intended_surface_type'], true)

      end

    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction #{construction.name}.")

    return construction

  end

  # Helper method to find a particular construction and add it to the model
  # after modifying the insulation value if necessary.
  def find_and_add_construction(template, climate_zone_set, intended_surface_type, standards_construction_type, building_category)

    # Get the construction properties,
    # which specifies properties by construction category by climate zone set.
    # AKA the info in Tables 5.5-1-5.5-8
    props = self.find_object(self.standards['construction_properties'], {'template'=>template,
                                                                    'climate_zone_set'=> climate_zone_set,
                                                                    'intended_surface_type'=> intended_surface_type,
                                                                    'standards_construction_type'=> standards_construction_type,
                                                                    'building_category' => building_category
                                                                    })
    if !props
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find construction properties for: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}.")
      return false
    else
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Construction properties for: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category} = #{props}.")
    end

    # Make sure that a construction is specified
    if props['construction'].nil?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "No typical construction is specified for construction properties of: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}.  Make sure it is entered in the spreadsheet.")
      return false
    end

    # Add the construction, modifying properties as necessary
    construction = add_construction(props['construction'], props)

    return construction

  end

  # Create a construction set from the openstudio standards dataset.
  # Returns an Optional DefaultConstructionSet
  def add_construction_set(template, clim, building_type, spc_type, is_residential)

    construction_set = OpenStudio::Model::OptionalDefaultConstructionSet.new

    # Find the climate zone set that this climate zone falls into
    climate_zone_set = find_climate_zone_set(clim, template)
    if !climate_zone_set
      return construction_set
    end

    # Get the object data
    data = self.find_object(self.standards['construction_sets'], {'template'=>template, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type, 'is_residential'=>is_residential})
    if !data
      data = self.find_object(self.standards['construction_sets'], {'template'=>template, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type})
      if !data
        return construction_set
      end
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction set: #{template}-#{clim}-#{building_type}-#{spc_type}-is_residential#{is_residential}")

    name = make_name(template, clim, building_type, spc_type)

    # Create a new construction set and name it
    construction_set = OpenStudio::Model::DefaultConstructionSet.new(self)
    construction_set.setName(name)

    # Exterior surfaces constructions
    exterior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSurfaceConstructions(exterior_surfaces)
    if data['exterior_floor_standards_construction_type'] && data['exterior_floor_building_category']
      exterior_surfaces.setFloorConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorFloor',
                                                                       data['exterior_floor_standards_construction_type'],
                                                                       data['exterior_floor_building_category']))
    end
    if data['exterior_wall_standards_construction_type'] && data['exterior_wall_building_category']
      exterior_surfaces.setWallConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorWall',
                                                                       data['exterior_wall_standards_construction_type'],
                                                                       data['exterior_wall_building_category']))
    end
    if data['exterior_roof_standards_construction_type'] && data['exterior_roof_building_category']
      exterior_surfaces.setRoofCeilingConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorRoof',
                                                                       data['exterior_roof_standards_construction_type'],
                                                                       data['exterior_roof_building_category']))
    end

    # Interior surfaces constructions
    interior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSurfaceConstructions(interior_surfaces)
    construction_name = data['interior_floors']
    if construction_name != nil
      interior_surfaces.setFloorConstruction(add_construction(construction_name))
    end
    construction_name = data['interior_walls']
    if construction_name != nil
      interior_surfaces.setWallConstruction(add_construction(construction_name))
    end
    construction_name = data['interior_ceilings']
    if construction_name != nil
      interior_surfaces.setRoofCeilingConstruction(add_construction(construction_name))
    end

    # Ground contact surfaces constructions
    ground_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultGroundContactSurfaceConstructions(ground_surfaces)
    if data['ground_contact_floor_standards_construction_type'] && data['ground_contact_floor_building_category']
      ground_surfaces.setFloorConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'GroundContactFloor',
                                                                       data['ground_contact_floor_standards_construction_type'],
                                                                       data['ground_contact_floor_building_category']))
    end
    if data['ground_contact_wall_standards_construction_type'] && data['ground_contact_wall_building_category']
      ground_surfaces.setWallConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'GroundContactWall',
                                                                       data['ground_contact_wall_standards_construction_type'],
                                                                       data['ground_contact_wall_building_category']))
    end
    if data['ground_contact_ceiling_standards_construction_type'] && data['ground_contact_ceiling_building_category']
      ground_surfaces.setRoofCeilingConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'GroundContactRoof',
                                                                       data['ground_contact_ceiling_standards_construction_type'],
                                                                       data['ground_contact_ceiling_building_category']))
    end

    # Exterior sub surfaces constructions
    exterior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSubSurfaceConstructions(exterior_subsurfaces)
    if data['exterior_fixed_window_standards_construction_type'] && data['exterior_fixed_window_building_category']
      exterior_subsurfaces.setFixedWindowConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorWindow',
                                                                       data['exterior_fixed_window_standards_construction_type'],
                                                                       data['exterior_fixed_window_building_category']))
    end
    if data['exterior_operable_window_standards_construction_type'] && data['exterior_operable_window_building_category']
      exterior_subsurfaces.setOperableWindowConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorWindow',
                                                                       data['exterior_operable_window_standards_construction_type'],
                                                                       data['exterior_operable_window_building_category']))
    end
    if data['exterior_door_standards_construction_type'] && data['exterior_door_building_category']
      exterior_subsurfaces.setDoorConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorDoor',
                                                                       data['exterior_door_standards_construction_type'],
                                                                       data['exterior_door_building_category']))
    end
    construction_name = data['exterior_glass_doors']
    if construction_name != nil
      exterior_subsurfaces.setGlassDoorConstruction(add_construction(construction_name))
    end
    if data['exterior_overhead_door_standards_construction_type'] && data['exterior_overhead_door_building_category']
      exterior_subsurfaces.setOverheadDoorConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'ExteriorDoor',
                                                                       data['exterior_overhead_door_standards_construction_type'],
                                                                       data['exterior_overhead_door_building_category']))
    end
    if data['exterior_skylight_standards_construction_type'] && data['exterior_skylight_building_category']
      exterior_subsurfaces.setSkylightConstruction(find_and_add_construction(template,
                                                                       climate_zone_set,
                                                                       'Skylight',
                                                                       data['exterior_skylight_standards_construction_type'],
                                                                       data['exterior_skylight_building_category']))
    end
    if construction_name = data['tubular_daylight_domes']
      exterior_subsurfaces.setTubularDaylightDomeConstruction(add_construction(construction_name))
    end
    if construction_name = data['tubular_daylight_diffusers']
      exterior_subsurfaces.setTubularDaylightDiffuserConstruction(add_construction(construction_name))
    end

    # Interior sub surfaces constructions
    interior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSubSurfaceConstructions(interior_subsurfaces)
    if construction_name = data['interior_fixed_windows']
      interior_subsurfaces.setFixedWindowConstruction(add_construction(construction_name))
    end
    if construction_name = data['interior_operable_windows']
      interior_subsurfaces.setOperableWindowConstruction(add_construction(construction_name))
    end
    if construction_name = data['interior_doors']
      interior_subsurfaces.setDoorConstruction(add_construction(construction_name))
    end

    # Other constructions
    if construction_name = data['interior_partitions']
      construction_set.setInteriorPartitionConstruction(add_construction(construction_name))
    end
    if construction_name = data['space_shading']
      construction_set.setSpaceShadingConstruction(add_construction(construction_name))
    end
    if construction_name = data['building_shading']
      construction_set.setBuildingShadingConstruction(add_construction(construction_name))
    end
    if construction_name = data['site_shading']
      construction_set.setSiteShadingConstruction(add_construction(construction_name))
    end

    # componentize the construction set
    #construction_set_component = construction_set.createComponent

    # Return the construction set
    return OpenStudio::Model::OptionalDefaultConstructionSet.new(construction_set)

  end

  def add_curve(curve_name, standards)

    #OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.addCurve", "Adding curve '#{curve_name}' to the model.")

    success = false

    curve_biquadratics = standards["curve_biquadratics"]
    curve_quadratics = standards["curve_quadratics"]
    curve_bicubics = standards["curve_bicubics"]
    curve_cubics = standards["curve_cubics"]

    # Make biquadratic curves
    curve_data = self.find_object(curve_biquadratics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveBiquadratic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setCoefficient4y(curve_data["coeff_4"])
      curve.setCoefficient5yPOW2(curve_data["coeff_5"])
      curve.setCoefficient6xTIMESY(curve_data["coeff_6"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      curve.setMinimumValueofy(curve_data["min_y"])
      curve.setMaximumValueofy(curve_data["max_y"])
      success = true
      return curve
    end

    # Make quadratic curves
    curve_data = self.find_object(curve_quadratics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveQuadratic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      success = true
      return curve
    end

    # Make cubic curves
    curve_data = self.find_object(curve_cubics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveCubic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setCoefficient4xPOW3(curve_data["coeff_4"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      success = true
      return curve
    end

    # Make bicubic curves
    curve_data = self.find_object(curve_bicubics, {"name"=>curve_name})
    if curve_data
      curve = OpenStudio::Model::CurveBicubic.new(self)
      curve.setName(curve_data["name"])
      curve.setCoefficient1Constant(curve_data["coeff_1"])
      curve.setCoefficient2x(curve_data["coeff_2"])
      curve.setCoefficient3xPOW2(curve_data["coeff_3"])
      curve.setCoefficient4y(curve_data["coeff_4"])
      curve.setCoefficient5yPOW2(curve_data["coeff_5"])
      curve.setCoefficient6xTIMESY(curve_data["coeff_6"])
      curve.setCoefficient7xPOW3(curve_data["coeff_7"])
      curve.setCoefficient8yPOW3(curve_data["coeff_8"])
      curve.setCoefficient9xPOW2TIMESY(curve_data["coeff_9"])
      curve.setCoefficient10xTIMESYPOW2(curve_data["coeff_10"])
      curve.setMinimumValueofx(curve_data["min_x"])
      curve.setMaximumValueofx(curve_data["max_x"])
      curve.setMinimumValueofy(curve_data["min_y"])
      curve.setMaximumValueofy(curve_data["max_y"])
      success = true
      return curve
    end

    # Return false if the curve was not created
    if success == false
      #OpenStudio::logFree(OpenStudio::Warn, "openstudio.prototype.addCurve", "Could not find a curve called '#{curve_name}' in the standards.")
      return nil
    end

  end

  # Get the full path to the weather file that is specified in the model.
  #
  # @return [OpenStudio::OptionalPath]
  def get_full_weather_file_path

    full_epw_path = OpenStudio::OptionalPath.new

    if self.weatherFile.is_initialized
      epw_path = self.weatherFile.get.path
      if epw_path.is_initialized
        if File.exist?(epw_path.get.to_s)
          full_epw_path = OpenStudio::OptionalPath.new(epw_path.get)
        else
          # If this is an always-run Measure, need to check a different path
          alt_weath_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../resources"))
          alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
          if File.exist?(alt_epw_path)
            full_epw_path = OpenStudio::OptionalPath.new(OpenStudio::Path.new(alt_epw_path))
          else
            OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Model", "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
          end
        end
      else
        OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Model", "Model has a weather file assigned, but the weather file path has been deleted.")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has not been assigned a weather file.')
    end
  
    return full_epw_path
  
  end

  # Method to gather prototype simulation results for a specific climate zone, building type, and template
  #
  # @param climate_zone [String] string for the ASHRAE climate zone.
  # @param building_type [String] string for prototype building type.
  # @param template [String] string for prototype template to target.
  # @return [Hash] Returns a hash with data presented in various bins. Returns nil if no search results
  def process_results_for_datapoint(climate_zone, building_type, template)

    # Combine the data from the JSON files into a single hash
    top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"

    # Load the legacy idf results JSON file into a ruby hash
    temp = File.read("#{standards_data_dir}/legacy_idf_results.json")
    legacy_idf_results = JSON.parse(temp)

    # List of all fuel types
    fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

    # List of all end uses
    end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection','Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

    # Get legacy idf results
    legacy_results_hash = {}
    legacy_results_hash['total_legacy_energy_val'] = 0
    legacy_results_hash['total_legacy_water_val'] = 0
    legacy_results_hash['total_energy_by_fuel'] = {}
    legacy_results_hash['total_energy_by_end_use'] = {}
    fuel_types.each do |fuel_type|

      end_uses.each do |end_use|
        next if end_use == 'Exterior Equipment'

        # Get the legacy results number
        legacy_val = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, end_use)

        # Combine the exterior lighting and exterior equipment
        if end_use == 'Exterior Lighting'
          legacy_exterior_equipment = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, 'Exterior Equipment')
          unless legacy_exterior_equipment.nil?
            legacy_val += legacy_exterior_equipment
          end
        end

        if legacy_val.nil?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "#{fuel_type} #{end_use} legacy idf value not found")
          next
        end

        # Add the energy to the total
        if fuel_type == 'Water'
          legacy_results_hash['total_legacy_water_val'] += legacy_val
        else
          legacy_results_hash['total_legacy_energy_val'] += legacy_val

          # add to fuel specific total
          if legacy_results_hash['total_energy_by_fuel'][fuel_type]
            legacy_results_hash['total_energy_by_fuel'][fuel_type] += legacy_val # add to existing counter
          else
            legacy_results_hash['total_energy_by_fuel'][fuel_type] = legacy_val # start new counter
          end

          # add to end use specific total
          if legacy_results_hash['total_energy_by_end_use'][end_use]
            legacy_results_hash['total_energy_by_end_use'][end_use] += legacy_val # add to existing counter
          else
            legacy_results_hash['total_energy_by_end_use'][end_use] = legacy_val # start new counter
          end

        end

      end # Next end use

    end # Next fuel type

    return legacy_results_hash

  end

  # Keep track of floor area for prototype buildings.
  # This is used to calculate EUI's to compare against non prototype buildings
  # Areas taken from scorecard Excel Files
  #
  # @param [Sting] building type
  # @return [Double] floor area (m^2) of prototype building for building type passed in. Returns nil if unexpected building type
  def find_prototype_floor_area(building_type)

    if building_type == 'FullServiceRestaurant' # 5502 ft^2
      result = 511
    elsif building_type == 'Hospital' # 241,410 ft^2 (including basement)
      result = 22422
    elsif building_type == 'LargeHotel' # 122,132 ft^2
      result = 11345
    elsif building_type == 'LargeOffice' # 498,600 ft^2
      result = 46320
    elsif building_type == 'MediumOffice' # 53,600 ft^2
      result = 4982
    elsif building_type == 'MidriseApartment' # 33,700 ft^2
      result = 3135
    elsif building_type == 'Office'
      result = nil # todo - there shouldn't be a prototype building for this
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Measures calling this should choose between SmallOffice, MediumOffice, and LargeOffice")
    elsif building_type == 'Outpatient' #40.950 ft^2
      result = 3804
    elsif building_type == 'PrimarySchool' # 73,960 ft^2
      result = 6871
    elsif building_type == 'QuickServiceRestaurant' # 2500 ft^2
      result = 232
    elsif building_type == 'Retail' # 24,695 ft^2
      result = 2294
    elsif building_type == 'SecondarySchool' # 210,900 ft^2
      result = 19592
    elsif building_type == 'SmallHotel' # 43,200 ft^2
      result = 4014
    elsif building_type == 'SmallOffice' # 5500 ft^2
      result = 511
    elsif building_type == 'StripMall' # 22,500 ft^2
      result = 2090
    elsif building_type == 'SuperMarket' #45,002 ft2 (from legacy reference idf file)
      result = 4181
    elsif building_type == 'Warehouse' # 49,495 ft^2 (legacy ref shows 52,045, but I wil calc using 49,495)
      result = 4595
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Didn't find expected building type. As a result can't determine floor prototype floor area")
      result = nil
    end

    return result

  end

  # this is used by other methods to get the clinzte aone and building type from a model.
  # it has logic to break office into small, medium or large based on building area that can be turned off
  # @param [bool] re-map small office or leave it alone
  # @return [hash] key for climate zone and building type, both values are strings
  def get_building_climate_zone_and_building_type(remap_office = true)

    # get climate zone from model
    # get ashrae climate zone from model
    climate_zone = ''
    climateZones = self.getClimateZones
    climateZones.climateZones.each do |climateZone|
      if climateZone.institution == "ASHRAE"
        climate_zone = "ASHRAE 169-2006-#{climateZone.value}"
        next
      end
    end

    # get building type from model
    building_type = ''
    if self.getBuilding.standardsBuildingType.is_initialized
      building_type = self.getBuilding.standardsBuildingType.get
    end

    # prototype small office approx 500 m^2
    # prototype medium office approx 5000 m^2
    # prototype large office approx 50,000 m^2
    # map office building type to small medium or large
    if building_type == "Office" and remap_office
      open_studio_area = self.getBuilding.floorArea
      if open_studio_area < 2750
        building_type = "SmallOffice"
      elsif open_studio_area < 25250
        building_type = "MediumOffice"
      else
        building_type = "LargeOffice"
      end
    end

    results = {}
    results['climate_zone'] = climate_zone
    results['building_type'] = building_type

    return results

  end

  # user needs to pass in building_vintage as string. The building type and climate zone will come from the model.
  # If the building type or ASHRAE climate zone is not set in the model this will return nil
  # If the lookup doesn't find matching simulation results this wil return nil
  #
  # @param [String] target prototype template for eui lookup
  # @return [Double] EUI (MJ/m^2) for target template for given OSM. Returns nil if can't calculate EUI
  def find_target_eui(template)

    building_data = self.get_building_climate_zone_and_building_type
    climate_zone = building_data['climate_zone']
    building_type = building_data['building_type']

    # look up results
    target_consumption = process_results_for_datapoint(climate_zone, building_type, template)

    # lookup target floor area for prototype buildings
    target_floor_area = find_prototype_floor_area(building_type)

    if target_consumption['total_legacy_energy_val'] > 0
      if target_floor_area > 0
        result = target_consumption['total_legacy_energy_val']/target_floor_area
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find prototype building floor area")
        result = nil
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find target results for #{climate_zone},#{building_type},#{template}")
      result = nil # couldn't calculate EUI consumpiton lookup failed
    end

    return result

  end

  # user needs to pass in building_vintage as string. The building type and climate zone will come from the model.
  # If the building type or ASHRAE climate zone is not set in the model this will return nil
  # If the lookup doesn't find matching simulation results this wil return nil
  #
  # @param [String] target prototype template for eui lookup
  # @return [Hash] EUI (MJ/m^2) This will return a hash of end uses. key is end use, value is eui
  def find_target_eui_by_end_use(template)

    building_data = self.get_building_climate_zone_and_building_type
    climate_zone = building_data['climate_zone']
    building_type = building_data['building_type']

    # look up results
    target_consumption = process_results_for_datapoint(climate_zone, building_type, template)

    # lookup target floor area for prototype buildings
    target_floor_area = find_prototype_floor_area(building_type)

    if target_consumption['total_legacy_energy_val'] > 0
      if target_floor_area > 0
        result = {}
        target_consumption['total_energy_by_end_use'].each do |end_use,consumption|
          result[end_use] = consumption/target_floor_area
        end
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find prototype building floor area")
        result = nil
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find target results for #{climate_zone},#{building_type},#{template}")
      result = nil # couldn't calculate EUI consumpiton lookup failed
    end

    return result

  end
  
  private

  # Helper method to make a shortened version of a name
  # that will be readable in a GUI.
  def make_name(template, clim, building_type, spc_type)
    clim = clim.gsub('ClimateZone ', 'CZ')
    if clim == 'CZ1-8'
      clim = ''
    end

    if building_type == 'FullServiceRestaurant'
      building_type = 'FullSrvRest'
    elsif building_type == 'Hospital'
      building_type = 'Hospital'
    elsif building_type == 'LargeHotel'
      building_type = 'LrgHotel'
    elsif building_type == 'LargeOffice'
      building_type = 'LrgOffice'
    elsif building_type == 'MediumOffice'
      building_type = 'MedOffice'
    elsif building_type == 'MidriseApartment'
      building_type = 'MidApt'
    elsif building_type == 'HighriseApartment'
      building_type = 'HighApt'
    elsif building_type == 'Office'
      building_type = 'Office'
    elsif building_type == 'Outpatient'
      building_type = 'Outpatient'
    elsif building_type == 'PrimarySchool'
      building_type = 'PriSchl'
    elsif building_type == 'QuickServiceRestaurant'
      building_type = 'QckSrvRest'
    elsif building_type == 'Retail'
      building_type = 'Retail'
    elsif building_type == 'SecondarySchool'
      building_type = 'SecSchl'
    elsif building_type == 'SmallHotel'
      building_type = 'SmHotel'
    elsif building_type == 'SmallOffice'
      building_type = 'SmOffice'
    elsif building_type == 'StripMall'
      building_type = 'StMall'
    elsif building_type == 'SuperMarket'
      building_type = 'SpMarket'
    elsif building_type == 'Warehouse'
      building_type = 'Warehouse'
    end

    parts = [template]

    unless building_type.empty?
      parts << building_type
    end

    unless spc_type.nil?
      parts << spc_type
    end

    unless clim.empty?
      parts << clim
    end

    result = parts.join(' - ')

    @created_names << result

    return result
  end

  # Helper method to find out which climate zone set contains a specific climate zone.
  # Returns climate zone set name as String if success, nil if not found.
  def find_climate_zone_set(clim, building_vintage)
    result = nil

    possible_climate_zones = []
    self.standards['climate_zone_sets'].each do |climate_zone_set|
      if climate_zone_set['climate_zones'].include?(clim)
        possible_climate_zones << climate_zone_set['name']
      end
    end

    # Check the results
    if possible_climate_zones.size == 0
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set containing #{clim}")
    elsif possible_climate_zones.size > 2
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Found more than 2 climate zone sets containing #{clim}; will return last matching cliimate zone set.")
    end

    # For Pre-1980 and 1980-2004, use the most specific climate zone set.
    # For example, 2A and 2 both contain 2A, so use 2A.
    # For 2004-2013, use least specific climate zone set.
    # For example, 2A and 2 both contain 2A, so use 2.
    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      result = possible_climate_zones.sort.last
    when '90.1-2007', '90.1-2010', '90.1-2013'
      result = possible_climate_zones.sort.first
    when '90.1-2004'
      if possible_climate_zones.include? "ClimateZone 3"
        result = possible_climate_zones.sort.last
      else
        result = possible_climate_zones.sort.first
      end
    end
        
    # Check that a climate zone set was found
    if result.nil?
      
    end
    
    return result
  
  end

end
