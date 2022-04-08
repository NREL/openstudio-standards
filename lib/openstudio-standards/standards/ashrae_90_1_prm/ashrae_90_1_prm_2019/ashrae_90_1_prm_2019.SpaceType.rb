class ASHRAE901PRM2019 < ASHRAE901PRM
  # @!group SpaceType

  # Sets the internal loads for Appendix G PRM for 2019 and later (possibly)
  # Initially, only lighting power density will be set
  # Possibly infiltration will also be set from here
  #
  # @param model [OpenStudio::Model::SpaceType] OpenStudio space type object
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  def space_type_apply_int_loads_prm(space_type, model)
    # Skip plenums
    # Check if the space type name
    # contains the word plenum.
    if space_type.name.get.to_s.downcase.include?('plenum')
      return false
    end

    if space_type.standardsSpaceType.is_initialized
      if space_type.standardsSpaceType.get.downcase.include?('plenum')
        return false
      end
    end

    # Pre-process the light instances in the space type
    # Remove all instances but leave one in the space type
    instances = space_type.lights.sort
    if instances.size.zero?
      definition = OpenStudio::Model::LightsDefinition.new(space_type.model)
      definition.setName("#{space_type.name} Lights Definition")
      instance = OpenStudio::Model::Lights.new(definition)
      instance.setName("#{space_type.name} Lights")
      instance.setSpaceType(space_type)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} had no lights, one has been created.")
      instances << instance
    elsif instances.size > 1
      instances.each_with_index do |inst, i|
        next if i.zero?

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "Removed #{inst.name} from #{space_type.name}.")
        inst.remove
      end
    end

    # Get userdata from userdata_space and userdata_spacetype
    user_spaces = @standards_data.key?('userdata_space') ? @standards_data['userdata_space'] : nil
    user_spacetypes = @standards_data.key?('userdata_spacetype') ? @standards_data['userdata_spacetype'] : nil
    space_lighting_per_area_hash = {}
    # first priority - user_space data
    if user_spaces && user_spaces.length >= 1
      space_type.spaces.each do |space|
        user_space_index = user_spaces.index { |user_space| user_space['name'] == space.name.get }
        unless user_space_index.nil?
          user_space_data = user_spaces[user_space_index]
          space_lighting_per_area = calculate_lpd_from_userdata(user_space_data, space)
          space_lighting_per_area_hash[space.name.get] = space_lighting_per_area
        end
      end
    end
    # second priority - user_spacetype
    if user_spacetypes && user_spacetypes.length >= 1
      # if space type has user data
      user_space_type_index = user_spacetypes.index { |user_spacetype| user_spacetype['name'] == space_type.name.get}
      unless user_space_type_index.nil?
        user_space_type_data = user_spacetypes[user_space_type_index]
        space_type.spaces.each do |space|
          # unless the space is in the hash, we will add lighting per area to the space
          space_name = space.name.get
          unless space_lighting_per_area_hash.key?(space_name)
            space_lighting_per_area = calculate_lpd_from_userdata(user_space_type_data, space)
            space_lighting_per_area_hash[space_name] = space_lighting_per_area
          end
        end
      end
    end
    # Third priority
    # set spae type to every space in the space_type, third priority
    # will also be assigned from the default space type
    space_type.spaces.each do |space|
      space_name = space.name.get
      unless space_lighting_per_area_hash.key?(space_name)
        space_lighting_per_area = calculate_lpd_by_space(space_type, space)
        space_lighting_per_area_hash[space_name] = space_lighting_per_area
      end
    end
    # All space is explored.
    # Now rewrite the space type in each space
    space_type.spaces.each do |space|
      space_name = space.name.get
      new_space_type = space_type.clone.to_SpaceType.get
      space.setSpaceType(new_space_type)
      lighting_per_area = space_lighting_per_area_hash[space_name]
      new_space_type.lights.each do |inst|
        definition = inst.lightsDefinition
        unless lighting_per_area.zero?
          new_definition = definition.clone.to_LightsDefinition.get
          occ_sens_lpd_factor = 1.0
          new_definition.setWattsperSpaceFloorArea(OpenStudio.convert(lighting_per_area.to_f * occ_sens_lpd_factor, 'W/ft^2', 'W/m^2').get)
          inst.setLightsDefinition(new_definition)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.SpaceType', "#{space_type.name} set LPD to #{lighting_per_area} W/ft^2.")
        end
      end
    end
    space_type.remove
  end

  # calculate the lighting power density per area based on space type
  # The function will calculate the LPD based on the space type (STRING)
  # It considers lighting per area, lighting per length as well as occupancy factors in the database.
  # @param space_type [String]
  # @param space [OpenStudio::Model::Space]
  def calculate_lpd_by_space(space_type, space)
    # get interior lighting data
    space_type_properties = interior_lighting_get_prm_data(space_type)
    space_lighting_per_area = 0.0
    # Assign data
    lights_have_info = false
    lighting_per_area = space_type_properties['w/ft^2'].to_f
    lighting_per_length = space_type_properties['w/ft'].to_f
    manon_or_partauto = space_type_properties['manon_or_partauto'].to_i
    # Adjust the occupancy control sensor reduction factor from dataset
    occ_control_reduction_factor = 0.0
    if manon_or_partauto == 1
      occ_control_reduction_factor = space_type_properties['occup_sensor_savings'].to_f
    else
      occ_control_reduction_factor = space_type_properties['occup_sensor_auto_on_svgs'].to_f
    end
    lights_have_info = true unless lighting_per_area.zero? && lighting_per_length.zero?
    if lights_have_info
      # Space height
      space_volume = space.volume
      space_area = space.floorArea
      space_height = space_volume / space_area
      # calculate the new lpd values
      space_lighting_per_area = (lighting_per_length * space_height +
        lighting_per_area) * (1 - occ_control_reduction_factor)
    end
    return space_lighting_per_area
  end

  # Calculate the lighting power density per area based on user data (space_based)
  # The function will calculate the LPD based on the space type (STRING)
  # It considers lighting per area, lighting per length as well as occupancy factors in the database.
  # @param user_data [Hash] user data from the user csv
  # @param space [OpenStudio::Model::Space]
  def calculate_lpd_from_userdata(user_data, space)
    num_std_ltg_types = user_data['num_std_ltg_types'].to_i
    space_lighting_per_area = 0.0
    frac_sum = 0.0 # prevent the total fraction over 1.0
    std_ltg_index = 0 # loop index
    # Loop through standard lighting type in a space
    while std_ltg_index < num_std_ltg_types && frac_sum <= 1.0
      # Retrieve data from user_data
      type_key = 'std_ltg_type%02d' % (std_ltg_index + 1)
      frac_key = 'std_ltg_type_frac%02d' % (std_ltg_index + 1)
      sub_space_type = user_data[type_key]
      sub_space_type_frac = user_data[frac_key].to_f
      # Adjust while loop condition factors
      frac_sum += sub_space_type_frac
      std_ltg_index += 1
      # get interior lighting data
      sub_space_type_properties = interior_lighting_get_prm_data(sub_space_type)
      # Assign data
      lights_have_info = false
      lighting_per_area = sub_space_type_properties['w/ft^2'].to_f
      lighting_per_length = sub_space_type_properties['w/ft'].to_f
      lights_have_info = true unless lighting_per_area.zero? && lighting_per_length.zero?
      manon_or_partauto = sub_space_type_properties['manon_or_partauto'].to_i
      # Adjust the occupancy control sensor reduction factor from dataset
      occ_control_reduction_factor = 0.0
      if manon_or_partauto == 1
        occ_control_reduction_factor = sub_space_type_properties['occup_sensor_savings'].to_f
      else
        occ_control_reduction_factor = sub_space_type_properties['occup_sensor_auto_on_svgs'].to_f
      end

      if lights_have_info
        # Space height
        space_volume = space.volume
        space_area = space.floorArea
        space_height = space_volume / space_area
        # calculate and add new lpd values
        space_lighting_per_area += (lighting_per_length * space_height * sub_space_type_frac +
          lighting_per_area * sub_space_type_frac) * (1 - occ_control_reduction_factor)
      end
    end
    return space_lighting_per_area
  end
end
