#Proposed Code Structure to reduce case statements for Standards and Prototype methods.

# Using Polymorphism to take care of multiple standards. This will require a Standard class to be subclassed from the
# OpenStudio::Model::Model.  This will also reduce methods at the "model" class level, which may conflict with user scripts
#
# The Standards class will contain the boiler plate code methods used by all the templates/vintages. It may also contain empty
# method stubs that *must* be implemented by children. The standard class methods will be the common interface for all
# the vintages. This way the program flow will be consistant between vintages.
#
# The Standards class and children shall not contain any prototype information, however the prototyp modules may contain
# standard information.

# For simplicity of developers, all Prototype information will be in a single folder. The benefit is that the logic could potentially
# be extended for end users creating their own prototypes that could operate out of our blessed archetypes.

#End result that  Standard code is in a single rb file.. all pro


#These are common prototype methods..things that use lookup are here.
module PrototypeMethods
  def common_prototype_methods
    "I am a common prototype method"
  end

  def assign_space_types()
    puts "assign #{building_type }Spaces for #{@template}"
  end
end

module LargeHotel
  def building_type ()
    "LargeHotel"
  end
end

module LargeOffice
  def building_type ()
    "LargeOffice"
  end
  def assign_space_types()
     puts "I'm a special case!"
  end
end



# This class will have all the common methods used by all vintages/templates/standards. This will include methods to
# look up stuff in the json files. There will also be stubs for incremental methods as required for each vintage.
class Standards_Model
  def intialized()
    @template = "standard"
  end

  #This static method will generate an instance of the a standards and extend the building type module.
  def self.create_prototype(epw_file, climate_zone, type: :LargeHotel)
    @epw_file = epw_file
    @climate_zone = climate_zone
    prototype_model = new
    prototype_model.extend(PrototypeMethods)
    prototype_model.extend const_get(type)
    prototype_model.assign_space_types()  #building_type Method

    prototype_model.add_hvac() #Child Class
    puts type.to_s.class
    return prototype_model
  end

  def self.create_proposed_model(model)
    raise("this should overridden in the child.")
  end

  def self.create_reference_model(model)
    raise("this should overridden in the child.")
  end

  def what_am_i
    puts "#{@template}_#{building_type()}_#{common_prototype_methods}"
  end


end

#This class / file will contain all NECB code required.
class NECB < Standards_Model
  def initialize(type: :LargeHotel)
    super()
    @template = "NECB 2011"
  end
  def add_hvac()
    puts "Adding NECB HVAC"
  end
end

#This class / file will contain all A901 code only
class A90_1 < Standards_Model
  def initialize(type: :LargeHotel)
    super()
    @template = "ASHRAE 90.1"
  end

  def add_hvac()
    puts "Adding A90.1 HVAC"
  end
end


NECB.create_prototype("toronto.epw", "CZ-3", type: :LargeOffice).what_am_i
#>>I'm a special case!
#>>Adding NECB HVAC
#>>NECB 2011_LargeOffice_I am a common prototype method

NECB.create_prototype("toronto.epw", "CZ-3", type: :LargeHotel).what_am_i
#>>assign LargeHotelSpaces for NECB 2011
#>>Adding NECB HVAC
#>>NECB 2011_LargeHotel_I am a common prototype method


A90_1.create_prototype("toronto.epw", "CZ-3", type: :LargeOffice).what_am_i
#>>I'm a special case!
#>>Adding A90.1 HVAC
#>>ASHRAE 90.1_LargeOffice_I am a common prototype method

A90_1.create_prototype("toronto.epw", "CZ-3", type: :LargeHotel).what_am_i
#>>assign LargeHotelSpaces for ASHRAE 90.1
#>>Adding A90.1 HVAC
#>>ASHRAE 90.1_LargeHotel_I am a common prototype method