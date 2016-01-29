
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::SpaceType

  # this returns standards data for selected space type and template
  # @param [string] target template for lookup
  # @return [hash] hash of internal loads for different load types
  def get_standards_data(template)

    if self.standardsBuildingType.is_initialized
      standards_building_type = self.standardsBuildingType.get
    else
      standards_building_type = nil
    end
    if self.standardsSpaceType.is_initialized
      standards_space_type = self.standardsSpaceType.get
    else
      standards_space_type = nil
    end

    # todo - remove loading standards before merge
    standards = self.model.load_openstudio_standards_json

    # populate search hash
    search_criteria = {
        "template" => template,
        "building_type" => standards_building_type,
        "space_type" => standards_space_type,
    }

    # lookup space type properties
    space_type_properties = self.model.find_object(standards["space_types"], search_criteria)

    return space_type_properties

  end

  # this returns standards data for selected construction
  # @param [string] target template for lookup
  # @param [string] intended_surface_type template for lookup
  # @param [string] standards_construction_type template for lookup
  # @return [hash] hash of construction properties
  def get_construction_properties(template,intended_surface_type,standards_construction_type)

    # get building_category value
    is_residential = self.get_standards_data(template)['is_residential']
    if is_residential == "Yes"
      building_category = "Residential"
    else
      building_category = "Nonresidential"
    end

    # todo - remove loading standards before merge
    standards = self.model.load_openstudio_standards_json

    # get climate_zone_set
    climate_zone = self.model.get_building_climate_zone_and_building_type['climate_zone']
    climate_zone_set = self.model.find_climate_zone_set(climate_zone, template,standards)

    # populate search hash
    search_criteria = {
        "template" => template,
        "climate_zone_set" => climate_zone_set,
        "intended_surface_type" => intended_surface_type,
        "standards_construction_type" => standards_construction_type,
        "building_category" => building_category,
    }

    # switch to use this but update test in standards and measures to load this outside of the method
    construction_properties = self.model.find_object(standards["construction_properties"], search_criteria)

    return construction_properties

  end

end
