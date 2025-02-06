class String
  def underscore
    self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr("-", "_").
        downcase
  end
end

class BTAPCosting

  def validate_constructions_sets()
    construction_sets = @costing_database['raw']['construction_sets']
    failed = false
    templates = ["NECB2011", "NECB2015", "NECB2017", "NECB2020", "BTAPPRE1980", "BTAP1980TO2010"]
    bad_records = {}
    bad_records[:invalid_space_type_names] = []
    bad_records[:min_max_floor_range_errors] = []
    #  CHECK if spacetype names are valid in costing database
    valid_space_types = []
    templates.each do |template|
      valid_space_types += Standard.build(template.gsub(/\s+/, "")).get_all_spacetype_names.map { |spacetype| (template + '-' + spacetype[0].to_s + '-' + spacetype[1].to_s).strip }
    end
    # construction_sets

    construction_sets.each do |row|
      target_space_type = "#{row['template'].gsub(/\s+/, "") + '-' + row['building_type']}-#{row['space_type']}".strip
      unless valid_space_types.include?(target_space_type.to_s)
        bad_records[:invalid_space_type_names] << {template: row['template'].gsub(/\s+/, ""), space_type: target_space_type}
      end
    end


    # Check if # of floors contains 1 to 999
    #Get Unique spacetypes.
    bad_evelope_story_ranges = []
    space_types = construction_sets.map { |row| {template: row["template"], building_type: row["building_type"], space_type: row["space_type"]} }.uniq
    space_types.each do |space_type|
      range = Array.new
      instances = construction_sets.select { |row| row['template'] == space_type[:template] && row['building_type'] == space_type[:building_type] && row['space_type'] == space_type[:space_type] }
      instances.each do |instance|
        min_val = instance['min_stories'].to_i
        min_val = 0 if min_val == 1
        max_val = instance['max_stories'].to_i
        range << min_val
        range << max_val
        failed = true
      end
      range.sort!
      incomplete_range = (range.first != 0 or range.last < 999)
      possible_duplicate = (range.uniq.size != range.size)
      if incomplete_range or possible_duplicate
        space_type[:range] = range
        space_type[:error] = {incomplete_range: incomplete_range, possible_duplicate: possible_duplicate}
        bad_records[:min_max_floor_range_errors] << space_type
      end
    end
    if bad_records[:min_max_floor_range_errors].size > 0 or bad_records[:invalid_space_type_names].size > 0
      puts "Errors in ConstructionSets Costing Table."
      puts JSON.pretty_generate(bad_records)
      raise("costing spreadsheet validation failed")
    end
  end


  def cost_audit_envelope(model, prototype_creator)
    # These are the only envelope costing items we are considering for envelopes..
    costed_surfaces = [
        "ExteriorWall",
        "ExteriorRoof",
        "ExteriorFloor",
        "ExteriorFixedWindow",
        "ExteriorOperableWindow",
        "ExteriorSkylight",
        "ExteriorTubularDaylightDiffuser",
        "ExteriorTubularDaylightDome",
        "ExteriorDoor",
        "ExteriorGlassDoor",
        "ExteriorOverheadDoor",
        "GroundContactWall",
        "GroundContactRoof",
        "GroundContactFloor"
    ]
    costed_surfaces.each do |surface_type|
      @costing_report["envelope"]["#{surface_type.underscore}_cost"] = 0.00
      @costing_report["envelope"]["#{surface_type.underscore}_area_m2"] = 0.0
      @costing_report["envelope"]["#{surface_type.underscore}_cost_per_m2"] = 0.00
    end

    @costing_report["envelope"]["construction_costs"] = []

    # Store number of stories. Required for envelope costing logic.
    num_of_above_ground_stories = model.getBuilding.standardsNumberOfAboveGroundStories.to_i

    template_type = prototype_creator.template

    closest_loc = get_closest_cost_location(model.getWeatherFile.latitude, model.getWeatherFile.longitude)
    generate_construction_cost_database_for_city(@costing_report["city"], @costing_report["province_state"])

    totEnvCost = 0

    # Iterate through the thermal zones.
    model.getThermalZones.sort.each do |zone|
      # Iterate through spaces.
      zone.spaces.sort.each do |space|
        # Get SpaceType defined for space.. if not defined it will skip the spacetype. May have to deal with Attic spaces.
        if space.spaceType.empty? or space.spaceType.get.standardsSpaceType.empty? or space.spaceType.get.standardsBuildingType.empty?
          raise ("standards Space type and building type is not defined for space:#{space.name.get}. Skipping this space for costing.")
        end

        # Get space type standard names.
        space_type = space.spaceType.get.standardsSpaceType
        building_type = space.spaceType.get.standardsBuildingType

        # Get standard constructions based on collected information (spacetype, no of stories, etc..)
        # This is a standard way to search a hash.
        construction_set = @costing_database['raw']['construction_sets'].select { |data|
          data['template'].to_s.gsub(/\s*/, '') == template_type and
              data['building_type'].to_s.downcase == building_type.to_s.downcase and
              data['space_type'].to_s.downcase == space_type.to_s.downcase and
              data['min_stories'].to_i <= num_of_above_ground_stories and
              data['max_stories'].to_i >= num_of_above_ground_stories
        }.first


        # Create Hash to store surfaces for this space by surface type
        surfaces = {}
        #Exterior
        exterior_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Outdoors")
        surfaces["ExteriorWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Wall")
        surfaces["ExteriorRoof"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "RoofCeiling")
        surfaces["ExteriorFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Floor")
        # Exterior Subsurface
        exterior_subsurfaces = exterior_surfaces.flat_map(&:subSurfaces)
        surfaces["ExteriorFixedWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["FixedWindow"])
        surfaces["ExteriorOperableWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OperableWindow"])
        surfaces["ExteriorSkylight"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Skylight"])
        surfaces["ExteriorTubularDaylightDiffuser"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDiffuser"])
        surfaces["ExteriorTubularDaylightDome"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDome"])
        surfaces["ExteriorDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Door"])
        surfaces["ExteriorGlassDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["GlassDoor"])
        surfaces["ExteriorOverheadDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OverheadDoor"])

        # Ground Surfaces
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Ground")
        ground_surfaces += BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Foundation")
        surfaces["GroundContactWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
        surfaces["GroundContactRoof"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
        surfaces["GroundContactFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")


        # Iterate through
        costed_surfaces.each do |surface_type|
          # Get Costs for this construction type. This will get the cost for the particular construction type
          # for all rsi levels for this location. This has been collected by the API costs data. Note that a space_type
          # of "- undefined -" will create a nil construction_set!


          if construction_set.nil?
            cost_range_hash = {}
          else
            cost_range_hash = @costing_database['constructions_costs'].select { |construction|
              construction['construction_type_name'] == construction_set[surface_type] &&
                  construction['province_state'] == @costing_report["province_state"] &&
                  construction['city'] == @costing_report["city"]
            }
          end

          # We don't need all the information, just the rsi and cost. However, for windows rsi = 1/u_w_per_m2_k
          surfaceIsGlazing = (surface_type == 'ExteriorFixedWindow' || surface_type == 'ExteriorOperableWindow' ||
              surface_type == 'ExteriorSkylight' || surface_type == 'ExteriorTubularDaylightDiffuser' ||
              surface_type == 'ExteriorTubularDaylightDome' || surface_type == 'ExteriorGlassDoor')
          if surfaceIsGlazing
            cost_range_array = cost_range_hash.map { |cost|
              [
                  (1.0 / cost['u_w_per_m2_k'].to_f),
                  cost['total_cost_with_op']
              ]
            }
          else
            cost_range_array = cost_range_hash.map { |cost|
              [
                  cost['rsi_k_m2_per_w'],
                  cost['total_cost_with_op']
              ]
            }
          end
          # Sorted based on rsi.
          cost_range_array.sort! { |a, b| a[0] <=> b[0] }

          # Iterate through actual surfaces in the model of surface_type.
          numSurfType = 0
          surfaces[surface_type].sort.each do |surface|
            numSurfType = numSurfType + 1

            # Get RSI of existing model surface (actually returns rsi for glazings too!).
            # Make an array of constructions to use with surfaces_get_conductance method which replaces the get_rsi
            # method
            rsi = 1 / (OpenstudioStandards::Constructions.construction_get_conductance(OpenStudio::Model::getConstructionByName(surface.model, surface.construction.get.name.to_s).get))


            #Check to see if it is in range


            # Use the cost_range_array to interpolate the estimated cost for the given rsi.
            # Note that window costs in the API data use U-value, which was converted to rsi for cost_range_array above
            exterpolate_percentage_range = 30.0
            cost = interpolate(x_y_array: cost_range_array, x2: rsi, exterpolate_percentage_range: exterpolate_percentage_range)


            # If the cost is nil, that means the rsi is out of range. Flag in the report.
            if cost.nil?
              if !cost_range_array.empty?
                notes = "Warning! RSI out of the range (#{'%.2f' % rsi}) or cost is 0!. Range for #{construction_set[surface_type]} is #{'%.2f' % cost_range_array.first[0]}-#{'%.2f' % cost_range_array.last[0]}."
                cost = 0.0
              else
                notes = "No cost found for this! So Cost is set to 0.0!"
                cost = 0.0
              end
            elsif cost.nan?
              raise("the values for cost and conductance for #{construction_set[surface_type]} cannot be interpolated...cannot create an equation of a line from #{cost_range_array.sort.uniq}. Check construction database and either eliminate the errant row, or set the x value to an appropriate number. ")
            else
              #Tell user if we are extrapolating outside of library.
              array = cost_range_array.sort { |a, b| a[0] <=> b[0] }
              if rsi < (array.first[0].to_f) || rsi > (array.last[0].to_f)
                notes = "RSI out of the range (#{'%.2f' % rsi}). Range for #{construction_set[surface_type]} is #{'%.2f' % cost_range_array.first[0]}-#{'%.2f' % cost_range_array.last[0]}.Using extrapolation up to +/-30% of library boundaries. "
              else
                notes = "OK"
              end
            end

            # Calculate SHGC/film cost
            film_cost = 0.0
            if surfaceIsGlazing
              #Get SHGC from surface.
              shgc = OpenstudioStandards::Constructions.construction_get_solar_transmittance(surface.construction.get.to_Construction.get)
              # Get the closest value in materials_glazing sheet of SolarFilms.
              material_row = @costing_database["raw"]["materials_glazing"].select{ |row| row['material_type'] == 'Solarfilms' }.min_by {|row| (shgc.to_f - row['solar_heat_gain_coefficient'].to_f).abs}
              standard_film_cost = getCost(material_row['description'], material_row, 1.0)
              regional_factors = get_regional_cost_factors(@costing_report['province_state'], @costing_report['city'], material_row)
              # mult regional cost and sum costs. Zip adds the arrays together, map multiplies each row and divides by 100.0 since the regional factor is in percents.
              film_cost = standard_film_cost.zip(regional_factors).map{|cost,region_factor| cost * region_factor / 100.0}.inject(0, :+)
            end


            testSurfName = surface.name.to_s
            testSpaceName = space.name.to_s
            surfArea = surface.netArea * zone.multiplier
            surfAreaft = (OpenStudio.convert(surfArea, "m^2", "ft^2").get).to_f
            surfCost = (cost + film_cost) * surfAreaft
            totEnvCost = totEnvCost + surfCost
            name = ""

            # Bin the costing by construction standard type and rsi
            if construction_set.nil?
              name = "undefined space type_#{(1.0 / rsi).round(3)}"
            else
              name = "#{construction_set[surface_type]}"
            end
            row = @costing_report["envelope"]["construction_costs"].detect { |row| (row['name'] == name) && (row['conductance'].round(3) == ((1.0 / rsi).round(3))) }
            if row.nil?
              @costing_report["envelope"]["construction_costs"] << {'name' => name, 'conductance' => ((1.0 / rsi).round(3)), 'area' => (surfArea.round(2)), 'cost' => (surfCost.round(2)), 'cost_per_area' => (surfCost / surfArea).round(2), 'note' => "Surf ##{numSurfType}: #{notes}"}
            else
              # Not using += for @costing_report additions so that output can be properly rounded
              row['area'] = (row['area'] + surfArea).round(2)
              row['cost'] = (row['cost'] + surfCost).round(2)
              row['cost_per_area'] = ((row['cost'] / row['area']).to_f.round(2))
              row['note'] += " / #{numSurfType}: #{notes}"
            end
            # Not using += for @costing_report additions so that output can be properly rounded
            @costing_report["envelope"]["#{surface_type.underscore}_cost"] = (@costing_report["envelope"]["#{surface_type.underscore}_cost"] + surfCost).round(2)
            @costing_report["envelope"]["#{surface_type.underscore}_area_m2"] = (@costing_report["envelope"]["#{surface_type.underscore}_area_m2"] + surfArea).round(2)
            @costing_report["envelope"]["#{surface_type.underscore}_cost_per_m2"] = (@costing_report["envelope"]["#{surface_type.underscore}_cost"] / @costing_report["envelope"]["#{surface_type.underscore}_area_m2"]).round(2)
          end # surfaces of surface type
        end # surface_type
      end # spaces
    end # thermalzone

    @costing_report["envelope"]['total_envelope_cost'] = totEnvCost.to_f.round(2)
    puts "\nEnvelope costing data successfully generated. Total envelope cost is $#{totEnvCost.to_f.round(2)}"

    return totEnvCost
  end

  def cost_construction(construction, location, type = 'opaque')

    material_layers = "material_#{type}_id_layers"
    material_id = "materials_#{type}_id"
    materials_database = @costing_database["raw"]["materials_#{type}"]

    total_with_op = 0.0
    material_cost_pairs = []
    construction[material_layers].split(',').reject { |c| c.empty? }.each do |material_index|
      material = materials_database.find { |data| data[material_id].to_s == material_index.to_s }
      if material.nil?
        puts "material error..could not find material #{material_index} in #{materials_database}"
        raise()
      else
        costing_data = @costing_database['costs'].detect { |data| data['id'].to_s.upcase == material['id'].to_s.upcase }
        if costing_data.nil?
          puts "This material id #{material['id']} was not found in the costing database. Skipping. This construction will be inaccurate. "
          raise()
        else
          regional_material, regional_installation = get_regional_cost_factors(location['province_state'], location['city'], material)

          # Get cost information from lookup.
          # Note that "glazing" types don't have a 'quantity' hash entry!
          # Don't need "and" below but using in-case this hash field is added in the future.
          if type == 'glazing' and material['quantity'].to_f == 0.0
            material['quantity'] = '1.0'
          end
          material_cost = costing_data['baseCosts']['materialOpCost'].to_f * material['material_mult'].to_f
          labour_cost = costing_data['baseCosts']['laborOpCost'].to_f * material['labour_mult'].to_f
          equipment_cost = costing_data['baseCosts']['equipmentOpCost'].to_f
          layer_cost = (((material_cost * regional_material / 100.0) + (labour_cost * regional_installation / 100.0) + equipment_cost) * material['quantity'].to_f).round(2)
          material_cost_pairs << {material_id.to_s => material_index,
                                  'cost' => layer_cost}
          total_with_op += layer_cost
        end
      end
    end
    new_construction = {
        'province_state' => location['province_state'],
        'city' => location['city'],
        "construction_type_name" => construction["construction_type_name"],
        'description' => construction["description"],
        'intended_surface_type' => construction["intended_surface_type"],
        'standards_construction_type' => construction["standards_construction_type"],
        'rsi_k_m2_per_w' => construction['rsi_k_m2_per_w'].to_f,
        'zone' => construction['climate_zone'],
        'fenestration_type' => construction['fenestration_type'],
        'u_w_per_m2_k' => construction['u_w_per_m2_k'],
        'materials' => material_cost_pairs,
        'total_cost_with_op' => total_with_op}

    @costing_database['constructions_costs'] << new_construction
  end
end
