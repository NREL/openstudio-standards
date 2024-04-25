class ACM179dASHRAE9012007
  # @!group SpaceType

  # Returns standards data for selected space type and template
  # This will check the building primary type instead
  #
  # @param space_type [OpenStudio::Model::SpaceType] space type object
  # @param extend_with_2007 [default True] whether to add anything we do not
  #        define (ventilation, exhaust, lighting control) from ASHRAE9012007
  # @return [hash] hash of internal loads for different load types
  def space_type_get_standards_data(space_type, extend_with_2007: true)
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

    if !extend_with_2007
      return space_type_properties
    end

    # This merges the ventilation, exhaust and lighting controls
    data2007 = @std_2007.space_type_get_standards_data(space_type)
    if data2007.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.SpaceType', "Space type properties from ASHRAE 90.1-2007 lookup failed")
    else
      space_type_properties = data2007.merge(space_type_properties)
      space_type_properties['space_type_2007'] = data2007['space_type']
    end

    return space_type_properties
  end
end
