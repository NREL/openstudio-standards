class ASHRAE9012016 < ASHRAE901
  # @!group Model

  # Determine the prototypical economizer type for the model.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param climate_zone [String] the climate zone
  # @return [String] the economizer type.  Possible values are:
  # 'NoEconomizer'
  # 'FixedDryBulb'
  # 'FixedEnthalpy'
  # 'DifferentialDryBulb'
  # 'DifferentialEnthalpy'
  # 'FixedDewPointAndDryBulb'
  # 'ElectronicEnthalpy'
  # 'DifferentialDryBulbAndEnthalpy'
  def model_economizer_type(model, climate_zone)
    economizer_type = case climate_zone
                      when 'ASHRAE 169-2006-0A',
                          'ASHRAE 169-2006-1A',
                          'ASHRAE 169-2006-2A',
                          'ASHRAE 169-2006-3A',
                          'ASHRAE 169-2006-4A',
                          'ASHRAE 169-2013-0A',
                          'ASHRAE 169-2013-1A',
                          'ASHRAE 169-2013-2A',
                          'ASHRAE 169-2013-3A',
                          'ASHRAE 169-2013-4A'
                        'DifferentialEnthalpy'
                      else
                        'DifferentialDryBulb'
                      end
    return economizer_type
  end

  # Metal coiling door code minimum infiltration rate at 75 Pa
  #
  # @code_sections [90.1-2019_5.4.3.2]
  # @param [String] Climate zone
  # @return [Float] Minimum infiltration rate for metal coiling doors
  def model_door_infil_flow_rate_metal_coiling_cfm_ft2(climate_zone)
    case climate_zone
      when 'ASHRAE 169-2006-7A',
           'ASHRAE 169-2006-7B',
           'ASHRAE 169-2006-8A',
           'ASHRAE 169-2006-8B',
           'ASHRAE 169-2013-7A',
           'ASHRAE 169-2013-7B',
           'ASHRAE 169-2013-8A',
           'ASHRAE 169-2013-8B'
        return 0.4
      else
        return 1.0
    end
  end
end
