class Standard
  # @!group Construction

  # Sets the U-value of a construction to a specified value by modifying the thickness of the insulation layer.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @param target_u_value_ip [Double] U-Value (Btu/ft^2*hr*R)
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param target_includes_interior_film_coefficients [Boolean] if true, subtracts off standard film interior coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @param target_includes_exterior_film_coefficients [Boolean] if true, subtracts off standard exterior film coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @return [Boolean] returns true if successful, false if not
  def construction_set_glazing_u_value(construction, target_u_value_ip, intended_surface_type = 'ExteriorWall', target_includes_interior_film_coefficients, target_includes_exterior_film_coefficients)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless OpenstudioStandards::Constructions.construction_simple_glazing?(construction)
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Can only set the u-value of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    glass_layer = construction.layers.first.to_SimpleGlazing.get
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---glass_layer = #{glass_layer.name} u_factor_si = #{glass_layer.uFactor.round(2)}.")

    # Convert the target U-value to SI
    target_u_value_ip = target_u_value_ip.to_f
    target_r_value_ip = 1.0 / target_u_value_ip

    target_u_value_si = OpenStudio.convert(target_u_value_ip, 'Btu/ft^2*hr*R', 'W/m^2*K').get
    target_r_value_si = 1.0 / target_u_value_si

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "#{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---target_u_value_ip = #{target_u_value_ip.round(3)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---target_r_value_ip = #{target_r_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---target_u_value_si = #{target_u_value_si.round(3)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---target_r_value_si = #{target_r_value_si.round(2)} for #{construction.name}.")

    # Determine the R-value of the air films, if requested
    film_coeff_r_value_si = 0.0
    # In EnergyPlus, the U-factor input of the WindowMaterial:SimpleGlazingSystem
    # object includes the film coefficients (see IDD description, and I/O reference
    # guide) so the target_includes_interior_film_coefficients and target_includes_exterior_film_coefficients
    # variable values are changed to their opposite so if the target value includes a film
    # the target value is unchanged
    film_coeff_r_value_si += OpenstudioStandards::Constructions.film_coefficients_r_value(intended_surface_type, !target_includes_interior_film_coefficients, !target_includes_exterior_film_coefficients)
    film_coeff_u_value_si = 1.0 / film_coeff_r_value_si
    film_coeff_u_value_ip = OpenStudio.convert(film_coeff_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    film_coeff_r_value_ip = 1.0 / film_coeff_u_value_ip

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---film_coeff_r_value_si = #{film_coeff_r_value_si.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---film_coeff_u_value_si = #{film_coeff_u_value_si.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---film_coeff_u_value_ip = #{film_coeff_u_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---film_coeff_r_value_ip = #{film_coeff_r_value_ip.round(2)} for #{construction.name}.")

    # Determine the difference between the desired R-value
    # and the R-value of the and air films.
    # This is the desired R-value of the insulation.
    ins_r_value_si = target_r_value_si - film_coeff_r_value_si
    if ins_r_value_si <= 0.0
      ins_r_value_si = 0.001
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Requested U-value of #{target_u_value_ip} Btu/ft^2*hr*R for #{construction.name} is too high given the film coefficients of U-#{film_coeff_u_value_ip.round(2)} Btu/ft^2*hr*R.")
    end
    ins_u_value_si = 1.0 / ins_r_value_si

    if ins_u_value_si > 7.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Requested U-value of #{target_u_value_ip} for #{construction.name} is too high given the film coefficients of U-#{film_coeff_u_value_ip.round(2)}; setting U-value to EnergyPlus limit of 7.0 W/m^2*K (1.23 Btu/ft^2*hr*R).")
      ins_u_value_si = 7.0
    end

    ins_u_value_ip = OpenStudio.convert(ins_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    ins_r_value_ip = 1.0 / ins_u_value_ip

    # Set the U-value of the insulation layer
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setUFactor(ins_u_value_si)

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---ins_r_value_ip = #{ins_r_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---ins_u_value_ip = #{ins_u_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---ins_u_value_si = #{ins_u_value_si.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---glass_layer = #{glass_layer.name} u_factor_si = #{glass_layer.uFactor.round(2)}.")

    return true
  end

  # Get the SHGC as calculated by EnergyPlus.
  # Only applies to fenestration constructions.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @return [Double] the SHGC as a decimal.
  def construction_calculated_solar_heat_gain_coefficient(construction)
    construction_name = construction.name.get.to_s

    shgc = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "SHGC row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      shgc_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass SHGC'
                  AND RowName='#{row_id}'"

      shgc = sql.execAndReturnFirstDouble(shgc_query)

      shgc = if shgc.is_initialized
               shgc.get
             end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return shgc
  end

  # Get the VT as calculated by EnergyPlus.
  # Only applies to fenestration constructions.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @return [Double] the visible transmittance as a decimal.
  def construction_calculated_visible_transmittance(construction)
    construction_name = construction.name.get.to_s

    vt = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "VT row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      vt_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass Visible Transmittance'
                  AND RowName='#{row_id}'"

      vt = sql.execAndReturnFirstDouble(vt_query)

      vt = if vt.is_initialized
             vt.get
           end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return vt
  end

  # Get the U-Factor as calculated by EnergyPlus.
  # Only applies to fenestration constructions.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @return [Double] the U-Factor in W/m^2*K.
  def construction_calculated_u_factor(construction)
    construction_name = construction.name.get.to_s

    u_factor_w_per_m2_k = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "U-Factor row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      u_factor_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass U-Factor'
                  AND RowName='#{row_id}'"

      u_factor_w_per_m2_k = sql.execAndReturnFirstDouble(u_factor_query)

      u_factor_w_per_m2_k = if u_factor_w_per_m2_k.is_initialized
                              u_factor_w_per_m2_k.get
                            end

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return u_factor_w_per_m2_k
  end

  # Calculate the fenestration U-Factor base on the glass, frame,
  # and divider performance and area calculated by EnergyPlus.
  #
  # @param construction [OpenStudio:Model:Construction] OpenStudio Construction object
  # @return [Double] the U-Factor in W/m^2*K
  def construction_calculated_fenestration_u_factor_w_frame(construction)
    construction_name = construction.name.get.to_s

    u_factor_w_per_m2_k = nil

    sql = construction.model.sqlFile

    if sql.is_initialized
      sql = sql.get

      row_query = "SELECT RowName
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND Value='#{construction_name.upcase}'"

      row_id = sql.execAndReturnFirstString(row_query)

      if row_id.is_initialized
        row_id = row_id.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "U-Factor row ID not found for construction: #{construction_name}.")
        row_id = 9999
      end

      # Glass U-Factor
      glass_u_factor_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass U-Factor'
                  AND RowName='#{row_id}'"

      glass_u_factor_w_per_m2_k = sql.execAndReturnFirstDouble(glass_u_factor_query)

      glass_u_factor_w_per_m2_k = glass_u_factor_w_per_m2_k.is_initialized ? glass_u_factor_w_per_m2_k.get : 0.0

      # Glass area
      glass_area_query = "SELECT Value
                          FROM tabulardatawithstrings
                          WHERE ReportName='EnvelopeSummary'
                          AND ReportForString='Entire Facility'
                          AND TableName='Exterior Fenestration'
                          AND ColumnName='Glass Area'
                          AND RowName='#{row_id}'"

      glass_area_m2 = sql.execAndReturnFirstDouble(glass_area_query)

      glass_area_m2 = glass_area_m2.is_initialized ? glass_area_m2.get : 0.0

      # Frame conductance
      frame_conductance_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Frame Conductance'
                  AND RowName='#{row_id}'"

      frame_conductance_w_per_m2_k = sql.execAndReturnFirstDouble(frame_conductance_query)

      frame_conductance_w_per_m2_k = frame_conductance_w_per_m2_k.is_initialized ? frame_conductance_w_per_m2_k.get : 0.0

      # Frame area
      frame_area_query = "SELECT Value
                          FROM tabulardatawithstrings
                          WHERE ReportName='EnvelopeSummary'
                          AND ReportForString='Entire Facility'
                          AND TableName='Exterior Fenestration'
                          AND ColumnName='Frame Area'
                          AND RowName='#{row_id}'"

      frame_area_m2 = sql.execAndReturnFirstDouble(frame_area_query)

      frame_area_m2 = frame_area_m2.is_initialized ? frame_area_m2.get : 0.0

      # Divider conductance
      divider_conductance_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Divider Conductance'
                  AND RowName='#{row_id}'"

      divider_conductance_w_per_m2_k = sql.execAndReturnFirstDouble(divider_conductance_query)

      divider_conductance_w_per_m2_k = divider_conductance_w_per_m2_k.is_initialized ? divider_conductance_w_per_m2_k.get : 0.0

      # Divider area
      divider_area_query = "SELECT Value
                          FROM tabulardatawithstrings
                          WHERE ReportName='EnvelopeSummary'
                          AND ReportForString='Entire Facility'
                          AND TableName='Exterior Fenestration'
                          AND ColumnName='Divder Area'
                          AND RowName='#{row_id}'"

      divider_area_m2 = sql.execAndReturnFirstDouble(divider_area_query)

      divider_area_m2 = divider_area_m2.is_initialized ? divider_area_m2.get : 0.0

      u_factor_w_per_m2_k = (glass_u_factor_w_per_m2_k * glass_area_m2 + frame_conductance_w_per_m2_k * frame_area_m2 + divider_conductance_w_per_m2_k * divider_area_m2) / (glass_area_m2 + frame_area_m2 + divider_area_m2)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', 'Model has no sql file containing results, cannot lookup data.')
    end

    return u_factor_w_per_m2_k
  end

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
      surface_conductance = BTAP::Geometry::Surfaces.get_surface_construction_conductance(surface)
      before_measure_surface_conductance = BTAP::Geometry::Surfaces.get_surface_construction_conductance(OpenStudio::Model.getSurfaceByName(before_measure_model, surface.name.to_s).get)
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

      surface_conductance = BTAP::Geometry::Surfaces.get_surface_construction_conductance(surface)
      before_surface = OpenStudio::Model.getSubSurfaceByName(before_measure_model, surface.name.to_s).get
      before_measure_surface_conductance = BTAP::Geometry::Surfaces.get_surface_construction_conductance(before_surface)
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
            standard.construction_set_glazing_u_value(new_construction,
                                                      target_u_value_ip.to_f,
                                                      nil,
                                                      false,
                                                      false)
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
