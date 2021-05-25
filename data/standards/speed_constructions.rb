module SpeedConstructions
  extend self

  # The corresponding enumeration used by SEED,
  # based on the enumeration used by openstudio-standards
  # @param os_enum [String] the openstudio-standards enumeration
  # @param enum_type [String] the key to be used for the inputs JSON,
  # the key to be used for the method (Foo_R_Value or Foo_Type),
  # or the user-facing GUI string
  # @return [String] the SPEED enumeration
  def speed_enum(os_enum, enum_type='key')
    speed_construction_enum_map = {
      # Templates
      '90.1-2007' => {'key' => 'ASHRAE_90_1_2007', 'gui' => 'ASHRAE_90_1_2007'},
      '90.1-2010' => {'key' => 'ASHRAE_90_1_2010', 'gui' => 'ASHRAE_90_1_2010'},
      '90.1-2013' => {'key' => 'ASHRAE_90_1_2013', 'gui' => 'ASHRAE_90_1_2013'},
      '90.1-2016' => {'key' => 'ASHRAE_90_1_2016', 'gui' => 'ASHRAE_90_1_2016'},
      # Climate Zones
      '1' => {'key' => '1', 'gui' => 'CZ1'},
      '2' => {'key' => '2', 'gui' => 'CZ2'},
      '3' => {'key' => '3', 'gui' => 'CZ3'},
      '4' => {'key' => '4', 'gui' => 'CZ4'},
      '5' => {'key' => '5', 'gui' => 'CZ5'},
      '6' => {'key' => '6', 'gui' => 'CZ6'},
      '7' => {'key' => '7', 'gui' => 'CZ7'},
      '8' => {'key' => '8', 'gui' => 'CZ8'},
      # Intended Surface Types
      'ExteriorRoof' => {'key' => 'Roof', 'method' => 'Roof', 'gui' => 'Roof'},
      'ExteriorWall' => {'key' => 'Exterior_Walls', 'method' => 'Wall', 'gui' => 'Wall'},
      'ExteriorWindow' => {'key' => 'Exterior_Window', 'method' => 'Window', 'gui' => 'Window'},
      'GroundContactFloor' => {'key' => 'Foundation', 'method' => 'Slab', 'gui' => 'Slab'},
      'InteriorFloor' => {'key' => 'Floors', 'method' => 'Floor', 'gui' => 'Floor'},
      'InteriorWall' => {'key' => 'Interior_Walls', 'method' => 'Int_Wall', 'gui' => 'Interior Wall'},
      # Standards Construction Types
      'Attic and Other' => {'key' => 'Attic_and_Other', 'gui' => 'Attic & Other'},
      'IEAD' => {'key' => 'IEAD', 'gui' => 'IEAD'},
      'Mass' => {'key' => 'Mass', 'gui' => 'Mass'},
      'Metal Building' => {'key' => 'Metal_Building', 'gui' => 'Metal'},
      'Metal framing (all other)' => {'key' => 'Metal_Framing', 'gui' => 'Mtl Framed'},
      'Metal framing (curtainwall/storefront)' => {'key' => 'Metal_Framing_CurtainWall', 'gui' => 'Mtl Framed CW'},
      'Nonmetal framing (all)' => {'key' => 'Non-Metal_Framing', 'gui' => 'Non Mtl Framed'},
      'SteelFramed' => {'key' => 'Steel_Framed', 'gui' => 'Steel Framed'},
      'Unheated' => {'key' => 'Slab_Type', 'gui' => 'Insulated'},
      'WoodFramed' => {'key' => 'Wood_Framed', 'gui' => 'Wood Framed'}
    }

    speed_enum = speed_construction_enum_map[os_enum]
    if speed_enum.nil?
      puts "ERROR Missing SPEED enum for #{os_enum}"
      return "TODO add SPEED enum for #{os_enum}"
    end

    speed_enum = speed_construction_enum_map[os_enum][enum_type]
    if speed_enum.nil?
      puts "ERROR Missising SPEED #{enum_type} enum for #{os_enum}"
      return "TODO add SPEED #{enum_type} enum for #{os_enum}"
    end

    return speed_enum
  end

  # Creates a better opaque construction using the supplied properties
  # @param props [Hash] openstudio-standards construction properties
  # @param improvement [Double] IP R-value increase.
  # @return [Hash] a copy improved properties in place
  def upgrade_opaque_construction_properties(props, r_val_increase_ip)
    new_props = props.clone

    # Increase the R-value by the specified amount
    old_u_value_ip = props['assembly_maximum_u_value'].to_f
    old_r_value_ip = 1.0 / old_u_value_ip
    new_r_value_ip = old_r_value_ip + r_val_increase_ip
    new_u_value_ip = 1.0 / new_r_value_ip
    new_props['assembly_maximum_u_value'] = new_u_value_ip

    return new_props
  end

  # Creates a better window construction using the supplied properties
  # @param props [Hash] openstudio-standards construction properties
  # @param shgc_decrease [Double] SHGC decrease. 0.1 = 10% decrease
  # @param u_val_decrease [Double] U-Value decrease. 0.1 = 10% decrease
  # @return [Hash] a copy improved properties in place
  def upgrade_window_construction_properties(props, shgc_decrease, u_val_decrease)
    new_props = props.clone

    # Decrease the SHGC
    old_shgc = props['assembly_maximum_solar_heat_gain_coefficient'].to_f
    new_shgc = old_shgc * (1.0 - shgc_decrease)
    new_props['assembly_maximum_solar_heat_gain_coefficient'] = new_shgc

    # Decrease the U-Value
    old_u_value_ip = props['assembly_maximum_u_value'].to_f
    new_u_value_ip = old_u_value_ip * (1.0 - u_val_decrease)
    new_props['assembly_maximum_u_value'] = new_u_value_ip

    return new_props
  end

  # Create a material from the openstudio standards dataset.
  # @todo make return an OptionalMaterial
  def model_add_material(std, model, material_name)
    # First check model and return material if it already exists
    model.getMaterials.sort.each do |material|
      if material.name.get.to_s == material_name
        # puts("DEBUG Already added material: #{material_name}")
        return material
      end
    end

    # puts("INFO Adding material: #{material_name}")

    # Get the object data
    data = std.model_find_object(std.standards_data['materials'], 'name' => material_name)
    unless data
      puts("WARNING Cannot find data for material: #{material_name}, will not be created.")
      return false # TODO: change to return empty optional material
    end

    material = nil
    material_type = data['material_type']

    if material_type == 'StandardOpaqueMaterial'
      material = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      material.setName(material_name)

      material.setRoughness(data['roughness'].to_s)
      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setThermalConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDensity(OpenStudio.convert(data['density'].to_f, 'lb/ft^3', 'kg/m^3').get)
      material.setSpecificHeat(OpenStudio.convert(data['specific_heat'].to_f, 'Btu/lb*R', 'J/kg*K').get)
      material.setThermalAbsorptance(data['thermal_absorptance'].to_f)
      material.setSolarAbsorptance(data['solar_absorptance'].to_f)
      material.setVisibleAbsorptance(data['visible_absorptance'].to_f)

    elsif material_type == 'MasslessOpaqueMaterial'
      material = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
      material.setName(material_name)
      material.setThermalResistance(OpenStudio.convert(data['resistance'].to_f, 'hr*ft^2*R/Btu', 'm^2*K/W').get)
      material.setThermalConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setThermalAbsorptance(data['thermal_absorptance'].to_f)
      material.setSolarAbsorptance(data['solar_absorptance'].to_f)
      material.setVisibleAbsorptance(data['visible_absorptance'].to_f)

    elsif material_type == 'AirGap'
      material = OpenStudio::Model::AirGap.new(model)
      material.setName(material_name)

      material.setThermalResistance(OpenStudio.convert(data['resistance'].to_f, 'hr*ft^2*R/Btu*in', 'm*K/W').get)

    elsif material_type == 'Gas'
      material = OpenStudio::Model::Gas.new(model)
      material.setName(material_name)

      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setGasType(data['gas_type'].to_s)

    elsif material_type == 'SimpleGlazing'
      material = OpenStudio::Model::SimpleGlazing.new(model)
      material.setName(material_name)

      material.setUFactor(OpenStudio.convert(data['u_factor'].to_f, 'Btu/hr*ft^2*R', 'W/m^2*K').get)
      material.setSolarHeatGainCoefficient(data['solar_heat_gain_coefficient'].to_f)
      material.setVisibleTransmittance(data['visible_transmittance'].to_f)

    elsif material_type == 'StandardGlazing'
      material = OpenStudio::Model::StandardGlazing.new(model)
      material.setName(material_name)

      material.setOpticalDataType(data['optical_data_type'].to_s)
      material.setThickness(OpenStudio.convert(data['thickness'].to_f, 'in', 'm').get)
      material.setSolarTransmittanceatNormalIncidence(data['solar_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideSolarReflectanceatNormalIncidence(data['front_side_solar_reflectance_at_normal_incidence'].to_f)
      material.setBackSideSolarReflectanceatNormalIncidence(data['back_side_solar_reflectance_at_normal_incidence'].to_f)
      material.setVisibleTransmittanceatNormalIncidence(data['visible_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideVisibleReflectanceatNormalIncidence(data['front_side_visible_reflectance_at_normal_incidence'].to_f)
      material.setBackSideVisibleReflectanceatNormalIncidence(data['back_side_visible_reflectance_at_normal_incidence'].to_f)
      material.setInfraredTransmittanceatNormalIncidence(data['infrared_transmittance_at_normal_incidence'].to_f)
      material.setFrontSideInfraredHemisphericalEmissivity(data['front_side_infrared_hemispherical_emissivity'].to_f)
      material.setBackSideInfraredHemisphericalEmissivity(data['back_side_infrared_hemispherical_emissivity'].to_f)
      material.setThermalConductivity(OpenStudio.convert(data['conductivity'].to_f, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      material.setDirtCorrectionFactorforSolarandVisibleTransmittance(data['dirt_correction_factor_for_solar_and_visible_transmittance'].to_f)
      if /true/i =~ data['solar_diffusing'].to_s
        material.setSolarDiffusing(true)
      else
        material.setSolarDiffusing(false)
      end

    else
      puts("ERROR  Unknown material type #{material_type}, cannot add material called #{material_name}.")
      exit
    end

    return material
  end

  # Create a construction from the openstudio standards dataset.
  # If construction_props are specified, modifies the insulation layer accordingly.
  def model_add_construction(std, model, construction_name, construction_props = nil, climate_zone = nil)
    # Get the object data
    data = std.model_find_object(std.standards_data['constructions'], 'name' => construction_name)
    unless data
      puts("WARNING Cannot find data for construction: #{construction_name}, will not be created.")
      return OpenStudio::Model::OptionalConstruction.new
    end

    # Create a new SPEED name for the contruction
    if construction_props
      # puts "INFO Making construction for #{construction_props['standards_construction_type']}-#{construction_props['intended_surface_type']}-#{climate_zone}"
      speed_const_type = speed_enum(construction_props['standards_construction_type'], 'gui')
      speed_surf_type = speed_enum(construction_props['intended_surface_type'], 'gui')
      speed_climate_zone = speed_enum(climate_zone, 'gui')
      construction_name = "#{speed_const_type} #{speed_surf_type} #{speed_climate_zone}"

      # Get contruction properties used in name
      target_u_value_ip = construction_props['assembly_maximum_u_value']
      target_f_factor_ip = construction_props['assembly_maximum_f_factor']
      target_c_factor_ip = construction_props['assembly_maximum_c_factor']
      target_shgc = construction_props['assembly_maximum_solar_heat_gain_coefficient'].to_f

      # If the minimum VT to SHGC ratio is included in the construction properties,
      # set the VT using this ratio.
      # If it is not specified by the standard, for SPEED,
      # always set the ratio of VT / SHGC = 1.1
      # This is done to avoid allowing E+ to infer VT,
      # which results in very low VTs that are only found in windows
      # with reflective metal films.  These window types are not
      # representative of typical design practice.
      target_vt = nil
      if construction_props['intended_surface_type'] == 'ExteriorWindow'
        if construction_props['assembly_minimum_vt_shgc']
          target_vt = target_shgc * construction_props['assembly_minimum_vt_shgc'].to_f
        else
          target_vt = target_shgc * 1.1
        end
      end

      # SPEED uses R-values for all contructions, as opposed to using the F-Factor or C-Factor
      # constructions in EnergyPlus.  However, standards requirements are specified as F-Factor and C-Factor.
      # Convert these to U-Value using regression equations.
      if target_u_value_ip.nil? && target_f_factor_ip
        target_u_value_ip = infer_slab_u_value_from_f_factor(target_f_factor_ip)
      elsif target_u_value_ip.nil? && target_c_factor_ip
        target_u_value_ip = infer_slab_u_value_from_c_factor(target_c_factor_ip)
      end

      # Convert U-Value to R-Value for naming
      target_r_value_ip = 1.0 / target_u_value_ip.to_f

      # Construction names differ between windows and opaque constructions
      if construction_props['intended_surface_type'] == 'ExteriorWindow'
        construction_name = "#{speed_const_type} #{speed_climate_zone}" # Leave ExteriorWindow out of the name
        if target_vt
          construction_name = "#{construction_name} U-#{target_u_value_ip.to_f.round(2)} SHGC-#{target_shgc.round(2)} VT-#{target_vt.round(2)}"
        else
          construction_name = "#{construction_name} U-#{target_u_value_ip.to_f.round(2)} SHGC-#{target_shgc.round(2)}"
        end
      elsif target_u_value_ip
        construction_name = "#{construction_name} R-#{target_r_value_ip.round(0)}"
      end
    end

    # Check model and return construction if it already exists
    existing_constructions = model.getConstructions.sort
    existing_constructions.each do |existing_construction|
      if existing_construction.name.get.to_s == construction_name
        # puts("INFO Reusing #{construction_name}, already in model")
        return existing_construction
      end
    end

    # Make a new construction and set the standards details
    construction = OpenStudio::Model::Construction.new(model)
    construction.setName(construction_name)
    standards_info = construction.standardsInformation

    intended_surface_type = data['intended_surface_type']
    intended_surface_type ||= ''
    standards_info.setIntendedSurfaceType(intended_surface_type)

    standards_construction_type = data['standards_construction_type']
    standards_construction_type ||= ''
    standards_info.setStandardsConstructionType(standards_construction_type)

    # Add the material layers to the construction
    layers = OpenStudio::Model::MaterialVector.new
    if construction_props && construction_props['intended_surface_type'] == 'ExteriorWindow' && construction_props['convert_to_simple_glazing'] == 'yes'
      # For SPEED, instead of using specified detailed glazing layers, sometimes use a SimpleGlazing material
      material = OpenStudio::Model::SimpleGlazing.new(model)
      material.setName('Simple Glazing')
      layers << material
    else
      data['materials'].each do |material_name|
        material = model_add_material(std, model, material_name)
        if material
          layers << material
        end
      end
    end
    construction.setLayers(layers)

    # Modify the R value of the insulation to hit the specified U-value, C-Factor, or F-Factor.
    if construction_props
      u_includes_int_film = construction_props['u_value_includes_interior_film_coefficient']
      u_includes_ext_film = construction_props['u_value_includes_exterior_film_coefficient']

      if target_u_value_ip
        # Handle Opaque and Fenestration Constructions differently
        if construction.isFenestration && construction_simple_glazing?(construction)
          # Set the U-Value, SHGC, and VT
          construction_set_glazing_u_value(construction, target_u_value_ip.to_f, data['intended_surface_type'], u_includes_int_film, u_includes_ext_film)
          construction_set_glazing_shgc(construction, target_shgc.to_f)
          if target_vt
            construction_set_glazing_visible_transmittance(construction, target_vt)
          end
        else
          # Set the U-Value
          construction_set_u_value(construction, target_u_value_ip.to_f, data['insulation_layer'], data['intended_surface_type'], u_includes_int_film, u_includes_ext_film)
        end
      end

      # If the construction is fenestration,
      # also set the frame type for use in future lookups
      if construction.isFenestration
        case standards_construction_type
        when 'Metal framing (all other)'
          standards_info.setFenestrationFrameType('Metal Framing')
        when 'Nonmetal framing (all)'
          standards_info.setFenestrationFrameType('Non-Metal Framing')
        end
      end
    end

    # puts("INFO Added construction #{construction.name}.")

    return construction
  end

  # Sets the U-value of a construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
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
    # puts("DEBUG Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    if construction.isFenestration
      puts("WARNING Can only set the u-value of opaque constructions or simple glazing. #{construction.name} is not opaque or simple glazing.")
      return false
    end

    # Make sure an insulation layer was specified
    if insulation_layer_name.nil? && target_u_value_ip == 0.0
      # Do nothing if the construction already doesn't have an insulation layer
    elsif insulation_layer_name.nil?
      insulation_layer_name = self.find_and_set_insulaton_layer(construction).name
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
      puts("WARNING Requested U-value of #{target_u_value_ip.round(3)} for #{construction.name} is greater than the sum of the inside and outside resistance, and the max U-value (6.636 SI) is used instead.")
    end

    # Convert the target U-value to SI
    target_u_value_ip = target_u_value_ip.to_f
    target_r_value_ip = 1.0 / target_u_value_ip

    target_u_value_si = OpenStudio.convert(target_u_value_ip, 'Btu/ft^2*hr*R', 'W/m^2*K').get
    target_r_value_si = 1.0 / target_u_value_si

    # puts("DEBUG #{construction.name}.")
    # puts("DEBUG ---target_u_value_ip = #{target_u_value_ip.round(3)} for #{construction.name}.")
    # puts("DEBUG ---target_r_value_ip = #{target_r_value_ip.round(2)} for #{construction.name}.")
    # puts("DEBUG ---target_u_value_si = #{target_u_value_si.round(3)} for #{construction.name}.")
    # puts("DEBUG ---target_r_value_si = #{target_r_value_si.round(2)} for #{construction.name}.")

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
    if ins_r_value_si <= 0.0
      puts("WARNING Requested U-value of #{target_u_value_ip.round(3)} for #{construction.name} is too low given the R-values of the other materials in the construction; insulation layer will be set to R-0.01")
      ins_r_value_si = OpenStudio.convert(0.01, 'ft^2*h*R/Btu', 'm^2*K/W').get
    end
    ins_r_value_ip = OpenStudio.convert(ins_r_value_si, 'm^2*K/W', 'ft^2*h*R/Btu').get

    # Set the R-value of the insulation layer
    construction.layers.each do |layer|
      next unless layer.name.get == insulation_layer_name
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

    return true
  end

  # Sets the U-value of a simple glazing construction to a specified value.
  # The U-value input for SimpleGlazing constructions in EnergyPlus includes
  # the U-values of the inside and outside air films.
  # https://bigladdersoftware.com/epx/docs/9-2/input-output-reference/group-surface-construction-elements.html#field-u-factor
  # If the specified U-value already includes these air films (as NFRC values specified in 90.1 do, for example),
  # then this U-value will be input directly. If the specified U-value does not already include
  # air films, then surface-type-appropriate air film U-values will be added to the target before being input.
  #
  # @param target_u_value_ip [Double] U-Value (Btu/ft^2*hr*R)
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param target_includes_int_film_coefficients [Bool] if true, then no air film value will be added.  If false, then
  #   an air film value from 90.1-2010 A9.4.1 Air Films will be added to the U-value being input to EnergyPlus.
  # @param target_includes_ext_film_coefficients [Bool] if true, then no air film value will be added.  If false, then
  #   an air film value from 90.1-2010 A9.4.1 Air Films will be added to the U-value being input to EnergyPlus.
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_u_value(construction, target_u_value_ip, intended_surface_type = 'ExteriorWall', target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
    # puts("DEBUG Setting U-Value for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
      puts("WARNING Can only set the u-value of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    glass_layer = construction.layers.first.to_SimpleGlazing.get
    # puts("DEBUG ---glass_layer = #{glass_layer.name} u_factor_si = #{glass_layer.uFactor.round(2)}.")

    # Convert the target U-value to SI
    target_u_value_ip = target_u_value_ip.to_f
    target_r_value_ip = 1.0 / target_u_value_ip

    target_u_value_si = OpenStudio.convert(target_u_value_ip, 'Btu/ft^2*hr*R', 'W/m^2*K').get
    target_r_value_si = 1.0 / target_u_value_si

    # puts("DEBUG #{construction.name}.")
    # puts("DEBUG ---target_u_value_ip = #{target_u_value_ip.round(3)} for #{construction.name}.")
    # puts("DEBUG ---target_r_value_ip = #{target_r_value_ip.round(2)} for #{construction.name}.")
    # puts("DEBUG ---target_u_value_si = #{target_u_value_si.round(3)} for #{construction.name}.")
    # puts("DEBUG ---target_r_value_si = #{target_r_value_si.round(2)} for #{construction.name}.")

    # Determine the R-value of the air films, if requested
    film_coeff_r_value_si = 0.0
    film_coeff_r_value_si += film_coefficients_r_value(intended_surface_type, !target_includes_int_film_coefficients, !target_includes_ext_film_coefficients)
    film_coeff_u_value_si = 1.0 / film_coeff_r_value_si
    film_coeff_u_value_ip = OpenStudio.convert(film_coeff_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    film_coeff_r_value_ip = 1.0 / film_coeff_u_value_ip

    # puts("DEBUG ---film_coeff_r_value_si = #{film_coeff_r_value_si.round(2)} for #{construction.name}.")
    # puts("DEBUG ---film_coeff_u_value_si = #{film_coeff_u_value_si.round(2)} for #{construction.name}.")
    # puts("DEBUG ---film_coeff_u_value_ip = #{film_coeff_u_value_ip.round(2)} for #{construction.name}.")
    # puts("DEBUG ---film_coeff_r_value_ip = #{film_coeff_r_value_ip.round(2)} for #{construction.name}.")

    # Determine the difference between the desired R-value
    # and the R-value of the and air films.
    # This is the desired R-value of the insulation.
    ins_r_value_si = target_r_value_si - film_coeff_r_value_si
    if ins_r_value_si <= 0.0
      puts("WARNING Requested U-value of #{target_u_value_ip.round(3)} Btu/ft^2*hr*R for #{construction.name} is too high given the film coefficients of U-#{film_coeff_u_value_ip.round(2)} Btu/ft^2*hr*R; U-value will not be modified.")
      return false
    end
    ins_u_value_si = 1.0 / ins_r_value_si

    # Per the E+ documentation: https://bigladdersoftware.com/epx/docs/9-2/input-output-reference/group-surface-construction-elements.html#field-u-factor
    # "Although the maximum allowable input is U-7.0 W/m^2*K, the effective upper limit of the glazings generated by the underlying model is around U-5.8 W/m^2*K"
    if ins_u_value_si > 5.8
      puts("WARNING Requested U-value of #{target_u_value_ip.round(3)} for #{construction.name} is too high because film coefficients alone make most of this U-value; setting U-value to EnergyPlus limit of 1.021 Btu/ft^2*hr*R (5.8 W/m^2*K)")
      ins_u_value_si = 5.8
    end

    ins_u_value_ip = OpenStudio.convert(ins_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    ins_r_value_ip = 1.0 / ins_u_value_ip

    # Set the U-value of the insulation layer
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setUFactor(ins_u_value_si)
    glass_layer.setName("#{glass_layer.name} U-#{ins_u_value_ip.round(4)}")

    # puts("DEBUG ---ins_r_value_ip = #{ins_r_value_ip.round(2)} for #{construction.name}.")
    # puts("DEBUG ---ins_u_value_ip = #{ins_u_value_ip.round(2)} for #{construction.name}.")
    # puts("DEBUG ---ins_u_value_si = #{ins_u_value_si.round(2)} for #{construction.name}.")
    # puts("DEBUG ---glass_layer = #{glass_layer.name} u_factor_si = #{glass_layer.uFactor.round(2)}.")

    return true
  end

  # Sets the visible transmittance of a construction to a specified value.
  # Only works for simple glazing.
  #
  # @param target_vt [Double] Visible transmittance
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_visible_transmittance(construction, target_vt)
    # puts("DEBUG Setting visible transmittance for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
      puts("WARNING Can only set the visible transmittance of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setVisibleTransmittance(target_vt)

    return true
  end

  # Sets the U-value of a construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
  # @param target_shgc [Double] Solar Heat Gain Coefficient
  # @return [Bool] returns true if successful, false if not
  def construction_set_glazing_shgc(construction, target_shgc)
    # puts("DEBUG Setting SHGC for #{construction.name}.")

    # Skip layer-by-layer fenestration constructions
    unless construction_simple_glazing?(construction)
      puts("WARNING Can only set the SHGC of simple glazing. #{construction.name} is not simple glazing.")
      return false
    end

    # Set the SHGC
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setSolarHeatGainCoefficient(target_shgc)
    glass_layer.setName("#{glass_layer.name} SHGC-#{target_shgc.round(4)}")

    return true
  end

  # Determines if the construction is a simple glazing construction,
  # as indicated by having a single layer of type SimpleGlazing.
  # @return [Bool] returns true if it is a simple glazing, false if not.
  def construction_simple_glazing?(construction)
    # Not simple if more than 1 layer
    if construction.layers.length > 1
      return false
    end

    # Not simple unless the layer is a SimpleGlazing material
    if construction.layers.first.to_SimpleGlazing.empty?
      return false
    end

    # If here, must be simple glazing
    return true
  end

  # Infer the U-Value of a slab based on F-Factor.
  # For SPEED, always return R-3 IP, which should make
  # sense coupled with the chosen ground temperature approach.
  #
  # @param target_f_factor_ip [Double] F-Factor
  # @return [Double] the corresponding U-value
  def infer_slab_u_value_from_f_factor(target_f_factor_ip)
    r_value_ip = 3.0
    u_value_ip = 1.0 / r_value_ip

    # puts("INFO Inferred U-Value of #{u_value_ip.round(2)} for F-Factor #{target_f_factor_ip}")

    return u_value_ip
  end

  # Infer the U-Value of an underground wall based on C-Factor.
  # Uses a regression based on values from
  # 90.1-2004 Table A4.2 Assembly C-Factors for Below-Grade walls,
  # assumeing continuous exterior insulation.
  #
  # @param target_c_factor_ip [Double] C-Factor
  # @return [Double] the corresponding U-value
  def infer_slab_u_value_from_c_factor(target_c_factor_ip)
    # Regression from table A4.2 continuous exterior insulation
    r_value_ip = 0.775 * target_c_factor_ip**-1.067
    u_value_ip = 1.0 / r_value_ip

    # puts("INFO Inferred U-Value of #{u_value_ip.round(2)} for C-Factor #{target_c_factor_ip}")

    return u_value_ip
  end

  # Gives the total R-value of the interior and exterior (if applicable)
  # film coefficients for a particular type of surface.
  #
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param int_film [Bool] if true, interior film coefficient will be included in result
  # @param ext_film [Bool] if true, exterior film coefficient will be included in result
  # @return [Double] Returns the R-Value of the film coefficients [m^2*K/W]
  # @ref [References::ASHRAE9012010] A9.4.1 Air Films
  def film_coefficients_r_value(intended_surface_type, int_film, ext_film)
    # Return zero if both interior and exterior are false
    return 0.0 if !int_film && !ext_film

    # Film values from 90.1-2010 A9.4.1 Air Films
    film_ext_surf_r_ip = 0.17
    film_semi_ext_surf_r_ip = 0.46
    film_int_surf_ht_flow_up_r_ip = 0.61
    film_int_surf_ht_flow_dwn_r_ip = 0.92
    fil_int_surf_vertical_r_ip = 0.68

    film_ext_surf_r_si = OpenStudio.convert(film_ext_surf_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    film_semi_ext_surf_r_si = OpenStudio.convert(film_semi_ext_surf_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    film_int_surf_ht_flow_up_r_si = OpenStudio.convert(film_int_surf_ht_flow_up_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    film_int_surf_ht_flow_dwn_r_si = OpenStudio.convert(film_int_surf_ht_flow_dwn_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    fil_int_surf_vertical_r_si = OpenStudio.convert(fil_int_surf_vertical_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get

    film_r_si = 0.0
    case intended_surface_type
    when 'AtticFloor'
      film_r_si += film_int_surf_ht_flow_up_r_si if ext_film # Outside
      film_r_si += film_semi_ext_surf_r_si if int_film # Inside
    when 'AtticWall', 'AtticRoof'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += film_semi_ext_surf_r_si if int_film # Inside
    when 'DemisingFloor', 'InteriorFloor'
      film_r_si += film_int_surf_ht_flow_up_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
    when 'InteriorCeiling'
      film_r_si += film_int_surf_ht_flow_dwn_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
    when 'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor'
      film_r_si += fil_int_surf_vertical_r_si if ext_film # Outside
      film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
    when 'DemisingRoof', 'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
    when 'ExteriorFloor'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
    when 'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
    when 'GroundContactFloor'
      film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
    when 'GroundContactWall'
      film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
    when 'GroundContactRoof'
      film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
    end
    return film_r_si
  end

  # The path where the construction library .osm is saved
  def construction_lib_path
    return "#{__dir__}/construction_lib.osm"
  end

  # Takes all of the window constructions in the construction library
  # and makes a punched window for each in the long_rect.osm model.
  # Then, runs a sizing run, wherein EnergyPlus calculated the window
  # properties for all constructions.
  #
  # @param std [Standard] the standard (doesn't matter which one)
  # @param model [OpenStudio::Model::Model] the contruction library model
  def do_window_property_sizing_run(std, model)
    # Load the geometry model
    geom_model = std.safe_load_model("#{__dir__}/long_rect.osm")

    # Get a long wall surface
    wall = geom_model.getSurfaceByName('Face 3').get

    # Find the bottom leftmost corner
    bot_left_x = 999.9
    bot_left_y = 999.9
    bot_left_z = 999.9
    wall.vertices.each do |vertex|
      # puts "#{vertex.x}, #{vertex.y}, #{vertex.z}"
      bot_left_x = vertex.x if vertex.x < bot_left_x
      bot_left_y = vertex.y if vertex.y < bot_left_y
      bot_left_z = vertex.z if vertex.z < bot_left_z
    end

    # puts 'Bottom left corner of wall:'
    # puts "#{bot_left_x}, #{bot_left_y}, #{bot_left_z}"

    # Define new window dimensions
    sill_z = bot_left_z += 0.5
    head_z = bot_left_z += 1.0
    width = 0.1
    spacing = 0.2

    # Clone the detailed glazing constructions from the library model
    # and make a window on this wall for each one.
    i = 0
    model.getConstructions.each do |const|
      next unless const.isFenestration
      const_clone = const.clone(geom_model).to_Construction.get
      # puts "cloned:  #{const_clone.name}"

      # Define vertices for new window
      new_vertices = []
      new_vertices << OpenStudio::Point3d.new(bot_left_x + (i * spacing), bot_left_y, sill_z)
      new_vertices << OpenStudio::Point3d.new(bot_left_x + (i * spacing) + width, bot_left_y, sill_z)
      new_vertices << OpenStudio::Point3d.new(bot_left_x + (i * spacing) + width, bot_left_y, head_z)
      new_vertices << OpenStudio::Point3d.new(bot_left_x + (i * spacing), bot_left_y, head_z)
      # puts "Window #{i}"
      # new_vertices.each do |vertex|
        # puts "#{vertex.x}, #{vertex.y}, #{vertex.z}"
      # end

      # Create a new subsurface with the vertices determined above.
      new_sub_surface = OpenStudio::Model::SubSurface.new(new_vertices, geom_model)
      new_sub_surface.setSurface(wall)
      new_sub_surface.setName("Window #{i}")

      # Assign the construction to the surface
      new_sub_surface.setConstruction(const_clone)

      i += 1 # Don't use default ruby iterator b/c want to only iterate for window constructions
    end

    # Add design days and weather file
    std.model_add_design_days_and_weather_file(geom_model, 'ASHRAE 169-2013-5B', 'USA_CO_Denver-Aurora-Buckley.AFB.724695_TMY3.epw')

    # Save the model with the windows added
    # geom_model.save("#{Dir.pwd}/long_rect_with_windows.osm", true)

    # Do a sizing run
    if std.model_run_sizing_run(geom_model, "#{__dir__}/SizingRunWindows") == false
      puts "ERROR Failed window property sizing run"
      return false
    end

    return true
  end

  # Compares the window construction properties in the name with the E+ values
  #
  # @param std [Standard] the standard (doesn't matter which one)
  # @param model [OpenStudio::Model::Model] the contruction library model
  # @param tolerance [Double] the acceptable threshold above which differencs are reported. 5.0 = 5%
  def compare_window_construction_properties(std, model, tolerance)
    # model = std.safe_load_model("#{__dir__}/long_rect_with_windows.osm")

    # Set sql file
    sql_path = "#{__dir__}/SizingRunWindows/run/eplusout.sql"
    sql_file = OpenStudio::SqlFile.new(sql_path)
    model.setSqlFile(sql_file)

    # Compare window properties from name vs. E+ calculated
    model.getConstructions.sort.each do |const|
      next unless const.isFenestration

      # Determine the glazing type
      glazing_type = if std.construction_simple_glazing?(const)
                       'Simple'
                     else
                       'Layered'
                     end

      # Get the properties from the name
      name = const.name.get.to_s
      matches = name.match(/.*(U-\d*\.\d*).*(SHGC-\d*\.\d*).*(VT-\d*\.\d*)/)
      name_u_ip = matches[1].gsub('U-','').to_f
      name_shgc = matches[2].gsub('SHGC-','').to_f
      name_vt = matches[3].gsub('VT-','').to_f
      # puts name
      # puts ".... from name U = #{name_u_ip}"
      # puts ".... from name SHGC = #{name_shgc}"
      # puts ".... from name VT = #{name_vt}"

      # Get the properties from the E+ output
      eplus_u_si = std.construction_calculated_u_factor(const) # W/m2-K
      eplus_u_ip = OpenStudio.convert(eplus_u_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get.round(3)
      eplus_shgc = std.construction_calculated_solar_heat_gain_coefficient(const)
      eplus_vt = std.construction_calculated_visible_transmittance(const)
      # puts ".... from eplus U = #{eplus_u_ip}"
      # puts ".... from eplus SHGC = #{eplus_shgc}"
      # puts ".... from eplus VT = #{eplus_vt}"

      # Compare the properties
      u_pct_diff = (((name_u_ip - eplus_u_ip) / eplus_u_ip).abs * 100.0).round(1)
      if u_pct_diff > tolerance
        puts "ERROR For #{glazing_type} Glazing called #{name}, name U = #{name_u_ip}, eplus U = #{eplus_u_ip}, difference = #{u_pct_diff}%"
      end

      shgc_pct_diff = (((name_shgc - eplus_shgc) / eplus_shgc).abs * 100.0).round(1)
      if shgc_pct_diff > tolerance
        puts "ERROR For #{glazing_type} Glazing called #{name}, name SHGC = #{name_shgc}, eplus SHGC = #{eplus_shgc}, difference = #{shgc_pct_diff}%"
      end

      vt_diff = (((name_vt - eplus_vt) / eplus_vt).abs * 100.0).round(1)
      if vt_diff > tolerance
        puts "ERROR For #{glazing_type} Glazing called #{name}, name VT = #{name_vt}, eplus VT = #{eplus_vt}, difference = #{vt_diff}%"
      end
    end
  end

  # Update the window construction properties in the name and the SimpleGlazing with the E+ values
  #
  # @param std [Standard] the standard (doesn't matter which one)
  # @param model [OpenStudio::Model::Model] the contruction library model
  # @return [Hash] a has where the key is the original construction name and the value is the new name
  def update_window_construction_names_with_vt(std, model)
    # Set sql file
    sql_path = "#{__dir__}/SizingRunWindows/run/eplusout.sql"
    sql_file = OpenStudio::SqlFile.new(sql_path)
    model.setSqlFile(sql_file)

    # Pull the VT
    old_to_new_map = {}
    model.getConstructions.sort.each do |const|
      next unless const.isFenestration

      # Determine the glazing type
      unless std.construction_simple_glazing?(const)
        # puts "INFO Only modifying VT for SimpleGlazing, but #{const.name} is detailed"
        next
      end

      # Determine if the VT is already set in the construction
      glass_layer = const.layers.first.to_SimpleGlazing.get
      if glass_layer.visibleTransmittance.is_initialized
        # puts "INFO For construction #{const.name}, VT was already set, not modifying"
        next
      end

      # Get the VT from the output
      eplus_vt = std.construction_calculated_visible_transmittance(const)

      # Append the VT to the name
      old_name = const.name.get.to_s
      new_name = "#{old_name} VT-#{eplus_vt.round(2)}"
      const.setName(new_name)
      # puts "INFO For construction #{old_name} renamed to #{new_name}"
      old_to_new_map[old_name] = new_name

      # Modify the VT
      glass_layer.setVisibleTransmittance(eplus_vt)
    end

    # Close the sql file
    sql_file.close

    return old_to_new_map
  end

  # Checks the construction properties in the name vs. the sum of all the layers
  #
  # @param std [Standard] the standard (doesn't matter which one)
  # @param model [OpenStudio::Model::Model] the contruction library model
  # @param tolerance [Double] the acceptable threshold above which differencs are reported. 5.0 = 5%
  def compare_opaque_contruction_properties(std, model, tolerance)
    # Compare R-values from name vs. sum of layers
    model.getConstructions.sort.each do |const|
      next if const.isFenestration

      # Get the R-Value from the name
      name = const.name.get.to_s
      matches = name.match(/.*(R-\d*).*/)
      if matches.nil?
        puts "ERROR For #{name}, could not find properties in name of construction, cannot compare to model inputs."
        next
      end
      name_r_ip = matches[1].gsub('R-','').to_f
      # puts name
      # puts ".... from name R IP = #{name_r_ip}"

      # Get the layers R-Value from the model inputs
      layers_u_si = const.thermalConductance # (W/m^2*K, does not include film coefficients)
      if layers_u_si.empty?
        puts "ERROR Could not get thermalConductance for construction #{name}, cannot compare to name."
        next
      end
      layers_u_ip = OpenStudio.convert(layers_u_si.get, 'W/m^2*K', 'Btu/ft^2*hr*R').get
      layers_r_ip = (1.0 / layers_u_ip).round(3)

      # Get the film coefficients assumed by openstudio-standards, which should match E+ closely
      if const.standardsInformation.intendedSurfaceType.empty?
        puts "ERROR Could not get surface type for construction #{name}, cannot compare to name."
        next
      end
      film_r_si = std.film_coefficients_r_value(const.standardsInformation.intendedSurfaceType.get, true, true)
      film_u_si = 1.0 / film_r_si
      film_u_ip = OpenStudio.convert(film_u_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
      film_r_ip = (1.0 / film_u_ip).round(3)

      # Add model + film coefficients
      model_r_ip = (layers_r_ip + film_r_ip).round(3)
      # puts ".... from model input total R IP = #{model_r_ip} = layers #{layers_r_ip} + #{film_r_ip} film"

      # Compare the properties
      r_pct_diff = (((name_r_ip - model_r_ip) / model_r_ip).abs * 100.0).round(1)
      if r_pct_diff > tolerance
        puts "ERROR For opaque construction called #{name}, name R IP = #{name_r_ip}, model input R IP = #{model_r_ip} = layers #{layers_r_ip} + #{film_r_ip} film, difference = #{r_pct_diff}%"
      end
    end
  end
end
