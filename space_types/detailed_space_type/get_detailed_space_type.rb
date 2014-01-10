#this script defines the on-demand detailed space types generator method

require 'rubygems'
require 'json'
require 'openstudio'

#load the data from the JSON files into ruby hashes

  #NREL reference buildings
  $nrel_spc_types = {}
  temp = File.read('nrel_ref_bldg_space_types.json')
  $nrel_spc_types = JSON.parse(temp)

  #ventilation standards
  $vent_spc_types = {}
  temp = File.read('vent_std_space_types.json')
  $vent_spc_types = JSON.parse(temp)

  #occupancy standards
  $occ_spc_types = {}
  temp = File.read('occ_std_space_types.json')
  $occ_spc_types = JSON.parse(temp)

  #lighting standards
  $lighting_spc_types = {}
  temp = File.read('lighting_std_space_types.json')
  $lighting_spc_types = JSON.parse(temp)


#detailed space type on-demand generator; returns a model populated with the newly made space type and associated loads and schedules
#must specify standards for ventilation, occupancy, lighting, and an NREL reference building to fill in the rest
def get_detailed_space_type(ref_bldg_std, ref_bldg_clim, ref_bldg_pri_spc_type, ref_bldg_sec_spc_type,
                            vent_std, vent_std_pri_spc_type, vent_std_sec_spc_type,
                            occ_std, occ_std_pri_spc_type, occ_std_sec_spc_type,
                            lighting_std, lighting_std_pri_spc_type, lighting_std_sec_spc_type)
 
  #error checking
  puts "ref_bldg*#{ref_bldg_std}*#{ref_bldg_clim}*#{ref_bldg_pri_spc_type}*#{ref_bldg_sec_spc_type}*"
  puts "vent*#{vent_std}*#{vent_std_pri_spc_type}*#{vent_std_sec_spc_type}*"
  puts "occ*#{occ_std}*#{occ_std_pri_spc_type}*#{occ_std_sec_spc_type}*"
  puts "lighting*#{lighting_std}*#{lighting_std_pri_spc_type}*#{lighting_std_sec_spc_type}*"
    
  #load up the osm with all the reference building schedules
  schedule_library_path = OpenStudio::Path.new("#{$root_path}MasterTemplate.osm")
  $schedule_library = OpenStudio::Model::Model::load(schedule_library_path).get  

  #make a new openstudio model to hold the space type
  $model = OpenStudio::Model::Model.new
  
  #method for converting from IP to SI if you know the strings of the input and the output
  def ip_to_si(number, ip_unit_string, si_unit_string)     
    ip_unit = OpenStudio::createUnit(ip_unit_string, "IP".to_UnitSystem).get
    si_unit = OpenStudio::createUnit(si_unit_string, "SI".to_UnitSystem).get
    #puts "#{ip_unit} --> #{si_unit}"
    ip_quantity = OpenStudio::Quantity.new(number, ip_unit)
    si_quantity = OpenStudio::convert(ip_quantity, si_unit).get
    puts "#{ip_quantity} = #{si_quantity}" 
    return si_quantity.value
  end

  #grabs a schedule with a specific name from the library, clones it into the space type model, and returns itself to the user
  def get_sch_from_lib(sch_name)
    #get the correct space type from the library file
    sch = $schedule_library.getObjectByTypeAndName("OS_Schedule_Ruleset".to_IddObjectType,sch_name)
    #clone the space type from the library model into the space type model
    clone_of_sch = sch.get.to_Schedule.get.clone($model)
    new_sch = clone_of_sch.to_ScheduleRuleset.get
    return new_sch
  end

  #create a new space type and name it
  space_type = OpenStudio::Model::SpaceType.new($model)
  #TODO decide on how to name these detailed space types
  space_type.setName("TODO change my name")

  #create the schedule set for the space type
  default_sch_set = OpenStudio::Model::DefaultScheduleSet.new($model)
  space_type.setDefaultScheduleSet(default_sch_set)
  
  #lighting - from the lighting standard
  unless lighting_std == "None"
    #create the lighting definition 
    lights_def = OpenStudio::Model::LightsDefinition.new($model)
    lights_def.setName("#{lighting_std} #{lighting_std_pri_spc_type} #{lighting_std_sec_spc_type} Lights Definition")
    
    lighting_per_area = $lighting_spc_types[lighting_std][lighting_std_pri_spc_type][lighting_std_sec_spc_type]["lighting_per_area"]
      unless  lighting_per_area == 0 or lighting_per_area.nil?
        lights_def.setWattsperSpaceFloorArea(ip_to_si(lighting_per_area,"W/ft^2","W/m^2"))
      end

    #create the lighting instance and hook it up to the space type
    lights = OpenStudio::Model::Lights.new(lights_def)
    lights.setName("#{lighting_std} #{lighting_std_pri_spc_type} #{lighting_std_sec_spc_type} Lights")
  end
  
  #ventilation - from the ventilation standard
  unless vent_std == "None"
    #create the ventilation object and hook it up to the space type
    ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new($model)
    ventilation.setName("#{vent_std} #{vent_std_pri_spc_type} #{vent_std_sec_spc_type} Ventilation")
    vent_per_area = $vent_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_per_area"]
      unless vent_per_area  == 0 or vent_per_area.nil? 
        ventilation.setOutdoorAirFlowperFloorArea(ip_to_si(vent_per_area,"ft^3/min*ft^2","m^3/s*m^2"))
      end
    vent_per_person = $vent_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_per_person"]
      unless vent_per_person == 0 or vent_per_person.nil?
        ventilation.setOutdoorAirFlowperFloorArea(ip_to_si(vent_per_person,"ft^3/min*person","m^3/s*person"))
      end
    vent_ach = $vent_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_ach"]
      unless vent_ach == 0 or vent_ach.nil?
        ventilation.setOutdoorAirFlowAirChangesperHour(vent_ach)
      end
    ventilation.setOutdoorAirMethod("Sum")
    space_type.setDesignSpecificationOutdoorAir(ventilation)
  end
    
  #occupancy - from the occupancy standard
  unless occ_std == "None"
    #create the people definition
    people_def = OpenStudio::Model::PeopleDefinition.new($model)
    people_def.setName("#{occ_std} #{occ_std_pri_spc_type} #{occ_std_sec_spc_type} People Definition")
    occ_per_area = $occ_spc_types[occ_std][occ_std_pri_spc_type][occ_std_sec_spc_type]["occ_per_area"]
      unless  occ_per_area == 0 or occ_per_area.nil?
        people_def.setPeopleperSpaceFloorArea(ip_to_si(occ_per_area/1000,"people/ft^2","people/m^2"))
      end

    #create the people instance and hook it up to the space type
    people = OpenStudio::Model::People.new(people_def)
    people.setName("#{occ_std} #{occ_std_pri_spc_type} #{occ_std_sec_spc_type} People") 
  end
  
  #infiltration, gas and electric equipment, and all schedules from the NREL ref bldgs
  unless ref_bldg_std == "None"
  
    #schedules for lighting 
    unless lighting_std == "None"
      lighting_sch = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_sch"]
        unless lighting_sch.nil?
          default_sch_set.setLightingSchedule(get_sch_from_lib(lighting_sch))
        end  
    end
    
    #schedules for occupancy
    unless occ_std == "None"
          occupancy_sch = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_sch"]
        unless occupancy_sch.nil?
          default_sch_set.setNumberofPeopleSchedule(get_sch_from_lib(occupancy_sch))
        end
      occupancy_activity_sch = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_activity_sch"]  
        unless occupancy_activity_sch.nil?
          default_sch_set.setPeopleActivityLevelSchedule(get_sch_from_lib(occupancy_activity_sch))
        end
    end
    
    #infiltration
    
      #create the infiltration object and hook it up to the space type
      infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new($model)
      infiltration.setName("#{ref_bldg_std} #{ref_bldg_clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Infiltration")
      infiltration_per_area_ext = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["infiltration_per_area_ext"]      
        unless infiltration_per_area_ext == 0 or infiltration_per_area_ext.nil?
          infiltration.setFlowperExteriorSurfaceArea(ip_to_si(infiltration_per_area_ext,"ft^3/min*ft^2","m^3/s*m^2"))
        end
      infiltration.setSpaceType(space_type)
      infiltration_sch = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["infiltration_sch"]
        unless infiltration_sch.nil?
          default_sch_set.setInfiltrationSchedule(get_sch_from_lib(infiltration_sch))
        end
        
    #gas equipment
      
      #creat the gas equipment definition
      gas_equip_def = OpenStudio::Model::GasEquipmentDefinition.new($model)
      gas_equip_def.setName("#{ref_bldg_std} #{ref_bldg_clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Gas Equipment Definition")
      gas_equip_per_area = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["gas_equip_per_area"]
        unless  gas_equip_per_area == 0 or gas_equip_per_area.nil?
          gas_equip_def.setWattsperSpaceFloorArea(ip_to_si(gas_equip_per_area,"btu/hr*ft^2","W/m^2"))
        end
      
      #create the gas equipment instance and hook it up to the space type
      gas_equip = OpenStudio::Model::GasEquipment.new(gas_equip_def)
      gas_equip.setName("#{ref_bldg_std} #{ref_bldg_clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Gas Equipment")
      gas_equip_sch = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["gas_equip_sch"]
        unless gas_equip_sch.nil?
          default_sch_set.setGasEquipmentSchedule(get_sch_from_lib())
        end
        
    #electric equipment
    
      #create the electric equipment definition
      elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new($model)
      elec_equip_def.setName("#{ref_bldg_std} #{ref_bldg_clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Electric Equipment Definition")
      elec_equip_per_area = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["elec_equip_per_area"]
        unless  elec_equip_per_area == 0 or elec_equip_per_area.nil?
          elec_equip_def.setWattsperSpaceFloorArea(ip_to_si(elec_equip_per_area,"W/ft^2","W/m^2"))
        end
        
      #create the electric equipment instance and hook it up to the space type
      elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
      elec_equip.setName("#{ref_bldg_std} #{ref_bldg_clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Electric Equipment")
      elec_equip_sch = $nrel_spc_types[ref_bldg_std][ref_bldg_clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["elec_equip_sch"]
        unless elec_equip_sch.nil?
          default_sch_set.setElectricEquipmentSchedule(get_sch_from_lib(elec_equip_sch))
        end
  end

  
  return $model #space_type

end



#test out the detailed space type on-demand generator
new_space_type_1 = get_detailed_space_type("ASHRAE_189.1-2009","ClimateZone 1-3","Hospital","Radiology",
                                          "ASHRAE 62.1-1999","Hotels, Motels, Resorts, Dormitories","Bedrooms",
                                          "ASHRAE 62.1-2004","General","Corridors",
                                          "ASHRAE 90.1-1999","Classroom/Lecture/Training","For Penitentiary")
puts new_space_type_1







