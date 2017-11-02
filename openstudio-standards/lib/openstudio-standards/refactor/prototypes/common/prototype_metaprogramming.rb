# Using Evals to metaprogram here... Probably bad practice and makes debugging difficult...that being said I'm stubbing
# these for now to expediate testing. This only works now since we all use the same buildings.. as the buildings change in the future will require
# separate files for each template in the templates folder.
require 'json'
prototype_buildings = [
    "FullServiceRestaurant",
    "Hospital",
    "HighriseApartment",
    "LargeHotel",
    "LargeOffice",
    "MediumOffice",
    "MidriseApartment",
    "Outpatient",
    "PrimarySchool",
    "QuickServiceRestaurant",
    "RetailStandalone",
    "SecondarySchool",
    "SmallHotel",
    "SmallOffice",
    "RetailStripmall",
    "Warehouse"
]


templates = ['NECB_2011',
             'A90_1_2004',
             'A90_1_2007',
             'A90_1_2010',
             'A90_1_2013',
             'DOERef1980_2004',
             'DOERefPre1980',
             'NRELZNEReady2017'
]

templates.each do |template|
  #Create Prototype base class (May not be needed...)
  #Ex: class NECB_2011_Prototype < NECB_2011_Model
  eval <<DYNAMICClass
class #{template}_Prototype < #{template}_Model
  attr_reader :instvarbuilding_type
  def initialize
    super()
  end
end
DYNAMICClass

  #Create Building Specific classes for each building.
  #Example class NECB_2011Hospital
  prototype_buildings.each do |name|
    eval <<DYNAMICClass
class #{template}#{name} < #{template}_Prototype
  @@building_type = "#{name}"
  register_standard ("\#{@@template}_\#{@@building_type}")
  attr_accessor :prototype_database
  attr_accessor :prototype_input
  attr_accessor :lookup_building_type
  attr_accessor :space_type_map
  attr_accessor :geometry_file
  attr_accessor :building_story_map
  attr_accessor :space_multiplier_map 
  attr_accessor :system_to_space_map
  def initialize
    super()
    @instvarbuilding_type = @@building_type
    #this will load data specific to this prototype based on the class name lookup.
    json_data = JSON.parse(File.read("\#{Folders.instance.refactor_folder}/prototypes/common/data/prototype_database.json"))
    @prototype_database = json_data.detect {|i| i["class_name"] == self.class.name }
    puts @prototype_database
    @prototype_input = self.model_find_object($os_standards['prototype_inputs'], {'template' => @instvartemplate,'building_type' => @@building_type }, nil)
    if @prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for \#{{'template' => @instvartemplate,'building_type' => @@building_type }}, cannot create model.")
      raise()
      return false
    end
    @lookup_building_type = self.model_get_lookup_name(@@building_type)
    #ideally we should map the data required to a instance variable.
    @geometry_file =     "\#{Folders.instance.data_geometry_folder}/\#{@prototype_database["geometry"]}"
    @space_type_map =     @prototype_database["space_type_map"]
    @system_to_space_map = @prototype_database["system_to_space_map"]
    self.set_variables()
  end
  def set_variables()
    #Will be overwritten in class reopen file.
    puts geometry_file
    puts @space_type_map
    puts @system_to_space_map
    #add all building methods for now. 
    self.extend(#{name})
  end
#Common Methods to all prototypes. 
  def define_space_type_map(building_type, template, climate_zone)
    return @space_type_map
  end

  def define_hvac_system_map(building_type, template, climate_zone)
    return @system_to_space_map
  end

  def define_space_multiplier
    return @space_multiplier_map
  end





 def define_building_story_map(building_type, instvartemplate, climate_zone)
    return @building_story_map
 end

 def modify_oa_controller(instvartemplate, model)
 end

 def reset_or_room_vav_minimum_damper(prototype_input, instvartemplate, model)
 end

 def update_exhaust_fan_efficiency(instvartemplate, model)
 end

 def update_fan_efficiency(model)
 end

   # Get the name of the building type used in lookups
  #
  # @param building_type [String] the building type
  # @return [String] returns the lookup name as a string
  # @todo Unify the lookup names and eliminate this method
  def model_get_lookup_name(building_type)
    lookup_name = building_type
    case building_type
      when 'SmallOffice'
        lookup_name = 'Office'
      when 'MediumOffice'
        lookup_name = 'Office'
      when 'LargeOffice'
        lookup_name = 'Office'
      when 'LargeOfficeDetail'
        lookup_name = 'Office'
      when 'RetailStandalone'
        lookup_name = 'Retail'
      when 'RetailStripmall'
        lookup_name = 'StripMall'
      when 'Office'
        lookup_name = 'Office'
    end
    return lookup_name
  end

end
DYNAMICClass
  end
end
