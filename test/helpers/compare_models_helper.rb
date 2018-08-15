# Compare two osm files and find differences.
# Assumes that objects with the same name in each file should
# be identical.  Cannot use handles for comparison because handles
# change for auto-generated models.
#
# @param model_true [OpenStudio::Model::Model] the "true" model
# @param model_compare [OpenStudio::Model::Model] the model to be
# compared to the "true" model
# @return [Array<String>] a list of differences between the two models
# @todo Handle comparison of objects without names
def compare_osm_files(model_true, model_compare)

  only_model_true = [] # objects only found in the true model
  only_model_compare = [] # objects only found in the compare model
  both_models = [] # objects found in both models
  renamed_object_aliases = Hash.new([]) # Hash of renamed objects
  diffs = [] # differences between the two models

  # Define types of objects to skip entirely during the comparison
  object_types_to_skip = [
    'OS:EnergyManagementSystem:Sensor', # Names are UIDs
    'OS:EnergyManagementSystem:Program', # Names are UIDs
    'OS:EnergyManagementSystem:Actuator', # Names are UIDs
    'OS:Connection', # Names are UIDs
    'OS:PortList', # Names are UIDs
    'OS:Building', # Name includes timestamp of creation
    'OS:ModelObjectList', # Names are UIDs
    'OS:ZoneHVAC:EquipmentList', # Names appear to be created non-deteministically
    'OS:AvailabilityManagerAssignmentList', # Names appear to be created non-deteministically
    'OS:Schedule:Rule', # Names appear to be created non-deteministically
    'OS:Rendering:Color' # Rendering colors don't matter
  ]

  # Fill model object lists with all object types to be compared
  model_true.getModelObjects.sort.each do |obj|
    next if object_types_to_skip.include?(obj.iddObject.name) # Skip comparison of certain object types
    next unless obj.iddObject.hasNameField # Skip comparison for objects with no name
    only_model_true << obj
  end

  model_compare.getModelObjects.sort.each do |obj|
    next if object_types_to_skip.include?(obj.iddObject.name) # Skip comparison of certain object types
    next unless obj.iddObject.hasNameField # Skip comparison for objects with no name
    only_model_compare << obj
  end

  # diffs << "before name match only_model_true = #{only_model_true.size}"
  # diffs << "before name match only_model_compare = #{only_model_compare.size}"
  # diffs << "before name match both_models = #{both_models.uniq.size}"

  # Match up the objects
  only_model_true, only_model_compare, both_models, renamed_object_aliases, diffs = match_objects!(model_true,
                                                                                                   model_compare,
                                                                                                   only_model_true,
                                                                                                   only_model_compare,
                                                                                                   both_models,
                                                                                                   renamed_object_aliases,
                                                                                                   diffs,
                                                                                                   object_types_to_skip)

  # require 'json'
  # diffs << "renamed"
  # diffs << JSON.pretty_generate(renamed_object_aliases)
  #
  # diffs << "after name match only_model_true = #{only_model_true.size}"
  # diffs << "after name match only_model_compare = #{only_model_compare.size}"
  # diffs << "after name match both_models = #{both_models.uniq.size}"

  # Report a diff for each object found in only the true model
  if only_model_true.size > 0
    diffs << "*** Objects only found in true model ***"
    only_model_true.each do |true_object|
      diffs << "A #{true_object.iddObject.name} called '#{true_object.name}'"
    end
    diffs << ""
  end

  # Report a diff for each object found in only the compare model
  if only_model_true.size > 0
    diffs << "*** Objects only found in compare model ***"
    only_model_compare.each do |compare_object|
      diffs << "A #{compare_object.iddObject.name} called '#{compare_object.name}'"
    end
    diffs << ""
  end

  # Compare objects found in both models field by field 
  both_models.uniq.each do |b|
    true_object = b[0]
    compare_object = b[1]
    obj_diffs = compare_objects_field_by_field(true_object, compare_object, renamed_object_aliases)
    if obj_diffs.size > 0
      diffs << "For #{true_object.iddObject.name} called '#{true_object.name}'"
      diffs << "  'Name': true model = #{true_object.name}, compare model = '#{compare_object.name}'" unless true_object.name.get.to_s == compare_object.name.get.to_s
      diffs += obj_diffs
      diffs << ""
    end
  end

  return diffs
end

