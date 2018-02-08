# Using Evals to metaprogram here... Probably bad practice and makes debugging difficult...that being said I'm stubbing
# these for now to expediate testing. This only works now since we all use the same buildings.. as the buildings change in the future will require
# separate files for each template in the templates folder.
require 'json'

def create_class_array
  prototype_buildings = [
      'FullServiceRestaurant',
      'Hospital',
      'HighriseApartment',
      'LargeHotel',
      'LargeOffice',
      'MediumOffice',
      'MidriseApartment',
      'Outpatient',
      'PrimarySchool',
      'QuickServiceRestaurant',
      'RetailStandalone',
      'SecondarySchool',
      'SmallHotel',
      'SmallOffice',
      'RetailStripmall',
      'Warehouse',
      'SuperMarket'
  ]

  templates = ['ASHRAE9012004',
               'ASHRAE9012007',
               'ASHRAE9012010',
               'ASHRAE9012013',
               'DOERef1980to2004',
               'DOERefPre1980',
               'NRELZNEReady2017']
  class_array = []
  templates.each do |template|
    # Create Prototype base class (May not be needed...)
    # Ex: class NECB2011_Prototype < NECB2011
    class_array << "
  class #{template}_Prototype < #{template}
  attr_reader :instvarbuilding_type
  def initialize
    super()
  end
