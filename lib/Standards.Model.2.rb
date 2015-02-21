
require 'json'

class OpenStudio::Model::Model

  @standards = {}

  # Load the openstudio standards dataset and attach it to the model.
  def load_openstudio_standards_json(path_to_standards_json)
    # load the data from the JSON file into a ruby hash
    temp = File.read(path_to_standards_json.to_s)
    @standards = JSON.parse(temp)
    @spc_types = @standards['space_types']
    @climate_zone_sets = @standards['climate_zone_sets']
    @climate_zones = @standards['climate_zones']
    if @spc_types.nil? || @climate_zone_sets.nil? || @climate_zones.nil?
      puts 'The space types json file did not load correctly.'
      exit
    end

    # TODO check that the data was loaded correctly

    @created_names = []
  end

  # Method to search through a hash for the objects that meets the
  # desired search criteria, as passed via a hash.  If capacity is supplied,
  # the objects will only be returned if the specified capacity is between
  # the minimum_capacity and maximum_capacity values.
  # Returns an Array (empty if nothing found) of matching objects.
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
  # Returns tbe first matching object if successful, nil if not.
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
      #OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}, capacity = #{capacity}.  Called from #{caller(0)[1]}")
    elsif matching_objects.size == 1
      desired_object = matching_objects[0]
    else 
      desired_object = matching_objects[0]
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Search criteria: #{search_criteria} Called from #{caller(0)[1]}.  All results: \n #{matching_objects.join("\n")}")
    end
   
    return desired_object
   
  end
  
  # Create a schedule from the openstudio standards dataset.
  # TODO make return an OptionalScheduleRuleset
  def add_schedule(schedule_name)

    # First check model and return schedule if it already exists
    self.getSchedules.each do |schedule|
      if schedule.name.get.to_s == schedule_name
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Already added schedule: #{schedule_name}")
        return schedule
      end
    end 
 
    require 'date'

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding schedule: #{schedule_name}")   
    
    # Find all the schedule rules that match the name
    rules = self.find_objects(@standards['schedules'], {'name'=>schedule_name})
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
        #OpenStudio::logFree(OpenStudio::Info, "Adding space type: #{template}-#{clim}-#{building_type}-#{spc_type}")
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
        day_sch.setName("#{schedule_name} Summer Design Day")
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
  # TODO make return an OptionalSpaceType
  def add_space_type(template, clim, building_type, spc_type)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding space type: #{template}-#{clim}-#{building_type}-#{spc_type}")

    # Get the space type data
    data = self.find_object(@standards['space_types'], {'template'=>template, 'building_type'=>building_type, 'space_type'=>spc_type})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for space type: #{template}-#{clim}-#{building_type}-#{spc_type}, will not be created.")
      return false #TODO change to return empty optional schedule:ruleset?
    end
    
    name = make_name(template, clim, building_type, spc_type)

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
    unless lighting_per_area == 0 || lighting_per_area.nil? then make_lighting = true end
    unless lighting_per_person == 0 || lighting_per_person.nil? then make_lighting = true end

    if make_lighting == true

      # Create the lighting definition
      lights_def = OpenStudio::Model::LightsDefinition.new(self)
      lights_def.setName("#{name} Lights Definition")
      unless  lighting_per_area == 0 || lighting_per_area.nil?
        lights_def.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area, 'W/ft^2', 'W/m^2').get)
      end
      unless lighting_per_person == 0 || lighting_per_person.nil?
        lights_def.setWattsperPerson(OpenStudio.convert(lighting_per_person, 'W/person', 'W/person').get)
      end

      # Create the lighting instance and hook it up to the space type
      lights = OpenStudio::Model::Lights.new(lights_def)
      lights.setName("#{name} Lights")
      lights.setSpaceType(space_type)

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
    unless ventilation_per_area  == 0 || ventilation_per_area.nil? then make_ventilation = true  end
    unless ventilation_per_person == 0 || ventilation_per_person.nil? then make_ventilation = true end
    unless ventilation_ach == 0 || ventilation_ach.nil? then make_ventilation = true end

    if make_ventilation == true

      # Create the ventilation object and hook it up to the space type
      ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new(self)
      ventilation.setName("#{name} Ventilation")
      space_type.setDesignSpecificationOutdoorAir(ventilation)
      ventilation.setOutdoorAirMethod('Sum')
      unless ventilation_per_area  == 0 || ventilation_per_area.nil?
        ventilation.setOutdoorAirFlowperFloorArea(OpenStudio.convert(ventilation_per_area, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
      end
      unless ventilation_per_person == 0 || ventilation_per_person.nil?
        ventilation.setOutdoorAirFlowperPerson(OpenStudio.convert(ventilation_per_person, 'ft^3/min*person', 'm^3/s*person').get)
      end
      unless ventilation_ach == 0 || ventilation_ach.nil?
        ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach)
      end

    end

    # Occupancy

    make_people = false
    occupancy_per_area = data['occupancy_per_area']
    unless occupancy_per_area == 0 || occupancy_per_area.nil? then make_people = true end

    if make_people == true

      # create the people definition
      people_def = OpenStudio::Model::PeopleDefinition.new(self)
      people_def.setName("#{name} People Definition")
      unless  occupancy_per_area == 0 || occupancy_per_area.nil?
        people_def.setPeopleperSpaceFloorArea(OpenStudio.convert(occupancy_per_area / 1000, 'people/ft^2', 'people/m^2').get)
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

    end

    # Infiltration

    make_infiltration = false
    infiltration_per_area_ext = data['infiltration_per_exterior_area']
    unless infiltration_per_area_ext == 0 || infiltration_per_area_ext.nil? then make_infiltration = true end

    if make_infiltration == true

      # Create the infiltration object and hook it up to the space type
      infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
      infiltration.setName("#{name} Infiltration")
      infiltration.setSpaceType(space_type)
      unless infiltration_per_area_ext == 0 || infiltration_per_area_ext.nil?
        infiltration.setFlowperExteriorSurfaceArea(OpenStudio.convert(infiltration_per_area_ext, 'ft^3/min*ft^2', 'm^3/s*m^2').get)
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
    unless elec_equip_per_area == 0 || elec_equip_per_area.nil? then make_electric_equipment = true end

    if make_electric_equipment == true

      # Create the electric equipment definition
      elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
      elec_equip_def.setName("#{name} Electric Equipment Definition")
      unless  elec_equip_per_area == 0 || elec_equip_per_area.nil?
        elec_equip_def.setWattsperSpaceFloorArea(OpenStudio.convert(elec_equip_per_area, 'W/ft^2', 'W/m^2').get)
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
    unless  gas_equip_per_area == 0 || gas_equip_per_area.nil? then make_gas_equipment = true end

    if make_gas_equipment == true

      # Create the gas equipment definition
      gas_equip_def = OpenStudio::Model::GasEquipmentDefinition.new(self)
      gas_equip_def.setName("#{name} Gas Equipment Definition")
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
  # TODO make return an OptionalMaterial
  def add_material(material_name)
    
    # First check model and return material if it already exists
    self.getMaterials.each do |material|
      if material.name.get.to_s == material_name
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Already added material: #{material_name}")
        return material
      end
    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding material: #{material_name}")

    # Get the object data
    data = self.find_object(@standards['materials'], {'name'=>material_name})
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
  # TODO make return an OptionalConstruction
  def add_construction(construction_name)

    # First check model and return construction if it already exists
    self.getConstructions.each do |construction|
      if construction.name.get.to_s == construction_name
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Already added construction: #{construction_name}")
        return construction
      end
    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction: #{construction_name}")  

    # Get the object data
    data = self.find_object(@standards['constructions'], {'name'=>construction_name})
    if !data
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for construction: #{construction_name}, will not be created.")
      return false #TODO change to return empty optional material
    end
    
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

    layers = OpenStudio::Model::MaterialVector.new
    data['materials'].each do |material_name|
      material = add_material(material_name)
      if material
        layers << material
      end
    end
    construction.setLayers(layers)

    return construction
    
  end  
  
  # Create a construction set from the openstudio standards dataset.
  # Returns an Optional DefaultConstructionSet
  def add_construction_set(template, clim, building_type, spc_type)

    construction_set = OpenStudio::Model::OptionalDefaultConstructionSet.new
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction set: #{template}-#{clim}-#{building_type}-#{spc_type}")

    # Find the climate zone set that this climate zone falls into
    climate_zone_set = find_climate_zone_set(template, clim, building_type, spc_type)
    if !climate_zone_set
      return construction_set
    end
    
    # Get the object data
    data = self.find_object(@standards['construction_sets'], {'template'=>template, 'climate_zone_set'=> climate_zone_set, 'building_type'=>building_type, 'space_type'=>spc_type})
    if !data
      return construction_set
    end

    name = make_name(template, clim, building_type, spc_type)

    # Create a new construction set and name it
    construction_set = OpenStudio::Model::DefaultConstructionSet.new(self)
    construction_set.setName(name)

    # Exterior surfaces constructions
    exterior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSurfaceConstructions(exterior_surfaces)
    if construction_name = data['exterior_floors']
      exterior_surfaces.setFloorConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_walls']
      exterior_surfaces.setWallConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_roofs']
      exterior_surfaces.setRoofCeilingConstruction(add_construction(construction_name))
    end

    # Interior surfaces constructions
    interior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultInteriorSurfaceConstructions(interior_surfaces)
    if construction_name = data['interior_floors']
      interior_surfaces.setFloorConstruction(add_construction(construction_name))
    end
    if construction_name = data['interior_walls']
      interior_surfaces.setWallConstruction(add_construction(construction_name))
    end
    if construction_name = data['interior_ceilings']
      interior_surfaces.setRoofCeilingConstruction(add_construction(construction_name))
    end

    # Ground contact surfaces constructions
    ground_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(self)
    construction_set.setDefaultGroundContactSurfaceConstructions(ground_surfaces)
    if construction_name = data['ground_contact_floors']
      ground_surfaces.setFloorConstruction(add_construction(construction_name))
    end
    if construction_name = data['ground_contact_walls']
      ground_surfaces.setWallConstruction(add_construction(construction_name))
    end
    if construction_name = data['ground_contact_ceiling']
      ground_surfaces.setRoofCeilingConstruction(add_construction(construction_name))
    end

    # Exterior sub surfaces constructions
    exterior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(self)
    construction_set.setDefaultExteriorSubSurfaceConstructions(exterior_subsurfaces)
    if construction_name = data['exterior_fixed_windows']
      exterior_subsurfaces.setFixedWindowConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_operable_windows']
      exterior_subsurfaces.setOperableWindowConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_doors']
      exterior_subsurfaces.setDoorConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_glass_doors']
      exterior_subsurfaces.setGlassDoorConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_overhead_doors']
      exterior_subsurfaces.setOverheadDoorConstruction(add_construction(construction_name))
    end
    if construction_name = data['exterior_skylights']
      exterior_subsurfaces.setOverheadDoorConstruction(add_construction(construction_name))
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
    elsif building_type == 'Mid-riseApartment'
      building_type = 'MidApt'
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

  # Helper method to find out which climate zone set contains a specific
  # climate zone for use in adding a construction set.
  # Returns climate zone set name as String if success, nil if not found.
  def find_climate_zone_set(template, clim, building_type, spc_type)
    result = nil
    
    # Find the construction sets that correspond
    # to the specified template, building type, and space type
    possible_const_sets = self.find_objects(@standards['construction_sets'], {'template'=>template, 'building_type'=>building_type, 'space_type'=>spc_type})
    if possible_const_sets.size == 0
      #OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find data for construction sets: #{template}-#{building_type}-#{spc_type}, will not be created.")
      return result
    end    
   
    # Get a list of climate_zone_sets to check for the specified climate_zone
    possible_climate_zone_set_names = []
    possible_const_sets.each do |possible_const_set|
      possible_climate_zone_set_name = possible_const_set['climate_zone_set']
      next if possible_climate_zone_set_name.nil?
      # Get the climate_zone_set with this name
      possible_climate_zone_set = self.find_object(@standards['climate_zone_sets'], {'name'=>possible_climate_zone_set_name})
      # Skip climate zone sets with no climate zones
      next if possible_climate_zone_set['climate_zones'].nil?
      # Check if this climate zone set includes the specified climate zone 
      next unless possible_climate_zone_set['climate_zones'].include?(clim)   
      # Found a possible match
      possible_climate_zone_set_names << possible_climate_zone_set_name
    end
    
    if possible_climate_zone_set_names.size == 0
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set containing #{clim}")
    elsif possible_climate_zone_set_names.size > 1
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Found multiple climate zone sets containing #{clim}, using the first one.")
      result = possible_climate_zone_set_names[0]
    else
      result = possible_climate_zone_set_names[0]
    end
  
    return result
  
  end
  
end
