class ACM179dASHRAE9012007
  # @!group SpaceType

  # Returns standards data for selected space type and template
  # This will check the building primary type instead
  #
  # @param space_type [OpenStudio::Model::SpaceType] space type object
  # @return [hash] hash of internal loads for different load types
  def space_type_get_standards_data(space_type)
    standards_building_type = model_get_primary_building_type(space_type.model)

    # populate search hash
    search_criteria = {
      'template' => template,
      'building_type' => standards_building_type,
      'space_type' => @whole_building_space_type_name,
    }

    # lookup space type properties
    space_type_properties = model_find_object(standards_data['space_types'], search_criteria)

    if space_type_properties.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.SpaceType', "Space type properties lookup failed: #{search_criteria}.")
      space_type_properties = {}
    end

    return space_type_properties
  end
end
