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
    model.getPlantLoops.each do |plant_loop|
      # Skip non service water heating loops
      next unless plant_loop_swh_loop?(plant_loop)

      # Rename the loop to avoid accidentally hooking up the HVAC systems to this loop later.
      plant_loop.setName('Service Water Heating Loop')

      htg_fuels, combination_system, storage_capacity, total_heating_capacity = plant_loop_swh_system_type(plant_loop)

      electric = true
      if htg_fuels.include?('NaturalGas') ||
        htg_fuels.include?('PropaneGas') ||
        htg_fuels.include?('FuelOilNo1') ||
        htg_fuels.include?('FuelOilNo2') ||
        htg_fuels.include?('Coal') ||
        htg_fuels.include?('Diesel') ||
        htg_fuels.include?('Gasoline')
        electric = false
      end

      # Per Table G3.1 11.e, if the baseline system was a combination of heating and service water heating,
      # delete all heating equipment and recreate a WaterHeater:Mixed.
      if combination_system
        a = plant_loop.supplyComponents
        b = plant_loop.demandComponents
        plantloop_components = a += b
        plantloop_components.each do |component|
          # Get the object type
          obj_type = component.iddObjectType.valueName.to_s
          next if ['OS_Node', 'OS_Pump_ConstantSpeed', 'OS_Pump_VariableSpeed', 'OS_Connector_Splitter', 'OS_Connector_Mixer', 'OS_Pipe_Adiabatic'].include?(obj_type)

          component.remove
        end

        water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
        water_heater.setName('Baseline Water Heater')
        water_heater.setHeaterMaximumCapacity(total_heating_capacity)
        water_heater.setTankVolume(storage_capacity)
        plant_loop.addSupplyBranchForComponent(water_heater)

        if electric
          # G3.1.11.b: If electric, WaterHeater:Mixed with electric resistance
          water_heater.setHeaterFuelType('Electricity')
          water_heater.setHeaterThermalEfficiency(1.0)
        else
          # @todo for now, just get the first fuel that isn't Electricity
          # A better way would be to count the capacities associated
          # with each fuel type and use the preponderant one
          fuels = htg_fuels - ['Electricity']
          fossil_fuel_type = fuels[0]
          water_heater.setHeaterFuelType(fossil_fuel_type)
          water_heater.setHeaterThermalEfficiency(0.8)
        end
        # If it's not a combination heating and service water heating system
        # just change the fuel type of all water heaters on the system
        # to electric resistance if it's electric
      else
        # Per Table G3.1 11.i, piping losses was deleted
        plant_loop_adiabatic_pipes_only(plant_loop)

        if electric
          plant_loop.supplyComponents.each do |component|
            next unless component.to_WaterHeaterMixed.is_initialized

            water_heater = component.to_WaterHeaterMixed.get
            # G3.1.11.b: If electric, WaterHeater:Mixed with electric resistance
            water_heater.setHeaterFuelType('Electricity')
            water_heater.setHeaterThermalEfficiency(1.0)
          end
        end
      end
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

    return true
  end
end
