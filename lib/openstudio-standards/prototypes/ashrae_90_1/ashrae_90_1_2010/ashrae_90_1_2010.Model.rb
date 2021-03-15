class ASHRAE9012010 < ASHRAE901
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

  # Is transfer air required?
  #
  # @code_sections [90.1-2010_6.5.7.1.2]
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] true if transfer air is required, false otherwise
  def transfer_air_required?(model)
    # TODO: It actually is for kitchen but not implemented yet
    return false
  end
end
