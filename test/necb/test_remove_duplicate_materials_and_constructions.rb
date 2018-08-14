require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require 'json'


# this method converts an idf object to a hash
=begin
EXAMPLE:
Converts the following IDF (openstudio::ModelObject) to
==================================================================
OS:Material,
  {8adb3faa-8e6a-48e3-bd73-ba6a02154b02}, !- Handle
  1/2IN Gypsum,                           !- Name
  Smooth,                                 !- Roughness
  0.0127,                                 !- Thickness {m}
  0.16,                                   !- Conductivity {W/m-K}
  784.9,                                  !- Density {kg/m3}
  830.000000000001,                       !- Specific Heat {J/kg-K}
  0.9,                                    !- Thermal Absorptance
  0.4,                                    !- Solar Absorptance
  0.4;                                    !- Visible Absorptance
===================================================================

===================================================================
{
  "Handle": "{8adb3faa-8e6a-48e3-bd73-ba6a02154b02}",
  "Name": "1/2IN Gypsum",
  "Roughness": "Smooth",
  "Thickness {m}": "0.0127",
  "Conductivity {W/m-K}": "0.16",
  "Density {kg/m3}": "784.9",
  "Specific Heat {J/kg-K}": "830.000000000001",
  "Thermal Absorptance": "0.9",
  "Solar Absorptance": "0.4",
  "Visible Absorptance": "0.4"
},
===================================================================
=end
def idf_to_h(obj)
  # split idf object by line
  obj_string = obj.to_s.split("\n")
  new_obj_hash = {}

  # itterate through each line and split the value and field
  # and assign it to the hash
  obj_string.each_with_index {|line,i|
    next if i == 0
    line.gsub!(/(\,|\;)/, '') # remove commas and semi-colons
    line.strip! # remove whitespace at the end and the beginning of the string
    v,k = line.split(/\s*\!\-\s+/) # split the line into at the string '!-' including the spaces before and after
    new_obj_hash[k] = v
  }
  new_obj_hash
end



# This method uses idf_to_h(obj) method, but deletes the fields named 'Handle' and 'Name'
=begin
EXAMPLE:
Converts the following IDF (openstudio::ModelObject) to
==================================================================
OS:Material,
  {8adb3faa-8e6a-48e3-bd73-ba6a02154b02}, !- Handle
  1/2IN Gypsum,                           !- Name
  Smooth,                                 !- Roughness
  0.0127,                                 !- Thickness {m}
  0.16,                                   !- Conductivity {W/m-K}
  784.9,                                  !- Density {kg/m3}
  830.000000000001,                       !- Specific Heat {J/kg-K}
  0.9,                                    !- Thermal Absorptance
  0.4,                                    !- Solar Absorptance
  0.4;                                    !- Visible Absorptance
===================================================================

===================================================================
{
  "Roughness": "Smooth",
  "Thickness {m}": "0.0127",
  "Conductivity {W/m-K}": "0.16",
  "Density {kg/m3}": "784.9",
  "Specific Heat {J/kg-K}": "830.000000000001",
  "Thermal Absorptance": "0.9",
  "Solar Absorptance": "0.4",
  "Visible Absorptance": "0.4"
},
===================================================================
=end
def idf_to_h_clean(obj)
  # converts the idf object to hash
  idf_hash = idf_to_h(obj)

  # remove the field named `Handle` and `Name` from the idf_hash
  idf_hash.delete("Handle") if idf_hash.key?("Handle")
  idf_hash.delete("Handle".to_sym) if idf_hash.key?("Handle".to_sym)

  idf_hash.delete("Name") if idf_hash.key?("Name")
  idf_hash.delete("Name".to_sym) if idf_hash.key?("Name".to_sym)

  # Loop through idf_hash and delete any field that matched the UUID regex
  # idf_hash.each {|k,v|
  #   idf_hash.delete(k) if /^\{[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\}$/.match(v)
  # }
  # idf_hash
end

# This method will group similar objects under a key that has all the
# values of an IDF object which excludes Handles and Names.
# NOTE: The objexts grouped should have the fields in the same order.
# If not, then it would not be consired as a duplicate.
=begin
# EXAMPLE:

