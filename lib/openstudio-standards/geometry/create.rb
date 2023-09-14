# Methods to create geometry
module OpenstudioStandards
  module Geometry
    # @!group Create

    # Building Form Defaults from Table 4.2 in Achieving the 30% Goal: Energy and Cost Savings Analysis of ASHRAE Standard 90.1-2010
    # aspect ratio for NA replaced with floor area to perimeter ratio from prototype model
    # currently no reason to split apart doe and deer inputs here
    #
    # @param building_type [String] standard building type
    # @return [Hash] Hash of aspect_ratio, wwr, typical_story, and perim_mult
    def self.building_form_defaults(building_type)
      hash = {}

      # DOE Prototypes

      # calculate aspect ratios not represented on Table 4.2
      primary_footprint = 73958.0
      primary_p = 619.0 # wrote measure using calculate_perimeter method in os_lib_geometry
      primary_ns_ew_ratio = 2.829268293 # estimated from ratio of ns/ew total wall area
      primary_width = Math.sqrt(primary_footprint / primary_ns_ew_ratio)
      primary_p_min = 2 * (primary_width + primary_width / primary_footprint)
      primary_p_mult = primary_p / primary_p_min

      secondary_footprint = 210887.0 / 2.0 # floor area divided by area instead of true footprint 128112.0)
      secondary_p = 708.0 # wrote measure using calculate_perimeter method in os_lib_geometry
      secondary_ns_ew_ratio = 2.069230769 # estimated from ratio of ns/ew total wall area
      secondary_width = Math.sqrt(secondary_footprint / secondary_ns_ew_ratio)
      secondary_p_min = 2 * (secondary_width + secondary_width / secondary_footprint)
      secondary_p_mult = secondary_p / secondary_p_min

      outpatient_footprint = 40946.0 / 3.0 # floor area divided by area instead of true footprint 17872.0)
      outpatient_p = 537.0 # wrote measure using calculate_perimeter method in os_lib_geometry
      outpatient_ns_ew_ratio = 1.56448737 # estimated from ratio of ns/ew total wall area
      outpatient_width = Math.sqrt(outpatient_footprint / outpatient_ns_ew_ratio)
      outpatient_p_min = 2 * (outpatient_width + outpatient_footprint / outpatient_width)
      outpatient_p_mult = outpatient_p / outpatient_p_min

      # primary_aspet_ratio = calc_aspect_ratio(73958.0, 2060.0)
      # secondary_aspet_ratio = calc_aspect_ratio(128112.0, 2447.0)
      # outpatient_aspet_ratio = calc_aspect_ratio(14782.0, 588.0)
      supermarket_a = 45001.0
      supermarket_p = 866.0
      supermarket_wwr = 1880.0 / (supermarket_p * 20.0)
      supermarket_aspect_ratio = calc_aspect_ratio(supermarket_a, supermarket_p)

      hash['SmallOffice'] = { aspect_ratio: 1.5, wwr: 0.15, typical_story: 10.0, perim_mult: 1.0 }
      hash['MediumOffice'] = { aspect_ratio: 1.5, wwr: 0.33, typical_story: 13.0, perim_mult: 1.0 }
      hash['LargeOffice'] = { aspect_ratio: 1.5, wwr: 0.15, typical_story: 13.0, perim_mult: 1.0 }
      hash['RetailStandalone'] = { aspect_ratio: 1.28, wwr: 0.07, typical_story: 20.0, perim_mult: 1.0 }
      hash['RetailStripmall'] = { aspect_ratio: 4.0, wwr: 0.11, typical_story: 17.0, perim_mult: 1.0 }
      hash['PrimarySchool'] = { aspect_ratio: primary_ns_ew_ratio.round(1), wwr: 0.35, typical_story: 13.0, perim_mult: primary_p_mult.round(3) }
      hash['SecondarySchool'] = { aspect_ratio: secondary_ns_ew_ratio.round(1), wwr: 0.33, typical_story: 13.0, perim_mult: secondary_p_mult.round(3) }
      hash['Outpatient'] = { aspect_ratio: outpatient_ns_ew_ratio.round(1), wwr: 0.20, typical_story: 10.0, perim_mult: outpatient_p_mult.round(3) }
      hash['Hospital'] = { aspect_ratio: 1.33, wwr: 0.16, typical_story: 14.0, perim_mult: 1.0 }
      hash['SmallHotel'] = { aspect_ratio: 3.0, wwr: 0.11, typical_story: 9.0, first_story: 11.0, perim_mult: 1.0 }
      hash['LargeHotel'] = { aspect_ratio: 5.1, wwr: 0.27, typical_story: 10.0, first_story: 13.0, perim_mult: 1.0 }

      # code in get_space_types_from_building_type is used to override building wwr with space type specific wwr
      hash['Warehouse'] = { aspect_ratio: 2.2, wwr: 0.0, typical_story: 28.0, perim_mult: 1.0 }

      hash['QuickServiceRestaurant'] = { aspect_ratio: 1.0, wwr: 0.14, typical_story: 10.0, perim_mult: 1.0 }
      hash['FullServiceRestaurant'] = { aspect_ratio: 1.0, wwr: 0.18, typical_story: 10.0, perim_mult: 1.0 }
      hash['QuickServiceRestaurant'] = { aspect_ratio: 1.0, wwr: 0.18, typical_story: 10.0, perim_mult: 1.0 }
      hash['MidriseApartment'] = { aspect_ratio: 2.75, wwr: 0.15, typical_story: 10.0, perim_mult: 1.0 }
      hash['HighriseApartment'] = { aspect_ratio: 2.75, wwr: 0.15, typical_story: 10.0, perim_mult: 1.0 }
      # SuperMarket inputs come from prototype model
      hash['SuperMarket'] = { aspect_ratio: supermarket_aspect_ratio.round(1), wwr: supermarket_wwr.round(2), typical_story: 20.0, perim_mult: 1.0 }

      # Add Laboratory and Data Centers
      hash['Laboratory'] = { aspect_ratio: 1.33, wwr: 0.12, typical_story: 10.0, perim_mult: 1.0 }
      hash['LargeDataCenterLowITE'] = { aspect_ratio: 1.67, wwr: 0.0, typical_story: 14.0, perim_mult: 1.0 }
      hash['LargeDataCenterHighITE'] = { aspect_ratio: 1.67, wwr: 0.0, typical_story: 14.0, perim_mult: 1.0 }
      hash['SmallDataCenterLowITE'] = { aspect_ratio: 1.5, wwr: 0.0, typical_story: 14.0, perim_mult: 1.0 }
      hash['SmallDataCenterHighITE'] = { aspect_ratio: 1.5, wwr: 0.0, typical_story: 14.0, perim_mult: 1.0 }

      # Add Courthouse and Education
      hash['Courthouse'] = { aspect_ratio: 2.06, wwr: 0.18, typical_story: 16.0, perim_mult: 1.0 }
      hash['College'] = { aspect_ratio: 2.5, wwr: 0.037, typical_story: 13.0, perim_mult: 1.0 }

      # DEER Prototypes
      hash['Asm'] = { aspect_ratio: 1.0, wwr: 0.19, typical_story: 15.0 }
      hash['ECC'] = { aspect_ratio: 4.0, wwr: 0.25, typical_story: 13.0 }
      hash['EPr'] = { aspect_ratio: 2.0, wwr: 0.16, typical_story: 12.0 }
      hash['ERC'] = { aspect_ratio: 1.7, wwr: 0.03, typical_story: 12.0 }
      hash['ESe'] = { aspect_ratio: 1.0, wwr: 0.15, typical_story: 13.0 }
      hash['EUn'] = { aspect_ratio: 2.5, wwr: 0.3, typical_story: 14.0 }
      hash['Gro'] = { aspect_ratio: 1.0, wwr: 0.07, typical_story: 25.0 }
      hash['Hsp'] = { aspect_ratio: 1.5, wwr: 0.11, typical_story: 13.0 }
      hash['Htl'] = { aspect_ratio: 3.0, wwr: 0.23, typical_story: 9.5, first_story: 12.0 }
      hash['MBT'] = { aspect_ratio: 10.7, wwr: 0.12, typical_story: 15.0 }
      hash['MFm'] = { aspect_ratio: 1.4, wwr: 0.24, typical_story: 9.5 }
      hash['MLI'] = { aspect_ratio: 1.0, wwr: 0.01, typical_story: 35.0 }
      hash['Mtl'] = { aspect_ratio: 5.1, wwr: 0.41, typical_story: 9.0 }
      hash['Nrs'] = { aspect_ratio: 10.3, wwr: 0.2, typical_story: 13.0 }
      hash['OfL'] = { aspect_ratio: 1.5, wwr: 0.33, typical_story: 12.0 }
      hash['OfS'] = { aspect_ratio: 1.5, wwr: 0.33, typical_story: 12.0 }
      hash['RFF'] = { aspect_ratio: 1.0, wwr: 0.25, typical_story: 13.0 }
      hash['RSD'] = { aspect_ratio: 1.0, wwr: 0.13, typical_story: 13.0 }
      hash['Rt3'] = { aspect_ratio: 1.0, wwr: 0.02, typical_story: 20.8 }
      hash['RtL'] = { aspect_ratio: 1.0, wwr: 0.03, typical_story: 20.5 }
      hash['RtS'] = { aspect_ratio: 1.0, wwr: 0.13, typical_story: 12.0 }
      hash['SCn'] = { aspect_ratio: 1.0, wwr: 0.01, typical_story: 48.0 }
      hash['SUn'] = { aspect_ratio: 1.0, wwr: 0.01, typical_story: 48.0 }
      hash['WRf'] = { aspect_ratio: 1.6, wwr: 0.0, typical_story: 32.0 }

      return hash[building_type]
    end

    # get length and width of rectangle matching bounding box aspect ratio will maintaining proper floor area
    #
    # @param envelope_data_hash [Hash] Hash of envelope data including building_max_xyz and effective__num_stories
    # @return [Hash] hash of bar length and width
    def self.calc_bar_reduced_bounding_box(envelope_data_hash)
      bar = {}

      bounding_length = envelope_data_hash[:building_max_xyz][0] - envelope_data_hash[:building_min_xyz][0]
      bounding_width = envelope_data_hash[:building_max_xyz][1] - envelope_data_hash[:building_min_xyz][1]
      bounding_area = bounding_length * bounding_width
      footprint_area = envelope_data_hash[:building_floor_area] / envelope_data_hash[:effective__num_stories].to_f
      area_multiplier = footprint_area / bounding_area
      edge_multiplier = Math.sqrt(area_multiplier)
      bar[:length] = bounding_length * edge_multiplier
      bar[:width] = bounding_width * edge_multiplier

      return bar
    end

    # get length and width of rectangle matching longer of two edges, and reducing the other way until floor area matches
    #
    # @param envelope_data_hash [Hash] Hash of envelope data including building_max_xyz and effective__num_stories
    # @return [Hash] hash of bar length and width
    def self.calc_bar_reduced_width(envelope_data_hash)
      bar = {}

      bounding_length = envelope_data_hash[:building_max_xyz][0] - envelope_data_hash[:building_min_xyz][0]
      bounding_width = envelope_data_hash[:building_max_xyz][1] - envelope_data_hash[:building_min_xyz][1]
      footprint_area = envelope_data_hash[:building_floor_area] / envelope_data_hash[:effective__num_stories].to_f

      if bounding_length >= bounding_width
        bar[:length] = bounding_length
        bar[:width] = footprint_area / bounding_length
      else
        bar[:width] = bounding_width
        bar[:length] = footprint_area / bounding_width
      end

      return bar
    end

    # get length and width of rectangle by stretching it until both floor area and exterior wall area or perimeter match
    #
    # @param envelope_data_hash [Hash] Hash of envelope data including building_max_xyz and effective__num_stories
    # @return [Hash] hash of bar length and width
    def self.calc_bar_stretched(envelope_data_hash)
      bar = {}

      bounding_length = envelope_data_hash[:building_max_xyz][0] - envelope_data_hash[:building_min_xyz][0]
      bounding_width = envelope_data_hash[:building_max_xyz][1] - envelope_data_hash[:building_min_xyz][1]
      a = envelope_data_hash[:building_floor_area] / envelope_data_hash[:effective__num_stories].to_f
      p = envelope_data_hash[:building_perimeter]

      if bounding_length >= bounding_width
        bar[:length] = 0.25 * (p + Math.sqrt(p**2 - 16 * a))
        bar[:width] = 0.25 * (p - Math.sqrt(p**2 - 16 * a))
      else
        bar[:length] = 0.25 * (p - Math.sqrt(p**2 - 16 * a))
        bar[:width] = 0.25 * (p + Math.sqrt(p**2 - 16 * a))
      end

      return bar
    end

    # create_bar(runner,model,bar_hash)
    # measures using this method should include OsLibGeometry and OsLibHelperMethods
    def self.create_bar(runner, model, bar_hash, story_multiplier_method = 'Basements Ground Mid Top')
      # warn about site shading
      if !model.getSite.shadingSurfaceGroups.empty?
        runner.registerWarning('The model has one or more site shading surafces. New geometry may not be positioned where expected, it will be centered over the center of the original geometry.')
      end

      # make custom story hash when number of stories below grade > 0
      # todo - update this so have option basements are not below 0? (useful for simplifying existing model and maintaining z position relative to site shading)
      story_hash = {}
      eff_below = bar_hash[:num_stories_below_grade]
      eff_above = bar_hash[:num_stories_above_grade]
      footprint_origin = bar_hash[:center_of_footprint]
      typical_story_height = bar_hash[:floor_height]

      # flatten story_hash out to individual stories included in building area
      stories_flat = []
      stories_flat_counter = 0
      bar_hash[:stories].each_with_index do |(k, v), i|
        # k is invalid in some cases, old story object that has been removed, should be from low to high including basement
        # skip if source story insn't included in building area
        if v[:story_included_in_building_area].nil? || (v[:story_included_in_building_area] == true)

          # add to counter
          stories_flat_counter += v[:story_min_multiplier]

          flat_hash = {}
          flat_hash[:story_party_walls] = v[:story_party_walls]
          flat_hash[:below_partial_story] = v[:below_partial_story]
          flat_hash[:bottom_story_ground_exposed_floor] = v[:bottom_story_ground_exposed_floor]
          flat_hash[:top_story_exterior_exposed_roof] = v[:top_story_exterior_exposed_roof]
          if i < eff_below
            flat_hash[:story_type] = 'B'
            flat_hash[:multiplier] = 1
          elsif i == eff_below
            flat_hash[:story_type] = 'Ground'
            flat_hash[:multiplier] = 1
          elsif stories_flat_counter == eff_below + eff_above.ceil
            flat_hash[:story_type] = 'Top'
            flat_hash[:multiplier] = 1
          else
            flat_hash[:story_type] = 'Mid'
            flat_hash[:multiplier] = v[:story_min_multiplier]
          end

          compare_hash = {}
          if !stories_flat.empty?
            stories_flat.last.each { |k, v| compare_hash[k] = flat_hash[k] if flat_hash[k] != v }
          end
          if (story_multiplier_method != 'None' && stories_flat.last == flat_hash) || (story_multiplier_method != 'None' && compare_hash.size == 1 && compare_hash.include?(:multiplier))
            stories_flat.last[:multiplier] += v[:story_min_multiplier]
          else
            stories_flat << flat_hash
          end
        end
      end

      if bar_hash[:num_stories_below_grade] > 0

        # add in below grade levels (may want to add below grade multipliers at some point if we start running deep basements)
        eff_below.times do |i|
          story_hash["B#{i + 1}"] = { space_origin_z: footprint_origin.z - typical_story_height * (i + 1), space_height: typical_story_height, multiplier: 1 }
        end
      end

      # add in above grade levels
      if eff_above > 2
        story_hash['Ground'] = { space_origin_z: footprint_origin.z, space_height: typical_story_height, multiplier: 1 }

        footprint_counter = 0
        effective_stories_counter = 1
        stories_flat.each do |hash|
          next if hash[:story_type] != 'Mid'

          if footprint_counter == 0
            string = 'Mid'
          else
            string = "Mid#{footprint_counter + 1}"
          end
          story_hash[string] = { space_origin_z: footprint_origin.z + typical_story_height * effective_stories_counter + typical_story_height * (hash[:multiplier] - 1) / 2.0, space_height: typical_story_height, multiplier: hash[:multiplier] }
          footprint_counter += 1
          effective_stories_counter += hash[:multiplier]
        end

        story_hash['Top'] = { space_origin_z: footprint_origin.z + typical_story_height * (eff_above.ceil - 1), space_height: typical_story_height, multiplier: 1 }
      elsif eff_above > 1
        story_hash['Ground'] = { space_origin_z: footprint_origin.z, space_height: typical_story_height, multiplier: 1 }
        story_hash['Top'] = { space_origin_z: footprint_origin.z + typical_story_height * (eff_above.ceil - 1), space_height: typical_story_height, multiplier: 1 }
      else # one story only
        story_hash['Ground'] = { space_origin_z: footprint_origin.z, space_height: typical_story_height, multiplier: 1 }
      end

      # create footprints
      if bar_hash[:bar_division_method] == 'Multiple Space Types - Simple Sliced'
        footprints = []
        story_hash.size.times do |i|
          # adjust size of bar of top story is not a full story
          if i + 1 == story_hash.size
            area_multiplier = (1.0 - bar_hash[:num_stories_above_grade].ceil + bar_hash[:num_stories_above_grade])
            edge_multiplier = Math.sqrt(area_multiplier)
            length = bar_hash[:length] * edge_multiplier
            width = bar_hash[:width] * edge_multiplier
          else
            length = bar_hash[:length]
            width = bar_hash[:width]
          end
          footprints << OsLib_Geometry.make_sliced_bar_simple_polygons(runner, bar_hash[:space_types], length, width, bar_hash[:center_of_footprint])
        end

      elsif bar_hash[:bar_division_method] == 'Multiple Space Types - Individual Stories Sliced'

        # update story_hash for partial_story_above
        story_hash.each_with_index do |(k, v), i|
          # adjust size of bar of top story is not a full story
          if i + 1 == story_hash.size
            story_hash[k][:partial_story_multiplier] = (1.0 - bar_hash[:num_stories_above_grade].ceil + bar_hash[:num_stories_above_grade])
          end
        end

        footprints = OsLib_Geometry.make_sliced_bar_multi_polygons(runner, bar_hash[:space_types], bar_hash[:length], bar_hash[:width], bar_hash[:center_of_footprint], story_hash)

      else
        footprints = []
        story_hash.size.times do |i|
          # adjust size of bar of top story is not a full story
          if i + 1 == story_hash.size
            area_multiplier = (1.0 - bar_hash[:num_stories_above_grade].ceil + bar_hash[:num_stories_above_grade])
            edge_multiplier = Math.sqrt(area_multiplier)
            length = bar_hash[:length] * edge_multiplier
            width = bar_hash[:width] * edge_multiplier
          else
            length = bar_hash[:length]
            width = bar_hash[:width]
          end
          footprints << OsLib_Geometry.make_core_and_perimeter_polygons(runner, length, width, bar_hash[:center_of_footprint]) # perimeter defaults to 15'
        end

        # set primary space type to building default space type
        space_types = bar_hash[:space_types].sort_by { |k, v| v[:floor_area] }
        if space_types.last.first.class.to_s == 'OpenStudio::Model::SpaceType'
          model.getBuilding.setSpaceType(space_types.last.first)
        end

      end

      # makeSpacesFromPolygons
      new_spaces = OsLib_Geometry.makeSpacesFromPolygons(runner, model, footprints, bar_hash[:floor_height], bar_hash[:num_stories], bar_hash[:center_of_footprint], story_hash)

      # put all of the spaces in the model into a vector for intersection and surface matching
      spaces = OpenStudio::Model::SpaceVector.new
      model.getSpaces.sort.each do |space|
        spaces << space
      end

      # flag for intersection and matching type
      diagnostic_intersect = true

      # only intersect if make_mid_story_surfaces_adiabatic false
      if diagnostic_intersect

        model.getPlanarSurfaces.sort.each do |surface|
          array = []
          vertices = surface.vertices
          fixed = false
          vertices.each do |vertex|
            next if fixed

            if array.include?(vertex)
              # create a new set of vertices
              new_vertices = OpenStudio::Point3dVector.new
              array_b = []
              surface.vertices.each do |vertex_b|
                next if array_b.include?(vertex_b)

                new_vertices << vertex_b
                array_b << vertex_b
              end
              surface.setVertices(new_vertices)
              num_removed = vertices.size - surface.vertices.size
              runner.registerWarning("#{surface.name} has duplicate vertices. Started with #{vertices.size} vertices, removed #{num_removed}.")
              fixed = true
            else
              array << vertex
            end
          end
        end

        # remove collinear points in a surface
        model.getPlanarSurfaces.sort.each do |surface|
          new_vertices = OpenStudio.removeCollinear(surface.vertices)
          starting_count = surface.vertices.size
          final_count = new_vertices.size
          if final_count < starting_count
            runner.registerWarning("Removing #{starting_count - final_count} collinear vertices from #{surface.name}.")
            surface.setVertices(new_vertices)
          end
        end

        # remove duplicate surfaces in a space (should be done after remove duplicate and collinear points)
        model.getSpaces.sort.each do |space|
          # secondary array to compare against
          surfaces_b = space.surfaces.sort

          space.surfaces.sort.each do |surface_a|
            # delete from secondary array
            surfaces_b.delete(surface_a)

            surfaces_b.each do |surface_b|
              next if surface_a == surface_b # dont' test against same surface

              if surface_a.equalVertices(surface_b)
                runner.registerWarning("#{surface_a.name} and #{surface_b.name} in #{space.name} have duplicate geometry, removing #{surface_b.name}.")
                surface_b.remove
              elsif surface_a.reverseEqualVertices(surface_b)
                # TODO: - add logic to determine which face naormal is reversed and which is correct
                runner.registerWarning("#{surface_a.name} and #{surface_b.name} in #{space.name} have reversed geometry, removing #{surface_b.name}.")
                surface_b.remove
              end
            end
          end
        end

        if !(bar_hash[:make_mid_story_surfaces_adiabatic])
          # intersect and surface match two pair by pair
          spaces_b = model.getSpaces.sort
          # looping through vector of each space
          model.getSpaces.sort.each do |space_a|
            spaces_b.delete(space_a)
            spaces_b.each do |space_b|
              # runner.registerInfo("Intersecting and matching surfaces between #{space_a.name} and #{space.name}")
              spaces_temp = OpenStudio::Model::SpaceVector.new
              spaces_temp << space_a
              spaces_temp << space_b
              # intersect and sort
              OpenStudio::Model.intersectSurfaces(spaces_temp)
              OpenStudio::Model.matchSurfaces(spaces_temp)
            end
          end
          runner.registerInfo('Intersecting and matching surfaces in model, this will create additional geometry.')
        else # elsif bar_hash[:double_loaded_corridor] # only intersect spaces in each story, not between wtory
          model.getBuilding.buildingStories.sort.each do |story|
            # intersect and surface match two pair by pair
            spaces_b = story.spaces.sort
            # looping through vector of each space
            story.spaces.sort.each do |space_a|
              spaces_b.delete(space_a)
              spaces_b.each do |space_b|
                spaces_temp = OpenStudio::Model::SpaceVector.new
                spaces_temp << space_a
                spaces_temp << space_b

                # intersect and sort
                OpenStudio::Model.intersectSurfaces(spaces_temp)
                OpenStudio::Model.matchSurfaces(spaces_temp)
              end
            end
            runner.registerInfo("Intersecting and matching surfaces in story #{story.name}, this will create additional geometry.")
          end
        end
      else
        if !(bar_hash[:make_mid_story_surfaces_adiabatic])
          # intersect surfaces
          # (when bottom floor has many space types and one above doesn't will end up with heavily subdivided floor. Maybe use adiabatic and don't intersect floor/ceilings)
          intersect_surfaces = true
          if intersect_surfaces
            OpenStudio::Model.intersectSurfaces(spaces)
            OpenStudio::Model.matchSurfaces(spaces)
            runner.registerInfo('Intersecting and matching surfaces in model, this will create additional geometry.')
          end
        else # elsif bar_hash[:double_loaded_corridor] # only intersect spaces in each story, not between wtory
          model.getBuilding.buildingStories.sort.each do |story|
            story_spaces = OpenStudio::Model::SpaceVector.new
            story.spaces.sort.each do |space|
              story_spaces << space
            end

            # intersect and sort
            OpenStudio::Model.intersectSurfaces(story_spaces)
            OpenStudio::Model.matchSurfaces(story_spaces)
            runner.registerInfo("Intersecting and matching surfaces in story #{story.name}, this will create additional geometry.")
          end
        end

      end

      # set boundary conditions if not already set when geometry was created
      # todo - update this to use space original z value vs. story name
      if bar_hash[:num_stories_below_grade] > 0
        model.getBuildingStorys.sort.each do |story|
          next if !story.name.to_s.include?('Story B')

          story.spaces.sort.each do |space|
            next if !new_spaces.include?(space)

            space.surfaces.sort.each do |surface|
              next if surface.surfaceType != 'Wall'
              next if surface.outsideBoundaryCondition != 'Outdoors'

              surface.setOutsideBoundaryCondition('Ground')
            end
          end
        end
      end

      # set wall boundary condtions to adiabatic if using make_mid_story_surfaces_adiabatic prior to windows being made
      if bar_hash[:make_mid_story_surfaces_adiabatic]

        runner.registerInfo('Finding non-exterior walls and setting boundary condition to adiabatic')

        # need to organize by story incase top story is partial story
        # should also be only for a single bar
        story_bounding = {}
        missed_match_count = 0

        # gather new spaces by story
        new_spaces.each do |space|
          story = space.buildingStory.get
          if story_bounding.key?(story)
            story_bounding[story][:spaces] << space
          else
            story_bounding[story] = { spaces: [space] }
          end
        end

        # get bounding box for each story
        story_bounding.each do |story, v|
          # get bounding_box
          bounding_box = OpenStudio::BoundingBox.new
          v[:spaces].each do |space|
            space.surfaces.each do |space_surface|
              bounding_box.addPoints(space.transformation * space_surface.vertices)
            end
          end
          min_x = bounding_box.minX.get
          min_y = bounding_box.minY.get
          max_x = bounding_box.maxX.get
          max_y = bounding_box.maxY.get
          ext_wall_toll = 0.01

          # check surfaces again against min/max and change to adiabatic if not fully on one min or max x or y
          # todo - may need to look at aidiabiatc constructions in downstream measure. Some may be exterior party wall others may be interior walls
          v[:spaces].each do |space|
            space.surfaces.each do |space_surface|
              next if space_surface.surfaceType != 'Wall'
              next if space_surface.outsideBoundaryCondition == 'Surface' # if if found a match leave it alone, don't change to adiabiatc

              surface_bounding_box = OpenStudio::BoundingBox.new
              surface_bounding_box.addPoints(space.transformation * space_surface.vertices)
              surface_on_outside = false
              # check xmin
              if (surface_bounding_box.minX.get - min_x).abs < ext_wall_toll && (surface_bounding_box.maxX.get - min_x).abs < ext_wall_toll then surface_on_outside = true end
              # check xmax
              if (surface_bounding_box.minX.get - max_x).abs < ext_wall_toll && (surface_bounding_box.maxX.get - max_x).abs < ext_wall_toll then surface_on_outside = true end
              # check ymin
              if (surface_bounding_box.minY.get - min_y).abs < ext_wall_toll && (surface_bounding_box.maxY.get - min_y).abs < ext_wall_toll then surface_on_outside = true end
              # check ymax
              if (surface_bounding_box.minY.get - max_y).abs < ext_wall_toll && (surface_bounding_box.maxY.get - max_y).abs < ext_wall_toll then surface_on_outside = true end

              # change if not exterior
              if !surface_on_outside
                space_surface.setOutsideBoundaryCondition('Adiabatic')
                missed_match_count += 1
              end
            end
          end
        end

        if missed_match_count > 0
          runner.registerInfo("#{missed_match_count} surfaces that were exterior appear to be interior walls and had boundary condition chagned to adiabiatic.")
        end
      end

      # sort stories (by name for now but need better way)
      sorted_stories = {}
      new_spaces.each do |space|
        next if !space.buildingStory.is_initialized

        story = space.buildingStory.get
        if !sorted_stories.key?(name.to_s)
          sorted_stories[story.name.to_s] = story
        end
      end

      # flag space types that have wwr overrides
      space_type_wwr_overrides = {}

      # loop through building stories, spaces, and surfaces
      sorted_stories.sort.each_with_index do |(key, story), i|
        # flag for adiabatic floor if building doesn't have ground exposed floor
        if stories_flat[i][:bottom_story_ground_exposed_floor] == false
          adiabatic_floor = true
        end
        # flag for adiabatic roof if building doesn't have exterior exposed roof
        if stories_flat[i][:top_story_exterior_exposed_roof] == false
          adiabatic_ceiling = true
        end

        # make all mid story floor and ceilings adiabatic if requested
        if bar_hash[:make_mid_story_surfaces_adiabatic]
          if i > 0
            adiabatic_floor = true
          end
          if i < sorted_stories.size - 1
            adiabatic_ceiling = true
          end
        end

        # flag orientations for this story to recieve party walls
        party_wall_facades = stories_flat[i][:story_party_walls]

        story.spaces.each do |space|
          next if !new_spaces.include?(space)

          space.surfaces. each do |surface|
            # set floor to adiabatic if requited
            if adiabatic_floor && surface.surfaceType == 'Floor'
              make_surfaces_adiabatic([surface])
            elsif adiabatic_ceiling && surface.surfaceType == 'RoofCeiling'
              make_surfaces_adiabatic([surface])
            end

            # skip of not exterior wall
            next if surface.surfaceType != 'Wall'
            next if surface.outsideBoundaryCondition != 'Outdoors'

            # get the absoluteAzimuth for the surface so we can categorize it
            absoluteAzimuth = OpenStudio.convert(surface.azimuth, 'rad', 'deg').get + surface.space.get.directionofRelativeNorth + model.getBuilding.northAxis
            absoluteAzimuth = absoluteAzimuth % 360.0 # should result in value between 0 and 360
            absoluteAzimuth = absoluteAzimuth.round(5) # this was creating issues at 45 deg angles with opposing facades

            # target wwr values that may be changed for specific space types
            wwr_n = bar_hash[:building_wwr_n]
            wwr_e = bar_hash[:building_wwr_e]
            wwr_s = bar_hash[:building_wwr_s]
            wwr_w = bar_hash[:building_wwr_w]

            # look for space type specific wwr values
            if surface.space.is_initialized && surface.space.get.spaceType.is_initialized
              space_type = surface.space.get.spaceType.get

              # see if space type has wwr value
              bar_hash[:space_types].each do |k, v|
                if v.key?(:space_type) && space_type == v[:space_type]

                  # if matching space type specifies a wwr then override the orientation specific recommendations for this surface.
                  if v.key?(:wwr)
                    wwr_n = v[:wwr]
                    wwr_e = v[:wwr]
                    wwr_s = v[:wwr]
                    wwr_w = v[:wwr]
                    space_type_wwr_overrides[space_type] = v[:wwr]
                  end
                end
              end
            end

            # add fenestration (wwr for now, maybe overhang and overhead doors later)
            if (absoluteAzimuth >= 315.0) || (absoluteAzimuth < 45.0)
              if party_wall_facades.include?('north')
                make_surfaces_adiabatic([surface])
              else
                surface.setWindowToWallRatio(wwr_n)
              end
            elsif (absoluteAzimuth >= 45.0) && (absoluteAzimuth < 135.0)
              if party_wall_facades.include?('east')
                make_surfaces_adiabatic([surface])
              else
                surface.setWindowToWallRatio(wwr_e)
              end
            elsif (absoluteAzimuth >= 135.0) && (absoluteAzimuth < 225.0)
              if party_wall_facades.include?('south')
                make_surfaces_adiabatic([surface])
              else
                surface.setWindowToWallRatio(wwr_s)
              end
            elsif (absoluteAzimuth >= 225.0) && (absoluteAzimuth < 315.0)
              if party_wall_facades.include?('west')
                make_surfaces_adiabatic([surface])
              else
                surface.setWindowToWallRatio(wwr_w)
              end
            else
              runner.registerError('Unexpected value of facade: ' + absoluteAzimuth + '.')
              return false
            end
          end
        end
      end

      # report space types with custom wwr values
      space_type_wwr_overrides.each do |space_type, wwr|
        runner.registerInfo("For #{space_type.name} the default building wwr was replaced with a space type specfic value of #{wwr}")
      end

      new_floor_area_si = 0.0
      new_spaces.each do |space|
        new_floor_area_si += space.floorArea * space.multiplier
      end
      new_floor_area_ip = OpenStudio.convert(new_floor_area_si, 'm^2', 'ft^2').get

      final_floor_area_ip = OpenStudio.convert(model.getBuilding.floorArea, 'm^2', 'ft^2').get
      if new_floor_area_ip == final_floor_area_ip
        runner.registerInfo("Created bar envelope with floor area of #{OpenStudio.toNeatString(new_floor_area_ip, 0, true)} ft^2.")
      else
        runner.registerInfo("Created bar envelope with floor area of #{OpenStudio.toNeatString(new_floor_area_ip, 0, true)} ft^2. Total building area is #{OpenStudio.toNeatString(final_floor_area_ip, 0, true)} ft^2.")
      end

      return new_spaces
    end

    def self.bar_hash_setup_run(runner, model, args, length, width, floor_height_si, center_of_footprint, space_types_hash, num_stories)
      # create envelope
      # populate bar_hash and create envelope with data from envelope_data_hash and user arguments
      bar_hash = {}
      bar_hash[:length] = length
      bar_hash[:width] = width
      bar_hash[:num_stories_below_grade] = args['num_stories_below_grade']
      bar_hash[:num_stories_above_grade] = args['num_stories_above_grade']
      bar_hash[:floor_height] = floor_height_si
      bar_hash[:center_of_footprint] = center_of_footprint
      bar_hash[:bar_division_method] = args['bar_division_method']
      bar_hash[:make_mid_story_surfaces_adiabatic] = args['make_mid_story_surfaces_adiabatic']
      bar_hash[:space_types] = space_types_hash
      bar_hash[:building_wwr_n] = args['wwr']
      bar_hash[:building_wwr_s] = args['wwr']
      bar_hash[:building_wwr_e] = args['wwr']
      bar_hash[:building_wwr_w] = args['wwr']

      # round up non integer stoires to next integer
      num_stories_round_up = num_stories.ceil
      runner.registerInfo("Making bar with length of #{OpenStudio.toNeatString(OpenStudio.convert(length, 'm', 'ft').get, 0, true)} ft and width of #{OpenStudio.toNeatString(OpenStudio.convert(width, 'm', 'ft').get, 0, true)} ft")

      # party_walls_array to be used by orientation specific or fractional party wall values
      party_walls_array = [] # this is an array of arrays, where each entry is effective building story with array of directions

      if args['party_wall_stories_north'] + args['party_wall_stories_south'] + args['party_wall_stories_east'] + args['party_wall_stories_west'] > 0

        # loop through effective number of stories add orientation specific party walls per user arguments
        num_stories_round_up.times do |i|
          test_value = i + 1 - bar_hash[:num_stories_below_grade]

          array = []
          if args['party_wall_stories_north'] >= test_value
            array << 'north'
          end
          if args['party_wall_stories_south'] >= test_value
            array << 'south'
          end
          if args['party_wall_stories_east'] >= test_value
            array << 'east'
          end
          if args['party_wall_stories_west'] >= test_value
            array << 'west'
          end

          # populate party_wall_array for this story
          party_walls_array << array
        end
      end

      # calculate party walls if using party_wall_fraction method
      if args['party_wall_fraction'] > 0 && !party_walls_array.empty?
        runner.registerWarning('Both orientation and fractional party wall values arguments were populated, will ignore fractional party wall input')
      elsif args['party_wall_fraction'] > 0

        # orientation of long and short side of building will vary based on building rotation

        # full story ext wall area
        typical_length_facade_area = length * floor_height_si
        typical_width_facade_area = width * floor_height_si

        # top story ext wall area, may be partial story
        partial_story_multiplier = (1.0 - args['num_stories_above_grade'].ceil + args['num_stories_above_grade'])
        area_multiplier = partial_story_multiplier
        edge_multiplier = Math.sqrt(area_multiplier)
        top_story_length = length * edge_multiplier
        top_story_width = width * edge_multiplier
        top_story_length_facade_area = top_story_length * floor_height_si
        top_story_width_facade_area = top_story_width * floor_height_si

        total_exterior_wall_area = 2 * (length + width) * (args['num_stories_above_grade'].ceil - 1.0) * floor_height_si + 2 * (top_story_length + top_story_width) * floor_height_si
        target_party_wall_area = total_exterior_wall_area * args['party_wall_fraction']

        width_counter = 0
        width_area = 0.0
        facade_area = typical_width_facade_area
        until (width_area + facade_area >= target_party_wall_area) || (width_counter == args['num_stories_above_grade'].ceil * 2)
          # update facade area for top story
          if width_counter == args['num_stories_above_grade'].ceil - 1 || width_counter == args['num_stories_above_grade'].ceil * 2 - 1
            facade_area = top_story_width_facade_area
          else
            facade_area = typical_width_facade_area
          end

          width_counter += 1
          width_area += facade_area

        end
        width_area_remainder = target_party_wall_area - width_area

        length_counter = 0
        length_area = 0.0
        facade_area = typical_length_facade_area
        until (length_area + facade_area >= target_party_wall_area) || (length_counter == args['num_stories_above_grade'].ceil * 2)
          # update facade area for top story
          if length_counter == args['num_stories_above_grade'].ceil - 1 || length_counter == args['num_stories_above_grade'].ceil * 2 - 1
            facade_area = top_story_length_facade_area
          else
            facade_area = typical_length_facade_area
          end

          length_counter += 1
          length_area += facade_area
        end
        length_area_remainder = target_party_wall_area - length_area

        # get rotation and best fit to adjust orientation for fraction party wall
        rotation = args['building_rotation'] % 360.0 # should result in value between 0 and 360
        card_dir_array = [0.0, 90.0, 180.0, 270.0, 360.0]
        # reverse array to properly handle 45, 135, 225, and 315
        best_fit = card_dir_array.reverse.min_by { |x| (x.to_f - rotation).abs }

        if ![90.0, 270.0].include? best_fit
          width_card_dir = ['east', 'west']
          length_card_dir = ['north', 'south']
        else # if rotation is closest to 90 or 270 then reverse which orientation is used for length and width
          width_card_dir = ['north', 'south']
          length_card_dir = ['east', 'west']
        end

        # if dont' find enough on short sides
        if width_area_remainder <= typical_length_facade_area

          num_stories_round_up.times do |i|
            if i + 1 <= args['num_stories_below_grade']
              party_walls_array << []
              next
            end
            if i + 1 - args['num_stories_below_grade'] <= width_counter
              if i + 1 - args['num_stories_below_grade'] <= width_counter - args['num_stories_above_grade']
                party_walls_array << width_card_dir
              else
                party_walls_array << [width_card_dir.first]
              end
            else
              party_walls_array << []
            end
          end

        else # use long sides instead

          num_stories_round_up.times do |i|
            if i + 1 <= args['num_stories_below_grade']
              party_walls_array << []
              next
            end
            if i + 1 - args['num_stories_below_grade'] <= length_counter
              if i + 1 - args['num_stories_below_grade'] <= length_counter - args['num_stories_above_grade']
                party_walls_array << length_card_dir
              else
                party_walls_array << [length_card_dir.first]
              end
            else
              party_walls_array << []
            end
          end

        end

        # TODO: - currently won't go past making two opposing sets of walls party walls. Info and registerValue are after create_bar in measure.rb

      end

      # populate bar hash with story information
      bar_hash[:stories] = {}
      num_stories_round_up.times do |i|
        if party_walls_array.empty?
          party_walls = []
        else
          party_walls = party_walls_array[i]
        end

        # add below_partial_story
        if num_stories.ceil > num_stories && i == num_stories_round_up - 2
          below_partial_story = true
        else
          below_partial_story = false
        end

        # bottom_story_ground_exposed_floor and top_story_exterior_exposed_roof already setup as bool
        bar_hash[:stories]["key #{i}"] = { story_party_walls: party_walls, story_min_multiplier: 1, story_included_in_building_area: true, below_partial_story: below_partial_story, bottom_story_ground_exposed_floor: args['bottom_story_ground_exposed_floor'], top_story_exterior_exposed_roof: args['top_story_exterior_exposed_roof'] }
      end

      # create bar
      new_spaces = create_bar(runner, model, bar_hash, args['story_multiplier'])

      # check expect roof and wall area
      target_footprint = bar_hash[:length] * bar_hash[:width]
      ground_floor_area = 0.0
      roof_area = 0.0
      new_spaces.each do |space|
        space.surfaces.each do |surface|
          if surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Ground'
            ground_floor_area += surface.netArea
          elsif surface.surfaceType == 'RoofCeiling' && surface.outsideBoundaryCondition == 'Outdoors'
            roof_area += surface.netArea
          end
        end
      end
      # TODO: - extend to address when top and or bottom story are not exposed via argument
      if ground_floor_area > target_footprint + 0.001 || roof_area > target_footprint + 0.001
        # runner.registerError("Ground exposed floor or Roof area is larger than footprint, likely inter-floor surface matching and intersection error.")
        # return false

        # not providing adiabatic work around when top story is partial story.
        if args['num_stories_above_grade'].to_f != args['num_stories_above_grade'].ceil
          runner.registerError('Ground exposed floor or Roof area is larger than footprint, likely inter-floor surface matching and intersection error.')
          return false
        else
          runner.registerInfo('Ground exposed floor or Roof area is larger than footprint, likely inter-floor surface matching and intersection error, altering impacted surfaces boundary condition to be adiabatic.')
          match_error = true
        end
      else
        match_error = false
      end

      # TODO: - should be able to remove this fix after OpenStudio intersection issue is fixed. At that time turn the above message into an error with return false after it
      if match_error

        # identify z value of top and bottom story
        bottom_story = nil
        top_story = nil
        new_spaces.each do |space|
          story = space.buildingStory.get
          nom_z = story.nominalZCoordinate.get
          if bottom_story.nil?
            bottom_story = nom_z
          elsif bottom_story > nom_z
            bottom_story = nom_z
          end
          if top_story.nil?
            top_story = nom_z
          elsif top_story < nom_z
            top_story = nom_z
          end
        end

        # change boundary condition and intersection as needed.
        new_spaces.each do |space|
          if space.buildingStory.get.nominalZCoordinate.get > bottom_story
            # change floors
            space.surfaces.each do |surface|
              next if !(surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Ground')

              surface.setOutsideBoundaryCondition('Adiabatic')
            end
          end
          if space.buildingStory.get.nominalZCoordinate.get < top_story
            # change ceilings
            space.surfaces.each do |surface|
              next if !(surface.surfaceType == 'RoofCeiling' && surface.outsideBoundaryCondition == 'Outdoors')

              surface.setOutsideBoundaryCondition('Adiabatic')
            end
          end
        end
      end
    end

    # bar_arg_check_setup
    def self.bar_arg_check_setup(model, runner, user_arguments, building_type_ratios = true)
      # assign the user inputs to variables
      args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments(model))
      if !args then return false end

      # add in arguments that may not be passed in
      if !args.key?('double_loaded_corridor')
        args['double_loaded_corridor'] = 'None' # use None when not in measure building type data may not contain this
      end
      if !args.key?('perim_mult')
        args['perim_mult'] = 1.0 # will not make two bars for extended perimeter
      end

      # lookup and replace argument values from upstream measures
      if args['use_upstream_args'] == true
        args.each do |arg, value|
          next if arg == 'use_upstream_args' # this argument should not be changed

          value_from_osw = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, arg)
          if !value_from_osw.empty?
            runner.registerInfo("Replacing argument named #{arg} from current measure with a value of #{value_from_osw[:value]} from #{value_from_osw[:measure_name]}.")
            new_val = value_from_osw[:value]
            # TODO: - make code to handle non strings more robust. check_upstream_measure_for_arg could pass back the argument type
            if arg == 'total_bldg_floor_area'
              args[arg] = new_val.to_f
            elsif arg == 'num_stories_above_grade'
              args[arg] = new_val.to_f
            elsif arg == 'zipcode'
              args[arg] = new_val.to_i
            else
              args[arg] = new_val
            end
          end
        end
      end

      # check expected values of double arguments
      fraction_args = ['wwr', 'party_wall_fraction']
      if building_type_ratios
        fraction_args << 'bldg_type_b_fract_bldg_area'
        fraction_args << 'bldg_type_c_fract_bldg_area'
        fraction_args << 'bldg_type_d_fract_bldg_area'
      end
      fraction = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments, 'min' => 0.0, 'max' => 1.0, 'min_eq_bool' => true, 'max_eq_bool' => true, 'arg_array' => fraction_args)

      one_or_greater_args = ['num_stories_above_grade']
      one_or_greater = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments, 'min' => 1.0, 'max' => nil, 'min_eq_bool' => true, 'max_eq_bool' => false, 'arg_array' => one_or_greater_args)

      non_neg_args = ['num_stories_below_grade',
                      'floor_height',
                      'ns_to_ew_ratio',
                      'party_wall_stories_north',
                      'party_wall_stories_south',
                      'party_wall_stories_east',
                      'party_wall_stories_west',
                      'total_bldg_floor_area',
                      'single_floor_area',
                      'bar_width']
      non_neg = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments, 'min' => 0.0, 'max' => nil, 'min_eq_bool' => true, 'max_eq_bool' => false, 'arg_array' => non_neg_args)

      # return false if any errors fail
      if !fraction then return false end
      return false if !one_or_greater
      return false if !non_neg

      return args
    end

    # bar_from_building_type_ratios
    # used for varieties of measures that create bar from building type ratios
    def self.bar_from_building_type_ratios(model, runner, user_arguments)
      # prep arguments
      args = bar_arg_check_setup(model, runner, user_arguments)
      if !args then return false end

      # check that sum of fractions for b,c, and d is less than 1.0 (so something is left for primary building type)
      bldg_type_a_fract_bldg_area = 1.0 - args['bldg_type_b_fract_bldg_area'] - args['bldg_type_c_fract_bldg_area'] - args['bldg_type_d_fract_bldg_area']
      if bldg_type_a_fract_bldg_area <= 0.0
        runner.registerError('Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.')
        return false
      end

      # Make the standard applier
      standard = Standard.build((args['template']).to_s)

      # report initial condition of model
      runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

      # determine of ns_ew needs to be mirrored
      mirror_ns_ew = false
      rotation = model.getBuilding.northAxis
      if rotation > 45.0 && rotation < 135.0
        mirror_ns_ew = true
      elsif rotation > 45.0 && rotation < 135.0
        mirror_ns_ew = true
      end

      # remove non-resource objects not removed by removing the building
      remove_non_resource_objects(runner, model)

      # rename building to infer template in downstream measure
      name_array = [args['template'], args['bldg_type_a']]
      if args['bldg_type_b_fract_bldg_area'] > 0 then name_array << args['bldg_type_b'] end
      if args['bldg_type_c_fract_bldg_area'] > 0 then name_array << args['bldg_type_c'] end
      if args['bldg_type_d_fract_bldg_area'] > 0 then name_array << args['bldg_type_d'] end
      model.getBuilding.setName(name_array.join('|').to_s)

      # hash to whole building type data
      building_type_hash = {}

      # gather data for bldg_type_a
      building_type_hash[args['bldg_type_a']] = {}
      building_type_hash[args['bldg_type_a']][:frac_bldg_area] = bldg_type_a_fract_bldg_area
      # building_type_hash[args['bldg_type_a']][:num_units] = args['bldg_type_a_num_units']
      building_type_hash[args['bldg_type_a']][:space_types] = get_space_types_from_building_type(args['bldg_type_a'], args['template'], true)

      # gather data for bldg_type_b
      if args['bldg_type_b_fract_bldg_area'] > 0
        building_type_hash[args['bldg_type_b']] = {}
        building_type_hash[args['bldg_type_b']][:frac_bldg_area] = args['bldg_type_b_fract_bldg_area']
        # building_type_hash[args['bldg_type_b']][:num_units] = args['bldg_type_b_num_units']
        building_type_hash[args['bldg_type_b']][:space_types] = get_space_types_from_building_type(args['bldg_type_b'], args['template'], true)
      end

      # gather data for bldg_type_c
      if args['bldg_type_c_fract_bldg_area'] > 0
        building_type_hash[args['bldg_type_c']] = {}
        building_type_hash[args['bldg_type_c']][:frac_bldg_area] = args['bldg_type_c_fract_bldg_area']
        # building_type_hash[args['bldg_type_c']][:num_units] = args['bldg_type_c_num_units']
        building_type_hash[args['bldg_type_c']][:space_types] = get_space_types_from_building_type(args['bldg_type_c'], args['template'], true)
      end

      # gather data for bldg_type_d
      if args['bldg_type_d_fract_bldg_area'] > 0
        building_type_hash[args['bldg_type_d']] = {}
        building_type_hash[args['bldg_type_d']][:frac_bldg_area] = args['bldg_type_d_fract_bldg_area']
        # building_type_hash[args['bldg_type_d']][:num_units] = args['bldg_type_d_num_units']
        building_type_hash[args['bldg_type_d']][:space_types] = get_space_types_from_building_type(args['bldg_type_d'], args['template'], true)
      end

      # call bar_from_building_space_type_ratios to generate bar
      bar_from_space_type_ratios(model, runner, user_arguments, args, building_type_hash)

      return true
    end

    # bar_from_space_type_ratios
    # used for varieties of measures that create bar from space type or building type ratios
    # args and building_type_hash should both be nil or neither shoould be nill
    def self.bar_from_space_type_ratios(model, runner, user_arguments, args = nil, building_type_hash = nil)
      # do not setup arguments if they were already passed in to this method
      if args.nil?
        # prep arguments
        args = bar_arg_check_setup(model, runner, user_arguments, false) # false stops it from checking args on used in bar_from_building_type_ratios
        if !args then return false end

        # process arg into hash
        space_type_hash_name = {}
        args['space_type_hash_string'][0..-1].split(/, /).each { |entry| entryMap = entry.split(/=>/); value_str = entryMap[1]; space_type_hash_name[entryMap[0].strip[0..-1].to_s] = value_str.nil? ? '' : value_str.strip[0..-1].to_f }

        # create building type hasn from space type ratios
        building_type_hash = {}
        building_type_fraction_of_building = 0.0
        space_type_hash_name.each do |building_space_type, ratio|
          building_type = building_space_type.split('|')[0].strip
          space_type = building_space_type.split('|')[1].strip

          # harvest height and circ info from get_space_types_from_building_type(building_type, template, whole_building = true)
          building_type_lookup_info = get_space_types_from_building_type(building_type, args['template'])
          if building_type_lookup_info.empty?
            runner.registerWarning("#{building_type} looks like an invalid building type for #{args['template']}")
          end
          space_type_info_hash = {}
          if building_type_lookup_info.key?(space_type)
            if building_type_lookup_info[space_type].key?(:story_height)
              space_type_info_hash[:story_height] = building_type_lookup_info[space_type][:story_height]
            end
            if building_type_lookup_info[space_type].key?(:default)
              space_type_info_hash[:default] = building_type_lookup_info[space_type][:default]
            end
            if building_type_lookup_info[space_type].key?(:circ)
              space_type_info_hash[:circ] = building_type_lookup_info[space_type][:circ]
            end
          else
            runner.registerWarning("#{space_type} looks like an invalid space type for #{building_type}")
          end

          # extend harvested data with custom ratios from space type ratio string argument.
          if building_type_hash.key?(building_type)
            building_type_hash[building_type][:frac_bldg_area] += ratio
            space_type_info_hash[:ratio] = ratio
            building_type_hash[building_type][:space_types][space_type] = space_type_info_hash
          else
            building_type_hash[building_type] = {}
            building_type_hash[building_type][:frac_bldg_area] = ratio
            space_type_info_hash[:ratio] = ratio
            space_types = {}
            space_types[space_type] = space_type_info_hash
            building_type_hash[building_type][:space_types] = space_types
          end
          building_type_fraction_of_building += ratio
        end

        # identify primary building type for building form defaults
        primary_building_type = building_type_hash.keys.first # update to choose building with highest ratio
        runner.registerInfo('Creating bar with space type ratio proided as argument.')
        runner.registerInfo("Using building type from first ratio #{primary_building_type} as the primary building type. This is used for building form defaults.")

        # TODO: - confirm if this will get normalized up/down later of if I should fix or stop here instead of just a warning
        if building_type_fraction_of_building > 1.0
          runner.registerWarning("Sum of Space Type Ratio of #{building_type_fraction_of_building} is greater than the expected value of 1.0")
        elsif building_type_fraction_of_building < 1.0
          runner.registerWarning("Sum of Space Type Ratio of #{building_type_fraction_of_building} is less than the expected value of 1.0")
        end

      else # else is used when bar_from_building_type_ratio is used

        # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
        primary_building_type = args['bldg_type_a']
        runner.registerInfo('Creating bar space type ratios by building type based on ratios from prototype models.')
        runner.registerInfo("#{primary_building_type} will be used for building form defaults.")

      end

      # get defaults for the primary building type
      building_form_defaults = building_form_defaults(primary_building_type)

      # store list of defaulted items
      defaulted_args = []

      if args['ns_to_ew_ratio'] == 0.0
        args['ns_to_ew_ratio'] = building_form_defaults[:aspect_ratio]
        runner.registerInfo("0.0 value for aspect ratio will be replaced with smart default for #{primary_building_type} of #{building_form_defaults[:aspect_ratio]}.")
      end

      if args['perim_mult'] == 0.0
        # if this is not defined then use default of 1.0
        if !building_form_defaults.key?(:perim_mult)
          args['perim_mult'] = 1.0
        else
          args['perim_mult'] = building_form_defaults[:perim_mult]
        end
        runner.registerInfo("0.0 value for minimum perimeter multiplier will be replaced with smart default for #{primary_building_type} of #{building_form_defaults[:perim_mult]}.")
      elsif args['perim_mult'] < 1.0
        runner.registerError('Other than the smart default value of 0, the minimum perimeter multiplier should be equal to 1.0 or greater.')
        return false
      end

      if args['floor_height'] == 0.0
        args['floor_height'] = building_form_defaults[:typical_story]
        runner.registerInfo("0.0 value for floor height will be replaced with smart default for #{primary_building_type} of #{building_form_defaults[:typical_story]}.")
        defaulted_args << 'floor_height'
      end
      # because of this can't set wwr to 0.0. If that is desired then we can change this to check for 1.0 instead of 0.0
      if args['wwr'] == 0.0
        args['wwr'] = building_form_defaults[:wwr]
        runner.registerInfo("0.0 value for window to wall ratio will be replaced with smart default for #{primary_building_type} of #{building_form_defaults[:wwr]}.")
      end

      # Make the standard applier
      standard = Standard.build((args['template']).to_s)

      # report initial condition of model
      runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

      # determine of ns_ew needs to be mirrored
      mirror_ns_ew = false
      rotation = model.getBuilding.northAxis
      if rotation > 45.0 && rotation < 135.0
        mirror_ns_ew = true
      elsif rotation > 45.0 && rotation < 135.0
        mirror_ns_ew = true
      end

      # remove non-resource objects not removed by removing the building
      remove_non_resource_objects(runner, model)

      # creating space types for requested building types
      building_type_hash.each do |building_type, building_type_hash|
        runner.registerInfo("Creating Space Types for #{building_type}.")

        # mapping building_type name is needed for a few methods
        building_type = standard.model_get_lookup_name(building_type)

        # create space_type_map from array
        sum_of_ratios = 0.0
        building_type_hash[:space_types] = building_type_hash[:space_types].sort_by { |k, v| v[:ratio] }.to_h
        building_type_hash[:space_types].each do |space_type_name, hash|
          next if hash[:space_type_gen] == false # space types like undeveloped and basement are skipped.

          # create space type
          space_type = OpenStudio::Model::SpaceType.new(model)
          space_type.setStandardsBuildingType(building_type)
          space_type.setStandardsSpaceType(space_type_name)
          space_type.setName("#{building_type} #{space_type_name}")

          # set color
          test = standard.space_type_apply_rendering_color(space_type) # this uses openstudio-standards
          if !test
            # TODO: - once fixed in standards un-comment this
            # runner.registerWarning("Could not find color for #{args['template']} #{space_type.name}")
          end

          # extend hash to hold new space type object
          hash[:space_type] = space_type

          # add to sum_of_ratios counter for adjustment multiplier
          sum_of_ratios += hash[:ratio]
        end

        # store multiplier needed to adjust sum of ratios to equal 1.0
        building_type_hash[:ratio_adjustment_multiplier] = 1.0 / sum_of_ratios
      end

      # calculate length and with of bar
      total_bldg_floor_area_si = OpenStudio.convert(args['total_bldg_floor_area'], 'ft^2', 'm^2').get
      single_floor_area_si = OpenStudio.convert(args['single_floor_area'], 'ft^2', 'm^2').get

      # store number of stories
      num_stories = args['num_stories_below_grade'] + args['num_stories_above_grade']

      # handle user-assigned single floor plate size condition
      if args['single_floor_area'] > 0.0
        footprint_si = single_floor_area_si
        total_bldg_floor_area_si = footprint_si * num_stories.to_f
        runner.registerWarning('User-defined single floor area was used for calculation of total building floor area')
        # add warning if custom_height_bar is true and applicable building type is selected
        if args['custom_height_bar']
          runner.registerWarning('Cannot use custom height bar with single floor area method, will not create custom height bar.')
          args['custom_height_bar'] = false
        end
      else
        footprint_si = nil
      end

      # populate space_types_hash
      space_types_hash = {}
      multi_height_space_types_hash = {}
      custom_story_heights = []
      if args['space_type_sort_logic'] == 'Building Type > Size'
        building_type_hash = building_type_hash.sort_by { |k, v| v[:frac_bldg_area] }
      end
      building_type_hash.each do |building_type, building_type_hash|
        if args['double_loaded_corridor'] == 'Primary Space Type'

          # see if building type has circulation space type, if so then merge that along with default space type into hash key in place of space type
          default_st = nil
          circ_st = nil
          building_type_hash[:space_types].each do |space_type_name, hash|
            if hash[:default] then default_st = space_type_name end
            if hash[:circ] then circ_st = space_type_name end
          end

          # update building hash
          if !default_st.nil? && !circ_st.nil?
            runner.registerInfo("Combining #{default_st} and #{circ_st} into a group representing a double loaded corridor")

            # add new item
            building_type_hash[:space_types]['Double Loaded Corridor'] = {}
            double_loaded_st = building_type_hash[:space_types]['Double Loaded Corridor']
            double_loaded_st[:ratio] = building_type_hash[:space_types][default_st][:ratio] + building_type_hash[:space_types][circ_st][:ratio]
            double_loaded_st[:double_loaded_corridor] = true
            double_loaded_st[:space_type] = model.getBuilding
            double_loaded_st[:children] = {}
            building_type_hash[:space_types][default_st][:orig_ratio] = building_type_hash[:ratio_adjustment_multiplier] * building_type_hash[:frac_bldg_area] * building_type_hash[:space_types][default_st][:ratio]
            building_type_hash[:space_types][circ_st][:orig_ratio] = building_type_hash[:ratio_adjustment_multiplier] * building_type_hash[:frac_bldg_area] * building_type_hash[:space_types][circ_st][:ratio]
            building_type_hash[:space_types][default_st][:name] = default_st
            building_type_hash[:space_types][circ_st][:name] = circ_st
            double_loaded_st[:children][:default] = building_type_hash[:space_types][default_st]
            double_loaded_st[:children][:circ] = building_type_hash[:space_types][circ_st]
            double_loaded_st[:orig_ratio] = 0.0

            # zero out ratios from old item (don't delete because I still want the space types made)
            building_type_hash[:space_types][default_st][:ratio] = 0.0
            building_type_hash[:space_types][circ_st][:ratio] = 0.0
          end
        end

        building_type_hash[:space_types].each do |space_type_name, hash|
          next if hash[:space_type_gen] == false

          space_type = hash[:space_type]
          ratio_of_bldg_total = hash[:ratio] * building_type_hash[:ratio_adjustment_multiplier] * building_type_hash[:frac_bldg_area]
          final_floor_area = ratio_of_bldg_total * total_bldg_floor_area_si # I think I can just pass ratio but passing in area is cleaner

          # only add custom height space if 0 is used for floor_height
          if defaulted_args.include?('floor_height') && hash.key?(:story_height) && args['custom_height_bar']
            multi_height_space_types_hash[space_type] = { floor_area: final_floor_area, space_type: space_type, story_height: hash[:story_height] }
            if hash.key?(:orig_ratio) then multi_height_space_types_hash[space_type][:orig_ratio] = hash[:orig_ratio] end
            custom_story_heights << hash[:story_height]
            if args['wwr'] == 0 && hash.key?(:wwr)
              multi_height_space_types_hash[space_type][:wwr] = hash[:wwr]
            end
          else
            # only add wwr if 0 used for wwr arg and if space type has wwr as key
            space_types_hash[space_type] = { floor_area: final_floor_area, space_type: space_type }
            if hash.key?(:orig_ratio) then space_types_hash[space_type][:orig_ratio] = hash[:orig_ratio] end
            if args['wwr'] == 0 && hash.key?(:wwr)
              space_types_hash[space_type][:wwr] = hash[:wwr]
            end
            if hash[:double_loaded_corridor]
              space_types_hash[space_type][:children] = hash[:children]
            end
          end
        end
      end

      # resort if not sorted by building type
      if args['space_type_sort_logic'] == 'Size'
        # added code to convert to hash. I use sort_by 3 other times, but those seem to be working fine as is now.
        space_types_hash = Hash[space_types_hash.sort_by { |k, v| v[:floor_area] }]
      end

      # calculate targets for testing
      target_areas = {} # used for checks
      target_areas_cust_height = 0.0
      space_types_hash.each do |k, v|
        if v.key?(:orig_ratio)
          target_areas[k] = v[:orig_ratio] * total_bldg_floor_area_si
        else
          target_areas[k] = v[:floor_area]
        end
      end
      multi_height_space_types_hash.each do |k, v|
        if v.key?(:orig_ratio)
          target_areas[k] = v[:orig_ratio] * total_bldg_floor_area_si
          target_areas_cust_height += v[:orig_ratio] * total_bldg_floor_area_si
        else
          target_areas[k] = v[:floor_area]
          target_areas_cust_height += v[:floor_area]
        end
      end

      # gather inputs
      if footprint_si.nil?
        footprint_si = (total_bldg_floor_area_si - target_areas_cust_height) / num_stories.to_f
      end
      floor_height_si = OpenStudio.convert(args['floor_height'], 'ft', 'm').get
      min_allow_size = OpenStudio.convert(15.0, 'ft', 'm').get
      specified_bar_width_si = OpenStudio.convert(args['bar_width'], 'ft', 'm').get

      # set custom width
      if specified_bar_width_si > 0
        runner.registerInfo('Ignoring perimeter multiplier argument when non zero width argument is used')
        if footprint_si / specified_bar_width_si >= min_allow_size
          width = specified_bar_width_si
          length = footprint_si / width
        else
          length = min_allow_size
          width = footprint_si / length
          runner.registerWarning('User specified width results in a length that is too short, adjusting width to be narrower than specified.')
        end
        width_cust_height = specified_bar_width_si
      else
        width = Math.sqrt(footprint_si / args['ns_to_ew_ratio'])
        length = footprint_si / width
        width_cust_height = Math.sqrt(target_areas_cust_height / args['ns_to_ew_ratio'])
      end
      length_cust_height = target_areas_cust_height / width_cust_height
      if args['perim_mult'] > 1.0 && target_areas_cust_height > 0.0
        # TODO: - update tests that hit this warning
        runner.registerWarning('Ignoring perimeter multiplier for bar that represents custom height spaces.')
      end

      # check if dual bar is needed
      dual_bar = false
      if specified_bar_width_si > 0.0 && args['bar_division_method'] == 'Multiple Space Types - Individual Stories Sliced'
        if length / width != args['ns_to_ew_ratio']

          if args['ns_to_ew_ratio'] >= 1.0 && args['ns_to_ew_ratio'] > length / width
            runner.registerWarning("Can't meet target aspect ratio of #{args['ns_to_ew_ratio']}, Lowering it to #{length / width} ")
            args['ns_to_ew_ratio'] = length / width
          elsif args['ns_to_ew_ratio'] < 1.0 && args['ns_to_ew_ratio'] > length / width
            runner.registerWarning("Can't meet target aspect ratio of #{args['ns_to_ew_ratio']}, Increasing it to #{length / width} ")
            args['ns_to_ew_ratio'] = length / width
          else
            # check if each bar would be longer then 15 feet, then set as dual bar and override perimeter multiplier
            length_alt1 = ((args['ns_to_ew_ratio'] * footprint_si) / width + 2 * args['ns_to_ew_ratio'] * width - 2 * width) / (1 + args['ns_to_ew_ratio'])
            length_alt2 = length - length_alt1
            if [length_alt1, length_alt2].min >= min_allow_size
              dual_bar = true
            else
              runner.registerInfo('Second bar would be below minimum length, will model as single bar')
              # swap length and width if single bar and aspect ratio less than 1
              if args['ns_to_ew_ratio'] < 1.0
                width = length
                length = specified_bar_width_si
              end
            end
          end
        end
      elsif args['perim_mult'] > 1.0 && args['bar_division_method'] == 'Multiple Space Types - Individual Stories Sliced'
        runner.registerInfo('You selected a perimeter multiplier greater than 1.0 for a supported bar division method. This will result in two detached rectangular buildings if secondary bar meets minimum size requirements.')
        dual_bar = true
      elsif args['perim_mult'] > 1.0
        runner.registerWarning("You selected a perimeter multiplier greater than 1.0 but didn't select a bar division method that supports this. The value for this argument will be ignored by the measure")
      end

      # calculations for dual bar, which later will be setup to run create_bar twice
      if dual_bar
        min_perim = 2 * width + 2 * length
        target_area = footprint_si
        target_perim = min_perim * args['perim_mult']
        tol_testing = 0.00001
        dual_bar_calc_approach = nil # stretched, adiabatic_ends_bar_b, dual_bar
        runner.registerInfo("Minimum rectangle is #{OpenStudio.toNeatString(OpenStudio.convert(length, 'm', 'ft').get, 0, true)} ft x #{OpenStudio.toNeatString(OpenStudio.convert(width, 'm', 'ft').get, 0, true)} ft with an area of #{OpenStudio.toNeatString(OpenStudio.convert(length * width, 'm^2', 'ft^2').get, 0, true)} ft^2. Perimeter is #{OpenStudio.toNeatString(OpenStudio.convert(min_perim, 'm', 'ft').get, 0, true)} ft.")
        runner.registerInfo("Target dual bar perimeter is #{OpenStudio.toNeatString(OpenStudio.convert(target_perim, 'm', 'ft').get, 0, true)} ft.")

        # determine which of the three paths to hit target perimeter multiplier are possible
        # A use dual bar non adiabatic
        # B use dual bar adiabatic
        # C use stretched bar (requires model to miss ns/ew ratio)

        # custom quadratic equation to solve two bars with common width 2l^2 - p*l + 4a = 0
        if target_perim**2 - 32 * footprint_si > 0
          if specified_bar_width_si > 0
            runner.registerInfo('Ignoring perimeter multiplier argument and using use specified bar width.')
            dual_double_end_width = specified_bar_width_si
            dual_double_end_length = footprint_si / dual_double_end_width
          else
            dual_double_end_length = 0.25 * (target_perim + Math.sqrt(target_perim**2 - 32 * footprint_si))
            dual_double_end_width = footprint_si / dual_double_end_length
          end

          # now that stretched  bar is made, determine where to split it and rotate
          bar_a_length = (args['ns_to_ew_ratio'] * (dual_double_end_length + dual_double_end_width) - dual_double_end_width) / (1 + args['ns_to_ew_ratio'])
          bar_b_length = dual_double_end_length - bar_a_length
          area_a = bar_a_length * dual_double_end_width
          area_b = bar_b_length * dual_double_end_width
        else
          # this will throw it to adiabatic ends test
          bar_a_length = 0
          bar_b_length = 0
        end

        if bar_a_length >= min_allow_size && bar_b_length >= min_allow_size
          dual_bar_calc_approach = 'dual_bar'
        else
          # adiabatic bar input calcs
          if target_perim**2 - 16 * footprint_si > 0
            adiabatic_dual_double_end_length = 0.25 * (target_perim + Math.sqrt(target_perim**2 - 16 * footprint_si))
            adiabatic_dual_double_end_width = footprint_si / adiabatic_dual_double_end_length
            # test for unexpected
            unexpected = false
            if (target_area - adiabatic_dual_double_end_length * adiabatic_dual_double_end_width).abs > tol_testing then unexpected = true end
            if specified_bar_width_si == 0
              if (target_perim - (adiabatic_dual_double_end_length * 2 + adiabatic_dual_double_end_width * 2)).abs > tol_testing then unexpected = true end
            end
            if unexpected
              runner.registerWarning('Unexpected values for dual rectangle adiabatic ends bar b.')
            end
            # now that stretched  bar is made, determine where to split it and rotate
            adiabatic_bar_a_length = (args['ns_to_ew_ratio'] * (adiabatic_dual_double_end_length + adiabatic_dual_double_end_width)) / (1 + args['ns_to_ew_ratio'])
            adiabatic_bar_b_length = adiabatic_dual_double_end_length - adiabatic_bar_a_length
            adiabatic_area_a = adiabatic_bar_a_length * adiabatic_dual_double_end_width
            adiabatic_area_b = adiabatic_bar_b_length * adiabatic_dual_double_end_width
          else
            # this will throw it stretched single bar
            adiabatic_bar_a_length = 0
            adiabatic_bar_b_length = 0
          end
          if adiabatic_bar_a_length >= min_allow_size && adiabatic_bar_b_length >= min_allow_size
            dual_bar_calc_approach = 'adiabatic_ends_bar_b'
          else
            dual_bar_calc_approach = 'stretched'
          end
        end

        # apply prescribed approach for stretched or dual bar
        if dual_bar_calc_approach == 'dual_bar'
          runner.registerInfo("Stretched  #{OpenStudio.toNeatString(OpenStudio.convert(dual_double_end_length, 'm', 'ft').get, 0, true)} ft x #{OpenStudio.toNeatString(OpenStudio.convert(dual_double_end_width, 'm', 'ft').get, 0, true)} ft rectangle has an area of #{OpenStudio.toNeatString(OpenStudio.convert(dual_double_end_length * dual_double_end_width, 'm^2', 'ft^2').get, 0, true)} ft^2. When split in two the perimeter will be #{OpenStudio.toNeatString(OpenStudio.convert(dual_double_end_length * 2 + dual_double_end_width * 4, 'm', 'ft').get, 0, true)} ft")
          if (target_area - dual_double_end_length * dual_double_end_width).abs > tol_testing || (target_perim - (dual_double_end_length * 2 + dual_double_end_width * 4)).abs > tol_testing
            runner.registerWarning('Unexpected values for dual rectangle.')
          end

          runner.registerInfo("For stretched split bar, to match target ns/ew aspect ratio #{OpenStudio.toNeatString(OpenStudio.convert(bar_a_length, 'm', 'ft').get, 0, true)} ft of bar should be horizontal, with #{OpenStudio.toNeatString(OpenStudio.convert(bar_b_length, 'm', 'ft').get, 0, true)} ft turned 90 degrees. Combined area is #{OpenStudio.toNeatString(OpenStudio.convert(area_a + area_b, 'm^2', 'ft^2').get, 0, true)} ft^2. Combined perimeter is #{OpenStudio.toNeatString(OpenStudio.convert(bar_a_length * 2 + bar_b_length * 2 + dual_double_end_width * 4, 'm', 'ft').get, 0, true)} ft")
          if (target_area - (area_a + area_b)).abs > tol_testing || (target_perim - (bar_a_length * 2 + bar_b_length * 2 + dual_double_end_width * 4)).abs > tol_testing
            runner.registerWarning('Unexpected values for rotated dual rectangle')
          end
        elsif dual_bar_calc_approach == 'adiabatic_ends_bar_b'
          runner.registerInfo("Can't hit target perimeter with two rectangles, need to make two ends adiabatic")

          runner.registerInfo("For dual bar with adiabatic ends on bar b, to reach target aspect ratio #{OpenStudio.toNeatString(OpenStudio.convert(adiabatic_bar_a_length, 'm', 'ft').get, 0, true)} ft of bar should be north/south, with #{OpenStudio.toNeatString(OpenStudio.convert(adiabatic_bar_b_length, 'm', 'ft').get, 0, true)} ft turned 90 degrees. Combined area is #{OpenStudio.toNeatString(OpenStudio.convert(adiabatic_area_a + adiabatic_area_b, 'm^2', 'ft^2').get, 0, true)} ft^2}. Combined perimeter is #{OpenStudio.toNeatString(OpenStudio.convert(adiabatic_bar_a_length * 2 + adiabatic_bar_b_length * 2 + adiabatic_dual_double_end_width * 2, 'm', 'ft').get, 0, true)} ft")
          if (target_area - (adiabatic_area_a + adiabatic_area_b)).abs > tol_testing || (target_perim - (adiabatic_bar_a_length * 2 + adiabatic_bar_b_length * 2 + adiabatic_dual_double_end_width * 2)).abs > tol_testing
            runner.registerWarning('Unexpected values for rotated dual rectangle adiabatic ends bar b')
          end
        else # stretched bar
          dual_bar = false

          stretched_length = 0.25 * (target_perim + Math.sqrt(target_perim**2 - 16 * footprint_si))
          stretched_width = footprint_si / stretched_length
          if (target_area - stretched_length * stretched_width).abs > tol_testing || (target_perim - (stretched_length + stretched_width) * 2) > tol_testing
            runner.registerWarning('Unexpected values for single stretched')
          end

          width = stretched_width
          length = stretched_length
          runner.registerInfo("Creating a dual bar to match the target minimum perimeter multiplier at the given aspect ratio would result in a bar with edge shorter than #{OpenStudio.toNeatString(OpenStudio.convert(min_allow_size, 'm', 'ft').get, 0, true)} ft. Will create a single stretched bar instead that hits the target perimeter with a slightly different ns/ew aspect ratio.")
        end
      end

      bars = {}
      bars['primary'] = {}
      if dual_bar
        if mirror_ns_ew && dual_bar_calc_approach == 'dual_bar'
          bars['primary'][:length] = dual_double_end_width
          bars['primary'][:width] = bar_a_length
        elsif dual_bar_calc_approach == 'dual_bar'
          bars['primary'][:length] = bar_a_length
          bars['primary'][:width] = dual_double_end_width
        elsif mirror_ns_ew
          bars['primary'][:length] = adiabatic_dual_double_end_width
          bars['primary'][:width] = adiabatic_bar_a_length
        else
          bars['primary'][:length] = adiabatic_bar_a_length
          bars['primary'][:width] = adiabatic_dual_double_end_width
        end
      else
        if mirror_ns_ew
          bars['primary'][:length] = width
          bars['primary'][:width] = length
        else
          bars['primary'][:length] = length
          bars['primary'][:width] = width
        end
      end
      bars['primary'][:floor_height_si] = floor_height_si # can make use of this when breaking out multi-height spaces
      bars['primary'][:num_stories] = num_stories
      bars['primary'][:center_of_footprint] = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
      space_types_hash_secondary = {}
      if dual_bar
        # loop through each story and move portion for other bar to its own hash
        primary_footprint = bars['primary'][:length] * bars['primary'][:width]
        secondary_footprint = target_area - primary_footprint
        footprint_counter = primary_footprint
        secondary_footprint_counter = secondary_footprint
        story_counter = 0
        pri_sec_tol = 0.0001 # m^2
        pri_sec_min_area = 0.0001 # m^2
        space_types_hash.each do |k, v|
          space_type_left = v[:floor_area]

          # do not go to next space type until this one is evaulate, which may span stories
          until space_type_left == 0.0 || story_counter >= num_stories

            # use secondary footprint if any left
            if secondary_footprint_counter > 0.0
              hash_area = [space_type_left, secondary_footprint_counter].min

              # confirm that the part of space type use or what is left is greater than min allowed value
              projected_space_type_left = space_type_left - hash_area
              test_a = hash_area >= pri_sec_min_area
              test_b = projected_space_type_left >= pri_sec_min_area || projected_space_type_left == 0.0 ? true : false
              test_c = k == space_types_hash.keys.last # if last space type accept sliver, no other space to infil
              if (test_a && test_b) || test_c
                if space_types_hash_secondary.key?(k)
                  # add to what was added for previous story
                  space_types_hash_secondary[k][:floor_area] += hash_area
                else
                  # add new space type to hash
                  if v.key?(:children)
                    space_types_hash_secondary[k] = { floor_area: hash_area, space_type: v[:space_type], children: v[:children] }
                  else
                    space_types_hash_secondary[k] = { floor_area: hash_area, space_type: v[:space_type] }
                  end
                end
                space_types_hash[k][:floor_area] -= hash_area
                secondary_footprint_counter -= hash_area
                space_type_left -= hash_area
              else
                runner.registerInfo("Shifting space types between bars to avoid sliver of #{k.name}.")
              end
            end

            # remove space if entirely used up by secondary bar
            if space_types_hash[k][:floor_area] <= pri_sec_tol
              space_types_hash.delete(k)
              space_type_left = 0.0
            else
              # then look at primary bar
              hash_area_pri = [space_type_left, footprint_counter].min
              footprint_counter -= hash_area_pri
              space_type_left -= hash_area_pri
            end

            # reset counter when full
            if footprint_counter <= pri_sec_tol && secondary_footprint_counter <= pri_sec_tol
              # check if this is partial top floor
              story_counter += 1
              if num_stories < story_counter + 1
                footprint_counter = primary_footprint * (num_stories - story_counter)
                secondary_footprint_counter = secondary_footprint * (num_stories - story_counter)
              else
                footprint_counter = primary_footprint
                secondary_footprint_counter = secondary_footprint
              end
            end
          end
        end
      end

      # setup bar_hash and run create_bar
      bars['primary'][:space_types_hash] = space_types_hash
      bars['primary'][:args] = args
      v = bars['primary']
      bar_hash_setup_run(runner, model, v[:args], v[:length], v[:width], v[:floor_height_si], v[:center_of_footprint], v[:space_types_hash], v[:num_stories])

      # store offset value for multiple bars
      if args.key?('bar_sep_dist_mult') && args['bar_sep_dist_mult'] > 0.0
        offset_val = num_stories.ceil * floor_height_si * args['bar_sep_dist_mult']
      elsif args.key?('bar_sep_dist_mult')
        runner.registerWarning('Positive value is required for bar_sep_dist_mult, ignoring input and using value of 0.1')
        offset_val = num_stories.ceil * floor_height_si * 0.1
      else
        offset_val = num_stories.ceil * floor_height_si * 10.0
      end

      if dual_bar
        args2 = args.clone
        bars['secondary'] = {}
        if mirror_ns_ew && dual_bar_calc_approach == 'dual_bar'
          bars['secondary'][:length] = bar_b_length
          bars['secondary'][:width] = dual_double_end_width
        elsif dual_bar_calc_approach == 'dual_bar'
          bars['secondary'][:length] = dual_double_end_width
          bars['secondary'][:width] = bar_b_length
        elsif mirror_ns_ew
          bars['secondary'][:length] = adiabatic_bar_b_length
          bars['secondary'][:width] = adiabatic_dual_double_end_width
          args2['party_wall_stories_east'] = num_stories.ceil
          args2['party_wall_stories_west'] = num_stories.ceil
        else
          bars['secondary'][:length] = adiabatic_dual_double_end_width
          bars['secondary'][:width] = adiabatic_bar_b_length
          args2['party_wall_stories_south'] = num_stories.ceil
          args2['party_wall_stories_north'] = num_stories.ceil
        end
        bars['secondary'][:floor_height_si] = floor_height_si # can make use of this when breaking out multi-height spaces
        bars['secondary'][:num_stories] = num_stories
        bars['secondary'][:space_types_hash] = space_types_hash_secondary
        if dual_bar_calc_approach == 'adiabatic_ends_bar_b'
          # warn that combination of dual bar with low perimeter multiplier and use of party wall may result in discrepency between target and actual adiabatic walls
          if args['party_wall_fraction'] > 0 || args['party_wall_stories_north'] > 0 || args['party_wall_stories_south'] > 0 || args['party_wall_stories_east'] > 0 || args['party_wall_stories_west'] > 0
            runner.registerWarning('The combination of low perimeter multiplier and use of non zero party wall inputs may result in discrepency between target and actual adiabatic walls. This is due to the need to create adiabatic walls on secondary bar to maintian target building perimeter.')
          else
            runner.registerInfo('Adiabatic ends added to secondary bar because target perimeter multiplier could not be met with two full rectangular footprints.')
          end
          bars['secondary'][:center_of_footprint] = OpenStudio::Point3d.new(adiabatic_bar_a_length * 0.5 + adiabatic_dual_double_end_width * 0.5 + offset_val, adiabatic_bar_b_length * 0.5 + adiabatic_dual_double_end_width * 0.5 + offset_val, 0.0)
        else
          bars['secondary'][:center_of_footprint] = OpenStudio::Point3d.new(bar_a_length * 0.5 + dual_double_end_width * 0.5 + offset_val, bar_b_length * 0.5 + dual_double_end_width * 0.5 + offset_val, 0.0)
        end
        bars['secondary'][:args] = args2

        # setup bar_hash and run create_bar
        v = bars['secondary']
        bar_hash_setup_run(runner, model, v[:args], v[:length], v[:width], v[:floor_height_si], v[:center_of_footprint], v[:space_types_hash], v[:num_stories])

      end

      # future development (up against primary bar run intersection and surface matching after add all bars, avoid interior windows)
      # I could loop through each space type and give them unique height but for now will just take largest height and make bar of that height, which is fine for prototypes
      if !multi_height_space_types_hash.empty?
        args3 = args.clone
        bars['custom_height'] = {}
        if mirror_ns_ew
          bars['custom_height'][:length] = width_cust_height
          bars['custom_height'][:width] = length_cust_height
        else
          bars['custom_height'][:length] = length_cust_height
          bars['custom_height'][:width] = width_cust_height
        end
        if args['party_wall_stories_east'] + args['party_wall_stories_west'] + args['party_wall_stories_south'] + args['party_wall_stories_north'] > 0.0
          runner.registerWarning('Ignorning party wall inputs for custom height bar')
        end

        # disable party walls
        args3['party_wall_stories_east'] = 0
        args3['party_wall_stories_west'] = 0
        args3['party_wall_stories_south'] = 0
        args3['party_wall_stories_north'] = 0

        # setup stories
        args3['num_stories_below_grade'] = 0
        args3['num_stories_above_grade'] = 1

        bars['custom_height'][:floor_height_si] = floor_height_si # can make use of this when breaking out multi-height spaces
        bars['custom_height'][:num_stories] = num_stories
        bars['custom_height'][:center_of_footprint] = OpenStudio::Point3d.new(bars['primary'][:length] * -0.5 - length_cust_height * 0.5 - offset_val, 0.0, 0.0)
        bars['custom_height'][:floor_height_si] = OpenStudio.convert(custom_story_heights.max, 'ft', 'm').get
        bars['custom_height'][:num_stories] = 1
        bars['custom_height'][:space_types_hash] = multi_height_space_types_hash
        bars['custom_height'][:args] = args3

        v = bars['custom_height']
        bar_hash_setup_run(runner, model, v[:args], v[:length], v[:width], v[:floor_height_si], v[:center_of_footprint], v[:space_types_hash], v[:num_stories])
      end

      # diagnostic log
      sum_actual = 0.0
      sum_target = 0.0
      throw_error = false

      # check expected floor areas against actual
      model.getSpaceTypes.sort.each do |space_type|
        next if !target_areas.key? space_type # space type in model not part of building type(s), maybe issue warning

        # convert to IP
        actual_ip = OpenStudio.convert(space_type.floorArea, 'm^2', 'ft^2').get
        target_ip = OpenStudio.convert(target_areas[space_type], 'm^2', 'ft^2').get
        sum_actual += actual_ip
        sum_target += target_ip

        if (space_type.floorArea - target_areas[space_type]).abs >= 1.0

          if !args['bar_division_method'].include? 'Single Space Type'
            runner.registerError("#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
            throw_error = true
          else
            # will see this if use Single Space type division method on multi-use building or single building type without whole building space type
            runner.registerWarning("#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
          end

        end
      end

      # report summary then throw error
      if throw_error
        runner.registerError("Sum of actual floor area is #{sum_actual} ft^2, sum of target floor area is #{sum_target}.")
        return false
      end

      # check party wall fraction by looping through surfaces
      if args['party_wall_fraction'] > 0
        actual_ext_wall_area = model.getBuilding.exteriorWallArea
        actual_party_wall_area = 0.0
        model.getSurfaces.sort.each do |surface|
          next if surface.outsideBoundaryCondition != 'Adiabatic'
          next if surface.surfaceType != 'Wall'

          actual_party_wall_area += surface.grossArea * surface.space.get.multiplier
        end
        actual_party_wall_fraction = actual_party_wall_area / (actual_party_wall_area + actual_ext_wall_area)
        runner.registerInfo("Target party wall fraction is #{args['party_wall_fraction']}. Realized fraction is #{actual_party_wall_fraction.round(2)}")
        runner.registerValue('party_wall_fraction_actual', actual_party_wall_fraction)
      end

      # check ns/ew aspect ratio (harder to check when party walls are added)
      wall_and_window_by_orientation = OsLib_Geometry.getExteriorWindowAndWllAreaByOrientation(model, model.getSpaces)
      wall_ns = (wall_and_window_by_orientation['northWall'] + wall_and_window_by_orientation['southWall'])
      wall_ew = wall_and_window_by_orientation['eastWall'] + wall_and_window_by_orientation['westWall']
      wall_ns_ip = OpenStudio.convert(wall_ns, 'm^2', 'ft^2').get
      wall_ew_ip = OpenStudio.convert(wall_ew, 'm^2', 'ft^2').get
      runner.registerValue('wall_area_ip', wall_ns_ip + wall_ew_ip, 'ft^2')
      runner.registerValue('ns_wall_area_ip', wall_ns_ip, 'ft^2')
      runner.registerValue('ew_wall_area_ip', wall_ew_ip, 'ft^2')
      # for now using perimeter of ground floor and average story area (building area / num_stories)
      runner.registerValue('floor_area_to_perim_ratio', model.getBuilding.floorArea / (OsLib_Geometry.calculate_perimeter(model) * num_stories))
      runner.registerValue('bar_width', OpenStudio.convert(bars['primary'][:width], 'm', 'ft').get, 'ft')

      if args['party_wall_fraction'] > 0 || args['party_wall_stories_north'] > 0 || args['party_wall_stories_south'] > 0 || args['party_wall_stories_east'] > 0 || args['party_wall_stories_west'] > 0
        runner.registerInfo('Target facade area by orientation not validated when party walls are applied')
      elsif args['num_stories_above_grade'] != args['num_stories_above_grade'].ceil
        runner.registerInfo('Target facade area by orientation not validated when partial top story is used')
      elsif dual_bar_calc_approach == 'stretched'
        runner.registerInfo('Target facade area by orientation not validated when single stretched bar has to be used to meet target minimum perimeter multiplier')
      elsif defaulted_args.include?('floor_height') && args['custom_height_bar'] && !multi_height_space_types_hash.empty?
        runner.registerInfo('Target facade area by orientation not validated when a dedicated bar is added for space types with custom heights')
      elsif args['bar_width'] > 0
        runner.registerInfo('Target facade area by orientation not validated when a dedicated custom bar width is defined')
      else

        # adjust length versus width based on building rotation
        if mirror_ns_ew
          wall_target_ns_ip = 2 * OpenStudio.convert(width, 'm', 'ft').get * args['perim_mult'] * args['num_stories_above_grade'] * args['floor_height']
          wall_target_ew_ip = 2 * OpenStudio.convert(length, 'm', 'ft').get * args['perim_mult'] * args['num_stories_above_grade'] * args['floor_height']
        else
          wall_target_ns_ip = 2 * OpenStudio.convert(length, 'm', 'ft').get * args['perim_mult'] * args['num_stories_above_grade'] * args['floor_height']
          wall_target_ew_ip = 2 * OpenStudio.convert(width, 'm', 'ft').get  * args['perim_mult'] * args['num_stories_above_grade'] * args['floor_height']
        end
        flag_error = false
        if (wall_target_ns_ip - wall_ns_ip).abs > 0.1
          runner.registerError("North/South walls don't have the expected area (actual #{OpenStudio.toNeatString(wall_ns_ip, 4, true)} ft^2, target #{OpenStudio.toNeatString(wall_target_ns_ip, 4, true)} ft^2)")
          flag_error = true
        end
        if (wall_target_ew_ip - wall_ew_ip).abs > 0.1
          runner.registerError("East/West walls don't have the expected area (actual #{OpenStudio.toNeatString(wall_ew_ip, 4, true)} ft^2, target #{OpenStudio.toNeatString(wall_target_ew_ip, 4, true)} ft^2)")
          flag_error = true
        end
        if flag_error
          return false
        end
      end

      # test for excessive exterior roof area (indication of problem with intersection and or surface matching)
      ext_roof_area = model.getBuilding.exteriorSurfaceArea - model.getBuilding.exteriorWallArea
      expected_roof_area = args['total_bldg_floor_area'] / (args['num_stories_above_grade'] + args['num_stories_below_grade']).to_f
      if ext_roof_area > expected_roof_area && single_floor_area_si == 0.0 # only test if using whole-building area input
        runner.registerError('Roof area larger than expected, may indicate problem with inter-floor surface intersection or matching.')
        return false
      end

      # set building rotation
      initial_rotation = model.getBuilding.northAxis
      if args['building_rotation'] != initial_rotation
        model.getBuilding.setNorthAxis(args['building_rotation'])
        runner.registerInfo("Set Building Rotation to #{model.getBuilding.northAxis}. Rotation altered after geometry generation is completed, as a result party wall orientation and aspect ratio may not reflect input values.")
      end

      # report final condition of model
      runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

      return true
    end
  end
end
