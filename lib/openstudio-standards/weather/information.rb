# Methods to create Schedule objects
module OpenstudioStandards
  module Weather
    # @!group Information

    # get the ASHRAE climate zone number
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Integer] ASHRAE climate zone number, 0-8
    def self.model_get_ashrae_climate_zone_number(model)
      # get ashrae climate zone from model
      ashrae_climate_zone = ''
      model.getClimateZones.climateZones.each do |climate_zone|
        if climate_zone.institution == 'ASHRAE'
          ashrae_climate_zone = climate_zone.value
        end
      end

      if ashrae_climate_zone == ''
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather', 'Please assign an ASHRAE Climate Zone to your model.')
        return false
      else
        cz_number = ashrae_climate_zone.split(//).first.to_i
      end

      # expected climate zone number should be 0 through 8
      if ![0, 1, 2, 3, 4, 5, 6, 7, 8].include? cz_number
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather', 'ASHRAE climate zone number is not within expected range of 1 to 8.')
        return false
      end

      return cz_number
    end
  end
end