# Returns an array of differences between two objects, on a field-by-field
# basis, excluding certain fields populated by UIDs or non-deterministic names
# generated by OpenStudio.
#
# @param true_object [OpenStudio::Model::ModelObject] the object that will be considered truth
# @param compare_object [OpenStudio::Model::ModelObject] the object that will be compared to the truth
# @param alias_hash [Hash] a hash that maps the name of an object in the true model
# to an array of corresponding objects that have been renamed but are otherwise identical in the
# compare model.
def compare_objects_field_by_field(true_object, compare_object, alias_hash = Hash.new([]))

  idd_object = true_object.iddObject

  true_object_num_fields = true_object.numFields
  compare_object_num_fields = compare_object.numFields

  # loop over fields skipping handle
  diffs = []
  (1...[true_object_num_fields, compare_object_num_fields].max).each do |i|

    field_name = idd_object.getField(i).get.name

    # Don't compare the name field because this is how
    # the objects were deemed to be the same in both files
    next if field_name == 'Name'

    # Don't compare fields populated with IDs
    next if field_name.include?('Node Name')
    next if field_name.include?('Branch Name')
    next if field_name.include?('Inlet Port')
    next if field_name.include?('Outlet Port')
    next if field_name.include?('Inlet Node')
    next if field_name.include?('Outlet Node')
    next if field_name.include?('Setpoint Node or NodeList Name')
    next if field_name.include?('Port List')
    next if field_name.include?('Cooling Control Zone or Zone List Name')
    next if field_name.include?('Heating Control Zone or Zone List Name')
    next if field_name.include?('Heating Zone Fans Only Zone or Zone List Name')

    # Don't compare fields populated by auto-generated names
    next if field_name.include?('Availability Manager List Name')
    next if field_name.include?('Control Zone or Zone List Name')
    next if field_name.include?('Thermostat Name')

    # Don't compare fields populated by auto-created objects
    next if field_name.include?('Demand Mixer Name')
    next if field_name.include?('Demand Splitter Name')
    next if field_name.include?('Demand Splitter A Name')
    next if field_name.include?('Demand Splitter B Name')
    next if field_name.include?('Supply Mixer Name')
    next if field_name.include?('Supply Splitter Name')

    # Don't compare names of schedules used by water use equipment and water use connections
    next if field_name.include?('Target Temperature Schedule Name')
    next if field_name.include?('Sensible Fraction Schedule Name')
    next if field_name.include?('Latent Fraction Schedule Name')
    next if field_name.include?('Water Use Equipment Name')

    # Don't compare the names of schedule type limits
    # because they appear to be created non-deteministically
    next if field_name.include?('Schedule Type Limits Name')

    # Fields that don't matter
    next if field_name.include?('Group Rendering Name')

    # Don't compare curve names (temporarily, for PNNL merge)
    next if field_name.include?('Curve Name')

    # Get the value from the true object
    true_value = ""
    if i < true_object_num_fields
      true_value = true_object.getString(i).to_s.downcase
    end
    true_value = " - " if true_value.empty?

    # Get the same value from the compare object
    compare_value = ""
    if i < true_object_num_fields
      compare_value = compare_object.getString(i).to_s.downcase
    end
    compare_value = " - " if compare_value.empty?

    # Round long numeric fields
    true_value = '0.0' if true_value == '0'
    compare_value = '0.0' if compare_value == '0'
    true_value = true_value.to_f.round(5) unless true_value.to_f.zero?
    compare_value = compare_value.to_f.round(5) unless compare_value.to_f.zero?

    # Check true value directly against compare value
    next if compare_value == true_value

    # Check true value to aliases from compare model
    renamed_in_true = alias_hash[true_value].uniq
    if renamed_in_true.map(&:downcase).include?(compare_value)
      # puts "found equality for '#{compare_value}' in [#{renamed_in_true.join(', ')}]"
      next
    end

    # Check compare value to aliases from true model
    renamed_in_compare = alias_hash[compare_value].uniq
    if renamed_in_compare.map(&:downcase).include?(true_value)
      # puts "found equality for '#{compare_value}' in [#{renamed_in_compare.join(', ')}]"
      next
    end

    # Report the difference
    diffs << "  '#{field_name}': true model = '#{true_value}', compare model = '#{compare_value}'"
    # diffs << "For #{true_object.iddObject.name} called '#{true_object.name}' field '#{field_name}': true model = #{true_value}, compare model = #{compare_value}"
  end

  return diffs
end

# Finds objects in the supplied model that match the supplied object
# on a field-by-field basis, excluding the handle, name, fields populated by UIDs, etc.
#
# @return [Array<OpenStudio::WorkSpaceObject>] an array of matching objects
def find_object_matches_field_by_field(true_object, compare_model, alias_hash = Hash.new([]))
  matching_objects = []
  # Check against each of the objects in the compare model
  compare_model.getModelObjects.sort.each do |compare_object|
    # Skip objects of different types
    next unless compare_object.iddObject.name == true_object.iddObject.name
    # Compare field by field
    obj_diffs = compare_objects_field_by_field(true_object, compare_object, alias_hash)
    # If there are no differences, this is an obvious match
    if obj_diffs.size.zero?
      matching_objects << compare_object
      # puts "renamed: #{true_object.name} matches #{compare_object.name}"
      next
    end
    # Give large non-resource objects some fuzzy matching.
    # If an object has more than 10 fields, if 80% of the fields
    # match, perhaps these are the same objects but they have differences beyond the name.
    # next if true_object.to_ResourceObject.is_initialized # Skip ResourceObjects like curves, schedules, etc.
    # num_fields = [true_object.numFields, compare_object.numFields].max
    # if num_fields > 10 && obj_diffs.size/num_fields < 0.2
    #   matching_objects << compare_object
    #   puts "renamed: #{true_object.name} fuzzy matches #{compare_object.name}"
    # end
  end

  return matching_objects
