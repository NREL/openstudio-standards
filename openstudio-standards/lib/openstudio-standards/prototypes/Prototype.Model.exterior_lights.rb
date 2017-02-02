# open the class to add methods to add exterior lighting
class OpenStudio::Model::Model

  # Add exterior lighting to the model
  #
  # @param template [String] Valid choices are
  # @param exterior_lighting_zone_number [Integer] Valid choices are
  # @return [Hash] the resulting elevator
  def add_typical_exterior_lights(template,exterior_lighting_zone_number)

    exterior_lights = {}


    # populate search hash
    search_criteria = {
        'template' => template,
        'exterior_lighting_zone_number' => exterior_lighting_zone_number,
    }


    # todo - load standards data
    exterior_lighting_properties = self.find_object($os_standards['exterior_lighting'], search_criteria)
    puts "hello"
    puts exterior_lighting_properties


    # todo - get building type (needed to get correct schedules)
    # use what building type says or see what buildin type is more prominant in floor area.


    # todo - lookup appropriate schedules (there may be up to three, one of which may be always on)


    # todo - determine the area and linear feet values needed to apply codes


    # todo - add builidng type specific logic based on assumptions from prototype models


    # todo - add exterior lights


    return exterior_lights

  end

end