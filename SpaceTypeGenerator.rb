
require 'rubygems'
require 'json'
require 'fileutils'
require 'openstudio'

class SpaceTypeGenerator

def initialize(path_to_space_type_json, path_to_master_schedules_library, path_to_office_schedules_library)
  
  #load the data from the JSON file into a ruby hash
  @spc_types = {}
  temp = File.read(path_to_space_type_json.to_s)
  @spc_types = JSON.parse(temp)

  #check that the data was loaded correctly
  check_data = @spc_types["NREL_2009"]["ClimateZone 1-3"]["Hospital"]["Radiology"]["lighting_w_per_area"]
  unless check_data == 0.36
    puts "The space types json file did not load correctly."
    exit
  end

  #load up the osm with all the reference building schedules
  path_to_master_schedules_library = OpenStudio::Path.new(path_to_master_schedules_library)
  @schedule_library = OpenStudio::Model::Model::load(path_to_master_schedules_library).get  

  #load up the osm with the office building schedules
  path_to_office_schedules_library = OpenStudio::Path.new(path_to_office_schedules_library)
  @office_schedule_library = OpenStudio::Model::Model::load(path_to_office_schedules_library).get  
  
  #make a new openstudio model to hold the space type
  @model = OpenStudio::Model::Model.new

end

