
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

    #load the data from the JSON file into a ruby hash
    top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"
    temp = File.read("#{standards_data_dir}/OpenStudio_Standards_space_types.json")
    @standards = {}
    @standards = JSON.parse(temp)

    # populate search hash
    search_criteria = {
        "template" => template,
        "building_type" => standards_building_type,
        "space_type" => standards_space_type,
    }

    # lookup space type properties
    space_type_properties = self.model.find_object(@standards["space_types"], search_criteria)

    return space_type_properties

  end
  
  private


end