end

# Check all objects that didn't have a matching name
# against all unmatched objects of the same type in the other file.
# If all fields except for the name match, assume these are actually the same object with a different name
# and add them to the array to be compared
# This method is recursive because after it finds that some objects have been renamed, it needs to re-compare
# all remaining unmatched objects because they might have been unmatched due to having fields
# referencing renamed object names be different.
def match_objects!(model_true, model_compare, unmatched_true_objects, unmatched_compare_objects, object_pairs, renamed_object_aliases, diffs, object_types_to_skip)
  # puts "running match_objects!"
  # Determine the number of renamed objects before matching
  num_renamed_objects_before = renamed_object_aliases.size

  # Find objects in the true model only or in both models
  model_true.getModelObjects.sort.each do |true_object|
    next if object_types_to_skip.include?(true_object.iddObject.name) # Skip comparison of certain object types
    next unless true_object.iddObject.hasNameField # Skip comparison for objects with no name

    # Start by finding an object with the same name
    compare_workspace_object = model_compare.getObjectByTypeAndName(true_object.iddObject.type, true_object.name.to_s)
    if compare_workspace_object.is_initialized
      compare_object = model_compare.getModelObject(compare_workspace_object.get.handle).get
      object_pairs << [true_object, compare_object]
      # puts "compare '#{compare_object.name}' matches true '#{true_object.name}'"
      next
    end

    # If not found by name, try to find based on field-by-field comparison
    matching_compare_objects = find_object_matches_field_by_field(true_object, model_compare, renamed_object_aliases)
    if matching_compare_objects.size > 0
      matching_compare_objects.each do |matching_compare_object|
        object_pairs << [true_object, matching_compare_object]
        # puts "compare '#{matching_compare_object.name}' renamed matches true '#{true_object.name}'"
        renamed_object_aliases[matching_compare_object.name.get.to_s] += [true_object.name.get.to_s] # Record the alias
      end
      next
    end
  end

  # Find objects in compare model or in both models
  model_compare.getModelObjects.sort.each do |compare_object|
    next if object_types_to_skip.include?(compare_object.iddObject.name) # Skip comparison of certain object types
    next unless compare_object.iddObject.hasNameField # Skip comparison for objects with no name
    # Start by finding an object with the same name
    true_workspace_object = model_true.getObjectByTypeAndName(compare_object.iddObject.type, compare_object.name.to_s)
    if true_workspace_object.is_initialized
      true_object = model_true.getModelObject(true_workspace_object.get.handle).get
      object_pairs << [true_object, compare_object]
      # puts "true '#{true_object.name}' matches compare '#{compare_object.name}'"
      next
    end

    # If not found by name, try to find based on field-by-field comparison
    matching_true_objects = find_object_matches_field_by_field(compare_object, model_true, renamed_object_aliases)
    if matching_true_objects.size > 0
      matching_true_objects.each do |matching_true_object|
        object_pairs << [matching_true_object, compare_object]
        # puts "true '#{matching_true_object.name}' renamed matches compare '#{compare_object.name}'"
        renamed_object_aliases[matching_true_object.name.get.to_s] += [compare_object.name.get.to_s] # Record the alias
      end
      next
    end
  end

  # If no objects were renamed, remove all objects found in a pair from the unmatched true/compare object arrays,
  # otherwise call recursively.
  num_renamed_objects_after = renamed_object_aliases.size
  if num_renamed_objects_before == num_renamed_objects_after
    object_pairs.uniq.each do |pair|
      true_obj = pair[0]
      compare_obj = pair[1]
      # diffs << "#{true_obj.class}, #{compare_obj.class}"
      unmatched_true_objects.delete(true_obj)
      unmatched_compare_objects.delete(compare_obj)
    end

    # puts "final renamed_object_aliases"
    # puts renamed_object_aliases

    return [unmatched_true_objects,
            unmatched_compare_objects,
            object_pairs,
            renamed_object_aliases,
            diffs]
  else
    match_objects!(model_true,
                   model_compare,
                   unmatched_true_objects,
                   unmatched_compare_objects,
                   object_pairs,
                   renamed_object_aliases,
                   diffs,
                   object_types_to_skip)
  end

end
