class Standard
  # @!group ServiceWaterHeating

  # This method will add a swh water fixture to the model for the space.
  # It will return a water fixture object, or NIL if there is no water load at all.
  #
  # Adds a WaterUseEquipment object representing the SWH loads of the supplied Space.
  # Attaches this WaterUseEquipment to the supplied PlantLoop via a new WaterUseConnections object.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param swh_loop [OpenStudio::Model::PlantLoop] the SWH loop to connect the WaterUseEquipment to
  # @param space [OpenStudio::Model::Space] the Space to add a WaterUseEquipment for
  # @param is_flow_per_area [Boolean] if true, use the value in the 'service_water_heating_peak_flow_per_area'
  #   field of the space_types JSON.  If false, use the value in the 'service_water_heating_peak_flow_rate' field.
  # @return [OpenStudio::Model::WaterUseEquipment] the WaterUseEquipment for the
  def model_add_swh_end_uses_by_space(model,
                                      swh_loop,
                                      space,
                                      is_flow_per_area: true)
    # SpaceType
    if space.spaceType.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name} does not have a Space Type assigned, cannot add SWH end uses.")
      return nil
    end
    space_type = space.spaceType.get

    # Standards Building Type
    if space_type.standardsBuildingType.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name}'s Space Type does not have a Standards Building Type assigned, cannot add SWH end uses.")
      return nil
    end
    stds_bldg_type = space_type.standardsBuildingType.get
    building_type = model_get_lookup_name(stds_bldg_type)

    # Standards Space Type
    if space_type.standardsSpaceType.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name}'s Space Type does not have a Standards Space Type assigned, cannot add SWH end uses.")
      return nil
    end
    stds_spc_type = space_type.standardsSpaceType.get

    # find the specific space_type properties from standard.json
    search_criteria = {
      'template' => template,
      'building_type' => building_type,
      'space_type' => stds_spc_type
    }
    data = standards_lookup_table_first(table_name: 'space_types', search_criteria: search_criteria)
    if data.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find space type for: #{search_criteria}.")
      return nil
    end
    space_area = OpenStudio.convert(space.floorArea, 'm^2', 'ft^2').get # ft2

    # If there is no service hot water load.. Don't bother adding anything.
    if data['service_water_heating_peak_flow_per_area'].to_f < 0.00001 && data['service_water_heating_peak_flow_rate'].to_f < 0.00001
      return nil
    end

    # rated flow rate
    rated_flow_rate_per_area = data['service_water_heating_peak_flow_per_area'].to_f # gal/h.ft2
    rated_flow_rate_gal_per_hour = if is_flow_per_area
                                     rated_flow_rate_per_area * space_area * space.multiplier # gal/h
                                   else
                                     data['service_water_heating_peak_flow_rate'].to_f
                                   end
    rated_flow_rate_gal_per_min = rated_flow_rate_gal_per_hour / 60 # gal/h to gal/min
    rated_flow_rate_m3_per_s = OpenStudio.convert(rated_flow_rate_gal_per_min, 'gal/min', 'm^3/s').get

    # target mixed water temperature
    mixed_water_temp_f = data['service_water_heating_target_temperature']
    mixed_water_temp_c = OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get

    # flow rate fraction schedule
    flow_rate_fraction_schedule = model_add_schedule(model, data['service_water_heating_schedule'])

    # create water use
    water_fixture = OpenstudioStandards::ServiceWaterHeating.create_water_use(model,
                                                                              name: "#{space.name}",
                                                                              flow_rate: rated_flow_rate_m3_per_s,
                                                                              flow_rate_fraction_schedule: flow_rate_fraction_schedule,
                                                                              water_use_temperature: mixed_water_temp_c,
                                                                              service_water_loop: swh_loop)

    return water_fixture
  end
end
