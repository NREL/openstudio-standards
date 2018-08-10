require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require 'json'

def diff_idd_objs(obj1 , obj2)
  hsh_1 = idf_to_h_clean(obj1)
  hsh_2 = idf_to_h_clean(obj2)

  puts "\n"
  puts hsh_1
  puts hsh_2

  if hsh_1.size > hsh_2.size
    diff = hsh_1.to_a - hsh_2.to_a
  else
    diff = hsh_2.to_a - hsh_1.to_a
  end

  puts "diff: #{diff.inspect}"
  return diff
end

def idf_dplicate?(obj1 , obj2)
  return diff_idd_objs(obj1 , obj2).length == 0
end

# this method converts an idf object to a hash
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
def idf_to_h_clean(obj)
  idf_hash = idf_to_h(obj)

  idf_hash.delete("Handle") if idf_hash.key?("Handle")
  idf_hash.delete("Handle".to_sym) if idf_hash.key?("Handle".to_sym)

  idf_hash.delete("Name") if idf_hash.key?("Name")
  idf_hash.delete("Name".to_sym) if idf_hash.key?("Name".to_sym)

  # Loop through idf_hash and delete any field that matched the UUID regex
  idf_hash.each {|k,v|
    idf_hash.delete(k) if /^\{[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\}$/.match(v)
  }
  idf_hash
end





translator = OpenStudio::OSVersion::VersionTranslator.new
osm_path = File.join(File.dirname(__FILE__), 'models', 'fsr.osm')
path = OpenStudio::Path.new(osm_path)
model = translator.loadModel(path)
model = model.get

prototype_creator = Standard.build("NECB2011")

default_cons_osm = File.join(File.absolute_path(File.dirname(__FILE__)),'..' , '..', 'lib','openstudio-standards','standards','necb','necb_2011','data','construction_defaults.osm')

puts default_cons_osm

prototype_creator.model_add_construction_set_from_osm(:model =>model, :osm_path => default_cons_osm)

materials = []
materials_nomass = []
other_mats = []
other_mats = []

mats = {}
cons = {}

model.getModelObjects.sort.each {|obj|
  # puts obj.iddObject.name.to_s
  # next if obj.iddObject.name.to_s == 'OS:StandardsInformation:Material'
  if obj.iddObject.name.to_s.downcase.include?('material')
    hsh = idf_to_h_clean(obj) # stores the idf converted to hash, without UUIDs and Name field
    (mats[obj.iddObject.name.to_s] ||= []) << idf_to_h(obj) unless hsh.empty?
  end

  if obj.iddObject.name.to_s.downcase.include?('construction')
    hsh = idf_to_h_clean(obj) # stores the idf converted to hash, without UUIDs and Name field
    (cons[obj.iddObject.name.to_s] ||= []) << idf_to_h(obj) unless hsh.empty?
  end
}

# puts JSON.pretty_generate(mats)


# # puts JSON.pretty_generate(cons)
#
# # mats.each {|k,v|
# #   uni = v.uniq{ |item|
# #   }
# # }
#
# # puts "idf_dplicate?(obj1 , obj2): #{idf_dplicate?(materials_nomass[2] , materials_nomass[3])}"
#
# # this works
# ob = model.getModelObjectByName('Basement Floor construction').get
# handle =  'dd09be59-067b-4aa7-83f8-e12cf75ef0e0'
# # OS:Construction,
# #   {61b2fabd-4ab4-4da0-a13e-da3b47dcca07}, !- Handle
# # Basement Floor construction,            !- Name
# # ,                                       !- Surface Rendering Name
# # {dd09be59-067b-4aa7-83f8-e12cf75ef0e0}, !- Layer 1
# # {188c748f-0c2c-4678-84fd-7872320e7f6f}; !- Layer 2
# puts "\nAFTER"
# numod = model.to_s.gsub(handle,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa').to_s
# # mod = translator.loadModel(numod)
#
# File.open('./models/out.osm', 'w') { |file| file.write(numod) }

puts JSON.pretty_generate(mats)
mat_array = mats["OS:Material"]

grouped_mats = mat_array.group_by{ |item|
  out = []
  item.each {|key, val|
    next if key == "Handle"
    next if key == "Name"
    out << val
  }
  out
}

grouped_mats.each {|key, dup_array|
  dup_array.sort_by{|dup|
    puts dup
    dup['Name']
  }
}

puts("\n\n\n" + "=="*10 + "\n\n")
puts JSON.pretty_generate(grouped_mats)