def generate_space_type(template, clim, building_type, spc_type)

  puts "generating #{template}-#{clim}-#{building_type}-#{spc_type}"

  #grabs a schedule with a specific name from the library, clones it into the space type model, and returns itself to the user
  def get_sch_from_lib(sch_name)
    #get the correct space type from the library file
    sch = nil
    sch = @schedule_library.getObjectByTypeAndName("OS_Schedule_Ruleset".to_IddObjectType,sch_name)
    if sch.empty?
      #temporarily check in the office file library.  this will be merged into master schedule library
      sch = @office_schedule_library.getObjectByTypeAndName("OS_Schedule_Ruleset".to_IddObjectType,sch_name)
      if sch.empty?
        puts "schedule called '#{sch_name}' not found in master schedule library or office schedule library"
        exit
      end
    end
    #clone the space type from the library model into the space type model
    clone_of_sch = sch.get.to_Schedule.get.clone(@model)
    new_sch = clone_of_sch.to_ScheduleRuleset.get
    return new_sch
  end

  #create a new space type and name it
  space_type = OpenStudio::Model::SpaceType.new(@model)
  space_type.setName("#{template} #{clim} #{building_type} #{spc_type}")

  #set the standards building type and space type for this new space type
  space_type.setStandardsBuildingType(building_type)
  space_type.setStandardsSpaceType(spc_type)
  
  #set the rendering color of the space type  
  rgb = @spc_types[template][clim][building_type][spc_type]["rgb"]
  rgb = rgb.split('_')
  r = rgb[0].to_i
  g = rgb[1].to_i
  b = rgb[2].to_i
  rendering_color = OpenStudio::Model::RenderingColor.new(@model)
  rendering_color.setRenderingRedValue(r)
  rendering_color.setRenderingGreenValue(g)
  rendering_color.setRenderingBlueValue(b)
  
  #create the schedule set for the space type
  default_sch_set = OpenStudio::Model::DefaultScheduleSet.new(@model)
  default_sch_set.setName("#{template} #{clim} #{building_type} #{spc_type} Schedule Set")
  space_type.setDefaultScheduleSet(default_sch_set)

  #lighting  
    
    make_lighting = false
    lighting_per_area = @spc_types[template][clim][building_type][spc_type]["lighting_w_per_area"]
    lighting_per_person = @spc_types[template][clim][building_type][spc_type]["lighting_w_per_person"]
    unless (lighting_per_area == 0 or lighting_per_area.nil?) then make_lighting = true end
    unless (lighting_per_person == 0 or lighting_per_person.nil?) then make_lighting = true end
    
    if make_lighting == true
    
      #create the lighting definition 
      lights_def = OpenStudio::Model::LightsDefinition.new(@model)
      lights_def.setName("#{template} #{clim} #{building_type} #{spc_type} Lights Definition")
      unless  lighting_per_area == 0 or lighting_per_area.nil?
        lights_def.setWattsperSpaceFloorArea(OpenStudio::convert(lighting_per_area,"W/ft^2","W/m^2").get)
      end
      unless lighting_per_person == 0 or lighting_per_person.nil?
        lights_def.setWattsperPerson(OpenStudio::convert(lighting_per_person,"W/person","W/person").get)
      end

      #create the lighting instance and hook it up to the space type
      lights = OpenStudio::Model::Lights.new(lights_def)
      lights.setName("#{template} #{clim} #{building_type} #{spc_type} Lights")
      lights.setSpaceType(space_type)  
      
      #get the lighting schedule and set it as the default
      lighting_sch = @spc_types[template][clim][building_type][spc_type]["lighting_sch"]
      unless lighting_sch.nil?
        default_sch_set.setLightingSchedule(get_sch_from_lib(lighting_sch))
      end    
    
    end

  #ventilation

    make_ventilation = false
    ventilation_per_area = @spc_types[template][clim][building_type][spc_type]["ventilation_per_area"]  
    ventilation_per_person = @spc_types[template][clim][building_type][spc_type]["ventilation_per_person"]
    ventilation_ach = @spc_types[template][clim][building_type][spc_type]["ventilation_ach"]
    unless (ventilation_per_area  == 0 or ventilation_per_area.nil?) then make_ventilation = true  end
    unless(ventilation_per_person == 0 or ventilation_per_person.nil?) then make_ventilation = true end
    unless(ventilation_ach == 0 or ventilation_ach.nil?) then make_ventilation = true end
    
    if make_ventilation == true
      
      #create the ventilation object and hook it up to the space type
      ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new(@model)
      ventilation.setName("#{template} #{clim} #{building_type} #{spc_type} Ventilation")
      space_type.setDesignSpecificationOutdoorAir(ventilation)
      ventilation.setOutdoorAirMethod("Sum")
      unless ventilation_per_area  == 0 or ventilation_per_area.nil? 
        ventilation.setOutdoorAirFlowperFloorArea(OpenStudio::convert(ventilation_per_area,"ft^3/min*ft^2","m^3/s*m^2").get)
      end
      unless ventilation_per_person == 0 or ventilation_per_person.nil?
        ventilation.setOutdoorAirFlowperPerson(OpenStudio::convert(ventilation_per_person,"ft^3/min*person","m^3/s*person").get)
      end
      unless ventilation_ach == 0 or ventilation_ach.nil?
        ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach)
      end
      
    end
    
  #occupancy

    make_people = false
    occupancy_per_area = @spc_types[template][clim][building_type][spc_type]["occupancy_per_area"]
    unless(occupancy_per_area == 0 or occupancy_per_area.nil?) then make_people = true end
    
    if make_people == true

      #create the people definition
      people_def = OpenStudio::Model::PeopleDefinition.new(@model)
      people_def.setName("#{template} #{clim} #{building_type} #{spc_type} People Definition")
      unless  occupancy_per_area == 0 or occupancy_per_area.nil?
        people_def.setPeopleperSpaceFloorArea(OpenStudio::convert(occupancy_per_area/1000,"people/ft^2","people/m^2").get)
      end    
      
      #create the people instance and hook it up to the space type
      people = OpenStudio::Model::People.new(people_def)
      people.setName("#{template} #{clim} #{building_type} #{spc_type} People")
      people.setSpaceType(space_type)
      
      #get the occupancy and occupant activity schedules from the library and set as the default
      occupancy_sch = @spc_types[template][clim][building_type][spc_type]["occupancy_sch"]
      unless occupancy_sch.nil?
        default_sch_set.setNumberofPeopleSchedule(get_sch_from_lib(occupancy_sch))
      end
      occupancy_activity_sch = @spc_types[template][clim][building_type][spc_type]["occupancy_activity_sch"]  
      unless occupancy_activity_sch.nil?
        default_sch_set.setPeopleActivityLevelSchedule(get_sch_from_lib(occupancy_activity_sch))
      end
      
    end
    
  #infiltration

    make_infiltration = false
    infiltration_per_area_ext = @spc_types[template][clim][building_type][spc_type]["infiltration_per_area_ext"]      
    unless(infiltration_per_area_ext == 0 or infiltration_per_area_ext.nil?) then make_infiltration = true end

    if make_infiltration == true
      
      #create the infiltration object and hook it up to the space type
      infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(@model)
      infiltration.setName("#{template} #{clim} #{building_type} #{spc_type} Infiltration")
      infiltration.setSpaceType(space_type)
      unless infiltration_per_area_ext == 0 or infiltration_per_area_ext.nil?
        infiltration.setFlowperExteriorSurfaceArea(OpenStudio::convert(infiltration_per_area_ext,"ft^3/min*ft^2","m^3/s*m^2").get)
      end
      
      #get the infiltration schedule from the library and set as the default
      infiltration_sch = @spc_types[template][clim][building_type][spc_type]["infiltration_sch"]
      unless infiltration_sch.nil?
        default_sch_set.setInfiltrationSchedule(get_sch_from_lib(infiltration_sch))
      end

    end    
      
  #electric equipment

    make_electric_equipment = false
    elec_equip_per_area = @spc_types[template][clim][building_type][spc_type]["elec_equip_per_area"]
    unless(elec_equip_per_area == 0 or elec_equip_per_area.nil?) then make_electric_equipment = true end
    
    if make_electric_equipment == true
    
      #create the electric equipment definition
      elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(@model)
      elec_equip_def.setName("#{template} #{clim} #{building_type} #{spc_type} Electric Equipment Definition")  
      unless  elec_equip_per_area == 0 or elec_equip_per_area.nil?
        elec_equip_def.setWattsperSpaceFloorArea(OpenStudio::convert(elec_equip_per_area,"W/ft^2","W/m^2").get)
      end
        
      #create the electric equipment instance and hook it up to the space type
      elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
      elec_equip.setName("#{template} #{clim} #{building_type} #{spc_type} Electric Equipment")
      elec_equip.setSpaceType(space_type)
      
      #get the electric equipment schedule from the library and set as the default
      elec_equip_sch = @spc_types[template][clim][building_type][spc_type]["elec_equip_sch"]
      unless elec_equip_sch.nil?
        default_sch_set.setElectricEquipmentSchedule(get_sch_from_lib(elec_equip_sch))
      end
      
    end
      
  #gas equipment
    
    make_gas_equipment = false
    gas_equip_per_area = @spc_types[template][clim][building_type][spc_type]["gas_equip_per_area"]
    unless  (gas_equip_per_area == 0 or gas_equip_per_area.nil?) then make_gas_equipment = true end
    
    if make_gas_equipment == true
    
      #create the gas equipment definition
      gas_equip_def = OpenStudio::Model::GasEquipmentDefinition.new(@model)
      gas_equip_def.setName("#{template} #{clim} #{building_type} #{spc_type} Gas Equipment Definition")
      unless  gas_equip_per_area == 0 or gas_equip_per_area.nil?
        gas_equip_def.setWattsperSpaceFloorArea(OpenStudio::convert(gas_equip_per_area,"Btu/hr*ft^2","W/m^2").get)
      end
      
      #create the gas equipment instance and hook it up to the space type
      gas_equip = OpenStudio::Model::GasEquipment.new(gas_equip_def)
      gas_equip.setName("#{template} #{clim} #{building_type} #{spc_type} Gas Equipment")
      gas_equip.setSpaceType(space_type)
      
      #get the gas equipment schedule from the library and set as the default
      gas_equip_sch = @spc_types[template][clim][building_type][spc_type]["gas_equip_sch"]
      unless gas_equip_sch.nil?
        default_sch_set.setGasEquipmentSchedule(get_sch_from_lib(gas_equip_sch))
      end

    end
    
  #component name
  component_name = space_type.name.get

  #componentize the space type
  space_type_component = space_type.createComponent

