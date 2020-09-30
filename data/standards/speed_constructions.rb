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
      'GroundContactFloor' => {'key' => 'Foundation', 'method' => 'Slab', 'gui' => 'Insulated Slab'},
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
      'Unheated' => {'key' => 'Slab_Type', 'gui' => 'Insulated Slab'},
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
      puts "INFO Making construction for #{construction_props['standards_construction_type']}-#{construction_props['intended_surface_type']}-#{climate_zone}"
      speed_const_type = speed_enum(construction_props['standards_construction_type'], 'gui')
      speed_surf_type = speed_enum(construction_props['intended_surface_type'], 'gui')
      speed_climate_zone = speed_enum(climate_zone, 'gui')
      construction_name = "#{speed_const_type} #{speed_surf_type} #{speed_climate_zone}"

      # Get contruction properties used in name
      target_u_value_ip = construction_props['assembly_maximum_u_value']
      target_f_factor_ip = construction_props['assembly_maximum_f_factor']
      target_c_factor_ip = construction_props['assembly_maximum_c_factor']
      target_shgc = construction_props['assembly_maximum_solar_heat_gain_coefficient'].to_f

      # SPEED includes VT in the construction name, but this property is not directly
      # available from detailed glazing assemblies.
      # Estimate VT / SHGC = 1.1, therefore VT = SHGC * 1.1
      if construction_props['intended_surface_type'] == 'ExteriorWindow'
        target_vt = target_shgc * 1.1
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
        construction_name = "#{construction_name} U-#{target_u_value_ip.to_f.round(2)} SHGC-#{target_shgc.round(2)} VT-#{target_vt.round(2)}"
      elsif target_u_value_ip
        construction_name = "#{construction_name} R-#{target_r_value_ip.round(0)}"
      end
    end

    # Check model and return construction if it already exists
    existing_constructions = model.getConstructions.sort
    existing_constructions.each do |existing_construction|
      if existing_construction.name.get.to_s == construction_name
        puts("INFO Reusing #{construction_name}, already in model")
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
          construction_set_glazing_visible_transmittance(construction, target_vt)
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

    puts("INFO Added construction #{construction.name}.")

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
      puts("WARNING Requested U-value of #{target_u_value_ip} for #{construction.name} is greater than the sum of the inside and outside resistance, and the max U-value (6.636 SI) is used instead.")
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
      puts("WARNING Requested U-value of #{target_u_value_ip} for #{construction.name} is too low given the other materials in the construction; insulation layer will not be modified.")
      return true
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

  # Sets the U-value of a construction to a specified value
  # by modifying the thickness of the insulation layer.
  #
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
    film_coeff_r_value_si += film_coefficients_r_value(intended_surface_type, target_includes_int_film_coefficients, target_includes_ext_film_coefficients)
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
      puts("WARNING Requested U-value of #{target_u_value_ip} Btu/ft^2*hr*R for #{construction.name} is too high given the film coefficients of U-#{film_coeff_u_value_ip.round(2)} Btu/ft^2*hr*R; U-value will not be modified.")
      return false
    end
    ins_u_value_si = 1.0 / ins_r_value_si
    
    if ins_u_value_si > 7.0
      puts("WARNING Requested U-value of #{target_u_value_ip} for #{construction.name} is too high given the film coefficients of U-#{film_coeff_u_value_ip.round(2)}; setting U-value to EnergyPlus limit of 7.0 W/m^2*K (1.23 Btu/ft^2*hr*R).")
      ins_u_value_si = 7.0
    end
    
    ins_u_value_ip = OpenStudio.convert(ins_u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    ins_r_value_ip = 1.0 / ins_u_value_ip

    # Set the U-value of the insulation layer
    glass_layer = construction.layers.first.to_SimpleGlazing.get
    glass_layer.setUFactor(ins_u_value_si)
    glass_layer.setName("#{glass_layer.name} U-#{ins_u_value_ip.round(2)}")
    
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
    glass_layer.setName("#{glass_layer.name} SHGC-#{target_shgc.round(2)}")

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
  # Uses a regression based on the values from
  # 90.1-2004 Table A6.3 Assembly F-Factors for Slab-on-Grade Floors,
  # assuming an unheated, fully insulated slab.
  #
  # @param target_f_factor_ip [Double] F-Factor
  # @return [Double] the corresponding U-value
  def infer_slab_u_value_from_f_factor(target_f_factor_ip)
    # Regression from table A6.3 unheated, fully insulated slab
    r_value_ip = 1.0248 * target_f_factor_ip**-2.186
    u_value_ip = 1.0 / r_value_ip

    puts("INFO Inferred U-Value of #{u_value_ip.round(2)} for F-Factor #{target_f_factor_ip}")

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

    puts("INFO Inferred U-Value of #{u_value_ip.round(2)} for C-Factor #{target_c_factor_ip}")

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
end
