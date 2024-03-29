class Standard
  # @!group Construction

  # change construction properties based on an a set of values
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param values [Hash] has of values
  # @param is_percentage [Boolean] toggle is percentage
  # @return [Hash] json information
  def change_construction_properties_in_model(model, values, is_percentage = false)
    # puts JSON.pretty_generate(values)
    # copy orginal model for reporting.
    before_measure_model = BTAP::FileIO.deep_copy(model)
    # report change as Info
    info = ''
    outdoor_surfaces = BTAP::Geometry::Surfaces.filter_by_boundary_condition(model.getSurfaces, 'Outdoors')
    outdoor_subsurfaces = outdoor_surfaces.flat_map(&:subSurfaces)
    ground_surfaces = BTAP::Geometry::Surfaces.filter_by_boundary_condition(model.getSurfaces, 'Ground')
    ext_windows = BTAP::Geometry::Surfaces.filter_subsurfaces_by_types(outdoor_subsurfaces, ['FixedWindow', 'OperableWindow'])
    ext_skylights = BTAP::Geometry::Surfaces.filter_subsurfaces_by_types(outdoor_subsurfaces, ['Skylight', 'TubularDaylightDiffuser', 'TubularDaylightDome'])
    ext_doors = BTAP::Geometry::Surfaces.filter_subsurfaces_by_types(outdoor_subsurfaces, ['Door'])
    ext_glass_doors = BTAP::Geometry::Surfaces.filter_subsurfaces_by_types(outdoor_subsurfaces, ['GlassDoor'])
    ext_overhead_doors = BTAP::Geometry::Surfaces.filter_subsurfaces_by_types(outdoor_subsurfaces, ['OverheadDoor'])

    # Ext and Ground Surfaces
    (outdoor_surfaces + ground_surfaces).sort.each do |surface|
      ecm_cond_name = "#{surface.outsideBoundaryCondition.downcase}_#{surface.surfaceType.downcase}_conductance"
      apply_changes_to_surface_construction(model,
                                            surface,
                                            values[ecm_cond_name],
                                            nil,
                                            nil,
                                            is_percentage)
      # report change as Info
      surface_construction = model.getConstructionByName(surface.construction.get.name.to_s).get
      surface_conductance = OpenstudioStandards::Constructions.construction_get_conductance(surface_construction)
      before_measure_surface = before_measure_model.getConstructionByName(surface.construction.get.name.to_s).get
      before_measure_surface_conductance = OpenstudioStandards::Constructions.construction_get_conductance(before_measure_surface)
      if before_measure_surface_conductance.round(3) != surface_conductance.round(3)
        info << "#{surface.outsideBoundaryCondition.downcase}_#{surface.surfaceType.downcase}_conductance for #{surface.name} changed from #{before_measure_surface_conductance.round(3)} to #{surface_conductance.round(3)}."
      end
    end
    # Subsurfaces
    (ext_doors + ext_overhead_doors + ext_windows + ext_glass_doors + ext_skylights).sort.each do |surface|
      ecm_cond_name = "#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_conductance"
      ecm_shgc_name = "#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_shgc"
      ecm_tvis_name = "#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_tvis"
      apply_changes_to_surface_construction(model,
                                            surface,
                                            values[ecm_cond_name],
                                            values[ecm_shgc_name],
                                            values[ecm_tvis_name])
      surface_construction = model.getConstructionByName(surface.construction.get.name.to_s).get
      surface_conductance = OpenstudioStandards::Constructions.construction_get_conductance(surface_construction)
      before_surface_construction = before_measure_model.getConstructionByName(surface.construction.get.name.to_s).get
      before_measure_surface_conductance = OpenstudioStandards::Constructions.construction_get_conductance(before_surface_construction)
      if before_measure_surface_conductance.round(3) != surface_conductance.round(3)
        info << "#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_conductance for #{surface.name} changed from #{before_measure_surface_conductance.round(3)} to #{surface_conductance.round(3)}."
      end
    end
    info << JSON.pretty_generate(BTAP::FileIO.compare_osm_files(before_measure_model, model))
    return info
  end

  # apply changes to a surface construction
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param surface [OpenStudio::Model::Surface] surface object
  # @param conductance [Double] conductance value in SI
  # @param shgc [Double] solar heat gain coefficient value, unitless
  # @param tvis [Double] visible transmittance
  # @param is_percentage [Boolean] toggle is percentage
  # @return [Boolean] returns true if successful, false if not
  def apply_changes_to_surface_construction(model, surface, conductance = nil, shgc = nil, tvis = nil, is_percentage = false)
    # If user has no changes...do nothing and return true.
    return true if conductance.nil? && shgc.nil? && tvis.nil?

    standard = Standard.new
    construction = OpenStudio::Model.getConstructionByName(surface.model, surface.construction.get.name.to_s).get

    # set initial targets
    target_u_value_si = conductance
    target_shgc = shgc
    target_tvis = tvis
    # Mulitply by percentages if required.
    if is_percentage
      target_u_value_si = target_u_value_si / 100.0 * OpenstudioStandards::Constructions.construction_get_conductance(construction) unless conductance.nil?
      if OpenstudioStandards::Constructions.construction_simple_glazing?(construction)
        target_shgc = target_shgc / 100.0 * construction.layers.first.to_SimpleGlazing.get.solarHeatGainCoefficient unless target_shgc.nil?
        target_tvis = target_tvis / 100.0 * construction.layers.first.to_SimpleGlazing.get.visibleTransmittance unless target_tvis.nil?
      end
    end

    new_construction_name_suffix = ':{'
    new_construction_name_suffix << " \"cond\"=>#{target_u_value_si.round(3)}" unless target_u_value_si.nil?
    new_construction_name_suffix << " \"shgc\"=>#{target_shgc.round(3)}" unless target_shgc.nil?
    new_construction_name_suffix << " \"tvis\"=>#{target_tvis.round(3)}" unless target_tvis.nil?
    new_construction_name_suffix << '}'

    new_construction_name = "#{surface.construction.get.name}-#{new_construction_name_suffix}"
    new_construction = OpenStudio::Model.getConstructionByName(surface.model, new_construction_name)

    if new_construction.empty?
      # create new construction.
      # create a copy
      target_u_value_ip = OpenStudio.convert(target_u_value_si.to_f, 'W/m^2*K', 'Btu/ft^2*hr*R').get unless target_u_value_si.nil?
      new_construction = OpenstudioStandards::Constructions.construction_deep_copy(construction)
      case surface.outsideBoundaryCondition
      when 'Outdoors'
        if OpenstudioStandards::Constructions.construction_simple_glazing?(new_construction)
          simple_glazing = construction.layers.first.to_SimpleGlazing.get
          unless conductance.nil?
            OpenstudioStandards::Constructions.construction_set_glazing_u_value(new_construction, target_u_value_ip.to_f,
                                                                                target_includes_interior_film_coefficients: false,
                                                                                target_includes_exterior_film_coefficients: false)
          end
          simple_glazing.setSolarHeatGainCoefficient(shgc) unless shgc.nil?
          simple_glazing.setVisibleTransmittance(tvis) unless tvis.nil?
        else
          unless conductance.nil?
            OpenstudioStandards::Constructions.construction_set_u_value(new_construction, target_u_value_ip.to_f,
                                                                        target_includes_interior_film_coefficients: false,
                                                                        target_includes_exterior_film_coefficients: false)
          end
        end
      when 'Ground'
        case surface.surfaceType
        when 'Wall'
          intended_surface_type = 'GroundContactWall'
        when 'RoofCeiling'
          intended_surface_type = 'GroundContactRoof'
        when 'Floor'
          intended_surface_type = 'GroundContactFloor'
        end
        unless conductance.nil?
          OpenstudioStandards::Constructions.construction_set_u_value(new_construction, target_u_value_ip.to_f,
                                                                      intended_surface_type: intended_surface_type,
                                                                      target_includes_interior_film_coefficients: false,
                                                                      target_includes_exterior_film_coefficients: false)
        end
      end
      new_construction.setName(new_construction_name)
    else
      new_construction = new_construction.get
    end
    surface.setConstruction(new_construction)
    return true
  end
end