"[\"Smooth\", \"0.216479986995276\", \"0.9\", \"0.7\", \"0.8\"]": [
    {
      "Handle": "{a7c45cf6-166d-48a6-9750-efb5c3386d91}",
      "Name": "Typical Carpet Pad",
      "Roughness": "Smooth",
      "Thermal Resistance {m2-K/W}": "0.216479986995276",
      "Thermal Absorptance": "0.9",
      "Solar Absorptance": "0.7",
      "Visible Absorptance": "0.8"
    },
    {
      "Handle": "{9873fb84-bfaf-459d-8b70-2c3f5722bda9}",
      "Name": "Typical Carpet Pad 1",
      "Roughness": "Smooth",
      "Thermal Resistance {m2-K/W}": "0.216479986995276",
      "Thermal Absorptance": "0.9",
      "Solar Absorptance": "0.7",
      "Visible Absorptance": "0.8"
    },
    {
      "Handle": "{63a12315-1de4-453a-b154-e6e6e9871be2}",
      "Name": "Typical Carpet Pad 4",
      "Roughness": "Smooth",
      "Thermal Resistance {m2-K/W}": "0.216479986995276",
      "Thermal Absorptance": "0.9",
      "Solar Absorptance": "0.7",
      "Visible Absorptance": "0.8"
    }
  ],
=end
def group_similar_objects(obj_array)
  # group [objects] by values except Handles and Name
  grouped_objs = obj_array.group_by{ |idf_hash|
    out = []
    # skip Handle and Name keys
    #
    # ideally the `keys` of the `idf_hash` should be sorted,
    # but I'll leave it alone for now
    idf_hash.each {|key, val|
      next if key == "Handle"
      next if key == "Name"
      out << val # push all the values into an array. This becomes the key of the hash that contains the duplicate objects
    }
    out
  }

  # Sort the grouped [objects] by Name.
  # This is doen such that the first object will always have the smaller name
  grouped_objs.each {|key, dup_array|
    dup_array.sort_by{|idf_hash|
      # puts idf_hash
      idf_hash['Name'] # Sort by Name
    }
  }
  return grouped_objs
end

# Replace the UUID of the duplicate material, unless it contains ", !- Handle"
# This is done so after the model has been written to the disk, It can be read and
# the duplicate materials can be removed safely.
def replace_duplicate_obj_handles(model, grouped_objs)
  model_string = model.to_s # convert the OS:Model into a String
  grouped_objs.each {|key, dup_array|
    dup_array.each_with_index {|idf_hash, index |
      next if index == 0 # skipping index 0, because it has the shortest name and considered as the original

      # givn that the idf_hash['Handle'] => '{8c88931b-e19d-479b-ac71-138d18c97cc9}'
      # The following regex matches "{8c88931b-e19d-479b-ac71-138d18c97cc9}" in the following line
      # {8c88931b-e19d-479b-ac71-138d18c97cc9}, !- Layer 1
      #
      # but matches nothing if the line has the keyword '!- Handle' in it e.g.
      # {8c88931b-e19d-479b-ac71-138d18c97cc9}, !- Handle
      replace_regex = idf_hash['Handle'].to_s.gsub('{', '\{'). # escape brackets
          gsub('}', '\}').   # escape brackets
          gsub('-', '\-') +  # escape dashes
          '(?!.*?\!\-(\s)*Handle)' # making sure the matched handle is not part of the line that contains the substring '!- Handle'
      replace_regex = Regexp.new(replace_regex)
      # p replace_regex

      # replace duplicate handles with the handle found at index 0
      model_string.gsub!(replace_regex, dup_array[0]['Handle'])# {|match| puts match;  dup_array[0]['Handle']}
    }
  }
  return model_string
end

# This method gets the model string, writes it in a temporary location, reads it, and
# converts it to an OpenStudio Model using a VersionTranslater
def get_OS_Model_from_string(model_string)
  require 'securerandom'
  require 'fileutils'
  # make temerorary directory called `temp` to store the osm file
  FileUtils.mkdir_p(File.join('.', 'temp'))
  # Using SecureRandom to generate the UUID to keep the osm file unique
  temp_filename =File.join('.', 'temp',SecureRandom.uuid.to_s + '.osm')
  # write the model string as a file
  File.open(temp_filename, 'w') { |file| file.write(model_string) }
  # use a VersionTranslator to read the osm model
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new(temp_filename)
  # read the model
  model = translator.loadModel(path)
  model = model.get
  # remove the temporary model
  FileUtils.rm(temp_filename)
  return model
end

