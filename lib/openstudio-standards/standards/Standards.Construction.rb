class Standard
  # @!group Construction

  # Sets the U-value of a construction to a specified value by modifying the thickness of the insulation layer.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @param target_u_value_ip [Double] U-Value (Btu/ft^2*hr*R)
  # @param insulation_layer_name [String] The name of the insulation layer in this construction
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param target_includes_int_film_coefficients [Bool] if true, subtracts off standard film interior coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @param target_includes_ext_film_coefficients [Bool] if true, subtracts off standard exterior film coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @return [Bool] returns true if successful, false if not
  # @todo Put in Phlyroy's logic for inferring the insulation layer of a construction
  def construction_set_u_value(construction, target_u_value_ip, insulation_layer_name = nil, intended_surface_type = 'ExteriorWall', target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    if construction.isFenestration
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Can only set the u-value of opaque constructions or simple glazing. #{construction.name} is not opaque or simple glazing.")
      return false
    end

    # Make sure an insulation layer was specified
    if insulation_layer_name.nil? && target_u_value_ip == 0.0
      # Do nothing if the construction already doesn't have an insulation layer
    elsif insulation_layer_name.nil?
      insulation_layer_name = find_and_set_insulation_layer(construction).name
    end

    # Remove the insulation layer if the specified U-value is zero.
    if target_u_value_ip == 0.0
      layer_index = 0
      construction.layers.each do |layer|
        break if layer.name.get == insulation_layer_name

        layer_index += 1
      end
      construction.eraseLayer(layer_index)
      return true
    end

    min_r_value_si = film_coefficients_r_value(intended_surface_type, target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    max_u_value_si = 1.0 / min_r_value_si
    max_u_value_ip = OpenStudio.convert(max_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    if target_u_value_ip >= max_u_value_ip
      target_u_value_ip = 1.0 / OpenStudio.convert(min_r_value_si + 0.001, 'm^2*K/W', 'ft^2*hr*R/Btu').get
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Requested U-value of #{target_u_value_ip} for #{construction.name} is greater than the sum of the inside and outside resistance, and the max U-value (6.636 SI) is used instead.")
    end

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

    # Determine the R-value of the non-insulation layers
    other_layer_r_value_si = 0.0
    construction.layers.each do |layer|
      next if layer.to_OpaqueMaterial.empty?
      next if layer.name.get == insulation_layer_name

      other_layer_r_value_si += layer.to_OpaqueMaterial.get.thermalResistance
    end

    # Determine the R-value of the air films, if requested
    other_layer_r_value_si += film_coefficients_r_value(intended_surface_type, target_includes_int_film_coefficients, target_includes_ext_film_coefficients)

    # Determine the difference between the desired R-value
    # and the R-value of the non-insulation layers and air films.
    # This is the desired R-value of the insulation.
    ins_r_value_si = target_r_value_si - other_layer_r_value_si

    # Set the R-value of the insulation layer
    construction.layers.each_with_index do |layer, l|
      next unless layer.name.get == insulation_layer_name

      # Remove insulation layer if requested R-value is lower than sum of non-insulation materials
      if ins_r_value_si <= 0.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Requested U-value of #{target_u_value_ip} for #{construction.name} is too low given the other materials in the construction; insulation layer will be removed.")
        construction.eraseLayer(l)
        # Set the target R-value to the sum of other layers to make name match properties
        target_r_value_ip = OpenStudio.convert(other_layer_r_value_si, 'm^2*K/W', 'ft^2*hr*R/Btu').get
        break # Don't modify the insulation layer since it has been removed
      end

      # Modify the insulation layer
      ins_r_value_ip = OpenStudio.convert(ins_r_value_si, 'm^2*K/W', 'ft^2*h*R/Btu').get
      if layer.to_StandardOpaqueMaterial.is_initialized
        layer = layer.to_StandardOpaqueMaterial.get
        layer.setThickness(ins_r_value_si * layer.conductivity)
        layer.setName("#{layer.name} R-#{ins_r_value_ip.round(2)}")
        break # Stop looking for the insulation layer once found
      elsif layer.to_MasslessOpaqueMaterial.is_initialized
        layer = layer.to_MasslessOpaqueMaterial.get
        layer.setThermalResistance(ins_r_value_si)
        layer.setName("#{layer.name} R-#{ins_r_value_ip.round(2)}")
        break # Stop looking for the insulation layer once found
      elsif layer.to_AirGap.is_initialized
        layer = layer.to_AirGap.get
        target_thickness = ins_r_value_si * layer.thermalConductivity
        layer.setThickness(target_thickness)
        layer.setName("#{layer.name} R-#{ins_r_value_ip.round(2)}")
        break # Stop looking for the insulation layer once found
      end
    end

    # Modify the construction name
    construction.setName("#{construction.name} R-#{target_r_value_ip.round(2)}")

    return true
  end

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
  # @param target_includes_int_film_coefficients [Bool] if true, subtracts off standard film interior coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @param target_includes_ext_film_coefficients [Bool] if true, subtracts off standard exterior film coefficients from your
  #   target_u_value before modifying insulation thickness.  Film values from 90.1-2010 A9.4.1 Air Films
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_u_value(construction, target_u_value_ip, intended_surface_type = 'ExteriorWall', target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
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
    # guide) so the target_includes_int_film_coefficients and target_includes_ext_film_coefficients
    # variable values are changed to their opposite so if the target value includes a film
    # the target value is unchanged
    film_coeff_r_value_si += film_coefficients_r_value(intended_surface_type, !target_includes_int_film_coefficients, !target_includes_ext_film_coefficients)
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
    glass_layer.setName("#{glass_layer.name} U-#{ins_u_value_ip.round(2)}")

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---ins_r_value_ip = #{ins_r_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---ins_u_value_ip = #{ins_u_value_ip.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---ins_u_value_si = #{ins_u_value_si.round(2)} for #{construction.name}.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "---glass_layer = #{glass_layer.name} u_factor_si = #{glass_layer.uFactor.round(2)}.")

    # Modify the construction name
    construction.setName("#{construction.name} U-#{target_u_value_ip.round(2)}")

    return true
  end

  # Sets the U-value of a construction to a specified value by modifying the thickness of the insulation layer.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @param target_shgc [Double] Solar Heat Gain Coefficient
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_shgc(construction, target_shgc)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "Setting SHGC for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Construction', "Can only set the SHGC of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    # Set the SHGC
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setSolarHeatGainCoefficient(target_shgc)
    glass_layer.setName("#{glass_layer.name} SHGC #{target_shgc.round(2)}")

    # Modify the construction name
    construction.setName("#{construction.name} SHGC #{target_shgc.round(2)}")

    return true
  end

  # Determines if the construction is a simple glazing construction,
  # as indicated by having a single layer of type SimpleGlazing.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @return [Bool] returns true if it is a simple glazing, false if not
  def construction_simple_glazing?(construction)
    # Not simple if more than 1 layer
    if construction.layers.length > 1
      return false
    end

    # Not simple unless the layer is a SimpleGlazing material
    # if construction.layers.first.to_SimpleGlazing.empty?
    if construction.layers.first.to_SimpleGlazing.empty?
      return false
    end

    # If here, must be simple glazing
    return true
  end

  # Set the F-Factor of a slab to a specified value.
  # Assumes an unheated, fully insulated slab, and modifies
  # the insulation layer according to the values from 90.1-2004
  # Table A6.3 Assembly F-Factors for Slab-on-Grade Floors.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @param target_f_factor_ip [Double] F-Factor
  # @param insulation_layer_name [String] The name of the insulation layer in this construction
  # @return [Bool] returns true if successful, false if not
  def construction_set_slab_f_factor(construction, target_f_factor_ip, insulation_layer_name = nil)
    # Regression from table A6.3 unheated, fully insulated slab
    r_value_ip = 1.0248 * target_f_factor_ip**-2.186
    u_value_ip = 1.0 / r_value_ip

    # Set the insulation U-value
    construction_set_u_value(construction, u_value_ip, insulation_layer_name, 'GroundContactFloor', true, true)

    # Modify the construction name
    construction.setName("#{construction.name} F-#{target_f_factor_ip.round(3)}")

    return true
  end

  # Set the surface specific F-factor parameters of a construction
  #
  # @param construction [OpenStudio::Model::FFactorGroundFloorConstruction] OpenStudio F-factor construction object
  # @param target_f_factor_ip [Float] Targeted F-Factor in IP units
  # @param surface [OpenStudio::Model::Surface] OpenStudio surface object
  # @return [Bool] returns true if successful, false if not
  def construction_set_surface_slab_f_factor(construction, target_f_factor_ip, surface)
    # Get space associated with surface
    space = surface.space.get

    # Find this space's exposed floor area and perimeter. NOTE: this assumes only only floor per space.
    perimeter, area = model_get_f_floor_geometry(space)

    if area == 0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', "Area for #{surface.name} was calculated to be 0 m2, slab f-factor cannot be set.")
      return false
    end

    # Change construction name
    construction.setName("#{construction.name}_#{surface.name}_#{target_f_factor_ip}")

    # Set properties
    f_factor_si = target_f_factor_ip * OpenStudio.convert(1.0, 'Btu/ft*h*R', 'W/m*K').get
    construction.setFFactor(f_factor_si)
    construction.setArea(area)
    construction.setPerimeterExposed(perimeter)

    # Set surface outside boundary condition
    surface.setOutsideBoundaryCondition('GroundFCfactorMethod')

    return true
  end

  # Set the C-Factor of an underground wall to a specified value.
  # Assumes continuous exterior insulation and modifies
  # the insulation layer according to the values from 90.1-2004
  # Table A4.2 Assembly C-Factors for Below-Grade walls.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @param target_c_factor_ip [Double] C-Factor
  # @param insulation_layer_name [String] The name of the insulation layer in this construction
  # @return [Bool] returns true if successful, false if not
  def construction_set_underground_wall_c_factor(construction, target_c_factor_ip, insulation_layer_name = nil)
    # Regression from table A4.2 continuous exterior insulation
    r_value_ip = 0.775 * target_c_factor_ip**-1.067
    u_value_ip = 1.0 / r_value_ip

    # Set the insulation U-value
    construction_set_u_value(construction, u_value_ip, insulation_layer_name, 'GroundContactWall', true, true)

    # Modify the construction name
    construction.setName("#{construction.name} C-#{target_c_factor_ip.round(3)}")

    return true
  end

  # Set the surface specific C-factor parameters of a construction
  #
  # @param construction [OpenStudio::Model::CFactorUndergroundWallConstruction] OpenStudio C-factor construction object
  # @param target_c_factor_ip [Float] Targeted C-Factor in IP units
  # @param surface [OpenStudio::Model::Surface] OpenStudio surface object
  # @return [Bool] returns true if successful, false if not
  def construction_set_surface_underground_wall_c_factor(construction, target_c_factor_ip, surface)
    # Get space associated with surface
    space = surface.space.get

    # Get height of the first below grade wall in this space.
    below_grade_wall_height = model_get_space_below_grade_wall_height(space)

    if below_grade_wall_height == 0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', "Below grade wall height for #{surface.name} was calculated to be 0 m2, below grade wall c-factor cannot be set.")
      return false
    end

    # Change construction name
    construction.setName("#{construction.name}_#{surface.name}_#{target_c_factor_ip}")

    # Set properties
    c_factor_si = target_c_factor_ip * OpenStudio.convert(1.0, 'Btu/ft^2*h*R', 'W/m^2*K').get
    construction.setCFactor(c_factor_si)
    construction.setHeight(below_grade_wall_height)

    # Set surface outside boundary condition
    surface.setOutsideBoundaryCondition('GroundFCfactorMethod')
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
  # @param [OpenStudio:Model:Construction] OpenStudio Construction object
  #
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

  # find and get the insulation layer for a construction
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @return [OpenStudio::Model::Material] insulation layer
  def find_and_set_insulation_layer(construction)
    # skip if already has an insulation layer set.
    return construction.insulation.get unless construction.insulation.empty?

    # find insulation layer
    min_conductance = 100.0
    # loop through Layers
    construction.layers.each do |layer|
      # try casting the layer to an OpaqueMaterial.
      material = nil
      material = layer.to_OpaqueMaterial.get unless layer.to_OpaqueMaterial.empty?
      material = layer.to_FenestrationMaterial.get unless layer.to_FenestrationMaterial.empty?
      # check if the cast was successful, then find the insulation layer.
      unless material.nil?

        if BTAP::Resources::Envelope::Materials.get_conductance(material) < min_conductance
          # Keep track of the highest thermal resistance value.
          min_conductance = BTAP::Resources::Envelope::Materials.get_conductance(material)
          return_material = material
          unless material.to_OpaqueMaterial.empty?
            construction.setInsulation(material)
          end
        end
      end
    end
    if construction.insulation.empty? && construction.isOpaque
      raise
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', "This construction has no insulation layer specified. Construction #{construction.name.get} insulation layer could not be set!. This occurs when a insulation layer is duplicated in the construction.")
    end
    return construction.insulation.get
  end

  # change construction properties based on an a set of values
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param values [Hash] has of values
  # @param is_percentage [Bool] toggle is percentage
  # @return [Hash] json information
  def change_construction_properties_in_model(model, values, is_percentage = false)
    # puts JSON.pretty_generate(values)
    # copy orginal model for reporting.
    before_measure_model = BTAP::FileIO.deep_copy(model)
    # report change as Info
    info = ''
    outdoor_surfaces = BTAP::Geometry::Surfaces.filter_by_boundary_condition(model.getSurfaces, 'Outdoors')
    outdoor_subsurfaces = BTAP::Geometry::Surfaces.get_subsurfaces_from_surfaces(outdoor_surfaces)
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
  # @param is_percentage [Bool] toggle is percentage
  # @return [Bool] returns true if successful, false if not
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
      target_u_value_si = target_u_value_si / 100.0 * BTAP::Resources::Envelope::Constructions.get_conductance(construction) unless conductance.nil?
      if standard.construction_simple_glazing?(construction)
        target_shgc = target_shgc / 100.0 * construction.layers.first.to_SimpleGlazing.get.solarHeatGainCoefficient unless target_shgc.nil?
        target_tvis = target_tvis / 100.0 * construction.layers.first.to_SimpleGlazing.get.setVisibleTransmittance unless target_tvis.nil?
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
      new_construction = construction_deep_copy(model, construction)
      case surface.outsideBoundaryCondition
        when 'Outdoors'
          if standard.construction_simple_glazing?(new_construction)
            unless conductance.nil?
              standard.construction_set_glazing_u_value(new_construction,
                                                        target_u_value_ip.to_f,
                                                        nil,
                                                        false,
                                                        false)
            end
            unless shgc.nil?
              standard.construction_set_glazing_shgc(new_construction,
                                                     shgc)
            end
            unless tvis.nil?
              construction_set_glazing_tvis(new_construction,
                                            tvis)
            end

          else
            unless conductance.nil?
              standard.construction_set_u_value(new_construction,
                                                target_u_value_ip.to_f,
                                                find_and_set_insulation_layer(
                                                  new_construction
                                                ).name.get,
                                                intended_surface_type = nil,
                                                false,
                                                false)
            end
          end
        when 'Ground'
          case surface.surfaceType
            when 'Wall'
              unless conductance.nil?
                standard.construction_set_u_value(new_construction,
                                                  target_u_value_ip.to_f,
                                                  find_and_set_insulation_layer(
                                                    new_construction
                                                  ).name.get,
                                                  intended_surface_type = nil,
                                                  false,
                                                  false)
              end
            #               standard.construction_set_underground_wall_c_factor(new_construction,
            #                                                                   target_u_value_ip.to_f,
            #                                                                   find_and_set_insulaton_layer(model,
            #                                                                   new_construction).name.get)
            when 'RoofCeiling', 'Floor'
              unless conductance.nil?
                standard.construction_set_u_value(new_construction,
                                                  target_u_value_ip.to_f,
                                                  find_and_set_insulation_layer(new_construction).name.get,
                                                  intended_surface_type = nil,
                                                  false,
                                                  false)
              end
            #               standard.construction_set_slab_f_factor(new_construction,
            #                                                       target_u_value_ip.to_f,
            #                                                       find_and_set_insulaton_layer(model,
            #                                                       new_construction).name.get)
          end
      end
      new_construction.setName(new_construction_name)
    else
      new_construction = new_construction.get
    end
    surface.setConstruction(new_construction)
    return true
  end

  # This will create a deep copy of the construction
  # @author Phylroy A. Lopez <plopez@nrcan.gc.ca>
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param construction [OpenStudio::Model::Construction] construction object
  # @return [OpenStudio::Model::Construction] new construction object
  def construction_deep_copy(model, construction)
    construction = BTAP::Common.validate_array(model, construction, 'Construction').first
    new_construction = construction.clone.to_Construction.get
    # interating through layers."
    (0..new_construction.layers.length - 1).each do |layernumber|
      # cloning material"
      cloned_layer = new_construction.getLayer(layernumber).clone.to_Material.get
      # "setting material to new construction."
      new_construction.setLayer(layernumber, cloned_layer)
    end
    return new_construction
  end

  # Sets the T-vis of a simple glazing construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
  # @param construction [OpenStudio::Model::Construction] construction object
  # @param target_tvis [Double] Visible Transmittance
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_tvis(construction, target_tvis)
    if target_tvis >= 1.0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', "Can only set the Tvis can only be set to less than 1.0. #{target_tvis} is greater than 1.0")
      return false
    end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Construction', "Setting TVis for #{construction.name} to #{target_tvis}")
    standard = Standard.new
    # Skip layer-by-layer fenestration constructions
    unless standard.construction_simple_glazing?(construction)
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Construction', "Can only set the Tvis of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    # Set the Tvis
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setVisibleTransmittance(target_tvis)
    glass_layer.setName("#{glass_layer.name} TVis #{target_tvis.round(3)}")

    # Modify the construction name
    construction.setName("#{construction.name} TVis #{target_tvis.round(2)}")
    return true
  end
end