end
"

    # Create Building Specific classes for each building.
    # Example class NECB2011Hospital
    prototype_buildings.each do |name|
      class_array << "
  # This class represents a prototypical #{template} #{name}.
  class #{template}#{name} < #{template}
  @@building_type = \"#{name}\"
  register_standard (\"\#{@@template}_\#{@@building_type}\")
  attr_accessor :prototype_database
  attr_accessor :prototype_input
  attr_accessor :lookup_building_type
  attr_accessor :space_type_map
  attr_accessor :geometry_file
  attr_accessor :building_story_map
  attr_accessor :system_to_space_map
  def initialize
    super()
    @instvarbuilding_type = @@building_type
    @prototype_input = self.model_find_object(standards_data['prototype_inputs'], {'template' => @template,'building_type' => @@building_type }, nil)
    if @prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', \"Could not find prototype inputs for \#{{'template' => @template,'building_type' => @@building_type }}, cannot create model.\")
      raise(\"Could not find prototype inputs for #{template}#{name}, cannot create model.\")
      return false
    end
    @lookup_building_type = self.model_get_lookup_name(@@building_type)
    #ideally we should map the data required to a instance variable.
    @geometry_file = Folders.instance.data_geometry_folder + '/' + self.class.name + '.osm'
    hvac_map_file =  Folders.instance.data_geometry_folder + '/' + self.class.name + '.hvac_map.json'
    @system_to_space_map = JSON.parse(File.read(hvac_map_file))if File.exist?(hvac_map_file)
    self.set_variables()
  end
  # This method is used to extend the class with building-type-specific
  # methods, as defined in Prototype.SomeBuildingType.rb.  Each building type
  # has its own set of methods that change things which are not
  # common across all prototype buildings, even within a given Standard.
  def set_variables()
    # Will be overwritten in class reopen file.
    # add all building methods for now.
    self.extend(#{name}) unless @template == 'NECB 2011'
  end
  # Returns the mapping between the names of the spaces
  # in the geometry .osm file and the space types
  # available for this particular Standard.
  def define_space_type_map(building_type, climate_zone)
    return @space_type_map
  end
  # Returns the mapping between the names of the spaces
  # in the geometry .osm file and the HVAC system that will
  # be applied to those spaces.
  def define_hvac_system_map(building_type, climate_zone)
    return @system_to_space_map
  end
  # Returns the mapping between the names of the spaces
  # in the geometry .osm file and the building story
  # that they are located on.
  def define_building_story_map(building_type, climate_zone)
     return @building_story_map
  end
  # Does nothing unless implmented by the specific standard
  def model_modify_oa_controller(model)
  end
  # Does nothing unless implmented by the specific standard
  def model_reset_or_room_vav_minimum_damper(prototype_input, model)
  end
  # Does nothing unless implmented by the specific standard
  def model_update_exhaust_fan_efficiency(model)
  end
  # Does nothing unless implmented by the specific standard
  def model_update_fan_efficiency(model)
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
"
    end
  end

  ['NECB2011',
   'NECB2015'].each do |template|
    # Create Prototype base class (May not be needed...)
    # Ex: class NECB2011_Prototype < NECB2011
    class_array << "
  class #{template}_Prototype < #{template}
  attr_reader :instvarbuilding_type
  def initialize
    super()
  end
end
"

    # Create Building Specific classes for each building.
    # Example class NECB2011Hospital
    prototype_buildings.each do |name|
      class_array << "
  # This class represents a prototypical #{template} #{name}.
  class #{template}#{name} < #{template}
    BUILDING_TYPE = \"#{name}\"
    TEMPLATE =  \"#{template}\"
    register_standard (\"\#{TEMPLATE}_\#{BUILDING_TYPE}\")
    attr_accessor :prototype_database
    attr_accessor :prototype_input
    attr_accessor :lookup_building_type
    attr_accessor :space_type_map
    attr_accessor :geometry_file
    attr_accessor :building_story_map
    attr_accessor :system_to_space_map

    def initialize
      super()
      @building_type = BUILDING_TYPE
      @template = TEMPLATE
      @instvarbuilding_type = @building_type
      @prototype_input = self.model_find_object(standards_data['prototype_inputs'], {'template' => @template,'building_type' => @building_type }, nil)
      if @prototype_input.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', \"Could not find prototype inputs for \#{{'template' => @template,'building_type' => @building_type }}, cannot create model.\")
        #puts JSON.pretty_generate(standards_data['prototype_inputs'])
        raise(\"Could not find prototype inputs for \#{@template}\#{@name}, cannot create model.\")
        return false
      end
      @lookup_building_type = self.model_get_lookup_name(@building_type)
      #ideally we should map the data required to a instance variable.
      @geometry_file = Folders.instance.data_geometry_folder + '/' + self.class.name + '.osm'
      hvac_map_file =  Folders.instance.data_geometry_folder + '/' + self.class.name + '.hvac_map.json'
      @system_to_space_map = JSON.parse(File.read(hvac_map_file))if File.exist?(hvac_map_file)
      self.set_variables()
    end

  # This method is used to extend the class with building-type-specific
  # methods, as defined in Prototype.SomeBuildingType.rb.  Each building type
  # has its own set of methods that change things which are not
  # common across all prototype buildings, even within a given Standard.
    def set_variables()
      # Will be overwritten in class reopen file.
      # add all building methods for now.
      self.extend(#{name}) unless @template == 'NECB2011'
    end

  # Returns the mapping between the names of the spaces
  # in the geometry .osm file and the space types
  # available for this particular Standard.
    def define_space_type_map(building_type, climate_zone)
      return @space_type_map
    end

  # Returns the mapping between the names of the spaces
  # in the geometry .osm file and the HVAC system that will
  # be applied to those spaces.
    def define_hvac_system_map(building_type, climate_zone)
      return @system_to_space_map
    end

  # Returns the mapping between the names of the spaces
  # in the geometry .osm file and the building story
  # that they are located on.
  def define_building_story_map(building_type, climate_zone)
     return @building_story_map
  end

  # Does nothing unless implmented by the specific standard
  def model_modify_oa_controller(model)
  end

  # Does nothing unless implmented by the specific standard
  def model_reset_or_room_vav_minimum_damper(prototype_input, model)
  end

  # Does nothing unless implmented by the specific standard
  def model_update_exhaust_fan_efficiency(model)
  end

  # Does nothing unless implmented by the specific standard
  def model_update_fan_efficiency(model)
  end

end
"
    end
  end


  return class_array
end

def create_meta_classes
  create_class_array.each {|item| eval(item)} # rubocop:disable Security/Eval
end

def save_meta_classes_to_file
  filepath = "#{File.dirname(__FILE__)}/do_not_edit_metaclasses.rb"
  File.open(filepath, 'w') {|f| create_class_array.each {|item| f << item}}
end

def remove_meta_class_file
  filepath = "#{File.dirname(__FILE__)}/do_not_edit_metaclasses.rb"
  FileUtils.rm(filepath)
end
