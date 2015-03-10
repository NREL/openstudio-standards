# This script checks uniqueness of the openstudio_standards.json file

require 'json'

def check_validity

  @path_to_standards_json = './build/openstudio_standards.json'

  errors = []
  
  # Load the data from the JSON file into a ruby hash
  temp = File.read(@path_to_standards_json.to_s)
  standards = JSON.parse(temp)

  # Check for name duplication
  puts "****Check that the names are unique in each array****"   
  standards.each do |key, data|
   
    
    # Skip sheets not stored as hashes
    unless data[0].is_a?(Hash)
      puts "Skipping #{key} because its rows aren't hashes"
      next
    end
    # Skip sheets without a name column
    unless data[0].has_key?('name')
      puts "Skipping #{key} because its rows don't have names"
      next
    end
    # Skip schedules sheet; rows are non-unique by design
    if key == 'schedules'
      puts "Skipping #{key} because rows are non-unique by design"
      next
    end    
    # Put the names into an array
    names = []
    data.each do |row|
      names << row['name']
    end
    # Check that there are no repeated names
    num_names = names.size
    num_unique_names = names.uniq.size
    if num_names > num_unique_names
      errors << "ERROR - #{key} - #{num_names - num_unique_names} non-unique names in the #{names.size} rows."
    end
    
  end 
    
  # Check for data duplicated under different names
  puts "****Check for duplicate rows with different names****"   
  standards.each do |key, data| 
    
    # Skip sheets not stored as hashes
    unless data[0].is_a?(Hash)
      puts "Skipping #{key} because its rows aren't hashes"
      next
    end
    # Create objects (without the name column)
    objs = []
    data.each do |row|
      obj = {}
      row.each do |k, v|
        # Skip the name field
        next if k == 'name'
        obj[k] = v
      end
    end
    # Check that there are no repeated names
    num_objs = objs.size
    num_unique_objs = objs.uniq.size
    if num_objs > num_unique_objs
      errors << "ERROR - #{key} - #{num_objs - num_unique_objs} rows with different names but duplicate data out of the #{names.size} rows."
    end    

  end

  puts "***ERRORS***"
  errors.each do |err|
    puts err
  end
  
end
