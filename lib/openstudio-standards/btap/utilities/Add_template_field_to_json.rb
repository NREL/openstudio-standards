# This utility adds a template field defining the NECB data the given json file refers to.  The template field is added
# to the top of each element in the table array.

require 'json'

class Add_template_field_to_json
  # Name of file you want to add template fields to:
  in_json_file = './necb_hvac_system_selection_type.json'
  # Name of file you want this script to produce:
  out_json_file = './necb_hvac_system_selection_type_mod.json'
  # What template version do you want to add:
  template_version = { 'template' => 'NECB2011' }
  # Open the json file and put the data in data_tables:
  file = File.read(in_json_file)
  data_tables = JSON.parse(file)
  # Go through the file and add whatever you put in template_version to the top of each element of the table array
  data_tables['tables'][0]['table'].each_with_index do |data_table, index|
    data_tables['tables'][0]['table'][index] = template_version.merge(data_table)
  end
  # Save the modified hash to a the file and location defined in out_json_file
  File.open(out_json_file, 'w') { |each_file| each_file.write(JSON.pretty_generate(data_tables)) }
end