=begin
  #TODO make this return BCL component space types?

  #setup the file names and save paths that will be used
  file_name = "nrel_ref_bldg_space_type"
  component_dir = "#{Dir.pwd}/#{component_name}"
  osm_file_path = OpenStudio::Path.new("#{component_dir}/files/#{file_name}.osm")
  osc_file_path = OpenStudio::Path.new("#{component_dir}/files/#{file_name}.osc")

  #puts "component_dir = #{component_dir}"

  puts "creating directories"
  FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
  FileUtils.mkdir_p(component_dir)
  FileUtils.mkdir_p("#{component_dir}/files/")

  #save the space type as a .osm
  #puts "saving osm to #{osm_file_path}"
  @model.toIdfFile().save(osm_file_path,true)
  
  #save the componentized space type as a .osc
  #puts "saving osc to #{osc_file_path}"
  space_type_component.toIdfFile().save(osc_file_path,true)

  #make the BCL component
  puts "creating BCL component"
  component = BCL::Component.new(component_dir)
  puts "created uid = #{component.uuid}"

  #add component information
  component.name = component_name
  component.description = "This space type represent spaces in typical commercial buildings in the United States.  The information to create these space types was taken from the DOE Commercial Reference Building Models, which can be found at http://www1.eere.energy.gov/buildings/commercial_initiative/reference_buildings.html.  These space types include plug loads, gas equipment loads (cooking, etc), occupancy, infiltration, and ventilation rates, as well as schedules.  These space types should be viewed as starting points, and should be reviewed before being used to make decisions."
  component.source_manufacturer = "DOE"
  component.source_url = "http://www1.eere.energy.gov/buildings/commercial_initiative/reference_buildings.html"
  component.add_provenance("dgoldwas", Time.now.gmtime.strftime('%Y-%m-%dT%H:%M:%SZ'), "")
  component.add_tag("Space Types") # todo: what is the taxonomy string for space type? is there one?

  #add arguments as attributes
  component.add_attribute("NREL_reference_building_vintage", template, "")
  component.add_attribute("Climate_zone", clim, "")
  component.add_attribute("NREL_reference_building_primary_space_type", building_type, "")
  component.add_attribute("NREL_reference_building_secondary_space_type", spc_type, "")

  #openstudio type attribute
  component.add_attribute("OpenStudio Type", space_type.iddObjectType.valueDescription, "")
              
  #add other attributes
  component.add_attribute("Lighting Standard",  @spc_types[template][clim][building_type][spc_type]["lighting_standard"], "")
  component.add_attribute("Lighting Primary Space Type",  @spc_types[template][clim][building_type][spc_type]["lighting_pri_spc_type"], "")
  component.add_attribute("Lighting Secondary Space Type",  @spc_types[template][clim][building_type][spc_type]["lighting_sec_spc_type"], "")

  component.add_attribute("Ventilation Standard",  @spc_types[template][clim][building_type][spc_type]["ventilation_standard"], "")
  component.add_attribute("Ventilation Primary Space Type",  @spc_types[template][clim][building_type][spc_type]["ventilation_pri_spc_type"], "")
  component.add_attribute("Ventilation Secondary Space Type",  @spc_types[template][clim][building_type][spc_type]["ventilation_sec_spc_type"], "")

  component.add_attribute("Occupancy Standard",  "NREL reference buildings", "")
  component.add_attribute("Occupancy Primary Space Type",  building_type, "")
  component.add_attribute("Occupancy Secondary Space Type",  spc_type, "")

  component.add_attribute("Infiltration, Gas Equipment, Electric Equipment, and Schedules Standard",  "NREL reference buildings", "")
  component.add_attribute("Infiltration, Gas Equipment, Electric Equipment, and Schedules Primary Space Type",  building_type, "")
  component.add_attribute("Infiltration, Gas Equipment, Electric Equipment, and Schedules Secondary Space Type",  spc_type, "")

  #add the osm and osc files to the component
  component.add_file("OpenStudio", "0.9.3",  osm_file_path.to_s, "#{file_name}.osm", "osm")
  component.add_file("OpenStudio", "0.9.3",  osc_file_path.to_s, "#{file_name}.osc", "osc")

  #puts "saving component to #{component_dir}"
  component.save_component_xml(component_dir)

=end  

  #return the space type and the componentized space type
  return [space_type, space_type_component]
  
end #end generate_space_type

end #end class SpaceTypeGenerator

