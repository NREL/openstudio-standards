module OpenstudioStandards
  # The CreateTypical module provides methods to create and modify an entire building energy model of a typical building
  module CreateTypical
    # @!group Space Type Blending
    # Methods to blend space types together

    # get all loads for a space or space type and place in hash by type
    #
    # @param space_or_space_type [OpenStudio::Model::Space, OpenStuido::Model::SpaceType] OpenStudio Space or SpaceType object
    # @return [Hash] Hash of internal load properties
    def self.space_or_space_type_gather_internal_loads(space_or_space_type)
      internal_load_hash = {}

      # gather different load types (all vectors except dsoa which will be turned into an array)
      internal_load_hash[:internal_mass] = space_or_space_type.internalMass
      internal_load_hash[:people] = space_or_space_type.people
      internal_load_hash[:lights] = space_or_space_type.lights
      internal_load_hash[:luminaires] = space_or_space_type.luminaires
      internal_load_hash[:electric_equipment] = space_or_space_type.electricEquipment
      internal_load_hash[:gas_equipment] = space_or_space_type.gasEquipment
      internal_load_hash[:hot_water_equipment] = space_or_space_type.hotWaterEquipment
      internal_load_hash[:steam_equipment] = space_or_space_type.steamEquipment
      internal_load_hash[:other_equipment] = space_or_space_type.otherEquipment
      internal_load_hash[:space_infiltration_design_flow_rates] = space_or_space_type.spaceInfiltrationDesignFlowRates
      internal_load_hash[:space_infiltration_effective_leakage_areas] = space_or_space_type.spaceInfiltrationEffectiveLeakageAreas
      if space_or_space_type.designSpecificationOutdoorAir.nil?
        internal_load_hash[:design_specification_outdoor_air] = []
      else
        internal_load_hash[:design_specification_outdoor_air] = [space_or_space_type.designSpecificationOutdoorAir]
      end
      if space_or_space_type.class.to_s == 'OpenStudio::Model::Space'
        internal_load_hash[:water_use_equipment] = space_or_space_type.waterUseEquipment # don't think this reports
        internal_load_hash[:daylighting_controls] = space_or_space_type.daylightingControls
      end

      # @todo warn if daylighting controls in spaces (should I alter fraction controled based on lighting per area ratio)

      return internal_load_hash
    end

    # blend_space_types_from_floor_area_ratio used when working from space type ratio and un-assigned space types
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param space_type_ratio_hash [Hash] Hash where the keys are OpenStudio SpaceType objects and hash includes the floor area ratio
    # @option space_type_ratio_hash [Double] :floor_area_ratio
    # @return [OpenStudio::Model::SpaceType] Blended OpenStudio SpaceType object
    def self.blend_space_types_from_floor_area_ratio(model, space_type_ratio_hash)
      # create stub blended space type
      blended_space_type = OpenStudio::Model::SpaceType.new(model)
      blended_space_type.setName('Blended Space Type')

      # @todo inspect people instances and see if any defs are not normalized per area. If find any issue warning

      # gather inputs
      sum_of_num_people_per_m_2 = 0.0
      space_type_ratio_hash.each do |space_type, ratios|
        # get number of peple per m 2 for space type. Can do this without looking at instances
        sum_of_num_people_per_m_2 += space_type.getPeoplePerFloorArea(1.0)
      end

      # raw num_people_ratios
      sum_area_adj_num_people_ratio = 0.0
      space_type_ratio_hash.each do |space_type, ratios|
        # calculate num_people_ratios
        area_adj_num_people_ratio = (space_type.getPeoplePerFloorArea(1.0) / sum_of_num_people_per_m_2) * ratios[:floor_area_ratio]
        sum_area_adj_num_people_ratio += area_adj_num_people_ratio
      end

      # set ratios
      largest_space_type = nil
      largest_space_type_ratio = 0.00
      space_type_ratio_hash.each do |space_type, ratios|
        # calculate num_people_ratios
        area_adj_num_people_ratio = (space_type.getPeoplePerFloorArea(1.0) / sum_of_num_people_per_m_2) * ratios[:floor_area_ratio]
        normalized_area_adj_num_people_ratio = area_adj_num_people_ratio / sum_area_adj_num_people_ratio

        # ratios[:floor_area_ratio] is already defined
        ratios[:num_people_ratio] = normalized_area_adj_num_people_ratio.round(4)
        ratios[:ext_surface_area_ratio] = ratios[:floor_area_ratio]
        ratios[:ext_wall_area_ratio] = ratios[:floor_area_ratio]
        ratios[:volume_ratio] = ratios[:floor_area_ratio]

        # update largest space type values
        if largest_space_type.nil? || ratios[:floor_area_ratio] > largest_space_type_ratio
          largest_space_type = space_type
          largest_space_type_ratio = ratios[:floor_area_ratio]
        end
      end

      if largest_space_type.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Didn't find any space types in model matching user argument string.")
        return false
      end

      # set standards info for space type based on largest ratio (for use to apply HVAC system)
      standards_building_type = largest_space_type.standardsBuildingType
      standards_space_type = largest_space_type.standardsSpaceType
      if standards_building_type.is_initialized
        blended_space_type.setStandardsBuildingType(standards_building_type.get)
      end
      if standards_space_type.is_initialized
        blended_space_type.setStandardsSpaceType(standards_space_type.get)
      end

      # loop therough space types to get instances from and then remove
      space_type_ratio_hash.each do |space_type, ratios|
        # blend internal loads (nil is space_hash)
        space_type_load_instances = OpenstudioStandards::CreateTypical.blend_internal_loads(model, space_type, blended_space_type, ratios, model.getBuilding.floorArea, nil)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Blending #{space_type.name.get} with floor area ratio of #{ratios[:floor_area_ratio]} and number of people ratio of #{ratios[:num_people_ratio]}.")

        # delete space type. Don't want to leave in model since internal loads have been removed from it
        space_type.remove
      end

      return blended_space_type
    end

    # takes in space type hash where each hash value is a collection of space types. Each collection is blended into it's own space type
    # If key for any collection is "Building" it will also opererate on spaces that don't have space type assigned
    # where a space assigned to a space type from a collection has space loads, those space loads are normalized and added to the blended space type
    # load instances are maintained so that they can haave unique schedules, and can have EE measures selectivly applied.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param space_type_hash [Hash] Hash of space type information
    # @return [Array<OpenStudio::Model::SpaceType>] Array of OpenStudio SpaceType objects
    def self.blend_space_type_collections(model, space_type_hash)
      # loop through building type hash to create multiple blends
      space_type_hash.each do |collection_name, space_types|
        if collection_name == 'Building'
          space_array = model.getSpaces.sort # use all space types, not just space types passed in
        else
          space_array = []
          space_types.each do |space_type|
            space_array.concat(space_type.spaces)
          end
        end

        # calculate metrics for all spaces included in building area to pass into space_type and space hash
        # @note in the future this may be a subset of spaces if blending into multiple space types vs. just one.
        collection_totals = {}
        collection_totals[:floor_area] = 0.0
        collection_totals[:num_people] = 0.0
        collection_totals[:ext_surface_area] = 0.0
        collection_totals[:ext_wall_area] = 0.0
        collection_totals[:volume] = 0.0
        space_array.each do |space|
          next if !space.partofTotalFloorArea

          collection_totals[:floor_area] += space.floorArea * space.multiplier
          collection_totals[:num_people] += space.numberOfPeople * space.multiplier
          collection_totals[:ext_surface_area] += space.exteriorArea * space.multiplier
          collection_totals[:ext_wall_area] += space.exteriorWallArea * space.multiplier
          collection_totals[:volume] += space.volume * space.multiplier
        end
        area_ip = OpenStudio.convert(collection_totals[:floor_area], 'm^2', 'ft^2').get
        area_ip_neat = OpenStudio.toNeatString(area_ip, 2, true)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "#{collection_name} area is #{area_ip_neat} ft^2, number of people is #{collection_totals[:num_people].round(0)}.")

        # create hash of space types and floor area for all space types with area > 0 when spaces included in floor area
        # code to gather space type areas came from openstudio_results measure.
        space_type_hash = {}
        largest_space_type = nil
        largest_space_type_ratio = 0.00
        space_types.each do |space_type|
          next if space_type.floorArea == 0

          space_type_totals = {}
          space_type_totals[:floor_area] = 0.0
          space_type_totals[:num_people] = 0.0
          space_type_totals[:ext_surface_area] = 0.0
          space_type_totals[:ext_wall_area] = 0.0
          space_type_totals[:volume] = 0.0
          # loop through spaces so I can skip if not included in floor area
          space_type.spaces.each do |space|
            next if !space.partofTotalFloorArea

            space_type_totals[:floor_area] += space.floorArea * space.multiplier
            space_type_totals[:num_people] += space.numberOfPeople * space.multiplier
            space_type_totals[:ext_surface_area] += space.exteriorArea * space.multiplier
            space_type_totals[:ext_wall_area] += space.exteriorWallArea * space.multiplier
            space_type_totals[:volume] += space.volume * space.multiplier
          end

          # update largest space type values
          if largest_space_type.nil? || space_type_totals[:floor_area] > largest_space_type_ratio
            largest_space_type = space_type
            largest_space_type_ratio = space_type_totals[:floor_area]
          end

          # gather internal loads
          space_type_loads_hash = OpenstudioStandards::CreateTypical.space_or_space_type_gather_internal_loads(space_type)

          # don't add to hash if no spaces used for space type are included in building area (e.g. plenum and attic)
          # @todo log these and decide what to do for them. Leave loads alone or remove, do they add to blend at all?
          next if space_type_totals[:floor_area] == 0

          if !space_type_totals[:floor_area] = space_type.floorArea
            # @todo not sure if these would ever show as different
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Some but not all spaces of #{space_type.name} space type are not included in the building floor area. May have unexpected results")
          end

          # populate space type hash
          space_type_hash[space_type] = { int_loads: space_type_loads_hash, totals: space_type_totals }
        end

        # report initial condition of model
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "#{collection_name} accounts for #{space_type_hash.size} space types.")

        if collection_name == 'Building'
          # count area of spaces that have no space type
          no_space_type_area_counter = 0
          model.getSpaces.sort.each do |space|
            if space.spaceType.empty?
              next if !space.partofTotalFloorArea

              no_space_type_area_counter += space.floorArea * space.multiplier
            end
          end
          floor_area_ratio = no_space_type_area_counter / collection_totals[:floor_area]
          if floor_area_ratio > 0
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "#{floor_area_ratio} fraction of building area is composed of spaces without space type assignments.")
          end
        end

        # report the space ratio for hard spaces
        space_hash = {}
        space_array.each do |space|
          next if !space.partofTotalFloorArea

          space_loads_hash = OpenstudioStandards::CreateTypical.space_or_space_type_gather_internal_loads(space)
          space_totals = {}
          space_totals[:floor_area] = space.floorArea * space.multiplier
          space_totals[:num_people] = space.numberOfPeople * space.multiplier
          space_totals[:ext_surface_area] = space.exteriorArea * space.multiplier
          space_totals[:ext_wall_area] = space.exteriorWallArea * space.multiplier
          space_totals[:volume] = space.volume * space.multiplier
          if !space_loads_hash[:daylighting_controls].empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "#{space.name} has one or more daylighting controls. Lighting loads from blended space type may affect lighting reduction from daylighting controls.")
          end
          if !space_loads_hash[:water_use_equipment].empty?
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "One or more water use equipment objects are associated with space #{space.name}. This can't be moved to a space type.")
          end
          # @note If generating ratios without geometry can calculate people_ratio given space_types floor_area_ratio
          space_hash[space] = { int_loads: space_loads_hash, totals: space_totals }
        end

        # create stub blended space type
        blended_space_type = OpenStudio::Model::SpaceType.new(model)
        blended_space_type.setName("#{collection_name} Blended Space Type")

        # set standards info for space type based on largest ratio (for use to apply HVAC system)
        standards_building_type = largest_space_type.standardsBuildingType
        standards_space_type = largest_space_type.standardsSpaceType
        if standards_building_type.is_initialized
          blended_space_type.setStandardsBuildingType(standards_building_type.get)
        end
        if standards_space_type.is_initialized
          blended_space_type.setStandardsSpaceType(standards_space_type.get)
        end

        # values from collection hash
        collection_floor_area = collection_totals[:floor_area]
        collection_num_people = collection_totals[:num_people]
        collection_ext_surface_area = collection_totals[:ext_surface_area]
        collection_ext_wall_area = collection_totals[:ext_wall_area]
        collection_volume = collection_totals[:volume]

        # loop through space that have one or more spaces included in the building area
        space_type_hash.each do |space_type, hash|
          # hard assign space load schedules before re-assign instances to blended space type
          space_type.hardApplySpaceLoadSchedules

          # vaules from space or space_type
          floor_area = hash[:totals][:floor_area]
          num_people = hash[:totals][:num_people]
          ext_surface_area = hash[:totals][:ext_surface_area]
          ext_wall_area = hash[:totals][:ext_wall_area]
          volume = hash[:totals][:volume]

          # ratios
          ratios = {}
          if collection_floor_area > 0
            ratios[:floor_area_ratio] = floor_area / collection_floor_area
          else
            ratios[:floor_area_ratio] = 0.0
          end
          if collection_num_people > 0
            ratios[:num_people_ratio] = num_people / collection_num_people
          else
            ratios[:num_people_ratio] = 0.0
          end
          if collection_ext_surface_area > 0
            ratios[:ext_surface_area_ratio] = ext_surface_area / collection_ext_surface_area
          else
            ratios[:ext_surface_area_ratio] = 0.0
          end
          if collection_ext_wall_area > 0
            ratios[:ext_wall_area_ratio] = ext_wall_area / collection_ext_wall_area
          else
            ratios[:ext_wall_area_ratio] = 0.0
          end
          if collection_volume > 0
            ratios[:volume_ratio] = volume / collection_volume
          else
            ratios[:volume_ratio] = 0.0
          end

          # populate blended space type with space type loads
          space_type_load_instances = OpenstudioStandards::CreateTypical.blend_internal_loads(model, space_type, blended_space_type, ratios, collection_floor_area, space_hash)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Blending space type #{space_type.name}. Floor area ratio is #{(hash[:totals][:floor_area] / collection_totals[:floor_area]).round(3)}. People ratio is #{(hash[:totals][:num_people] / collection_totals[:num_people]).round(3)}")

          # hard assign any constructions assigned by space types, except for space not included in the building area
          if space_type.defaultConstructionSet.is_initialized
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Hard assigning constructions for #{space_type.name}.")
            space_type.spaces.each(&:hardApplyConstructions)
          end

          # remove all space type assignments, except for spaces not included in building area.
          space_type.spaces.each do |space|
            next if !space.partofTotalFloorArea

            space.resetSpaceType
          end

          # delete space type. Don't want to leave in model since internal loads  have been removed from it
          space_type.remove
        end

        # loop through spaces that are included in building area
        space_hash.each do |space, hash|
          # hard assign space load schedules before re-assign instances to blended space type
          space.hardApplySpaceLoadSchedules

          # vaules from space or space_type
          floor_area = hash[:totals][:floor_area]
          num_people = hash[:totals][:num_people]
          ext_surface_area = hash[:totals][:ext_surface_area]
          ext_wall_area = hash[:totals][:ext_wall_area]
          volume = hash[:totals][:volume]

          # ratios
          ratios = {}
          if collection_floor_area > 0
            ratios[:floor_area_ratio] = floor_area / collection_floor_area
          else
            ratios[:floor_area_ratio] = 0.0
          end
          if collection_num_people > 0
            ratios[:num_people_ratio] = num_people / collection_num_people
          else
            ratios[:num_people_ratio] = 0.0
          end
          if collection_ext_surface_area > 0
            ratios[:ext_surface_area_ratio] = ext_surface_area / collection_ext_surface_area
          else
            ratios[:ext_surface_area_ratio] = 0.0
          end
          if collection_ext_wall_area > 0
            ratios[:ext_wall_area_ratio] = ext_wall_area / collection_ext_wall_area
          else
            ratios[:ext_wall_area_ratio] = 0.0
          end
          if collection_volume > 0
            ratios[:volume_ratio] = volume / collection_volume
          else
            ratios[:volume_ratio] = 0.0
          end

          # populate blended space type with space loads
          space_load_instances = OpenstudioStandards::CreateTypical.blend_internal_loads(model, space, blended_space_type, ratios, collection_floor_area, space_hash)
          next if space_load_instances.empty?

          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Blending space #{space.name}. Floor area ratio is #{(hash[:totals][:floor_area] / collection_totals[:floor_area]).round(3)}. People ratio is #{(hash[:totals][:num_people] / collection_totals[:num_people]).round(3)}")
        end

        if collection_name == 'Building'
          # assign blended space type to building
          model.getBuilding.setSpaceType(blended_space_type)
          building_space_type = model.getBuilding.spaceType
        else
          space_array.each do |space|
            space.setSpaceType(blended_space_type)
          end
        end
      end

      return model.getSpaceTypes.sort
    end

    # blend internal loads used when working from existing model
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param source_space_or_space_type [OpenStudio::Model::Space, OpenStuido::Model::SpaceType] OpenStudio Space or SpaceType object
    # @param target_space_type [OpenStuido::Model::SpaceType] target OpenStudio SpaceType object
    # @param ratios [Hash] Hash of ratios
    # @option ratios [Double] :floor_area_ratio
    # @option ratios [Double] :num_people_ratio
    # @option ratios [Double] :ext_surface_area_ratio
    # @option ratios [Double] :ext_wall_area_ratio
    # @option ratios [Double] :volume_ratio
    # @param collection_floor_area [Double] floor area in m^2
    # @param space_hash [Hash] has of space load properties with space_hash[space] = { int_loads: space_loads_hash, totals: space_totals }
    # @return [Array<OpenStudio::Model::SpaceLoad>] Array of OpenStudio SpaceLoad objects
    def self.blend_internal_loads(model, source_space_or_space_type, target_space_type, ratios, collection_floor_area, space_hash)
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', 'WARNING: This method blends space types together. We recommend against blending space types. Blending space types averages internal loads that determine peak loads and therefore HVAC sizing. DO NOT use this method across thermal zones coupled with autosized HVAC.')

      # ratios
      floor_area_ratio = ratios[:floor_area_ratio]
      num_people_ratio = ratios[:num_people_ratio]
      ext_surface_area_ratio = ratios[:ext_surface_area_ratio]
      ext_wall_area_ratio = ratios[:ext_wall_area_ratio]
      volume_ratio = ratios[:volume_ratio]

      # for normalizing design level loads I need to know effective number of spaces instance is applied to
      if source_space_or_space_type.to_Space.is_initialized
        eff_num_spaces = source_space_or_space_type.multiplier
      else
        eff_num_spaces = 0
        source_space_or_space_type.spaces.each do |space|
          eff_num_spaces += space.multiplier
        end
      end

      # array of load instacnes re-assigned to blended space
      instances_array = []

      # internal_mass
      source_space_or_space_type.internalMass.each do |load_inst|
        load_def = load_inst.definition.to_InternalMassDefinition.get
        if load_def.surfaceArea.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_InternalMass.get
            orig_design_level = cloned_load_def.surfaceArea.get
            cloned_load_def.setSurfaceAreaperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} m^2.")
            load_inst.setInternalMassDefinition(cloned_load_def)
          end
        elsif load_def.surfaceAreaperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.surfaceAreaperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # people
      source_space_or_space_type.people.each do |load_inst|
        load_def = load_inst.definition.to_PeopleDefinition.get
        if load_def.numberofPeople.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_PeopleDefinition.get
            orig_design_level = cloned_load_def.numberofPeople.get
            cloned_load_def.setPeopleperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} people.")
            load_inst.setPeopleDefinition(cloned_load_def)
          end
        elsif load_def.peopleperSpaceFloorArea.is_initialized || load_def.spaceFloorAreaperPerson.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # lights
      source_space_or_space_type.lights.each do |load_inst|
        load_def = load_inst.definition.to_LightsDefinition.get
        if load_def.lightingLevel.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_LightsDefinition.get
            orig_design_level = cloned_load_def.lightingLevel.get
            cloned_load_def.setWattsperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} W.")
            load_inst.setLightsDefinition(cloned_load_def)
          end
        elsif load_def.wattsperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.wattsperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # luminaires
      source_space_or_space_type.luminaires.each do |load_inst|
        # @todo can't normalize luminaire. Replace it with similar normalized lights def and instance
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't area normalize luminaire. Instance will be applied to every space using the blended space type")
        instances_array << load_inst
      end

      # electric_equipment
      source_space_or_space_type.electricEquipment.each do |load_inst|
        load_def = load_inst.definition.to_ElectricEquipmentDefinition.get
        if load_def.designLevel.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_ElectricEquipmentDefinition.get
            orig_design_level = cloned_load_def.designLevel.get
            cloned_load_def.setWattsperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} W.")
            load_inst.setElectricEquipmentDefinition(cloned_load_def)
          end
        elsif load_def.wattsperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.wattsperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # gas_equipment
      source_space_or_space_type.gasEquipment.each do |load_inst|
        load_def = load_inst.definition.to_GasEquipmentDefinition.get
        if load_def.designLevel.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_GasEquipmentDefinition.get
            orig_design_level = cloned_load_def.designLevel.get
            cloned_load_def.setWattsperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} W.")
            load_inst.setGasEquipmentDefinition(cloned_load_def)
          end
        elsif load_def.wattsperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.wattsperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # hot_water_equipment
      source_space_or_space_type.hotWaterEquipment.each do |load_inst|
        load_def = load_inst.definition.to_HotWaterDefinition.get
        if load_def.designLevel.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_HotWaterEquipmentDefinition.get
            orig_design_level = cloned_load_def.designLevel.get
            cloned_load_def.setWattsperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} W.")
            load_inst.setHotWaterEquipmentDefinition(cloned_load_def)
          end
        elsif load_def.wattsperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.wattsperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # steam_equipment
      source_space_or_space_type.steamEquipment.each do |load_inst|
        load_def = load_inst.definition.to_SteamDefinition.get
        if load_def.designLevel.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_SteamEquipmentDefinition.get
            orig_design_level = cloned_load_def.designLevel.get
            cloned_load_def.setWattsperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} W.")
            load_inst.setSteamEquipmentDefinition(cloned_load_def)
          end
        elsif load_def.wattsperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.wattsperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # other_equipment
      source_space_or_space_type.otherEquipment.each do |load_inst|
        load_def = load_inst.definition.to_OtherDefinition.get
        if load_def.designLevel.is_initialized
          # edit and assign a clone of definition and normalize per area based on floor area ratio
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            cloned_load_def = load_def.clone(model).to_OtherEquipmentDefinition.get
            orig_design_level = cloned_load_def.designLevel.get
            cloned_load_def.setWattsperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            cloned_load_def.setName("#{cloned_load_def.name} - pre-normalized value was #{orig_design_level.round} W.")
            load_inst.setOtherEquipmentDefinition(cloned_load_def)
          end
        elsif load_def.wattsperSpaceFloorArea.is_initialized
          load_inst.setMultiplier(load_inst.multiplier * floor_area_ratio)
        elsif load_def.wattsperPerson.is_initialized
          if num_people_ratio.nil?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{load_def} has value defined per person, but people ratio wasn't passed in")
            return false
          else
            load_inst.setMultiplier(load_inst.multiplier * num_people_ratio)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_def.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # space_infiltration_design_flow_rates
      source_space_or_space_type.spaceInfiltrationDesignFlowRates.each do |load_inst|
        case load_inst.designFlowRateCalculationMethod
        when 'Flow/Space'
          # edit load so normalized for building area
          if collection_floor_area == 0
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't determine building floor area to normalize #{load_def}. #{load_inst} will be asigned the the blended space without altering its values.")
          else
            orig_design_level = load_inst.designFlowRate.get
            load_inst.setFlowperSpaceFloorArea(eff_num_spaces * orig_design_level / collection_floor_area)
            load_inst.setName("#{load_inst.name} -  pre-normalized value was #{orig_design_level} m^3/sec")
          end
        when 'Flow/Area'
          load_inst.setFlowperSpaceFloorArea(load_inst.flowperSpaceFloorArea.get * floor_area_ratio)
        when 'Flow/ExteriorArea'
          load_inst.setFlowperExteriorSurfaceArea(load_inst.flowperExteriorSurfaceArea.get * ext_surface_area_ratio)
        when 'Flow/ExteriorWallArea'
          load_inst.setFlowperExteriorWallArea(load_inst.flowperExteriorWallArea.get * ext_wall_area_ratio)
        when 'AirChanges/Hour'
          load_inst.setAirChangesperHour(load_inst.airChangesperHour.get * volume_ratio)
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Unexpected value type for #{load_inst.name}")
          return false
        end
        load_inst.setSpaceType(target_space_type)
        instances_array << load_inst
      end

      # space_infiltration_effective_leakage_areas
      source_space_or_space_type.spaceInfiltrationEffectiveLeakageAreas.each do |load|
        # @todo can't normalize space_infiltration_effective_leakage_areas. Come up with logic to address this
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't area normalize space_infiltration_effective_leakage_areas. It will be applied to every space using the blended space type")
        load.setSpaceType(target_space_type)
        instances_array << load
      end

      # add OA object if it doesn't already exist
      if target_space_type.designSpecificationOutdoorAir.is_initialized
        blended_oa = target_space_type.designSpecificationOutdoorAir.get
      else
        blended_oa = OpenStudio::Model::DesignSpecificationOutdoorAir.new(model)
        blended_oa.setName('Blended OA')
        blended_oa.setOutdoorAirMethod('Sum')
        target_space_type.setDesignSpecificationOutdoorAir(blended_oa)
        instances_array << blended_oa
      end

      # update OA object
      if source_space_or_space_type.designSpecificationOutdoorAir.is_initialized
        oa = source_space_or_space_type.designSpecificationOutdoorAir.get
        oa_sch = nil
        if oa.outdoorAirFlowRateFractionSchedule.is_initialized
          # @todo improve logic to address multiple schedules
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Schedule #{oa.outdoorAirFlowRateFractionSchedule.get.name} assigned to #{oa.name} will be ignored. New OA object will not have a schedule assigned")
        end
        if oa.outdoorAirMethod == 'Maximum'
          # @todo  see if way to address this by pre-calculating the max and only entering that value for space type
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Outdoor air method of Maximum will be ignored for #{oa.name}. New OA object will have outdoor air method of Sum.")
        end
        # adjusted ratios for oa (lowered for space type if there is hard assigned oa load for one or more spaces)
        oa_floor_area_ratio = floor_area_ratio
        oa_num_people_ratio = num_people_ratio
        if source_space_or_space_type.class.to_s == 'OpenStudio::Model::SpaceType'
          source_space_or_space_type.spaces.each do |space|
            if !space.isDesignSpecificationOutdoorAirDefaulted
              if space_hash.nil?
                OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', 'No space_hash passed in and model has OA designed at space level.')
              else
                oa_floor_area_ratio -= space_hash[space][:floor_area_ratio]
                oa_num_people_ratio -= space_hash[space][:num_people_ratio]
              end
            end
          end
        end
        # add to values of blended OA load
        if oa.outdoorAirFlowperPerson > 0
          blended_oa.setOutdoorAirFlowperPerson(blended_oa.outdoorAirFlowperPerson + (oa.outdoorAirFlowperPerson * oa_num_people_ratio))
        end
        if oa.outdoorAirFlowperFloorArea > 0
          blended_oa.setOutdoorAirFlowperFloorArea(blended_oa.outdoorAirFlowperFloorArea + (oa.outdoorAirFlowperFloorArea * oa_floor_area_ratio))
        end
        if oa.outdoorAirFlowRate > 0

          # calculate quantity for instance (doesn't exist as a method in api)
          if source_space_or_space_type.class.to_s == 'OpenStudio::Model::SpaceType'
            quantity = 0
            source_space_or_space_type.spaces.each do |space|
              if !space.isDesignSpecificationOutdoorAirDefaulted
                quantity += space.multiplier
              end
            end
          else
            quantity = source_space_or_space_type.multiplier
          end

          # can't normalize air flow rate, convert to air flow rate per floor area
          blended_oa.setOutdoorAirFlowperFloorArea(blended_oa.outdoorAirFlowperFloorArea + (quantity * oa.outdoorAirFlowRate / collection_floor_area))
        end
        if oa.outdoorAirFlowAirChangesperHour > 0
          # floor area should be good approximation of area for multiplier
          blended_oa.setOutdoorAirFlowAirChangesperHour(blended_oa.outdoorAirFlowAirChangesperHour + (oa.outdoorAirFlowAirChangesperHour * oa_floor_area_ratio))
        end
      end

      # @note water_use_equipment can't be assigned to a space type. Leave it as is, if assigned to space type
      # @todo if we use this measure with new geometry need to find a way to pull water use equipment loads into new model

      return instances_array
    end
  end
end