# model OS:Model
# model_obj_type String e.g. "OS:Material"
# returns new model (OS:Model) if the changes were made.
#         else returns the old model if no changes were made.
def eleminate_duplicate_objs(model, model_obj_type) # = "OS:Material")
  model_objs_json = {}

  # convert each of the ModelObjectas a hash for easy parsing
  model.getModelObjects.sort.each {|obj|
    # hsh = idf_to_h_clean(obj) # stores the idf converted to hash, without UUIDs and Name field

    # create a hash containing all the model objects sorted by the name of the model object.
    # e.g the `OS:Construction` ModelObject  type will e placed within the `OS:Construction` key, and
    # each ModelObject has been converted to an idf_hash and pushed into the array with the appropriate key.
    (model_objs_json[obj.iddObject.name.to_s] ||= []) << idf_to_h(obj) # unless hsh.empty?
  }

  # isolate a single ModelObject type specified by the model_obj_type variable
  mat_array = model_objs_json[model_obj_type]
  if mat_array.nil? # return the old model if model_obj_type is not found
    puts "Skipping because ModelObject of type [#{model_obj_type}] was not found"
    return model
  end
  # group duplicates
  grouped_objs = group_similar_objects(mat_array)
  # replace handles of duplicate objects
  model_string = replace_duplicate_obj_handles(model, grouped_objs)
  # write the model string to a file and read it as a model
  new_model = get_OS_Model_from_string(model_string)

  # Now loop through each of the grouped objects. skip the first one, and get ModelObjects (from new osm file)
  # by name and safely remove all the duplicates
  grouped_objs.each {|key, dup_array|
    dup_array.each_with_index {|object, index |
      next if index == 0
       unless object.key?('Name') # if the idf_hash does not have a key called Name, Skip it.
         puts "Skipping ModelObject of type [#{model_obj_type}] With data [#{object.inspect}] does not have a field called 'Name'"
         next
       end
      name = object['Name']
      # puts "object: [#{object}]"
      # puts "object['Name']: [#{object['Name']}]"
      # get the object to delete by name
      obj_to_delete = new_model.getModelObjectByName(name)
      if obj_to_delete.empty? # check if the object to be deleted is initialized (or present within the new model)
        puts "ModelObject of type [#{model_obj_type}] with name [#{object['Name']}] does not exist in new model"
      else
        puts "ModelObject of type [#{model_obj_type}] with name [#{object['Name']}] was deleted"
        obj_to_delete = obj_to_delete.get # get the modelObject if it is initialized
        obj_to_delete.remove # remove object form the model
      end
    }
  }
  # File.open('./models/after.osm', 'w') { |file| file.write(new_model.to_s) }


  # File.open("./models/grp_#{model_obj_type}.json", 'w') { |file| file.write(JSON.pretty_generate(grouped_objs)) }

  return new_model
  # File.open('./models/after.osm', 'w') { |file| file.write(model_string) }
  # puts("\n\n\n" + "=="*10 + "\n\n")
  # puts JSON.pretty_generate(grouped_mats)
end



class TestRemoveDuplicateModelObjects < CreateDOEPrototypeBuildingTest

  def test_remove_duplicate_model_objects
    # read a sample model called fsr model present within the test/necb/models/fsr.osm
    translator = OpenStudio::OSVersion::VersionTranslator.new
    osm_path = File.join(File.dirname(__FILE__), 'models', 'fsr.osm')
    path = OpenStudio::Path.new(osm_path)
    model = translator.loadModel(path)
    model = model.get

    old_number_of_objects = model.getModelObjects.length
    prototype_creator = Standard.build("NECB2011")

# add duplicate constructions and materials for testing purposes
    default_cons_osm = File.join(File.absolute_path(File.dirname(__FILE__)),'..' , '..', 'lib','openstudio-standards','standards','necb','necb_2011','data','construction_defaults.osm')
    puts default_cons_osm

# add duplicate construction sets
# prototype_creator.model_add_construction_set_from_osm(:model =>model, :osm_path => default_cons_osm)

# write model for comparision
# File.open('./models/before.osm', 'w') { |file| file.write(model.to_s) }


=begin
# determine what ModelObject Types are present within the OS:Model
obj_types = []
model.getModelObjects.sort.each{|obj|
  next unless obj.iddObject.name.to_s.downcase.include?('material') or obj.iddObject.name.to_s.downcase.include?('constru')
  obj_types << obj.iddObject.name.to_s
}

p obj_types.uniq.sort.reverse
=end

    new_model = model

# eleminate dplicate Material objects
    obj_types = [
        "OS:Material",
        "OS:Material:NoMass",
        "OS:WindowMaterial:SimpleGlazingSystem",
        "OS:WindowMaterial:Glazing",
        "OS:WindowMaterial:Gas",
        "OS:StandardsInformation:Material"
    ]

    obj_types.each {|model_obj_type|
      new_model = eleminate_duplicate_objs(new_model, model_obj_type)
    }

# eleminate dplicate Construction objects
    obj_types = [
        "OS:Construction",
        "OS:DefaultSurfaceConstructions",
        "OS:DefaultSubSurfaceConstructions",
        "OS:DefaultConstructionSet",
        "OS:StandardsInformation:Construction",
    ]
    obj_types.each {|model_obj_type|
      new_model = eleminate_duplicate_objs(new_model, model_obj_type)
    }


    new_number_of_objects = new_model.getModelObjects.length

    puts "Number of objects removed: #{old_number_of_objects - new_number_of_objects}"
    assert((old_number_of_objects - new_number_of_objects > 0))
  end
end
