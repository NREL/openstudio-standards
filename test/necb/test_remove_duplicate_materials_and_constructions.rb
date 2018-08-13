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
    line.gsub!(/(\,|\;)/, '')
    line.strip!
    v,k = line.split(/\s*\!\-\s+/)
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
  idf_hash = idf_to_h(obj)

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
# values of an IDF object which excludes Handles and Names
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
  grouped_objs = obj_array.group_by{ |item|
    out = []
    # skip Handle and Name keys
    item.each {|key, val|
      next if key == "Handle"
      next if key == "Name"
      out << val
    }
    out
  }

  # Sort the grouped [objects] by Name.
  # This is doen such that the first object will always have the smaller name
  grouped_objs.each {|key, dup_array|
    dup_array.sort_by{|dup|
      # puts dup
      dup['Name']
    }
  }
  return grouped_objs
end

# Replace the UUID of the duplicate material, unless it contains ", !- Handle"
# This is done so after the model has been written to the disk, It can be read and
# the duplicate materials can be removed safely.
def replace_duplicate_obj_handles(model, grouped_objs)
  model_string = model.to_s
  grouped_objs.each {|key, dup_array|
    dup_array.each_with_index {|array, index |
      next if index == 0
      replace_regex = array['Handle'].to_s.gsub('{', '\{').
          gsub('}', '\}').
          gsub('-', '\-') + '(?!.*?\!\-(\s)*Handle)'
      replace_regex = Regexp.new(replace_regex)
      # p replace_regex
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
  FileUtils.mkdir_p(File.join('.', 'temp'))
  temp_filename =File.join('.', 'temp',SecureRandom.uuid.to_s + '.osm')
  File.open(temp_filename, 'w') { |file| file.write(model_string) }
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new(temp_filename)
  model = translator.loadModel(path)
  model = model.get
  FileUtils.rm(temp_filename)
  return model
end

def eleminate_duplicate_objs(model, model_obj_type = "OS:Material")
  model_objs_json = {}

  # convert each of the ModelObjectas a hash for easy parsing
  model.getModelObjects.sort.each {|obj|
    # hsh = idf_to_h_clean(obj) # stores the idf converted to hash, without UUIDs and Name field

    # include it in the model_objs_json  if it does not consist fully of UUID and name
    (model_objs_json[obj.iddObject.name.to_s] ||= []) << idf_to_h(obj) # unless hsh.empty?
  }

  mat_array = model_objs_json[model_obj_type]
  grouped_objs = group_similar_objects(mat_array)
  model_string = replace_duplicate_obj_handles(model, grouped_objs)
  new_model = get_OS_Model_from_string(model_string)

  # Now loop through each of the grouped objects. skip the first one, and get ModelObjects (from new osm file)
  # by name and safely remove all the duplicates
  grouped_objs.each {|key, dup_array|
    dup_array.each_with_index {|object, index |
      next if index == 0
      next unless object.key?('Name')
      name = object['Name']
      # puts "object: [#{object}]"
      puts "object['Name']: [#{object['Name']}]"
      obj_to_delete = new_model.getModelObjectByName(name)
      if obj_to_delete.empty?
        puts "ModelObject of type [#{model_obj_type}] with name [#{object['Name']}] does not exist in new model"
      else
        puts "ModelObject of type [#{model_obj_type}] with name [#{object['Name']}] was deleted"
        obj_to_delete = obj_to_delete.get
        obj_to_delete.remove
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

translator = OpenStudio::OSVersion::VersionTranslator.new
osm_path = File.join(File.dirname(__FILE__), 'models', 'fsr.osm')
path = OpenStudio::Path.new(osm_path)
model = translator.loadModel(path)
model = model.get

prototype_creator = Standard.build("NECB2011")

# add duplicate constructions and materials for testing purposes
default_cons_osm = File.join(File.absolute_path(File.dirname(__FILE__)),'..' , '..', 'lib','openstudio-standards','standards','necb','necb_2011','data','construction_defaults.osm')
puts default_cons_osm
prototype_creator.model_add_construction_set_from_osm(:model =>model, :osm_path => default_cons_osm)

# File.open('./models/before.osm', 'w') { |file| file.write(model.to_s) }



obj_types = []
model.getModelObjects.sort.each{|obj|
  next unless obj.iddObject.name.to_s.downcase.include?('material') or obj.iddObject.name.to_s.downcase.include?('constru')
  obj_types << obj.iddObject.name.to_s
}

p obj_types.uniq.sort.reverse

new_model = model


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


