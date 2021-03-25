class ASHRAE9012013 < ASHRAE901
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

  # Adjust model to comply with fenestration orientation requirements
  #
  # @code_sections [90.1-2013_5.5.4.5]
  # @param [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] Returns true if successful, false otherwise
  def model_fenestration_orientation(model, climate_zone)
    # Building rotation to meet the same code requirement for
    # 90.1-2010 are kept
    if model.getBuilding.standardsBuildingType.is_initialized
      building_type = model.getBuilding.standardsBuildingType.get

      case building_type
        when 'Hospital'
          # Rotate the building counter-clockwise
          model_set_building_north_axis(model, 270.0)
        when 'SmallHotel'
          # Rotate the building clockwise
          model_set_building_north_axis(model, 180)
      end
    end

    wwr = false
    # Section 6.2.1.2 in the ANSI/ASHRAE/IES Standard 90.1-2013 Determination
    # of Energy Savings: Quantitative Analysis mentions that the SHGC trade-off
    # path is most likely to be used by designers for compliance.
    #
    # The following adjustment are only made for models with simple glazing objects
    non_simple_glazing = false
    shgc_a = 0
    model.getSpaces.each do |space|
      # Get thermal zone multiplier
      multiplier = space.thermalZone.get.multiplier

      space.surfaces.each do |surface|
        surface.subSurfaces.each do |subsurface|
          # Get window subsurface type
          subsurface_type = subsurface.subSurfaceType.to_s.downcase

          # Window, glass doors
          next unless (subsurface_type.include? 'window') || (subsurface_type.include? 'glass')

          # Check if non simple glazing fenestration objects are used
          subsurface_cons = subsurface.construction.get.to_Construction.get
          non_simple_glazing = true unless subsurface_cons.layers[0].to_SimpleGlazing.is_initialized

          if non_simple_glazing
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_2013.model', 'Fenestration objects in the model use non-simple glazing models, fenestration requirements are not applied')
            return false
          end

          # Get subsurface's simple glazing object
          subsurface_shgc = subsurface_cons.layers[0].to_SimpleGlazing.get.solarHeatGainCoefficient

          # Get subsurface area
          subsurface_area = subsurface.grossArea * subsurface.multiplier * multiplier

          # SHGC * Area
          shgc_a += subsurface_shgc * subsurface_area
        end
      end
    end

    # Calculate West, East and total fenestration area
    a_w = model_get_window_area_info_for_orientation(model, 'W', wwr: wwr)
    a_e = model_get_window_area_info_for_orientation(model, 'E', wwr: wwr)
    a_t = a_w + a_e + model_get_window_area_info_for_orientation(model, 'N', wwr: wwr) + model_get_window_area_info_for_orientation(model, 'S', wwr: wwr)

    return true if a_t == 0.0

    # For prototypes SHGC_c assumed to be the building's weighted average SHGC
    shgc_c = shgc_a / a_t
    shgc_c = shgc_c.round(2)

    # West and East facing WWR
    wwr_w = model_get_window_area_info_for_orientation(model, 'W', wwr: true)
    wwr_e = model_get_window_area_info_for_orientation(model, 'E', wwr: true)

    # Calculate new SHGC for west and east facing fenestration;
    # Create new simple glazing object and assign it to all
    # West and East fenestration
    #
    # Exception 5 is applied when applicable
    shgc_w = 0
    shgc_e = 0
    if !((a_w <= a_t / 4) && (a_e <= a_t / 4))
      # Calculate new SHGC
      if wwr_w > 0.2
        shgc_w = a_t * shgc_c / (4 * a_w)
      end
      if wwr_e > 0.2
        shgc_e = a_t * shgc_c / (4 * a_w)
      end

      # No SHGC adjustment needed
      return true if shgc_w == 0 && shgc_e == 0

      model.getSpaces.each do |space|
        # Get thermal zone multiplier
        multiplier = space.thermalZone.get.multiplier

        space.surfaces.each do |surface|
          # Proceed only for East and West facing surfaces that are required
          # to have their SHGC adjusted
          next unless (surface_cardinal_direction(surface) == 'W' && shgc_w > 0) ||
                      (surface_cardinal_direction(surface) == 'E' && shgc_e > 0)

          surface.subSurfaces.each do |subsurface|
            # Get window subsurface type
            subsurface_type = subsurface.subSurfaceType.to_s.downcase

            # Window, glass doors
            next unless (subsurface_type.include? 'window') || (subsurface_type.include? 'glass')

            new_shgc = surface_cardinal_direction(surface) == 'W' ? shgc_w : shgc_e
            new_shgc = new_shgc.round(2)

            # Get construction/simple glazing associated with the subsurface
            subsurface_org_cons = subsurface.construction.get.to_Construction.get
            subsurface_org_cons_mat = subsurface_org_cons.layers[0].to_SimpleGlazing.get

            # Only proceed if new SHGC is different than orignal one
            next unless (new_shgc - subsurface_org_cons_mat.solarHeatGainCoefficient).abs > 0

            # Clone construction/simple glazing associated with the subsurface
            subsurface_new_cons = subsurface_org_cons.clone(model).to_Construction.get
            subsurface_new_cons.setName("#{subsurface.name} Wind Cons U-#{OpenStudio.convert(subsurface_org_cons_mat.uFactor, 'W/m^2*K', 'Btu/ft^2*h*R').get.round(2)} SHGC #{new_shgc}")
            subsurface_new_cons_mat = subsurface_org_cons_mat.clone(model).to_SimpleGlazing.get
            subsurface_new_cons_mat.setName("#{subsurface.name} Wind SG Mat U-#{OpenStudio.convert(subsurface_org_cons_mat.uFactor, 'W/m^2*K', 'Btu/ft^2*h*R').get.round(2)} SHGC #{new_shgc}")
            subsurface_new_cons_mat.setSolarHeatGainCoefficient(new_shgc)
            new_layers = OpenStudio::Model::MaterialVector.new
            new_layers << subsurface_new_cons_mat
            subsurface_new_cons.setLayers(new_layers)

            # Assign new construction to sub surface
            subsurface.setConstruction(subsurface_new_cons)
          end
        end
      end
    end

    return true
  end

  # Is transfer air required?
  #
  # @code_sections [90.1-2013_6.5.7.1.2]
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] true if transfer air is required, false otherwise
  def model_transfer_air_required?(model)
    # TODO: It actually is for kitchen but not implemented yet
    return false
  end
end
