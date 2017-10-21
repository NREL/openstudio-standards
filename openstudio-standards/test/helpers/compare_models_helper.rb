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
  diffs = [] # differences between the two models
  num_ignored = 0 # objects not compared because they don't have names
  
  # Define types of objects to skip entirely during the comparison
  object_types_to_skip = [
    'OS:EnergyManagementSystem:Sensor', # Names are UIDs
    'OS:EnergyManagementSystem:Program', # Names are UIDs
    'OS:EnergyManagementSystem:Actuator', # Names are UIDs
    'OS:Connection', # Names are UIDs
    'OS:PortList', # Names are UIDs
    'OS:Building' # Name includes timestamp of creation
  ]
  
  # Find objects in the true model only or in both models
  model_true.getModelObjects.sort.each do |true_object|
  
    # Skip comparison of certain object types
    next if object_types_to_skip.include?(true_object.iddObject.name)
  
    # Skip comparison for objects with no name
    unless true_object.iddObject.hasNameField
      num_ignored += 1
      next
    end

    # Find the object with the same name in the other model
    compare_object = model_compare.getObjectByTypeAndName(true_object.iddObject.type, true_object.name.to_s)
    if compare_object.empty?
      only_model_true << true_object
    else 
      both_models << [true_object, compare_object.get]
    end
  end 
  
  # Report a diff for each object found in only the true model
  only_model_true.each do |true_object|
    diffs << "A #{true_object.iddObject.name} called '#{true_object.name}' was found only in the true model"
  end
  
  # Find objects in compare model only
  model_compare.getModelObjects.sort.each do |compare_object|
    
    # Skip comparison of certain object types
    next if object_types_to_skip.include?(compare_object.iddObject.name)
    
    # Skip comparison for objects with no name
    unless compare_object.iddObject.hasNameField
      num_ignored += 1
      next
    end

    # Find the object with the same name in the other model
    true_object = model_true.getObjectByTypeAndName(compare_object.iddObject.type, compare_object.name.to_s)
    if true_object.empty?
      only_model_compare << compare_object
    end
  end 
  
  # Report a diff for each object found in only the compare model
  only_model_compare.each do |compare_object|
    #diffs << "An object called #{compare_object.name} of type #{compare_object.iddObject.name} was found only in the compare model"
    diffs << "A #{compare_object.iddObject.name} called '#{compare_object.name}' was found only in the compare model"
  end
  
  # Compare objects found in both models field by field 
  both_models.each do |b|
    true_object = b[0]
    compare_object = b[1]
    idd_object = true_object.iddObject
    
    true_object_num_fields = true_object.numFields
    compare_object_num_fields = compare_object.numFields

    # loop over fields skipping handle
    (1...[true_object_num_fields, compare_object_num_fields].max).each do |i|
    
      field_name = idd_object.getField(i).get.name
      
      # Don't compare node, branch, or port names because they are populated with IDs
      next if field_name.include?('Node Name')
      next if field_name.include?('Branch Name')
      next if field_name.include?('Inlet Port')
      next if field_name.include?('Outlet Port')
      next if field_name.include?('Inlet Node')
      next if field_name.include?('Outlet Node')
      next if field_name.include?('Port List')
      
      # Don't compare the names of schedule type limits
      # because they appear to be created non-deteministically
      next if field_name.include?('Schedule Type Limits Name')
      
      # Get the value from the true object
      true_value = ""
      if i < true_object_num_fields
        true_value = true_object.getString(i).to_s
      end
      true_value = "-" if true_value.empty?
      
      # Get the same value from the compare object
      compare_value = ""
      if i < compare_object_num_fields
        compare_value = compare_object.getString(i).to_s
      end
      compare_value = "-" if compare_value.empty?
      
      # Round long numeric fields
      true_value = true_value.to_f.round(5) unless true_value.to_f.zero?
      compare_value = compare_value.to_f.round(5) unless compare_value.to_f.zero?

      # Move to the next field if no difference was found
      next if true_value == compare_value

      # Report the difference
      diffs << "For #{true_object.iddObject.name} called '#{true_object.name}' field '#{field_name}': true model = #{true_value}, compare model = #{compare_value}" 

    end

  end

  return diffs
end

