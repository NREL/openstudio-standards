class ASHRAE901PRM2019 < ASHRAE901PRM
  # @!group Model

  # Determine if there is a need for a proposed model sizing run.
  # A typical application of such sizing run is to determine space
  # conditioning type.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  #
  # @return [Boolean] Returns true if a sizing run is required
  def model_create_prm_baseline_building_requires_proposed_model_sizing_run(model)
    return true
  end

  # Determines the skylight to roof ratio limit for a given standard
  # 3% for 90.1-PRM-2019
  # @return [Double] the skylight to roof ratio, as a percent: 5.0 = 5%
  def model_prm_skylight_to_roof_ratio_limit(model)
    srr_lim = 3.0
    return srr_lim
  end

  # Determine the surface range of a baseline model.
  # The method calculates the window to wall ratio (assuming all spaces are conditioned)
  # and select the range based on the calculated window to wall ratio
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param wwr_parameter [Hash] parameters to choose min and max percent of surfaces,
  #            could be different set in different standard
  def model_get_percent_of_surface_range(model, wwr_parameter)
    wwr_range = { 'minimum_percent_of_surface' => nil, 'maximum_percent_of_surface' => nil }
    intended_surface_type = wwr_parameter['intended_surface_type']
    if intended_surface_type == 'ExteriorWindow' || intended_surface_type == 'GlassDoor'
      if wwr_parameter.key?('wwr_building_type')
        wwr_building_type = wwr_parameter['wwr_building_type']
        wwr_info = wwr_parameter['wwr_info']
        if wwr_info[wwr_building_type] <= 10
          wwr_range['minimum_percent_of_surface'] = 0
          wwr_range['maximum_percent_of_surface'] = 10
        elsif wwr_info[wwr_building_type] <= 20
          wwr_range['minimum_percent_of_surface'] = 10.1
          wwr_range['maximum_percent_of_surface'] = 20
        elsif wwr_info[wwr_building_type] <= 30
          wwr_range['minimum_percent_of_surface'] = 20.1
          wwr_range['maximum_percent_of_surface'] = 30
        elsif wwr_info[wwr_building_type] <= 40
          wwr_range['minimum_percent_of_surface'] = 30.1
          wwr_range['maximum_percent_of_surface'] = 40
        else
          wwr_range['minimum_percent_of_surface'] = nil
          wwr_range['maximum_percent_of_surface'] = nil
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No wwr_building_type found for ExteriorWindow or GlassDoor')
      end
    end
    return wwr_range
  end

  # Modify the existing service water heating loops to match the baseline required heating type.
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type (For consistency with the standard class, not used in the method)
  # @param swh_building_type [String] the swh building are type
  # @return [Boolean] returns true if successful, false if not

  def model_apply_baseline_swh_loops(model,
                                     building_type,
                                     swh_building_type = 'All others')
    # Get the original water heater information
    original_water_heater_info_hash = {}
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      original_water_heater_info_hash = {water_heater.name.get.to_s => model_get_object_hash(water_heater)}
    end

    # Get the building area type from the additional properties of wateruse_equipment
    wateruse_equipment_hash = {}
    model.getWaterUseEquipments.each do |wateruse_equipment|
      wateruse_equipment_hash[wateruse_equipment.name.get.to_s] = get_additional_property_as_string(wateruse_equipment, 'building_type_swh')
    end

    # If there is additional properties, get the uniq building area type numbers.
    if wateruse_equipment_hash
      building_area_type_number = wateruse_equipment_hash.values.uniq.length
    else
      building_area_type_number = 1
    end


    # Apply baseline swh loops
    # if building_area_type_number == 1
      # One building area type
      # Modify the service water heater
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      model_apply_water_heater_prm_parameter(water_heater,
                                             swh_building_type)
    end
    # else
      # Todo: service water heater with multiple building area type

      # # 1. Remove current swh loop
      # model.getPlantLoops.sort.each do |loop|
      #   # Don't remove loops except service water heating loops
      #   next unless plant_loop_swh_loop?(loop)
      #   loop.remove
      # end
      # # 2. Create new swh loops based on building area type
      # building_type_swh_unique = building_type_swh_hash.values.uniq
      # building_type_swh_unique.each do |building_type_swh|
      #   building_type_swh_hash_new = building_type_swh_hash.select{|key, value| value == building_type_swh}
      #   model_add_swh_loop(model,
      #                      building_type_swh,
      #                      building_type_swh_hash_new,
      #                      service_water_temperature,
      #                      service_water_pump_head,
      #                      service_water_pump_motor_efficiency,
      #                      water_heater_capacity,
      #                      water_heater_volume)
      #
      # end
    # end
    return true
  end


  # Modified Method (added an additional argument 'volume') to search through a hash
  # for the objects that meets the desired search criteria, as passed via a hash.
  # Returns an Array (empty if nothing found) of matching objects.
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between the minimum_capacity and maximum_capacity values.
  # @param date [<OpenStudio::Date>] date of the object in question.  If date is supplied,
  #   the objects will only be returned if the specified date is between the start_date and end_date.
  # @param area [Double] area of the object in question.  If area is supplied,
  #   the objects will only be returned if the specified area is between the minimum_area and maximum_area values.
  # @param num_floors [Double] num_floors of the object in question.  If num_floors is supplied,
  #   the objects will only be returned if the specified num_floors is between the minimum_floors and maximum_floors values.
  # @param volume [Double] volume of the object in question.  If volume is supplied,
  #   the objects will only be returned if the specified volume is between the minimum_storage and maximum_storage values.
  # @return [Array] returns an array of hashes, one hash per object.  Array is empty if no results.
  def model_find_objects(hash_of_objects, search_criteria, capacity = nil, date = nil, area = nil, num_floors = nil, fan_motor_bhp = nil, volume = nil)
    matching_objects = []
    if hash_of_objects.is_a?(Hash) && hash_of_objects.key?('table')
      hash_of_objects = hash_of_objects['table']
    end

    # Compare each of the objects against the search criteria
    raise("This is not a table #{hash_of_objects}") unless hash_of_objects.respond_to?(:each)

    hash_of_objects.each do |object|
      meets_all_search_criteria = true
      search_criteria.each do |key, value|
        # Don't check non-existent search criteria
        next unless object.key?(key)

        # Stop as soon as one of the search criteria is not met
        # 'Any' is a special key that matches anything
        unless object[key] == value || object[key] == 'Any'
          meets_all_search_criteria = false
          break
        end
      end
      # Skip objects that don't meet all search criteria
      next unless meets_all_search_criteria

      # If made it here, object matches all search criteria
      matching_objects << object
    end

    # If capacity was specified, narrow down the matching objects
    unless capacity.nil?
      # Skip objects that don't have fields for minimum_capacity and maximum_capacity
      matching_objects = matching_objects.reject { |object| !object.key?('minimum_capacity') || !object.key?('maximum_capacity') }

      # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
      matching_objects = matching_objects.reject { |object| object['minimum_capacity'].nil? || object['maximum_capacity'].nil? }

      # Round up if capacity is an integer
      if capacity == capacity.round
        capacity += (capacity * 0.01)
      end

      # Skip objects whose the minimum capacity is below or maximum capacity above the specified capacity
      matching_capacity_objects = matching_objects.reject { |object| capacity.to_f <= object['minimum_capacity'].to_f || capacity.to_f > object['maximum_capacity'].to_f }

      # If no object was found, round the capacity down in case the number fell between the limits in the json file.
      if matching_capacity_objects.size.zero?
        capacity *= 0.99
        # Skip objects whose minimum capacity is below or maximum capacity above the specified capacity
        matching_objects = matching_objects.reject { |object| capacity.to_f <= object['minimum_capacity'].to_f || capacity.to_f > object['maximum_capacity'].to_f }
      else
        matching_objects = matching_capacity_objects
      end
    end
    # If volume was specified, narrow down the matching objects
    unless volume.nil?
      # Skip objects that don't have fields for minimum_storage and maximum_storage
      matching_objects = matching_objects.reject { |object| !object.key?('minimum_storage') || !object.key?('maximum_storage') }

      # Skip objects that don't have values specified for minimum_storage and maximum_storage
      matching_objects = matching_objects.reject { |object| object['minimum_storage'].nil? || object['maximum_storage'].nil? }
      # Round up if volume is an integer
      if volume == volume.round
        volume += (volume * 0.01)
      end
      # Skip objects whose the minimum volume is below or maximum volume above the specified volume
      matching_volume_objects = matching_objects.reject { |object| volume.to_f <= object['minimum_storage'].to_f || volume.to_f > object['maximum_storage'].to_f }

      # If no object was found, round the volume down in case the number fell between the limits in the json file.
      if matching_volume_objects.size.zero?
        volume *= 0.99
        # Skip objects whose minimum volume is below or maximum volume above the specified volume
        matching_objects = matching_objects.reject { |object| volume.to_f <= object['minimum_storage'].to_f || volume.to_f > object['maximum_storage'].to_f }
      else
        matching_objects = matching_volume_objects
      end
    end

    # If fan_motor_bhp was specified, narrow down the matching objects
    unless fan_motor_bhp.nil?
      # Skip objects that don't have fields for minimum_capacity and maximum_capacity
      matching_objects = matching_objects.reject { |object| !object.key?('minimum_capacity') || !object.key?('maximum_capacity') }

      # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
      matching_objects = matching_objects.reject { |object| object['minimum_capacity'].nil? || object['maximum_capacity'].nil? }

      # Skip objects whose the minimum capacity is below or maximum capacity above the specified fan_motor_bhp
      matching_capacity_objects = matching_objects.reject { |object| fan_motor_bhp.to_f <= object['minimum_capacity'].to_f || fan_motor_bhp.to_f > object['maximum_capacity'].to_f }

      # Filter based on motor type
      matching_capacity_objects = matching_capacity_objects.select { |object| object['type'].downcase == search_criteria['type'].downcase } if search_criteria.keys.include?('type')

      # If no object was found, round the fan_motor_bhp down in case the number fell between the limits in the json file.
      if matching_capacity_objects.size.zero?
        fan_motor_bhp *= 0.99
        # Skip objects whose minimum capacity is below or maximum capacity above the specified fan_motor_bhp
        matching_objects = matching_objects.reject { |object| fan_motor_bhp.to_f <= object['minimum_capacity'].to_f || fan_motor_bhp.to_f > object['maximum_capacity'].to_f }
      else
        matching_objects = matching_capacity_objects
      end
    end

    # If date was specified, narrow down the matching objects
    unless date.nil?
      # Skip objects that don't have fields for start_date and end_date
      matching_objects = matching_objects.reject { |object| !object.key?('start_date') || !object.key?('end_date') }

      # Skip objects whose start date is earlier than the specified date
      matching_objects = matching_objects.reject { |object| date <= Date.parse(object['start_date']) }

      # Skip objects whose end date is later than the specified date
      matching_objects = matching_objects.reject { |object| date > Date.parse(object['end_date']) }
    end

    # If area was specified, narrow down the matching objects
    unless area.nil?
      # Skip objects that don't have fields for minimum_area and maximum_area
      matching_objects = matching_objects.reject { |object| !object.key?('minimum_area') || !object.key?('maximum_area') }

      # Skip objects that don't have values specified for minimum_area and maximum_area
      matching_objects = matching_objects.reject { |object| object['minimum_area'].nil? || object['maximum_area'].nil? }

      # Skip objects whose minimum area is below or maximum area is above area
      matching_objects = matching_objects.reject { |object| area.to_f <= object['minimum_area'].to_f || area.to_f > object['maximum_area'].to_f }
    end

    # If area was specified, narrow down the matching objects
    unless num_floors.nil?
      # Skip objects that don't have fields for minimum_floors and maximum_floors
      matching_objects = matching_objects.reject { |object| !object.key?('minimum_floors') || !object.key?('maximum_floors') }

      # Skip objects that don't have values specified for minimum_floors and maximum_floors
      matching_objects = matching_objects.reject { |object| object['minimum_floors'].nil? || object['maximum_floors'].nil? }

      # Skip objects whose minimum floors is below or maximum floors is above num_floors
      matching_objects = matching_objects.reject { |object| num_floors.to_f < object['minimum_floors'].to_f || num_floors.to_f > object['maximum_floors'].to_f }
    end

    # Check the number of matching objects found
    if matching_objects.size.zero?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Find objects search criteria returned no results. Search criteria: #{search_criteria}. Called from #{caller(0)[1]}.")
    end

    return matching_objects
  end

  # Method to search through a hash for an object that meets the desired search criteria, as passed via a hash.
  # If capacity is supplied, the object will only be returned if the specified capacity is between the minimum_capacity and maximum_capacity values.
  #
  # @param hash_of_objects [Hash] hash of objects to search through
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between the minimum_capacity and maximum_capacity values.
  # @param date [<OpenStudio::Date>] date of the object in question.  If date is supplied,
  #   the objects will only be returned if the specified date is between the start_date and end_date.
  # @param area [Double] area of the object in question.  If area is supplied,
  #   the objects will only be returned if the specified area is between the minimum_area and maximum_area values.
  # @param num_floors [Double] capacity of the object in question.  If num_floors is supplied,
  #   the objects will only be returned if the specified num_floors is between the minimum_floors and maximum_floors values.
  # @param volume [Double] capacity of the object in question.  If volume is supplied,
  #   the objects will only be returned if the specified volume is between the minimum_storage and maximum_storage values.
  # @return [Hash] Return tbe first matching object hash if successful, nil if not.

  def model_find_object(hash_of_objects, search_criteria, capacity = nil, date = nil, area = nil, num_floors = nil, fan_motor_bhp = nil, volume = nil)
    matching_objects = model_find_objects(hash_of_objects, search_criteria, capacity, date, area, num_floors, fan_motor_bhp, volume)
    # Check the number of matching objects found
    if matching_objects.size.zero?
      desired_object = nil
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}. Called from #{caller(0)[1]}")
    elsif matching_objects.size == 1
      desired_object = matching_objects[0]
    else
      desired_object = matching_objects[0]
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Called from #{caller(0)[1]}. \n Search criteria: \n #{search_criteria}, capacity = #{capacity} \n  All results: \n #{matching_objects.join("\n")}")
    end
    return desired_object
  end
end
