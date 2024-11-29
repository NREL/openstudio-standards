class ASHRAE9012010 < ASHRAE901
  # @!group Model

  # Determine the prototypical economizer type for the model.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
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

  # Adjust model to comply with fenestration orientation requirements
  # @note code_sections [90.1-2010_5.5.4.5]
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Boolean] Returns true if successful, false otherwise
  def model_fenestration_orientation(model, climate_zone)
    wwr = false

    win_area_w = OpenstudioStandards::Geometry.model_get_exterior_window_and_wall_area_by_orientation(model)['west_window']
    win_area_e = OpenstudioStandards::Geometry.model_get_exterior_window_and_wall_area_by_orientation(model)['east_window']
    win_area_s = OpenstudioStandards::Geometry.model_get_exterior_window_and_wall_area_by_orientation(model)['south_window']

    # Make prototype specific adjustment to meet the code requirement
    if !((win_area_s > win_area_w) && (win_area_s > win_area_e))
      if model.getBuilding.standardsBuildingType.is_initialized
        building_type = model.getBuilding.standardsBuildingType.get

        case building_type
          # @todo Implementatation for other building types not meeting the requirement
          #   The offices, schools, warehouse (exempted), large hotel, outpatient,
          #   retails, apartments should meet the requirement according to Section
          #   5.2.1.7 in Thornton et al. 2011
          when 'Hospital'
            # Rotate the building counter-clockwise
            OpenstudioStandards::Geometry.model_set_building_north_axis(model, 270.0)
          when 'SmallHotel'
            # Rotate the building clockwise
            OpenstudioStandards::Geometry.model_set_building_north_axis(model, 180.0)
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.ashrae_90_1_2010', "The prototype model doesn't meet the requirement from Section 5.5.4.5 in ASHRAE Standard 90.1-2010.")
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.ashrae_90_1_2010', "The prototype model doesn't meet the requirement from Section 5.5.4.5 in ASHRAE Standard 90.1-2010, its standards building type shall be specified.")
      end
    end

    return true
  end

  # Is transfer air required?
  # @note code_sections [90.1-2010_6.5.7.1.2]
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] true if transfer air is required, false otherwise
  def model_transfer_air_required?(model)
    # @todo It actually is for kitchen but not implemented yet
    return false
  end
end
