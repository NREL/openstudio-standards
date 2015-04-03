# This script checks uniqueness of the openstudio_standards.json file

require 'json'

def check_validity
  @path_to_standards_json = './build/openstudio_standards.json'

  @errors = []

  # Load the data from the JSON file into a ruby hash
  temp = File.read(@path_to_standards_json.to_s)
  standards = JSON.parse(temp)

  # Check for name duplication
  puts '****Check that the names are unique in each array****'
  standards.each do |key, data|
    # Skip sheets not stored as hashes
    unless data[0].is_a?(Hash)
      puts "Skipping #{key} because its rows aren't hashes"
      next
    end
    # Skip sheets without a name column
    unless data[0].key?('name')
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
      @errors << "ERROR - #{key} - #{num_names - num_unique_names} non-unique names in the #{names.size} rows."
    end
  end

  # Check for data duplicated under different names
  puts '****Check for duplicate rows with different names****'
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
      @errors << "ERROR - #{key} - #{num_objs - num_unique_objs} rows with different names but duplicate data out of the #{names.size} rows."
    end
  end

  # Check that space types are referencing valid schedule names
  puts '****Check that space types are referencing valid schedule names****'
  def check_sch(sch_name, schedules)
    return true if sch_name.nil?
    unless schedules.find { |x| x['name'] == sch_name }
      @errors << "ERROR - #{space_type['name']} - Invalid schedule called #{sch_name} is referenced."
    end
    return true
  end
  # Loop through the space types
  standards['space_types'].each do |space_type|
    check_sch(space_type['lighting_schedule'], standards['schedules'])
    check_sch(space_type['occupancy_schedule'], standards['schedules'])
    check_sch(space_type['occupancy_activity_schedule'], standards['schedules'])
    check_sch(space_type['infiltration_schedule'], standards['schedules'])
    check_sch(space_type['electric_equipment_schedule'], standards['schedules'])
    check_sch(space_type['gas_equipment_schedule'], standards['schedules'])
    check_sch(space_type['heating_setpoint_schedule'], standards['schedules'])
    check_sch(space_type['cooling_setpoint_schedule'], standards['schedules'])
  end

  # Check that internal constructions have matching reversed constructions
  puts '****Check that internal constructions have matching reversed constructions****'
  constructions = standards['constructions']
  def check_reverse_equal(left, right, construction_set, constructions)
    # Skip blank constructions
    return false if left.nil? && right.nil?

    left_construction = constructions.find { |x| x['name'] == left }
    if left_construction.nil?
      @errors << "ERROR - Cannot find construction named '#{left}' in constructions."
      return false
    end

    right_construction = constructions.find { |x| x['name'] == right }
    if right_construction.nil?
      @errors << "ERROR - Cannot find construction named '#{right}' in constructions."
      return false
    end

    left_layers = left_construction['materials']
    right_layers = right_construction['materials']
    unless (left_layers.join(',') == right_layers.reverse.join(','))
      @errors << "ERROR - Layers are not reverse equal, '#{left}' vs '#{right}' from #{construction_set}."
      return false
    end

    return true
  end
  # Loop through the construction sets
  standards['construction_sets'].each do |cs|
    check_reverse_equal(cs['interior_operable_windows'], cs['interior_operable_windows'], cs, constructions)
    check_reverse_equal(cs['interior_fixed_windows'], cs['interior_fixed_windows'], cs, constructions)
    check_reverse_equal(cs['interior_walls'], cs['interior_walls'], cs, constructions)
    check_reverse_equal(cs['interior_doors'], cs['interior_doors'], cs, constructions)
    check_reverse_equal(cs['interior_floors'], cs['interior_ceilings'], cs, constructions)
  end

  puts '***Errors***'
  @errors.each do |err|
    puts err
  end
end
