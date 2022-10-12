require 'csv'

class Standard
  attr_accessor :space_multiplier_map
  attr_accessor :standards_data

  # returns the space multiplier map

  # @return [Hash] space multiplier map
  def define_space_multiplier
    return @space_multiplier_map
  end

  # @!group Model

  # Creates a Performance Rating Method (aka Appendix G aka LEED) baseline building model
  # based on the inputs currently in the model.
  #
  # @note Per 90.1, the Performance Rating Method "does NOT offer an alternative compliance path for minimum standard compliance."
  #   This means you can't use this method for code compliance to get a permit.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param custom [String] the custom logic that will be applied during baseline creation.  Valid choices are 'Xcel Energy CO EDA' or '90.1-2007 with addenda dn'.
  #   If nothing is specified, no custom logic will be applied; the process will follow the template logic explicitly.
  # @param sizing_run_dir [String] the directory where the sizing runs will be performed
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  def model_create_prm_baseline_building(model, building_type, climate_zone, custom = nil, sizing_run_dir = Dir.pwd, debug = false)
    model.getBuilding.setName("#{template}-#{building_type}-#{climate_zone} PRM baseline created: #{Time.new}")

    # Remove external shading devices
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Removing External Shading Devices ***')
    model_remove_external_shading_devices(model)

    # Reduce the WWR and SRR, if necessary
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Adjusting Window and Skylight Ratios ***')
    model_apply_prm_baseline_window_to_wall_ratio(model, climate_zone)
    model_apply_prm_baseline_skylight_to_roof_ratio(model)

    # Assign building stories to spaces in the building where stories are not yet assigned.
    model_assign_spaces_to_stories(model)

    # Modify the internal loads in each space type, keeping user-defined schedules.
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Changing Lighting Loads ***')
    model.getSpaceTypes.sort.each do |space_type|
      set_people = false
      set_lights = true
      set_electric_equipment = false
      set_gas_equipment = false
      set_ventilation = false
      set_infiltration = false
      space_type_apply_internal_loads(space_type, set_people, set_lights, set_electric_equipment, set_gas_equipment, set_ventilation, set_infiltration)
    end

    # If any of the lights are missing schedules, assign an always-off schedule to those lights.
    # This is assumed to be the user's intent in the proposed model.
    model.getLightss.sort.each do |lights|
      if lights.schedule.empty?
        lights.setSchedule(model.alwaysOffDiscreteSchedule)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Adding Daylighting Controls ***')

    # Run a sizing run to calculate VLT for layer-by-layer windows.
    if model_create_prm_baseline_building_requires_vlt_sizing_run(model)
      if model_run_sizing_run(model, "#{sizing_run_dir}/SRVLT") == false
        return false
      end
    end

    # Add daylighting controls to each space
    model.getSpaces.sort.each do |space|
      added = space_add_daylighting_controls(space, false, false)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Baseline Constructions ***')

    # Modify some of the construction types as necessary
    model_apply_prm_construction_types(model)

    # Set the construction properties of all the surfaces in the model
    model_apply_standard_constructions(model, climate_zone)

    # Get the groups of zones that define the baseline HVAC systems for later use.
    # This must be done before removing the HVAC systems because it requires knowledge of proposed HVAC fuels.
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Grouping Zones by Fuel Type and Occupancy Type ***')
    sys_groups = model_prm_baseline_system_groups(model, custom)

    # Remove all HVAC from model, excluding service water heating
    model_remove_prm_hvac(model)

    # Remove all EMS objects from the model
    model_remove_prm_ems_objects(model)

    # Modify the service water heating loops per the baseline rules
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Cleaning up Service Water Heating Loops ***')
    model_apply_baseline_swh_loops(model, building_type)

    # Determine the baseline HVAC system type for each of the groups of zones and add that system type.
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Adding Baseline HVAC Systems ***')
    sys_groups.each do |sys_group|
      # Determine the primary baseline system type
      system_type = model_prm_baseline_system_type(model,
                                                   climate_zone,
                                                   sys_group['occ'],
                                                   sys_group['fuel'],
                                                   sys_group['area_ft2'],
                                                   sys_group['stories'],
                                                   custom)

      sys_group['zones'].sort.each_slice(5) do |zone_list|
        zone_names = []
        zone_list.each do |zone|
          zone_names << zone.name.get.to_s
        end
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{zone_names.join(', ')}")
      end

      # Add the system type for these zones
      model_add_prm_baseline_system(model,
                                    system_type[0],
                                    system_type[1],
                                    system_type[2],
                                    system_type[3],
                                    sys_group['zones'])
    end

    # Set the zone sizing SAT for each zone in the model
    model.getThermalZones.each do |zone|
      thermal_zone_apply_prm_baseline_supply_temperatures(zone)
    end

    # Set the system sizing properties based on the zone sizing information
    model.getAirLoopHVACs.each do |air_loop|
      air_loop_hvac_apply_prm_sizing_temperatures(air_loop)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Baseline HVAC System Controls ***')

    # SAT reset, economizers
    model.getAirLoopHVACs.sort.each do |air_loop|
      air_loop_hvac_apply_prm_baseline_controls(air_loop, climate_zone)
    end

    # Apply the minimum damper positions, assuming no DDC control of VAV terminals
    model.getAirLoopHVACs.sort.each do |air_loop|
      air_loop_hvac_apply_minimum_vav_damper_positions(air_loop, false)
    end

    # Apply the baseline system temperatures
    model.getPlantLoops.sort.each do |plant_loop|
      # Skip the SWH loops
      next if plant_loop_swh_loop?(plant_loop)

      plant_loop_apply_prm_baseline_temperatures(plant_loop)
    end

    # Set the heating and cooling sizing parameters
    model_apply_prm_sizing_parameters(model)

    # Run sizing run with the HVAC equipment
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR1") == false
      return false
    end

    # If there are any multizone systems, reset damper positions to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    model_apply_multizone_vav_outdoor_air_sizing(model)

    # Set the baseline fan power for all airloops
    model.getAirLoopHVACs.sort.each do |air_loop|
      air_loop_hvac_apply_prm_baseline_fan_power(air_loop)
    end

    # Set the baseline fan power for all zone HVAC
    model.getZoneHVACComponents.sort.each do |zone_hvac|
      zone_hvac_component_apply_prm_baseline_fan_power(zone_hvac)
    end

    # Set the baseline number of boilers and chillers
    model.getPlantLoops.sort.each do |plant_loop|
      # Skip the SWH loops
      next if plant_loop_swh_loop?(plant_loop)

      plant_loop_apply_prm_number_of_boilers(plant_loop)
      plant_loop_apply_prm_number_of_chillers(plant_loop)
    end

    # Set the baseline number of cooling towers
    # Must be done after all chillers are added
    model.getPlantLoops.sort.each do |plant_loop|
      # Skip the SWH loops
      next if plant_loop_swh_loop?(plant_loop)

      plant_loop_apply_prm_number_of_cooling_towers(plant_loop)
    end

    # Run sizing run with the new chillers, boilers, and cooling towers to determine capacities
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR2") == false
      return false
    end

    # Set the pumping control strategy and power
    # Must be done after sizing components
    model.getPlantLoops.sort.each do |plant_loop|
      # Skip the SWH loops
      next if plant_loop_swh_loop?(plant_loop)

      plant_loop_apply_prm_baseline_pump_power(plant_loop)
      plant_loop_apply_prm_baseline_pumping_type(plant_loop)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Prescriptive HVAC Controls and Equipment Efficiencies ***')

    # Apply the HVAC efficiency standard
    model_apply_hvac_efficiency_standard(model, climate_zone)

    # Fix EMS references.
    # Temporary workaround for OS issue #2598
    model_temp_fix_ems_references(model)

    # Delete all the unused resource objects
    model_remove_unused_resource_objects(model)

    # @todo turn off self shading
    # Set Solar Distribution to MinimalShadowing... problem is when you also have detached shading such as surrounding buildings etc
    # It won't be taken into account, while it should: only self shading from the building itself should be turned off but to my knowledge there isn't a way to do this in E+

    model_status = 'final'
    model.save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    # Translate to IDF and save for debugging
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path = OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.idf")
    idf.save(idf_path, true)

    return true
  end

  # Determine if there needs to be a sizing run after constructions are added
  # so that EnergyPlus can calculate the VLTs of layer-by-layer glazing constructions.
  # These VLT values are needed for the daylighting controls logic for some templates.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if required, false if not
  def model_create_prm_baseline_building_requires_vlt_sizing_run(model)
    return false # Not required for most templates
  end

  # Determine the residential and nonresidential floor areas based on the space type properties for each space.
  # For spaces with no space type, assume nonresidential.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Hash] keys are 'residential' and 'nonresidential', units are m^2
  def model_residential_and_nonresidential_floor_areas(model)
    res_area_m2 = 0
    nonres_area_m2 = 0
    model.getSpaces.sort.each do |space|
      if thermal_zone_residential?(space)
        res_area_m2 += space.floorArea
      else
        nonres_area_m2 += space.floorArea
      end
    end

    return { 'residential' => res_area_m2, 'nonresidential' => nonres_area_m2 }
  end

  # Determine the number of stories spanned by the supplied zones.
  # If all zones on one of the stories have an identical multiplier,
  # assume that the multiplier is a floor multiplier and increase the number of stories accordingly.
  # Stories do not have to be contiguous.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param zones [Array<OpenStudio::Model::ThermalZone>] an array of zones
  # @return [Integer] the number of stories spanned
  def model_num_stories_spanned(model, zones)
    # Get the story object for all zones
    stories = []
    zones.each do |zone|
      zone.spaces.each do |space|
        story = space.buildingStory
        next if story.empty?

        stories << story.get
      end
    end

    # Reduce down to the unique set of stories
    stories = stories.uniq

    # Tally up stories including multipliers
    num_stories = 0
    stories.each do |story|
      num_stories += building_story_floor_multiplier(story)
    end

    return num_stories
  end

  # Categorize zones by occupancy type and fuel type, where the types depend on the standard.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param custom [String] custom fuel type
  # @return [Array<Hash>] an array of hashes, one for each zone,
  #   with the keys 'zone', 'type' (occ type), 'fuel', and 'area'
  def model_zones_with_occ_and_fuel_type(model, custom)
    zones = []

    model.getThermalZones.sort.each do |zone|
      # Skip plenums
      if thermal_zone_plenum?(zone)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Zone #{zone.name} is a plenum.  It will not be assigned a baseline system.")
        next
      end

      # Skip unconditioned zones
      heated = thermal_zone_heated?(zone)
      cooled = thermal_zone_cooled?(zone)
      if !heated && !cooled
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Zone #{zone.name} is unconditioned.  It will not be assigned a baseline system.")
        next
      end

      zn_hash = {}

      # The zone object
      zn_hash['zone'] = zone

      # Floor area
      zn_hash['area'] = zone.floorArea

      # Occupancy type
      zn_hash['occ'] = thermal_zone_occupancy_type(zone)

      # Building type
      zn_hash['bldg_type'] = thermal_zone_building_type(zone)

      # Fuel type
      zn_hash['fuel'] = thermal_zone_fossil_or_electric_type(zone, custom)

      zones << zn_hash
    end

    return zones
  end

  # Determine the dominant and exceptional areas of the building based on fuel types and occupancy types.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param custom [String] custom fuel type
  # @return [Array<Hash>] an array of hashes of area information,
  #   with keys area_ft2, type, fuel, and zones (an array of zones)
  def model_prm_baseline_system_groups(model, custom)
    # Define the minimum area for the
    # exception that allows a different
    # system type in part of the building.
    exception_min_area_m2 = model_prm_baseline_system_group_minimum_area(model, custom)
    exception_min_area_ft2 = OpenStudio.convert(exception_min_area_m2, 'm^2', 'ft^2').get

    # Get occupancy type, fuel type, and area information for all zones,
    # excluding unconditioned zones.
    # Occupancy types are:
    # Residential
    # NonResidential
    # (and for 90.1-2013)
    # PublicAssembly
    # Retail
    # Fuel types are:
    # fossil
    # electric
    # (and for Xcel Energy CO EDA)
    # fossilandelectric
    zones = model_zones_with_occ_and_fuel_type(model, custom)

    # Ensure that there is at least one conditioned zone
    if zones.size.zero?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'The building does not appear to have any conditioned zones. Make sure zones have thermostat with appropriate heating and cooling setpoint schedules.')
      return []
    end

    # Group the zones by occupancy type
    type_to_area = Hash.new { 0.0 }
    zones_grouped_by_occ = zones.group_by { |z| z['occ'] }

    # Determine the dominant occupancy type by area
    zones_grouped_by_occ.each do |occ_type, zns|
      zns.each do |zn|
        type_to_area[occ_type] += zn['area']
      end
    end
    dom_occ = type_to_area.sort_by { |k, v| v }.reverse[0][0]

    # Get the dominant occupancy type group
    dom_occ_group = zones_grouped_by_occ[dom_occ]

    # Check the non-dominant occupancy type groups to see if they are big enough to trigger the occupancy exception.
    # If they are, leave the group standing alone.
    # If they are not, add the zones in that group back to the dominant occupancy type group.
    occ_groups = []
    zones_grouped_by_occ.each do |occ_type, zns|
      # Skip the dominant occupancy type
      next if occ_type == dom_occ

      # Add up the floor area of the group
      area_m2 = 0
      zns.each do |zn|
        area_m2 += zn['area']
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

      # If the non-dominant group is big enough, preserve that group.
      if area_ft2 > exception_min_area_ft2
        occ_groups << [occ_type, zns]
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The portion of the building with an occupancy type of #{occ_type} is bigger than the minimum exception area of #{exception_min_area_ft2.round} ft2.  It will be assigned a separate HVAC system type.")
        # Otherwise, add the zones back to the dominant group.
      else
        dom_occ_group += zns
      end
    end
    # Add the dominant occupancy group to the list
    occ_groups << [dom_occ, dom_occ_group]

    # Inside of each remaining occupancy group, determine the dominant fuel type.
    # This determination should only include zones that are part of the dominant area type inside of this group.
    occ_and_fuel_groups = []
    occ_groups.each do |occ_type, zns|
      # Separate the zones that are part of the dominant occ type
      dom_occ_zns = []
      nondom_occ_zns = []
      zns.each do |zn|
        if zn['occ'] == occ_type
          dom_occ_zns << zn
        else
          nondom_occ_zns << zn
        end
      end

      # Determine the dominant fuel type from the subset of the dominant area type zones
      fuel_to_area = Hash.new { 0.0 }
      zones_grouped_by_fuel = dom_occ_zns.group_by { |z| z['fuel'] }
      zones_grouped_by_fuel.each do |fuel, zns_by_fuel|
        zns_by_fuel.each do |zn|
          fuel_to_area[fuel] += zn['area']
        end
      end

      sorted_by_area = fuel_to_area.sort_by { |k, v| v }.reverse
      dom_fuel = sorted_by_area[0][0]

      # Don't allow unconditioned to be the dominant fuel, go to the next biggest
      if dom_fuel == 'unconditioned'
        if sorted_by_area.size > 1
          dom_fuel = sorted_by_area[1][0]
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'The fuel type was not able to be determined for any zones in this model.  Run with debug messages enabled to see possible reasons.')
          return []
        end
      end

      # Get the dominant fuel type group
      dom_fuel_group = {}
      dom_fuel_group['occ'] = occ_type
      dom_fuel_group['fuel'] = dom_fuel
      dom_fuel_group['zones'] = zones_grouped_by_fuel[dom_fuel]

      # The zones that aren't part of the dominant occ type are automatically added to the dominant fuel group
      dom_fuel_group['zones'] += nondom_occ_zns

      # Check the non-dominant occupancy type groups to see if they are big enough to trigger the occupancy exception.
      # If they are, leave the group standing alone.
      # If they are not, add the zones in that group back to the dominant occupancy type group.
      zones_grouped_by_fuel.each do |fuel_type, zns_by_fuel|
        # Skip the dominant occupancy type
        next if fuel_type == dom_fuel

        # Add up the floor area of the group
        area_m2 = 0
        zns_by_fuel.each do |zn|
          area_m2 += zn['area']
        end
        area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

        # If the non-dominant group is big enough, preserve that group.
        if area_ft2 > exception_min_area_ft2
          group = {}
          group['occ'] = occ_type
          group['fuel'] = fuel_type
          group['zones'] = zns_by_fuel
          occ_and_fuel_groups << group
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The portion of the building with an occupancy type of #{occ_type} and fuel type of #{fuel_type} is bigger than the minimum exception area of #{exception_min_area_ft2.round} ft2.  It will be assigned a separate HVAC system type.")
          # Otherwise, add the zones back to the dominant group.
        else
          dom_fuel_group['zones'] += zns_by_fuel
        end
      end
      # Add the dominant occupancy group to the list
      occ_and_fuel_groups << dom_fuel_group
    end

    # Moved heated-only zones into their own groups.
    # Per the PNNL PRM RM, this must be done AFTER the dominant occ and fuel types are determined
    # so that heated-only zone areas are part of the determination.
    final_groups = []
    occ_and_fuel_groups.each do |gp|
      # Skip unconditioned groups
      next if gp['fuel'] == 'unconditioned'

      heated_only_zones = []
      heated_cooled_zones = []
      gp['zones'].each do |zn|
        if thermal_zone_heated?(zn['zone']) && !thermal_zone_cooled?(zn['zone'])
          heated_only_zones << zn
        else
          heated_cooled_zones << zn
        end
      end
      gp['zones'] = heated_cooled_zones

      # Add the group (less unheated zones) to the final list
      final_groups << gp

      # If there are any heated-only zones, create a new group for them.
      unless heated_only_zones.empty?
        htd_only_group = {}
        htd_only_group['occ'] = 'heatedonly'
        htd_only_group['fuel'] = gp['fuel']
        htd_only_group['zones'] = heated_only_zones
        final_groups << htd_only_group
      end
    end

    # Calculate the area for each of the final groups and replace the zone hashes with the zone objects
    final_groups.each do |gp|
      area_m2 = 0.0
      gp_zns = []
      gp['zones'].each do |zn|
        area_m2 += zn['area']
        gp_zns << zn['zone']
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      gp['area_ft2'] = area_ft2
      gp['zones'] = gp_zns
    end

    # @todo Remove the secondary zones before
    # determining the area used to pick the HVAC system, per PNNL PRM RM

    # If there is any district heating or district cooling in the proposed building, the heating and cooling
    # fuels in the entire baseline building are changed for the purposes of HVAC system assignment
    all_htg_fuels = []
    all_clg_fuels = []
    model.getThermalZones.sort.each do |zone|
      all_htg_fuels += zone.heating_fuels
      all_clg_fuels += zone.cooling_fuels
    end

    purchased_heating = false
    purchased_cooling = false

    # Purchased heating
    if all_htg_fuels.include?('DistrictHeating')
      purchased_heating = true
    end

    # Purchased cooling
    if all_clg_fuels.include?('DistrictCooling')
      purchased_cooling = true
    end

    # Categorize
    district_fuel = nil
    if purchased_heating && purchased_cooling
      district_fuel = 'purchasedheatandcooling'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'The proposed model included purchased heating and cooling.  All baseline building system selection will be based on this information.')
    elsif purchased_heating && !purchased_cooling
      district_fuel = 'purchasedheat'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'The proposed model included purchased heating.  All baseline building system selection will be based on this information.')
    elsif !purchased_heating && purchased_cooling
      district_fuel = 'purchasedcooling'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'The proposed model included purchased cooling.  All baseline building system selection will be based on this information.')
    end

    # Change the fuel in all final groups if district systems were found.
    if district_fuel
      final_groups.each do |gp|
        gp['fuel'] = district_fuel
      end
    end

    # Determine the number of stories spanned by each group and report out info.
    final_groups.each do |group|
      # Determine the number of stories this group spans
      num_stories = model_num_stories_spanned(model, group['zones'])
      group['stories'] = num_stories
      # Report out the final grouping
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Final system type group: occ = #{group['occ']}, fuel = #{group['fuel']}, area = #{group['area_ft2'].round} ft2, num stories = #{group['stories']}, zones:")
      group['zones'].sort.each_slice(5) do |zone_list|
        zone_names = []
        zone_list.each do |zone|
          zone_names << zone.name.get.to_s
        end
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{zone_names.join(', ')}")
      end
    end

    return final_groups
  end

  # Determines the area of the building above which point
  # the non-dominant area type gets it's own HVAC system type.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param custom [String] custom fuel type
  # @return [Double] the minimum area (m^2)
  def model_prm_baseline_system_group_minimum_area(model, custom)
    exception_min_area_ft2 = 20_000
    exception_min_area_m2 = OpenStudio.convert(exception_min_area_ft2, 'ft^2', 'm^2').get
    return exception_min_area_m2
  end

  # Determine the baseline system type given the inputs.  Logic is different for different standards.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param area_type [String] Valid choices are residential, nonresidential, and heatedonly
  # @param fuel_type [String] Valid choices are electric, fossil, fossilandelectric,
  #   purchasedheat, purchasedcooling, purchasedheatandcooling
  # @param area_ft2 [Double] Area in ft^2
  # @param num_stories [Integer] Number of stories
  # @param custom [String] custom fuel type
  # @return [String] The system type.  Possibilities are PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes,
  #   VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace
  # @todo add 90.1-2013 systems 11-13
  def model_prm_baseline_system_type(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    #             [type, central_heating_fuel, zone_heating_fuel, cooling_fuel]
    system_type = [nil, nil, nil, nil]

    # Get the row from TableG3.1.1A
    sys_num = model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)

    # Modify the fuel type if called for by the standard
    fuel_type = model_prm_baseline_system_change_fuel_type(model, fuel_type, climate_zone, custom)

    # Define the lookup by row and by fuel type
    sys_lookup = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

    # fossil, fossil and electric, purchased heat, purchased heat and cooling
    sys_lookup['1_or_2']['fossil'] = ['PTAC', 'NaturalGas', nil, 'Electricity']
    sys_lookup['1_or_2']['fossilandelectric'] = ['PTAC', 'NaturalGas', nil, 'Electricity']
    sys_lookup['1_or_2']['purchasedheat'] = ['PTAC', 'DistrictHeating', nil, 'Electricity']
    sys_lookup['1_or_2']['purchasedheatandcooling'] = ['Fan_Coil', 'DistrictHeating', nil, 'DistrictCooling']
    sys_lookup['3_or_4']['fossil'] = ['PSZ_AC', 'NaturalGas', nil, 'Electricity']
    sys_lookup['3_or_4']['fossilandelectric'] = ['PSZ_AC', 'NaturalGas', nil, 'Electricity']
    sys_lookup['3_or_4']['purchasedheat'] = ['PSZ_AC', 'DistrictHeating', nil, 'Electricity']
    sys_lookup['3_or_4']['purchasedheatandcooling'] = ['PSZ_AC', 'DistrictHeating', nil, 'DistrictCooling']
    sys_lookup['5_or_6']['fossil'] = ['PVAV_Reheat', 'NaturalGas', 'NaturalGas', 'Electricity']
    sys_lookup['5_or_6']['fossilandelectric'] = ['PVAV_Reheat', 'NaturalGas', 'Electricity', 'Electricity']
    sys_lookup['5_or_6']['purchasedheat'] = ['PVAV_Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity']
    sys_lookup['5_or_6']['purchasedheatandcooling'] = ['PVAV_Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    sys_lookup['7_or_8']['fossil'] = ['VAV_Reheat', 'NaturalGas', 'NaturalGas', 'Electricity']
    sys_lookup['7_or_8']['fossilandelectric'] = ['VAV_Reheat', 'NaturalGas', 'Electricity', 'Electricity']
    sys_lookup['7_or_8']['purchasedheat'] = ['VAV_Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity']
    sys_lookup['7_or_8']['purchasedheatandcooling'] = ['VAV_Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    sys_lookup['9_or_10']['fossil'] = ['Gas_Furnace', 'NaturalGas', nil, nil]
    sys_lookup['9_or_10']['fossilandelectric'] = ['Gas_Furnace', 'NaturalGas', nil, nil]
    sys_lookup['9_or_10']['purchasedheat'] = ['Gas_Furnace', 'DistrictHeating', nil, nil]
    sys_lookup['9_or_10']['purchasedheatandcooling'] = ['Gas_Furnace', 'DistrictHeating', nil, nil]
    # electric (heat), purchased cooling
    sys_lookup['1_or_2']['electric'] = ['PTHP', 'Electricity', nil, 'Electricity']
    sys_lookup['1_or_2']['purchasedcooling'] = ['Fan_Coil', 'NaturalGas', nil, 'DistrictCooling']
    sys_lookup['3_or_4']['electric'] = ['PSZ_HP', 'Electricity', nil, 'Electricity']
    sys_lookup['3_or_4']['purchasedcooling'] = ['PSZ_AC', 'NaturalGas', nil, 'DistrictCooling']
    sys_lookup['5_or_6']['electric'] = ['PVAV_PFP_Boxes', 'Electricity', 'Electricity', 'Electricity']
    sys_lookup['5_or_6']['purchasedcooling'] = ['PVAV_PFP_Boxes', 'Electricity', 'Electricity', 'DistrictCooling']
    sys_lookup['7_or_8']['electric'] = ['VAV_PFP_Boxes', 'Electricity', 'Electricity', 'Electricity']
    sys_lookup['7_or_8']['purchasedcooling'] = ['VAV_PFP_Boxes', 'Electricity', 'Electricity', 'DistrictCooling']
    sys_lookup['9_or_10']['electric'] = ['Electric_Furnace', 'Electricity', nil, nil]
    sys_lookup['9_or_10']['purchasedcooling'] = ['Electric_Furnace', 'Electricity', nil, nil]

    # Get the system type
    system_type = sys_lookup[sys_num][fuel_type]

    if system_type.nil?
      system_type = [nil, nil, nil, nil]
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not determine system type for #{template}, #{area_type}, #{fuel_type}, #{area_ft2.round} ft^2, #{num_stories} stories.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "System type is #{system_type[0]} for #{template}, #{area_type}, #{fuel_type}, #{area_ft2.round} ft^2, #{num_stories} stories.")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{system_type[1]} for main heating") unless system_type[1].nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{system_type[2]} for zone heat/reheat") unless system_type[2].nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{system_type[3]} for cooling") unless system_type[3].nil?
    end

    return system_type
  end

  # Determines which system number is used for the baseline system. Default is 90.1-2004 approach.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param area_type [String] Valid choices are residential, nonresidential, and heatedonly
  # @param fuel_type [String] Valid choices are electric, fossil, fossilandelectric,
  #   purchasedheat, purchasedcooling, purchasedheatandcooling
  # @param area_ft2 [Double] Area in ft^2
  # @param num_stories [Integer] Number of stories
  # @param custom [String] custom fuel type
  # @return [String] the system number: 1_or_2, 3_or_4, 5_or_6, 7_or_8, 9_or_10
  def model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    sys_num = nil
    # Set the area limit
    limit_ft2 = 75_000

    # Warn about heated only
    if area_type == 'heatedonly'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Per Table G3.1.10.d, '(In the proposed building) Where no cooling system exists or no cooling system has been specified, the cooling system shall be identical to the system modeled in the baseline building design.' This requires that you go back and add a cooling system to the proposed model.  This code cannot do that for you; you must do it manually.")
    end

    case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential', 'heatedonly'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
          # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
          # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
    end

    return sys_num
  end

  # Change the fuel type based on climate zone, depending on the standard. Defaults to no change.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param fuel_type [String] Valid choices are electric, fossil, fossilandelectric,
  #   purchasedheat, purchasedcooling, purchasedheatandcooling
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param custom [String] custom fuel type
  # @return [String] the revised fuel type
  def model_prm_baseline_system_change_fuel_type(model, fuel_type, climate_zone, custom = nil)
    return fuel_type # Don't change fuel type for most templates
  end

  # Add the specified baseline system type to the specified zones based on the specified template.
  # For some multi-zone system types, the standards require identifying zones whose loads or schedules
  # are outliers and putting these systems on separate single-zone systems.  This method does that.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param system_type [String] The system type.  Valid choices are PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat,
  #   PVAV_PFP_Boxes, VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace,
  #   which are also returned by the method OpenStudio::Model::Model.prm_baseline_system_type.
  # @param main_heat_fuel [String] main heating fuel.  Valid choices are Electricity, NaturalGas, DistrictHeating
  # @param zone_heat_fuel [String] zone heating/reheat fuel.  Valid choices are Electricity, NaturalGas, DistrictHeating
  # @param cool_fuel [String] cooling fuel.  Valid choices are Electricity, DistrictCooling
  # @param zones [Array<OpenStudio::Model::ThermalZone>] an array of zones
  # @return [Bool] returns true if successful, false if not
  # @todo Add 90.1-2013 systems 11-13
  def model_add_prm_baseline_system(model, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, zones)
    case system_type
      when 'PTAC' # System 1
        unless zones.empty?
          # Retrieve the existing hot water loop or add a new one if necessary.
          hot_water_loop = nil
          hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                             model.getPlantLoopByName('Hot Water Loop').get
                           else
                             model_add_hw_loop(model, main_heat_fuel)
                           end

          # Add a hot water PTAC to each zone
          model_add_ptac(model,
                         zones,
                         cooling_type: 'Single Speed DX AC',
                         heating_type: 'Water',
                         hot_water_loop: hot_water_loop,
                         fan_type: 'ConstantVolume')
        end

      when 'PTHP' # System 2
        unless zones.empty?
          # add an air-source packaged terminal heat pump with electric supplemental heat to each zone.
          model_add_pthp(model,
                         zones,
                         fan_type: 'ConstantVolume')
        end

      when 'PSZ_AC' # System 3
        unless zones.empty?
          heating_type = 'Gas'
          # if district heating
          hot_water_loop = nil
          if main_heat_fuel == 'DistrictHeating'
            heating_type = 'Water'
            hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                               model.getPlantLoopByName('Hot Water Loop').get
                             else
                               model_add_hw_loop(model, main_heat_fuel)
                             end
          end

          cooling_type = 'Single Speed DX AC'
          # If district cooling
          chilled_water_loop = nil
          if cool_fuel == 'DistrictCooling'
            cooling_type = 'Water'
            chilled_water_loop = if model.getPlantLoopByName('Chilled Water Loop').is_initialized
                                   model.getPlantLoopByName('Chilled Water Loop').get
                                 else
                                   model_add_chw_loop(model,
                                                      cooling_fuel: cool_fuel,
                                                      chw_pumping_type: 'const_pri')
                                 end
          end

          # Add a PSZ-AC to each zone
          model_add_psz_ac(model,
                           zones,
                           cooling_type: cooling_type,
                           chilled_water_loop: chilled_water_loop,
                           heating_type: heating_type,
                           supplemental_heating_type: 'Gas',
                           hot_water_loop: hot_water_loop,
                           fan_location: 'DrawThrough',
                           fan_type: 'ConstantVolume')
        end

      when 'PSZ_HP' # System 4
        unless zones.empty?
          # Add an air-source packaged single zone heat pump with electric supplemental heat to each zone.
          model_add_psz_ac(model,
                           zones,
                           system_name: 'PSZ-HP',
                           cooling_type: 'Single Speed Heat Pump',
                           heating_type: 'Single Speed Heat Pump',
                           supplemental_heating_type: 'Electric',
                           fan_location: 'DrawThrough',
                           fan_type: 'ConstantVolume')
        end

      when 'PVAV_Reheat' # System 5
        # Retrieve the existing hot water loop or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         else
                           model_add_hw_loop(model, main_heat_fuel)
                         end

        # If district cooling
        chilled_water_loop = nil
        if cool_fuel == 'DistrictCooling'
          chilled_water_loop = if model.getPlantLoopByName('Chilled Water Loop').is_initialized
                                 model.getPlantLoopByName('Chilled Water Loop').get
                               else
                                 model_add_chw_loop(model,
                                                    cooling_fuel: cool_fuel,
                                                    chw_pumping_type: 'const_pri')
                               end
        end

        # If electric zone heat
        electric_reheat = false
        if zone_heat_fuel == 'Electricity'
          electric_reheat = true
        end

        # Group zones by story
        story_zone_lists = model_group_zones_by_story(model, zones)

        # For the array of zones on each story,
        # separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones
        # and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |story_group|
          # Differentiate primary and secondary zones
          pri_sec_zone_lists = model_differentiate_primary_secondary_thermal_zones(model, story_group)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']

          # Add a PVAV with Reheat for the primary zones
          stories = []
          story_group[0].spaces.each do |space|
            stories << [space.buildingStory.get.name.get, building_story_minimum_z_value(space.buildingStory.get)]
          end
          story_name = stories.min_by { |nm, z| z }[0]
          system_name = "#{story_name} PVAV_Reheat (Sys5)"

          # If and only if there are primary zones to attach to the loop
          # counter example: floor with only one elevator machine room that get classified as sec_zones
          unless pri_zones.empty?
            model_add_pvav(model,
                           pri_zones,
                           system_name: system_name,
                           hot_water_loop: hot_water_loop,
                           chilled_water_loop: chilled_water_loop,
                           electric_reheat: electric_reheat)
          end

          # Add a PSZ_AC for each secondary zone
          unless sec_zones.empty?
            model_add_prm_baseline_system(model, 'PSZ_AC', main_heat_fuel, zone_heat_fuel, cool_fuel, sec_zones)
          end
        end

      when 'PVAV_PFP_Boxes' # System 6
        # If district cooling
        chilled_water_loop = nil
        if cool_fuel == 'DistrictCooling'
          chilled_water_loop = if model.getPlantLoopByName('Chilled Water Loop').is_initialized
                                 model.getPlantLoopByName('Chilled Water Loop').get
                               else
                                 model_add_chw_loop(model,
                                                    cooling_fuel: cool_fuel,
                                                    chw_pumping_type: 'const_pri')
                               end
        end

        # Group zones by story
        story_zone_lists = model_group_zones_by_story(model, zones)

        # For the array of zones on each story,
        # separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones
        # and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |story_group|
          # Differentiate primary and secondary zones
          pri_sec_zone_lists = model_differentiate_primary_secondary_thermal_zones(model, story_group)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']

          # Add an VAV for the primary zones
          stories = []
          story_group[0].spaces.each do |space|
            stories << [space.buildingStory.get.name.get, building_story_minimum_z_value(space.buildingStory.get)]
          end
          story_name = stories.min_by { |nm, z| z }[0]
          system_name = "#{story_name} PVAV_PFP_Boxes (Sys6)"
          # If and only if there are primary zones to attach to the loop
          unless pri_zones.empty?
            model_add_pvav_pfp_boxes(model,
                                     pri_zones,
                                     system_name: system_name,
                                     chilled_water_loop: chilled_water_loop,
                                     fan_efficiency: 0.62,
                                     fan_motor_efficiency: 0.9,
                                     fan_pressure_rise: 4.0)
          end
          # Add a PSZ_HP for each secondary zone
          unless sec_zones.empty?
            model_add_prm_baseline_system(model, 'PSZ_HP', main_heat_fuel, zone_heat_fuel, cool_fuel, sec_zones)
          end
        end

      when 'VAV_Reheat' # System 7
        # Retrieve the existing hot water loop or add a new one if necessary.
        hot_water_loop = nil
        hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                           model.getPlantLoopByName('Hot Water Loop').get
                         else
                           model_add_hw_loop(model, main_heat_fuel)
                         end

        # Retrieve the existing chilled water loop or add a new one if necessary.
        chilled_water_loop = nil
        if model.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
        else
          if cool_fuel == 'DistrictCooling'
            chilled_water_loop = model_add_chw_loop(model,
                                                    cooling_fuel: cool_fuel,
                                                    chw_pumping_type: 'const_pri')
          else
            fan_type = model_cw_loop_cooling_tower_fan_type(model)
            condenser_water_loop = model_add_cw_loop(model,
                                                     cooling_tower_type: 'Open Cooling Tower',
                                                     cooling_tower_fan_type: 'Propeller or Axial',
                                                     cooling_tower_capacity_control: fan_type,
                                                     number_of_cells_per_tower: 1,
                                                     number_cooling_towers: 1)
            chilled_water_loop = model_add_chw_loop(model,
                                                    chw_pumping_type: 'const_pri_var_sec',
                                                    chiller_cooling_type: 'WaterCooled',
                                                    chiller_compressor_type: 'Rotary Screw',
                                                    condenser_water_loop: condenser_water_loop)
          end
        end

        # If electric zone heat
        reheat_type = 'Water'
        if zone_heat_fuel == 'Electricity'
          reheat_type = 'Electricity'
        end

        # Group zones by story
        story_zone_lists = model_group_zones_by_story(model, zones)

        # For the array of zones on each story, separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |story_group|
          # The model_group_zones_by_story(model)  NO LONGER returns empty lists when a given floor doesn't have any of the zones
          # So NO need to filter it out otherwise you get an error undefined method `spaces' for nil:NilClass
          # next if zones.empty?

          # Differentiate primary and secondary zones
          pri_sec_zone_lists = model_differentiate_primary_secondary_thermal_zones(model, story_group)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']

          # Add a VAV for the primary zones
          stories = []
          story_group[0].spaces.each do |space|
            stories << [space.buildingStory.get.name.get, building_story_minimum_z_value(space.buildingStory.get)]
          end
          story_name = stories.min_by { |nm, z| z }[0]
          system_name = "#{story_name} VAV_Reheat (Sys7)"

          # If and only if there are primary zones to attach to the loop
          # counter example: floor with only one elevator machine room that get classified as sec_zones
          unless pri_zones.empty?
            model_add_vav_reheat(model,
                                 pri_zones,
                                 system_name: system_name,
                                 reheat_type: reheat_type,
                                 hot_water_loop: hot_water_loop,
                                 chilled_water_loop: chilled_water_loop,
                                 fan_efficiency: 0.62,
                                 fan_motor_efficiency: 0.9,
                                 fan_pressure_rise: 4.0)
          end

          # Add a PSZ_AC for each secondary zone
          unless sec_zones.empty?
            model_add_prm_baseline_system(model, 'PSZ_AC', main_heat_fuel, zone_heat_fuel, cool_fuel, sec_zones)
          end
        end

      when 'VAV_PFP_Boxes' # System 8
        # Retrieve the existing chilled water loop or add a new one if necessary.
        chilled_water_loop = nil
        if model.getPlantLoopByName('Chilled Water Loop').is_initialized
          chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
        else
          if cool_fuel == 'DistrictCooling'
            chilled_water_loop = model_add_chw_loop(model,
                                                    cooling_fuel: cool_fuel,
                                                    chw_pumping_type: 'const_pri')
          else
            fan_type = model_cw_loop_cooling_tower_fan_type(model)
            condenser_water_loop = model_add_cw_loop(model,
                                                     cooling_tower_type: 'Open Cooling Tower',
                                                     cooling_tower_fan_type: 'Propeller or Axial',
                                                     cooling_tower_capacity_control: fan_type,
                                                     number_of_cells_per_tower: 1,
                                                     number_cooling_towers: 1)
            chilled_water_loop = model_add_chw_loop(model,
                                                    chw_pumping_type: 'const_pri_var_sec',
                                                    chiller_cooling_type: 'WaterCooled',
                                                    chiller_compressor_type: 'Rotary Screw',
                                                    condenser_water_loop: condenser_water_loop)
          end
        end

        # Group zones by story
        story_zone_lists = model_group_zones_by_story(model, zones)

        # For the array of zones on each story,
        # separate the primary zones from the secondary zones.
        # Add the baseline system type to the primary zones
        # and add the suplemental system type to the secondary zones.
        story_zone_lists.each do |story_group|
          # Differentiate primary and secondary zones
          pri_sec_zone_lists = model_differentiate_primary_secondary_thermal_zones(model, story_group)
          pri_zones = pri_sec_zone_lists['primary']
          sec_zones = pri_sec_zone_lists['secondary']

          # Add an VAV for the primary zones
          stories = []
          story_group[0].spaces.each do |space|
            stories << [space.buildingStory.get.name.get, building_story_minimum_z_value(space.buildingStory.get)]
          end
          story_name = stories.min_by { |nm, z| z }[0]
          system_name = "#{story_name} VAV_PFP_Boxes (Sys8)"
          # If and only if there are primary zones to attach to the loop
          unless pri_zones.empty?
            model_add_vav_pfp_boxes(model,
                                    pri_zones,
                                    system_name: system_name,
                                    chilled_water_loop: chilled_water_loop,
                                    fan_efficiency: 0.62,
                                    fan_motor_efficiency: 0.9,
                                    fan_pressure_rise: 4.0)
          end
          # Add a PSZ_HP for each secondary zone
          unless sec_zones.empty?
            model_add_prm_baseline_system(model, 'PSZ_HP', main_heat_fuel, zone_heat_fuel, cool_fuel, sec_zones)
          end
        end

      when 'Gas_Furnace' # System 9
        unless zones.empty?
          # If district heating
          hot_water_loop = nil
          if main_heat_fuel == 'DistrictHeating'
            hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                               model.getPlantLoopByName('Hot Water Loop').get
                             else
                               model_add_hw_loop(model, main_heat_fuel)
                             end
          end
          # Add a System 9 - Gas Unit Heater to each zone
          model_add_unitheater(model,
                               zones,
                               fan_control_type: 'ConstantVolume',
                               fan_pressure_rise: 0.2,
                               heating_type: main_heat_fuel,
                               hot_water_loop: hot_water_loop)
        end

      when 'Electric_Furnace' # System 10
        unless zones.empty?
          # Add a System 10 - Electric Unit Heater to each zone
          model_add_unitheater(model,
                               zones,
                               fan_control_type: 'ConstantVolume',
                               fan_pressure_rise: 0.2,
                               heating_type: main_heat_fuel)
        end

      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "System type #{system_type} is not a valid choice, nothing will be added to the model.")
        return false
    end
    return true
  end

  # Determines the fan type used by VAV_Reheat and VAV_PFP_Boxes systems.
  # Defaults to two speed fan.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_baseline_system_vav_fan_type(model)
    fan_type = 'TwoSpeed Fan'
    return fan_type
  end

  # Looks through the model and creates an hash of what the baseline system type should be for each zone.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param custom [String] custom fuel type
  # @return [Hash] keys are zones, values are system type strings
  #   PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes,
  #   VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace
  def model_get_baseline_system_type_by_zone(model, climate_zone, custom = nil)
    zone_to_sys_type = {}

    # Get the groups of zones that define the
    # baseline HVAC systems for later use.
    # This must be done before removing the HVAC systems
    # because it requires knowledge of proposed HVAC fuels.
    sys_groups = model_prm_baseline_system_groups(model, custom)

    # Assign building stories to spaces in the building
    # where stories are not yet assigned.
    model_assign_spaces_to_stories(model)

    # Determine the baseline HVAC system type for each of
    # the groups of zones and add that system type.
    sys_groups.each do |sys_group|
      # Determine the primary baseline system type
      pri_system_type = model_prm_baseline_system_type(model,
                                                       climate_zone,
                                                       sys_group['occ'],
                                                       sys_group['fuel'],
                                                       sys_group['area_ft2'],
                                                       sys_group['stories'],
                                                       custom)[0]

      # Record the zone-by-zone system type assignments
      case pri_system_type
        when 'PTAC', 'PTHP', 'PSZ_AC', 'PSZ_HP', 'Gas_Furnace', 'Electric_Furnace'

          sys_group['zones'].each do |zone|
            zone_to_sys_type[zone] = pri_system_type
          end

        when 'PVAV_Reheat', 'PVAV_PFP_Boxes', 'VAV_Reheat', 'VAV_PFP_Boxes'

          # Determine the secondary system type
          sec_system_type = nil
          case pri_system_type
          when 'PVAV_Reheat', 'VAV_Reheat'
            sec_system_type = 'PSZ_AC'
          when 'PVAV_PFP_Boxes', 'VAV_PFP_Boxes'
            sec_system_type = 'PSZ_HP'
          end

          # Group zones by story
          story_zone_lists = model_group_zones_by_story(model, sys_group['zones'])
          # For the array of zones on each story,
          # separate the primary zones from the secondary zones.
          # Add the baseline system type to the primary zones
          # and add the suplemental system type to the secondary zones.
          story_zone_lists.each do |zones|
            # Differentiate primary and secondary zones
            pri_sec_zone_lists = model_differentiate_primary_secondary_thermal_zones(model, zones)
            # Record the primary zone system types
            pri_sec_zone_lists['primary'].each do |zone|
              zone_to_sys_type[zone] = pri_system_type
            end
            # Record the secondary zone system types
            pri_sec_zone_lists['secondary'].each do |zone|
              zone_to_sys_type[zone] = sec_system_type
            end
          end
      end
    end

    return zone_to_sys_type
  end

  # elimates outlier zones based on a set of keys
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param array_of_zones [Array] an array of Hashes for each zone, with the keys 'zone'
  # @param key_to_inspect [String] hash key to inspect in array of zones
  # @param tolerance [Double] tolerance
  # @param field_name [String] field name to inspect
  # @param units [String] units
  # @return [Array] an array of Hashes for each zone
  def model_eliminate_outlier_zones(model, array_of_zones, key_to_inspect, tolerance, field_name, units)
    # Sort the zones by the desired key
    begin
      array_of_zones = array_of_zones.sort_by { |hsh| hsh[key_to_inspect] }
    rescue ArgumentError => e
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Unable to sort array_of_zones by #{key_to_inspect} due to #{e.message}, defaulting to order that was passed")
    end

    # Calculate the area-weighted average
    total = 0.0
    total_area = 0.0
    all_vals = []
    all_areas = []
    all_zn_names = []
    array_of_zones.each do |zn|
      val = zn[key_to_inspect]
      area = zn['area_ft2']
      total += val * area
      total_area += area
      all_vals << val.round(1)
      all_areas << area.round
      all_zn_names << zn['zone'].name.get.to_s
    end

    if total_area == 0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Total area is zero for array_of_zones with key #{key_to_inspect}, unable to calculate area-weighted average.")
      return false
    end

    avg = total / total_area
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Values for #{field_name}, tol = #{tolerance} #{units}, area ft2:")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "vals  #{all_vals.join(', ')}")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "areas #{all_areas.join(', ')}")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "names #{all_zn_names.join(', ')}")

    # Calculate the biggest delta and the index of the biggest delta
    biggest_delta_i = 0 # array at first item in case delta is 0
    biggest_delta = 0.0
    worst = nil
    array_of_zones.each_with_index do |zn, i|
      val = zn[key_to_inspect]
      if worst.nil? # array at first item in case delta is 0
        worst = val
      end
      delta = (val - avg).abs
      if delta >= biggest_delta
        biggest_delta = delta
        biggest_delta_i = i
        worst = val
      end
    end

    # puts "   #{worst} - #{avg.round} = #{biggest_delta.round} biggest delta"

    # Compare the biggest delta against the difference and eliminate that zone if higher than the limit.
    if biggest_delta > tolerance
      zn_name = array_of_zones[biggest_delta_i]['zone'].name.get.to_s
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For zone #{zn_name}, the #{field_name} of #{worst.round(1)} #{units} is more than #{tolerance} #{units} outside the area-weighted average of #{avg.round(1)} #{units}; it will be placed on its own secondary system.")
      array_of_zones.delete_at(biggest_delta_i)
      # Call method recursively if something was eliminated
      array_of_zones = model_eliminate_outlier_zones(model, array_of_zones, key_to_inspect, tolerance, field_name, units)
    else
      zn_name = array_of_zones[biggest_delta_i]['zone'].name.get.to_s
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For zone #{zn_name}, the #{field_name} #{worst.round(2)} #{units} - average #{field_name} #{avg.round(2)} #{units} = #{biggest_delta.round(2)} #{units} less than the tolerance of #{tolerance} #{units}, stopping elimination process.")
    end

    return array_of_zones
  end

  # Determine which of the zones should be served by the primary HVAC system.
  # First, eliminate zones that differ by more# than 40 full load hours per week.
  # In this case, lighting schedule is used as the proxy for operation instead
  # of occupancy to avoid accidentally removing transition spaces.
  # Second, eliminate zones whose design internal loads differ from the area-weighted average of all other zones
  # on the system by more than 10 Btu/hr*ft^2.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param zones [Array<OpenStudio::Model::ThermalZone>] an array of zones
  # @return [Hash] A hash of two arrays of ThermalZones,
  #   where the keys are 'primary' and 'secondary'
  def model_differentiate_primary_secondary_thermal_zones(model, zones)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Determining which zones are served by the primary vs. secondary HVAC system.')

    # Determine the operational hours (proxy is annual
    # full load lighting hours) for all zones
    zone_data_1 = []
    zones.each do |zone|
      data = {}
      data['zone'] = zone
      # Get the area
      area_ft2 = OpenStudio.convert(zone.floorArea * zone.multiplier, 'm^2', 'ft^2').get
      data['area_ft2'] = area_ft2
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "#{zone.name}")
      zone.spaces.each do |space|
        # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "***#{space.name}")
        # Get all lights from either the space
        # or the space type.
        all_lights = []
        all_lights += space.lights
        if space.spaceType.is_initialized
          all_lights += space.spaceType.get.lights
        end
        # Base the annual operational hours
        # on the first lights schedule with hours
        # greater than zero.
        ann_op_hrs = 0
        all_lights.sort.each do |lights|
          # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "******#{lights.name}")
          # Get the fractional lighting schedule
          lights_sch = lights.schedule
          full_load_hrs = 0.0
          # Skip lights with no schedule
          next if lights_sch.empty?

          lights_sch = lights_sch.get
          if lights_sch.to_ScheduleRuleset.is_initialized
            lights_sch = lights_sch.to_ScheduleRuleset.get
            full_load_hrs = schedule_ruleset_annual_equivalent_full_load_hrs(lights_sch)
            if full_load_hrs > 0
              ann_op_hrs = full_load_hrs
              break # Stop after the first schedule with more than 0 hrs
            end
          elsif lights_sch.to_ScheduleConstant.is_initialized
            lights_sch = lights_sch.to_ScheduleConstant.get
            full_load_hrs = schedule_constant_annual_equivalent_full_load_hrs(lights_sch)
            if full_load_hrs > 0
              ann_op_hrs = full_load_hrs
              break # Stop after the first schedule with more than 0 hrs
            end
          end
        end
        wk_op_hrs = ann_op_hrs / 52.0
        data['wk_op_hrs'] = wk_op_hrs
        # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "******wk_op_hrs = #{wk_op_hrs.round}")
      end

      zone_data_1 << data
    end

    # Filter out any zones that operate differently by more than 40hrs/wk.
    # This will be determined by a difference of more than (40 hrs/wk * 52 wks/yr) = 2080 annual full load hrs.
    zones_same_hrs = model_eliminate_outlier_zones(model, zone_data_1, 'wk_op_hrs', 40, 'weekly operating hrs', 'hrs')

    # Get the internal loads for
    # all remaining zones.
    zone_data_2 = []
    zones_same_hrs.each do |zn_data|
      data = {}
      zone = zn_data['zone']
      data['zone'] = zone
      # Get the area
      area_m2 = zone.floorArea * zone.multiplier
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
      data['area_ft2'] = area_ft2
      # Get the internal loads
      int_load_w = thermal_zone_design_internal_load(zone) * zone.multiplier
      # Normalize per-area
      int_load_w_per_m2 = int_load_w / area_m2
      int_load_btu_per_ft2 = OpenStudio.convert(int_load_w_per_m2, 'W/m^2', 'Btu/hr*ft^2').get
      data['int_load_btu_per_ft2'] = int_load_btu_per_ft2
      zone_data_2 << data
    end

    # Filter out any zones that are +/- 10 Btu/hr*ft^2 from the average
    pri_zn_data = model_eliminate_outlier_zones(model, zone_data_2, 'int_load_btu_per_ft2', 10, 'internal load', 'Btu/hr*ft^2')

    # Get just the primary zones themselves
    pri_zones = []
    pri_zone_names = []
    pri_zn_data.each do |zn_data|
      pri_zones << zn_data['zone']
      pri_zone_names << zn_data['zone'].name.get.to_s
    end

    # Get the secondary zones
    sec_zones = []
    sec_zone_names = []
    zones.each do |zone|
      unless pri_zones.include?(zone)
        sec_zones << zone
        sec_zone_names << zone.name.get.to_s
      end
    end

    # Report out the primary vs. secondary zones
    unless pri_zone_names.empty?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Primary system zones = #{pri_zone_names.join(', ')}.")
    end
    unless sec_zone_names.empty?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Secondary system zones = #{sec_zone_names.join(', ')}.")
    end

    return { 'primary' => pri_zones, 'secondary' => sec_zones }
  end

  # Group an array of zones into multiple arrays, one for each story in the building.
  # Zones with spaces on multiple stories will be assigned to only one of the stories.
  # Removes empty array (when the story doesn't contain any of the zones)
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param zones [Array<OpenStudio::Model::ThermalZone>] an array of zones
  # @return [Array<Array<OpenStudio::Model::ThermalZone>>] array of arrays of zones
  def model_group_zones_by_story(model, zones)
    story_zone_lists = []
    zones_already_assigned = []
    model.getBuildingStorys.sort.each do |story|
      # Get all the spaces on this story
      spaces = story.spaces

      # Get all the thermal zones that serve these spaces
      all_zones_on_story = []
      spaces.each do |space|
        if space.thermalZone.is_initialized
          all_zones_on_story << space.thermalZone.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space #{space.name} has no thermal zone, it is not included in the simulation.")
        end
      end

      # Find zones in the list that are on this story
      zones_on_story = []
      zones.each do |zone|
        if all_zones_on_story.include?(zone)
          # Skip zones that were already assigned to a story.
          # This can happen if a zone has multiple spaces on multiple stories.
          # Stairwells and atriums are typical scenarios.
          next if zones_already_assigned.include?(zone)

          zones_on_story << zone
          zones_already_assigned << zone
        end
      end

      unless zones_on_story.empty?
        story_zone_lists << zones_on_story
      end
    end

    return story_zone_lists
  end

  # Assign each space in the model to a building story based on common z (height) values.
  # If no story object is found for a particular height, create a new one and assign it to the space.
  # Does not assign a story to plenum spaces.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_assign_spaces_to_stories(model)
    # Make hash of spaces and minz values
    sorted_spaces = {}
    model.getSpaces.sort.each do |space|
      # Skip plenum spaces
      next if space_plenum?(space)

      # loop through space surfaces to find min z value
      z_points = []
      space.surfaces.each do |surface|
        surface.vertices.each do |vertex|
          z_points << vertex.z
        end
      end
      minz = z_points.min + space.zOrigin
      sorted_spaces[space] = minz
    end

    # Pre-sort spaces
    sorted_spaces = sorted_spaces.sort_by { |a| a[1] }

    # Take the sorted list and assign/make stories
    sorted_spaces.each do |space|
      space_obj = space[0]
      space_minz = space[1]
      if space_obj.buildingStory.empty?
        story = model_get_story_for_nominal_z_coordinate(model, space_minz)
        space_obj.setBuildingStory(story)
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space #{space[0].name} was not assigned to a story by the user.  It has been assigned to #{story.name}.")
      end
    end

    return true
  end

  # Applies the multi-zone VAV outdoor air sizing requirements to all applicable air loops in the model.
  # @note This must be performed before the sizing run because it impacts component sizes, which in turn impact efficiencies.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_apply_multizone_vav_outdoor_air_sizing(model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying multizone vav OA sizing.')

    # Multi-zone VAV outdoor air sizing
    model.getAirLoopHVACs.sort.each { |obj| air_loop_hvac_apply_multizone_vav_outdoor_air_sizing(obj) }

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying multizone vav OA sizing.')
  end

  # Applies the HVAC parts of the template to all objects in the model using the the template specified in the model.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param apply_controls [Bool] toggle whether to apply air loop and plant loop controls
  # @param sql_db_vars_map [Hash] hash map
  # @return [Bool] returns true if successful, false if not
  def model_apply_hvac_efficiency_standard(model, climate_zone, apply_controls: true, sql_db_vars_map: nil)
    sql_db_vars_map = {} if sql_db_vars_map.nil?

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Started applying HVAC efficiency standards for #{template} template.")

    # Air Loop Controls
    if apply_controls.nil? || apply_controls == true
      model.getAirLoopHVACs.sort.each { |obj| air_loop_hvac_apply_standard_controls(obj, climate_zone) }
    end

    # Plant Loop Controls
    if apply_controls.nil? || apply_controls == true
      model.getPlantLoops.sort.each { |obj| plant_loop_apply_standard_controls(obj, climate_zone) }
    end

    # Zone HVAC Controls
    model.getZoneHVACComponents.sort.each { |obj| zone_hvac_component_apply_standard_controls(obj) }

    ##### Apply equipment efficiencies

    # Fans
    model.getFanVariableVolumes.sort.each { |obj| fan_apply_standard_minimum_motor_efficiency(obj, fan_brake_horsepower(obj)) }
    model.getFanConstantVolumes.sort.each { |obj| fan_apply_standard_minimum_motor_efficiency(obj, fan_brake_horsepower(obj)) }
    model.getFanOnOffs.sort.each { |obj| fan_apply_standard_minimum_motor_efficiency(obj, fan_brake_horsepower(obj)) }
    model.getFanZoneExhausts.sort.each { |obj| fan_apply_standard_minimum_motor_efficiency(obj, fan_brake_horsepower(obj)) }

    # Pumps
    model.getPumpConstantSpeeds.sort.each { |obj| pump_apply_standard_minimum_motor_efficiency(obj) }
    model.getPumpVariableSpeeds.sort.each { |obj| pump_apply_standard_minimum_motor_efficiency(obj) }
    model.getHeaderedPumpsConstantSpeeds.sort.each { |obj| pump_apply_standard_minimum_motor_efficiency(obj) }
    model.getHeaderedPumpsVariableSpeeds.sort.each { |obj| pump_apply_standard_minimum_motor_efficiency(obj) }

    # Unitary HPs
    # set DX HP coils before DX clg coils because when DX HP coils need to first
    # pull the capacities of their paired DX clg coils, and this does not work
    # correctly if the DX clg coil efficiencies have been set because they are renamed.
    model.getCoilHeatingDXSingleSpeeds.sort.each { |obj| sql_db_vars_map = coil_heating_dx_single_speed_apply_efficiency_and_curves(obj, sql_db_vars_map) }

    # Unitary ACs
    model.getCoilCoolingDXTwoSpeeds.sort.each { |obj| sql_db_vars_map = coil_cooling_dx_two_speed_apply_efficiency_and_curves(obj, sql_db_vars_map) }
    model.getCoilCoolingDXSingleSpeeds.sort.each { |obj| sql_db_vars_map = coil_cooling_dx_single_speed_apply_efficiency_and_curves(obj, sql_db_vars_map) }
    model.getCoilCoolingDXMultiSpeeds.sort.each { |obj| sql_db_vars_map = coil_cooling_dx_multi_speed_apply_efficiency_and_curves(obj, sql_db_vars_map) }

    # WSHPs
    # set WSHP heating coils before cooling coils to get cooling coil capacities before they are renamed
    model.getCoilHeatingWaterToAirHeatPumpEquationFits.sort.each { |obj| sql_db_vars_map = coil_heating_water_to_air_heat_pump_apply_efficiency_and_curves(obj, sql_db_vars_map) }
    model.getCoilCoolingWaterToAirHeatPumpEquationFits.sort.each { |obj| sql_db_vars_map = coil_cooling_water_to_air_heat_pump_apply_efficiency_and_curves(obj, sql_db_vars_map) }

    # Chillers
    clg_tower_objs = model.getCoolingTowerSingleSpeeds
    model.getChillerElectricEIRs.sort.each { |obj| chiller_electric_eir_apply_efficiency_and_curves(obj, clg_tower_objs) }

    # Boilers
    model.getBoilerHotWaters.sort.each { |obj| boiler_hot_water_apply_efficiency_and_curves(obj) }

    # Water Heaters
    model.getWaterHeaterMixeds.sort.each { |obj| water_heater_mixed_apply_efficiency(obj) }

    # Cooling Towers
    model.getCoolingTowerSingleSpeeds.sort.each { |obj| cooling_tower_single_speed_apply_efficiency_and_curves(obj) }
    model.getCoolingTowerTwoSpeeds.sort.each { |obj| cooling_tower_two_speed_apply_efficiency_and_curves(obj) }
    model.getCoolingTowerVariableSpeeds.sort.each { |obj| cooling_tower_variable_speed_apply_efficiency_and_curves(obj) }

    # Fluid Coolers
    model.getFluidCoolerSingleSpeeds.sort.each { |obj| fluid_cooler_apply_minimum_power_per_flow(obj, equipment_type: 'Dry Cooler') }
    model.getFluidCoolerTwoSpeeds.sort.each { |obj| fluid_cooler_apply_minimum_power_per_flow(obj, equipment_type: 'Dry Cooler') }
    model.getEvaporativeFluidCoolerSingleSpeeds.sort.each { |obj| fluid_cooler_apply_minimum_power_per_flow(obj, equipment_type: 'Closed Cooling Tower') }
    model.getEvaporativeFluidCoolerTwoSpeeds.sort.each { |obj| fluid_cooler_apply_minimum_power_per_flow(obj, equipment_type: 'Closed Cooling Tower') }

    # ERVs
    model.getHeatExchangerAirToAirSensibleAndLatents.each { |obj| heat_exchanger_air_to_air_sensible_and_latent_apply_effectiveness(obj) }

    # Gas Heaters
    model.getCoilHeatingGass.sort.each { |obj| coil_heating_gas_apply_efficiency_and_curves(obj) }
    model.getCoilHeatingGasMultiStages.each { |obj| coil_heating_gas_multi_stage_apply_efficiency_and_curves(obj) }

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Finished applying HVAC efficiency standards for #{template} template.")
    return true
  end

  # Applies daylighting controls to each space in the model per the standard.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_add_daylighting_controls(model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding daylighting controls.')

    # Add daylighting controls to each space
    model.getSpaces.sort.each do |space|
      added = space_add_daylighting_controls(space, false, false)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding daylighting controls.')
    return true
  end

  # Apply the air leakage requirements to the model, as described in PNNL section 5.2.1.6.
  # This method creates customized infiltration objects for each space
  # and removes the SpaceType-level infiltration objects.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  # @todo This infiltration method is not used by the Reference buildings, fix this inconsistency.
  def model_apply_infiltration_standard(model)
    # Set the infiltration rate at each space
    model.getSpaces.sort.each do |space|
      space_apply_infiltration_rate(space)
    end

    # Remove infiltration rates set at the space type
    model.getSpaceTypes.sort.each do |space_type|
      space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
    end

    return true
  end

  # Method to search through a hash for the objects that meets the desired search criteria, as passed via a hash.
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
  # @param num_floors [Double] capacity of the object in question.  If num_floors is supplied,
  #   the objects will only be returned if the specified num_floors is between the minimum_floors and maximum_floors values.
  # @return [Array] returns an array of hashes, one hash per object.  Array is empty if no results.
  # @example Find all the schedule rules that match the name
  #   rules = model_find_objects(standards_data['schedules'], 'name' => schedule_name)
  #   if rules.size.zero?
  #     OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
  #     return false
  #   end
  def model_find_objects(hash_of_objects, search_criteria, capacity = nil, date = nil, area = nil, num_floors = nil)
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
  # @return [Hash] Return tbe first matching object hash if successful, nil if not.
  # @example Find the motor that meets these size criteria
  #   search_criteria = {
  #   'template' => template,
  #   'number_of_poles' => 4.0,
  #   'type' => 'Enclosed',
  #   }
  #   motor_properties = self.model.find_object(motors, search_criteria, capacity: 2.5)
  def model_find_object(hash_of_objects, search_criteria, capacity = nil, date = nil, area = nil, num_floors = nil)
    matching_objects = model_find_objects(hash_of_objects, search_criteria, capacity, date, area, num_floors)

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

  # Method to search through a hash for the objects that meets the desired search criteria, as passed via a hash.
  # Returns an Array (empty if nothing found) of matching objects.
  #
  # @param table_name [Hash] name of table in standards database.
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between the minimum_capacity and maximum_capacity values.
  # @param date [<OpenStudio::Date>] date of the object in question.  If date is supplied,
  #   the objects will only be returned if the specified date is between the start_date and end_date.
  # @param area [Double] area of the object in question.  If area is supplied,
  #   the objects will only be returned if the specified area is between the minimum_area and maximum_area values.
  # @param num_floors [Double] capacity of the object in question.  If num_floors is supplied,
  #   the objects will only be returned if the specified num_floors is between the minimum_floors and maximum_floors values.
  # @return [Array] returns an array of hashes, one hash per object.  Array is empty if no results.
  # @example Find all the schedule rules that match the name
  #   rules = model_find_objects(standards_data['schedules'], 'name' => schedule_name)
  #   if rules.size.zero?
  #     OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
  #     return false
  #   end
  def standards_lookup_table_many(table_name:, search_criteria: {}, capacity: nil, date: nil, area: nil, num_floors: nil)
    desired_object = nil
    search_criteria_matching_objects = []
    matching_objects = []
    hash_of_objects = @standards_data[table_name]

    # needed for NRCan data structure compatibility. We keep all tables in a 'tables' hash in @standards_data and the table
    # itself is in the 'table' hash index.
    if hash_of_objects.nil?
      # Format of @standards_data is not NRCan-style and table simply doesn't exist.
      return matching_objects if @standards_data['tables'].nil?

      table = @standards_data['tables'][table_name]['table']
      hash_of_objects = table
    end

    # Compare each of the objects against the search criteria
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
        search_criteria_matching_objects.each do |object|
          # Skip objects that don't have fields for minimum_capacity and maximum_capacity
          next if !object.key?('minimum_capacity') || !object.key?('maximum_capacity')
          # Skip objects that don't have values specified for minimum_capacity and maximum_capacity
          next if object['minimum_capacity'].nil? || object['maximum_capacity'].nil?
          # Skip objects whose the minimum capacity is below the specified capacity
          next if capacity <= object['minimum_capacity'].to_f
          # Skip objects whose max
          next if capacity > object['maximum_capacity'].to_f

          # Found a matching object
          matching_objects << object
        end
      end
      # If date was specified, narrow down the matching objects
      unless date.nil?
        date_matching_objects = []
        matching_objects.each do |object|
          # Skip objects that don't have fields for minimum_capacity and maximum_capacity
          next if !object.key?('start_date') || !object.key?('end_date')
          # Skip objects whose the start date is earlier than the specified date
          next if date <= Date.parse(object['start_date'])
          # Skip objects whose end date is beyond the specified date
          next if date > Date.parse(object['end_date'])

          # Found a matching object
          date_matching_objects << object
        end
        matching_objects = date_matching_objects
      end
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
  # @param table_name [String] name of table
  # @param search_criteria [Hash] hash of search criteria
  # @param capacity [Double] capacity of the object in question.  If capacity is supplied,
  #   the objects will only be returned if the specified capacity is between the minimum_capacity and maximum_capacity values.
  # @param date [<OpenStudio::Date>] date of the object in question.  If date is supplied,
  #   the objects will only be returned if the specified date is between the start_date and end_date.
  # @return [Hash] Return tbe first matching object hash if successful, nil if not.
  # @example Find the motor that meets these size criteria
  #   search_criteria = {
  #   'template' => template,
  #   'number_of_poles' => 4.0,
  #   'type' => 'Enclosed',
  #   }
  #   motor_properties = self.model.find_object(motors, search_criteria, 2.5)
  def standards_lookup_table_first(table_name:, search_criteria: {}, capacity: nil, date: nil)
    # run the many version of the look up code...DRY.
    matching_objects = standards_lookup_table_many(table_name: table_name,
                                                   search_criteria: search_criteria,
                                                   capacity: capacity,
                                                   date: date)

    # Check the number of matching objects found
    if matching_objects.size.zero?
      desired_object = nil
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Find object search criteria returned no results. Search criteria: #{search_criteria}. Called from #{caller(0)[1]}")
    elsif matching_objects.size == 1
      desired_object = matching_objects[0]
    else
      desired_object = matching_objects[0]
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Find object search criteria returned #{matching_objects.size} results, the first one will be returned. Called from #{caller(0)[1]}. \n Search criteria: \n #{search_criteria}, capacity = #{capacity} \n  All results: \n#{matching_objects.join("\n")}")
    end

    return desired_object
  end

  # Create constant ScheduleRuleset
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param value [Double] the value to use, 24-7, 365
  # @param name [String] the name of the schedule
  # @param sch_type_limit [String] the name of a schedule type limit
  #   options are Temperature, Humidity Ratio, Fractional, OnOff, and Activity
  # @return [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  def model_add_constant_schedule_ruleset(model,
                                          value,
                                          name = nil,
                                          sch_type_limit: 'Temperature')
    # check to see if schedule exists with same name and constant value and return if true
    unless name.nil?
      existing_sch = model.getScheduleRulesetByName(name)
      if existing_sch.is_initialized
        existing_sch = existing_sch.get
        existing_day_sch_vals = existing_sch.defaultDaySchedule.values
        if existing_day_sch_vals.size == 1 && (existing_day_sch_vals[0] - value).abs < 1.0e-6
          return existing_sch
        end
      end
    end

    schedule = OpenStudio::Model::ScheduleRuleset.new(model)
    unless name.nil?
      schedule.setName(name)
      schedule.defaultDaySchedule.setName("#{name} Default")
    end

    if !sch_type_limit.nil?
      sch_type_limits_obj = model_add_schedule_type_limits(model, standard_sch_type_limit: sch_type_limit)
      schedule.setScheduleTypeLimits(sch_type_limits_obj)
    end

    schedule.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), value)
    return schedule
  end

  # Create ScheduleTypeLimits
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param standard_sch_type_limit [String] the name of a standard schedule type limit with predefined limits
  #   options are Temperature, Humidity Ratio, Fractional, OnOff, and Activity
  # @param name [String] the name of the schedule type limits
  # @param lower_limit_value [double] the lower limit value for the schedule type
  # @param upper_limit_value [double] the upper limit value for the schedule type
  # @param numeric_type [String] the numeric type, options are Continuous or Discrete
  # @param unit_type [String] the unit type, options are defined in EnergyPlus I/O reference
  # @return [OpenStudio::Model::ScheduleTypeLimits] schedule type limits
  def model_add_schedule_type_limits(model,
                                     standard_sch_type_limit: nil,
                                     name: nil,
                                     lower_limit_value: nil,
                                     upper_limit_value: nil,
                                     numeric_type: nil,
                                     unit_type: nil)

    if standard_sch_type_limit.nil?
      if lower_limit_value.nil? || upper_limit_value.nil? || numeric_type.nil? || unit_type.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'If calling model_add_schedule_type_limits without a standard_sch_type_limit, you must specify all properties of ScheduleTypeLimits.')
        return false
      end
      schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
      schedule_type_limits.setName(name) if !name.nil?
      schedule_type_limits.setLowerLimitValue(lower_limit_value)
      schedule_type_limits.setUpperLimitValue(upper_limit_value)
      schedule_type_limits.setNumericType(numeric_type)
      schedule_type_limits.setUnitType(unit_type)
    else
      schedule_type_limits = model.getScheduleTypeLimitsByName(standard_sch_type_limit)
      if !schedule_type_limits.empty?
        schedule_type_limits = schedule_type_limits.get
        if schedule_type_limits.name.to_s.downcase == 'temperature'
          schedule_type_limits.resetLowerLimitValue
          schedule_type_limits.resetUpperLimitValue
          schedule_type_limits.setNumericType('Continuous')
          schedule_type_limits.setUnitType('Temperature')
        end
      else
        case standard_sch_type_limit.downcase
          when 'temperature'
            schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            schedule_type_limits.setName('Temperature')
            schedule_type_limits.setLowerLimitValue(0.0)
            schedule_type_limits.setUpperLimitValue(100.0)
            schedule_type_limits.setNumericType('Continuous')
            schedule_type_limits.setUnitType('Temperature')

          when 'humidity ratio'
            schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            schedule_type_limits.setName('Humidity Ratio')
            schedule_type_limits.setLowerLimitValue(0.0)
            schedule_type_limits.setUpperLimitValue(0.3)
            schedule_type_limits.setNumericType('Continuous')
            schedule_type_limits.setUnitType('Dimensionless')

          when 'fraction', 'fractional'
            schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            schedule_type_limits.setName('Fraction')
            schedule_type_limits.setLowerLimitValue(0.0)
            schedule_type_limits.setUpperLimitValue(1.0)
            schedule_type_limits.setNumericType('Continuous')
            schedule_type_limits.setUnitType('Dimensionless')

          when 'onoff'
            schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            schedule_type_limits.setName('OnOff')
            schedule_type_limits.setLowerLimitValue(0)
            schedule_type_limits.setUpperLimitValue(1)
            schedule_type_limits.setNumericType('Discrete')
            schedule_type_limits.setUnitType('Availability')

          when 'activity'
            schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            schedule_type_limits.setName('Activity')
            schedule_type_limits.setLowerLimitValue(70.0)
            schedule_type_limits.setUpperLimitValue(1000.0)
            schedule_type_limits.setNumericType('Continuous')
            schedule_type_limits.setUnitType('ActivityLevel')
          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Invalid standard_sch_type_limit for method model_add_schedule_type_limits.')
        end
      end
    end
    return schedule_type_limits
  end

  # Create a schedule from the openstudio standards dataset and add it to the model.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param schedule_name [String} name of the schedule
  # @return [ScheduleRuleset] the resulting schedule ruleset
  # @todo make return an OptionalScheduleRuleset
  def model_add_schedule(model, schedule_name)
    return nil if schedule_name.nil? || schedule_name == ''

    # First check model and return schedule if it already exists
    model.getSchedules.sort.each do |schedule|
      if schedule.name.get.to_s == schedule_name
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added schedule: #{schedule_name}")
        return schedule
      end
    end

    require 'date'

    # OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding schedule: #{schedule_name}")

    # Find all the schedule rules that match the name
    rules = model_find_objects(standards_data['schedules'], 'name' => schedule_name)
    if rules.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find data for schedule: #{schedule_name}, will not be created.")
      return model.alwaysOnDiscreteSchedule
    end

    # Make a schedule ruleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    sch_ruleset.setName(schedule_name.to_s)

    # Loop through the rules, making one for each row in the spreadsheet
    rules.each do |rule|
      day_types = rule['day_types']
      start_date = DateTime.parse(rule['start_date'])
      end_date = DateTime.parse(rule['end_date'])
      sch_type = rule['type']
      values = rule['values']

      # Day Type choices: Wkdy, Wknd, Mon, Tue, Wed, Thu, Fri, Sat, Sun, WntrDsn, SmrDsn, Hol
      # Default
      if day_types.include?('Default')
        day_sch = sch_ruleset.defaultDaySchedule
        day_sch.setName("#{schedule_name} Default")
        model_add_vals_to_sch(model, day_sch, sch_type, values)
      end

      # Winter Design Day
      if day_types.include?('WntrDsn')
        day_sch = OpenStudio::Model::ScheduleDay.new(model)
        sch_ruleset.setWinterDesignDaySchedule(day_sch)
        day_sch = sch_ruleset.winterDesignDaySchedule
        day_sch.setName("#{schedule_name} Winter Design Day")
        model_add_vals_to_sch(model, day_sch, sch_type, values)
      end

      # Summer Design Day
      if day_types.include?('SmrDsn')
        day_sch = OpenStudio::Model::ScheduleDay.new(model)
        sch_ruleset.setSummerDesignDaySchedule(day_sch)
        day_sch = sch_ruleset.summerDesignDaySchedule
        day_sch.setName("#{schedule_name} Summer Design Day")
        model_add_vals_to_sch(model, day_sch, sch_type, values)
      end

      # Other days (weekdays, weekends, etc)
      if day_types.include?('Wknd') ||
         day_types.include?('Wkdy') ||
         day_types.include?('Sat') ||
         day_types.include?('Sun') ||
         day_types.include?('Mon') ||
         day_types.include?('Tue') ||
         day_types.include?('Wed') ||
         day_types.include?('Thu') ||
         day_types.include?('Fri')

        # Make the Rule
        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{schedule_name} #{day_types} Day")
        model_add_vals_to_sch(model, day_sch, sch_type, values)

        # Set the dates when the rule applies
        sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_date.month.to_i), start_date.day.to_i))
        sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_date.month.to_i), end_date.day.to_i))

        # Set the days when the rule applies
        # Weekends
        if day_types.include?('Wknd')
          sch_rule.setApplySaturday(true)
          sch_rule.setApplySunday(true)
        end
        # Weekdays
        if day_types.include?('Wkdy')
          sch_rule.setApplyMonday(true)
          sch_rule.setApplyTuesday(true)
          sch_rule.setApplyWednesday(true)
          sch_rule.setApplyThursday(true)
          sch_rule.setApplyFriday(true)
        end
        # Individual Days
        sch_rule.setApplyMonday(true) if day_types.include?('Mon')
        sch_rule.setApplyTuesday(true) if day_types.include?('Tue')
        sch_rule.setApplyWednesday(true) if day_types.include?('Wed')
        sch_rule.setApplyThursday(true) if day_types.include?('Thu')
        sch_rule.setApplyFriday(true) if day_types.include?('Fri')
        sch_rule.setApplySaturday(true) if day_types.include?('Sat')
        sch_rule.setApplySunday(true) if day_types.include?('Sun')
      end
    end
    return sch_ruleset
  end

  # Create a material from the openstudio standards dataset.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param material_name [String] name of the material
  # @return [OpenStudio::Model::Material] material object
  # @todo make return an OptionalMaterial
  def model_add_material(model, material_name)
    # First check model and return material if it already exists
    model.getMaterials.sort.each do |material|
      if material.name.get.to_s == material_name
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added material: #{material_name}")
        return material
      end
    end

    # OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding material: #{material_name}")

    # Get the object data
    data = model_find_object(standards_data['materials'], 'name' => material_name)
    unless data
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for material: #{material_name}, will not be created.")
      return false
      # @todo change to return empty optional material
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
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Unknown material type #{material_type}, cannot add material called #{material_name}.")
      exit
    end

    return material
  end

  # Create a construction from the openstudio standards dataset.
  # If construction_props are specified, modifies the insulation layer accordingly.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param construction_name [String] name of the construction
  # @param construction_props [Hash] hash of construction properties
  # @return [OpenStudio::Model::Construction] construction object
  # @todo make return an OptionalConstruction
  def model_add_construction(model, construction_name, construction_props = nil)
    # First check model and return construction if it already exists
    model.getConstructions.sort.each do |construction|
      if construction.name.get.to_s == construction_name
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added construction: #{construction_name}")
        return construction
      end
    end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Adding construction: #{construction_name}")

    # Get the object data
    data = model_find_object(standards_data['constructions'], 'name' => construction_name)
    unless data
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find data for construction: #{construction_name}, will not be created.")
      return OpenStudio::Model::OptionalConstruction.new
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

    # @todo could put construction rendering color in the spreadsheet

    # Add the material layers to the construction
    layers = OpenStudio::Model::MaterialVector.new
    data['materials'].each do |material_name|
      material = model_add_material(model, material_name)
      if material
        layers << material
      end
    end
    construction.setLayers(layers)

    # Modify the R value of the insulation to hit the specified U-value, C-Factor, or F-Factor.
    # Doesn't currently operate on glazing constructions
    if construction_props
      # Determine the target U-value, C-factor, and F-factor
      target_u_value_ip = construction_props['assembly_maximum_u_value']
      target_f_factor_ip = construction_props['assembly_maximum_f_factor']
      target_c_factor_ip = construction_props['assembly_maximum_c_factor']
      target_shgc = construction_props['assembly_maximum_solar_heat_gain_coefficient']
      u_includes_int_film = construction_props['u_value_includes_interior_film_coefficient']
      u_includes_ext_film = construction_props['u_value_includes_exterior_film_coefficient']

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "#{data['intended_surface_type']} u_val #{target_u_value_ip} f_fac #{target_f_factor_ip} c_fac #{target_c_factor_ip}")

      if target_u_value_ip

        # Handle Opaque and Fenestration Constructions differently
        if construction.isFenestration && construction_simple_glazing?(construction)
          # Set the U-Value and SHGC
          construction_set_glazing_u_value(construction, target_u_value_ip.to_f, data['intended_surface_type'], u_includes_int_film, u_includes_ext_film)
          construction_set_glazing_shgc(construction, target_shgc.to_f)
        else # if !data['intended_surface_type'] == 'ExteriorWindow' && !data['intended_surface_type'] == 'Skylight'
          # Set the U-Value
          construction_set_u_value(construction, target_u_value_ip.to_f, data['insulation_layer'], data['intended_surface_type'], u_includes_int_film, u_includes_ext_film)
          # else
          # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Not modifying U-value for #{data['intended_surface_type']} u_val #{target_u_value_ip} f_fac #{target_f_factor_ip} c_fac #{target_c_factor_ip}")
        end

      elsif target_f_factor_ip && data['intended_surface_type'] == 'GroundContactFloor'

        # Set the F-Factor (only applies to slabs on grade)
        # @todo figure out what the prototype buildings did about ground heat transfer
        # construction_set_slab_f_factor(construction, target_f_factor_ip.to_f, data['insulation_layer'])
        construction_set_u_value(construction, 0.0, data['insulation_layer'], data['intended_surface_type'], u_includes_int_film, u_includes_ext_film)

      elsif target_c_factor_ip && data['intended_surface_type'] == 'GroundContactWall'

        # Set the C-Factor (only applies to underground walls)
        # @todo figure out what the prototype buildings did about ground heat transfer
        # construction_set_underground_wall_c_factor(construction, target_c_factor_ip.to_f, data['insulation_layer'])
        construction_set_u_value(construction, 0.0, data['insulation_layer'], data['intended_surface_type'], u_includes_int_film, u_includes_ext_film)

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

      # If the construction has a skylight framing material specified,
      # get the skylight frame material properties and add frame to
      # all skylights in the model.
      if data['skylight_framing']
        # Get the skylight framing material
        framing_name = data['skylight_framing']
        frame_data = model_find_object(standards_data['materials'], 'name' => framing_name)
        if frame_data
          frame_width_in = frame_data['frame_width'].to_f
          frame_with_m = OpenStudio.convert(frame_width_in, 'in', 'm').get
          frame_resistance_ip = frame_data['resistance'].to_f
          frame_resistance_si = OpenStudio.convert(frame_resistance_ip, 'hr*ft^2*R/Btu', 'm^2*K/W').get
          frame_conductance_si = 1.0 / frame_resistance_si
          frame = OpenStudio::Model::WindowPropertyFrameAndDivider.new(model)
          frame.setName("Skylight frame R-#{frame_resistance_ip.round(2)} #{frame_width_in.round(1)} in. wide")
          frame.setFrameWidth(frame_with_m)
          frame.setFrameConductance(frame_conductance_si)
          skylights_frame_added = 0
          model.getSubSurfaces.each do |sub_surface|
            next unless sub_surface.outsideBoundaryCondition == 'Outdoors' && sub_surface.subSurfaceType == 'Skylight'

            # @todo enable proper window frame setting after https://github.com/NREL/OpenStudio/issues/2895 is fixed
            sub_surface.setString(8, frame.name.get.to_s)
            skylights_frame_added += 1
            # if sub_surface.allowWindowPropertyFrameAndDivider
            #   sub_surface.setWindowPropertyFrameAndDivider(frame)
            #   skylights_frame_added += 1
            # else
            #   OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "For #{sub_surface.name}: cannot add a frame to this skylight.")
            # end
          end
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding #{frame.name} to #{skylights_frame_added} skylights.") if skylights_frame_added > 0
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Cannot find skylight framing data for: #{framing_name}, will not be created.")
          return false
          # @todo change to return empty optional material
        end
      end

    end
    #     # Check if the construction with the modified name was already in the model.
    #     # If it was, delete this new construction and return the copy already in the model.
    #     m = construction.name.get.to_s.match(/\s(\d+)/)
    #     if m
    #       revised_cons_name = construction.name.get.to_s.gsub(/\s\d+/,'')
    #       model.getConstructions.sort.each do |exist_construction|
    #         if exist_construction.name.get.to_s == revised_cons_name
    #           OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added construction: #{construction_name}")
    #           # Remove the recently added construction
    #           lyrs = construction.layers
    #           # Erase the layers in the construction
    #           construction.setLayers([])
    #           # Delete unused materials
    #           lyrs.uniq.each do |lyr|
    #             if lyr.directUseCount.zero?
    #               OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Removing Material: #{lyr.name}")
    #               lyr.remove
    #             end
    #           end
    #           construction.remove # Remove the construction
    #           return exist_construction
    #         end
    #       end
    #     end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction #{construction.name}.")

    return construction
  end

  # Helper method to find a particular construction and add it to the model after modifying the insulation value if necessary.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone_set [String] climate zone set
  # @param intended_surface_type [String] intended surface type
  # @param standards_construction_type [String] standards construction type
  # @param building_category [String] building category
  # @return [OpenStudio::Model::Construction] construction object
  def model_find_and_add_construction(model, climate_zone_set, intended_surface_type, standards_construction_type, building_category)
    # Get the construction properties,
    # which specifies properties by construction category by climate zone set.
    # AKA the info in Tables 5.5-1-5.5-8

    wwr = model_get_percent_of_surface_range(model, intended_surface_type)

    search_criteria = { 'template' => template,
                        'climate_zone_set' => climate_zone_set,
                        'intended_surface_type' => intended_surface_type,
                        'standards_construction_type' => standards_construction_type,
                        'building_category' => building_category }

    if !wwr['minimum_percent_of_surface'].nil? && !wwr['maximum_percent_of_surface'].nil?
      search_criteria['minimum_percent_of_surface'] = wwr['minimum_percent_of_surface']
      search_criteria['maximum_percent_of_surface'] = wwr['maximum_percent_of_surface']
    end

    # First search
    props = model_find_object(standards_data['construction_properties'], search_criteria)

    if !props
      # Second search: In case need to use climate zone (e.g: 3) instead of sub-climate zone (e.g: 3A) for search
      climate_zone = climate_zone_set[0..-2]
      search_criteria['climate_zone_set'] = climate_zone
      props = model_find_object(standards_data['construction_properties'], search_criteria)
    end

    if !props
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find construction properties for: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}.")
      # Return an empty construction
      construction = OpenStudio::Model::Construction.new(model)
      construction.setName('Could not find construction properties set to Adiabatic ')
      almost_adiabatic = OpenStudio::Model::MasslessOpaqueMaterial.new(model, 'Smooth', 500)
      construction.insertLayer(0, almost_adiabatic)
      return construction
      # else
      # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Construction properties for: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category} = #{props}.")
    end

    # Make sure that a construction is specified
    if props['construction'].nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No typical construction is specified for construction properties of: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}.  Make sure it is entered in the spreadsheet.")
      # Return an empty construction
      construction = OpenStudio::Model::Construction.new(model)
      construction.setName('No typical construction was specified')
      return construction
    end

    # Add the construction, modifying properties as necessary
    construction = model_add_construction(model, props['construction'], props)

    return construction
  end

  # Create a construction set from the openstudio standards dataset.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param building_type [String] the building type
  # @param spc_type [String] the space type
  # @param is_residential [Bool] true if the building is residential
  # @return [OpenStudio::Model::OptionalDefaultConstructionSet] an optional default construction set
  def model_add_construction_set(model, climate_zone, building_type, spc_type, is_residential)
    construction_set = OpenStudio::Model::OptionalDefaultConstructionSet.new

    # Find the climate zone set that this climate zone falls into
    climate_zone_set = model_find_climate_zone_set(model, climate_zone)
    unless climate_zone_set
      return construction_set
    end

    # Get the object data
    data = model_find_object(standards_data['construction_sets'], 'template' => template, 'climate_zone_set' => climate_zone_set, 'building_type' => building_type, 'space_type' => spc_type, 'is_residential' => is_residential)
    unless data
      # Search again without the is_residential criteria in the case that this field is not specified for a standard
      data = model_find_object(standards_data['construction_sets'], 'template' => template, 'climate_zone_set' => climate_zone_set, 'building_type' => building_type, 'space_type' => spc_type)
      unless data
        # if nothing matches say that we could not find it
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Construction set for template =#{template}, climate zone set =#{climate_zone_set}, building type = #{building_type}, space type = #{spc_type}, is residential = #{is_residential} was not found in standards_data['construction_sets']")
        return construction_set
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Adding construction set: #{template}-#{climate_zone}-#{building_type}-#{spc_type}-is_residential#{is_residential}")

    name = model_make_name(model, climate_zone, building_type, spc_type)

    # Create a new construction set and name it
    construction_set = OpenStudio::Model::DefaultConstructionSet.new(model)
    construction_set.setName(name)

    # Exterior surfaces constructions
    exterior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
    construction_set.setDefaultExteriorSurfaceConstructions(exterior_surfaces)
    # Special condition for attics, where the insulation is actually on the floor but the soffit is uninsulated
    if spc_type == 'Attic'
      exterior_surfaces.setFloorConstruction(model_add_construction(model, 'Typical Attic Soffit'))
    else
      if data['exterior_floor_standards_construction_type'] && data['exterior_floor_building_category']
        exterior_surfaces.setFloorConstruction(model_find_and_add_construction(model,
                                                                               climate_zone_set,
                                                                               'ExteriorFloor',
                                                                               data['exterior_floor_standards_construction_type'],
                                                                               data['exterior_floor_building_category']))
      end
    end
    if data['exterior_wall_standards_construction_type'] && data['exterior_wall_building_category']
      exterior_surfaces.setWallConstruction(model_find_and_add_construction(model,
                                                                            climate_zone_set,
                                                                            'ExteriorWall',
                                                                            data['exterior_wall_standards_construction_type'],
                                                                            data['exterior_wall_building_category']))
    end
    # Special condition for attics, where the insulation is actually on the floor and the roof itself is uninsulated
    if spc_type == 'Attic'
      if data['exterior_roof_standards_construction_type'] && data['exterior_roof_building_category']
        exterior_surfaces.setRoofCeilingConstruction(model_add_construction(model, 'Typical Uninsulated Wood Joist Attic Roof'))
      end
    else
      if data['exterior_roof_standards_construction_type'] && data['exterior_roof_building_category']
        exterior_surfaces.setRoofCeilingConstruction(model_find_and_add_construction(model,
                                                                                     climate_zone_set,
                                                                                     'ExteriorRoof',
                                                                                     data['exterior_roof_standards_construction_type'],
                                                                                     data['exterior_roof_building_category']))
      end
    end
    # Interior surfaces constructions
    interior_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
    construction_set.setDefaultInteriorSurfaceConstructions(interior_surfaces)
    construction_name = data['interior_floors']
    # Special condition for attics, where the insulation is actually on the floor and the roof itself is uninsulated
    if spc_type == 'Attic'
      if data['exterior_roof_standards_construction_type'] && data['exterior_roof_building_category']
        interior_surfaces.setFloorConstruction(model_find_and_add_construction(model,
                                                                               climate_zone_set,
                                                                               'ExteriorRoof',
                                                                               data['exterior_roof_standards_construction_type'],
                                                                               data['exterior_roof_building_category']))

      end
    else
      unless construction_name.nil?
        interior_surfaces.setFloorConstruction(model_add_construction(model, construction_name))
      end
    end
    construction_name = data['interior_walls']
    unless construction_name.nil?
      interior_surfaces.setWallConstruction(model_add_construction(model, construction_name))
    end
    construction_name = data['interior_ceilings']
    unless construction_name.nil?
      interior_surfaces.setRoofCeilingConstruction(model_add_construction(model, construction_name))
    end

    # Ground contact surfaces constructions
    ground_surfaces = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
    construction_set.setDefaultGroundContactSurfaceConstructions(ground_surfaces)
    if data['ground_contact_floor_standards_construction_type'] && data['ground_contact_floor_building_category']
      ground_surfaces.setFloorConstruction(model_find_and_add_construction(model,
                                                                           climate_zone_set,
                                                                           'GroundContactFloor',
                                                                           data['ground_contact_floor_standards_construction_type'],
                                                                           data['ground_contact_floor_building_category']))
    end
    if data['ground_contact_wall_standards_construction_type'] && data['ground_contact_wall_building_category']
      ground_surfaces.setWallConstruction(model_find_and_add_construction(model,
                                                                          climate_zone_set,
                                                                          'GroundContactWall',
                                                                          data['ground_contact_wall_standards_construction_type'],
                                                                          data['ground_contact_wall_building_category']))
    end
    if data['ground_contact_ceiling_standards_construction_type'] && data['ground_contact_ceiling_building_category']
      ground_surfaces.setRoofCeilingConstruction(model_find_and_add_construction(model,
                                                                                 climate_zone_set,
                                                                                 'GroundContactRoof',
                                                                                 data['ground_contact_ceiling_standards_construction_type'],
                                                                                 data['ground_contact_ceiling_building_category']))

    end

    # Exterior sub surfaces constructions
    exterior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(model)
    construction_set.setDefaultExteriorSubSurfaceConstructions(exterior_subsurfaces)
    if data['exterior_fixed_window_standards_construction_type'] && data['exterior_fixed_window_building_category']
      exterior_subsurfaces.setFixedWindowConstruction(model_find_and_add_construction(model,
                                                                                      climate_zone_set,
                                                                                      'ExteriorWindow',
                                                                                      data['exterior_fixed_window_standards_construction_type'],
                                                                                      data['exterior_fixed_window_building_category']))
    end
    if data['exterior_operable_window_standards_construction_type'] && data['exterior_operable_window_building_category']
      exterior_subsurfaces.setOperableWindowConstruction(model_find_and_add_construction(model,
                                                                                         climate_zone_set,
                                                                                         'ExteriorWindow',
                                                                                         data['exterior_operable_window_standards_construction_type'],
                                                                                         data['exterior_operable_window_building_category']))
    end
    if data['exterior_door_standards_construction_type'] && data['exterior_door_building_category']
      exterior_subsurfaces.setDoorConstruction(model_find_and_add_construction(model,
                                                                               climate_zone_set,
                                                                               'ExteriorDoor',
                                                                               data['exterior_door_standards_construction_type'],
                                                                               data['exterior_door_building_category']))
    end
    if data['exterior_glass_door_standards_construction_type'] && data['exterior_glass_door_building_category']
      exterior_subsurfaces.setGlassDoorConstruction(model_find_and_add_construction(model,
                                                                                    climate_zone_set,
                                                                                    'GlassDoor',
                                                                                    data['exterior_glass_door_standards_construction_type'],
                                                                                    data['exterior_glass_door_building_category']))
    end
    if data['exterior_overhead_door_standards_construction_type'] && data['exterior_overhead_door_building_category']
      exterior_subsurfaces.setOverheadDoorConstruction(model_find_and_add_construction(model,
                                                                                       climate_zone_set,
                                                                                       'ExteriorDoor',
                                                                                       data['exterior_overhead_door_standards_construction_type'],
                                                                                       data['exterior_overhead_door_building_category']))
    end
    if data['exterior_skylight_standards_construction_type'] && data['exterior_skylight_building_category']
      exterior_subsurfaces.setSkylightConstruction(model_find_and_add_construction(model,
                                                                                   climate_zone_set,
                                                                                   'Skylight',
                                                                                   data['exterior_skylight_standards_construction_type'],
                                                                                   data['exterior_skylight_building_category']))
    end
    if (construction_name = data['tubular_daylight_domes'])
      exterior_subsurfaces.setTubularDaylightDomeConstruction(model_add_construction(model, construction_name))
    end
    if (construction_name = data['tubular_daylight_diffusers'])
      exterior_subsurfaces.setTubularDaylightDiffuserConstruction(model_add_construction(model, construction_name))
    end

    # Interior sub surfaces constructions
    interior_subsurfaces = OpenStudio::Model::DefaultSubSurfaceConstructions.new(model)
    construction_set.setDefaultInteriorSubSurfaceConstructions(interior_subsurfaces)
    if (construction_name = data['interior_fixed_windows'])
      interior_subsurfaces.setFixedWindowConstruction(model_add_construction(model, construction_name))
    end
    if (construction_name = data['interior_operable_windows'])
      interior_subsurfaces.setOperableWindowConstruction(model_add_construction(model, construction_name))
    end
    if (construction_name = data['interior_doors'])
      interior_subsurfaces.setDoorConstruction(model_add_construction(model, construction_name))
    end

    # Other constructions
    if (construction_name = data['interior_partitions'])
      construction_set.setInteriorPartitionConstruction(model_add_construction(model, construction_name))
    end
    if (construction_name = data['space_shading'])
      construction_set.setSpaceShadingConstruction(model_add_construction(model, construction_name))
    end
    if (construction_name = data['building_shading'])
      construction_set.setBuildingShadingConstruction(model_add_construction(model, construction_name))
    end
    if (construction_name = data['site_shading'])
      construction_set.setSiteShadingConstruction(model_add_construction(model, construction_name))
    end

    # componentize the construction set
    # construction_set_component = construction_set.createComponent

    # Return the construction set
    return OpenStudio::Model::OptionalDefaultConstructionSet.new(construction_set)
  end

  # Adds a curve from the OpenStudio-Standards dataset to the model based on the curve name.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param curve_name [String] name of the curve
  # @return [OpenStudio::Model::Curve] curve object, nil if not found
  def model_add_curve(model, curve_name)
    # First check model and return curve if it already exists
    existing_curves = []
    existing_curves += model.getCurveLinears
    existing_curves += model.getCurveCubics
    existing_curves += model.getCurveQuadratics
    existing_curves += model.getCurveBicubics
    existing_curves += model.getCurveBiquadratics
    existing_curves.sort.each do |curve|
      if curve.name.get.to_s == curve_name
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Already added curve: #{curve_name}")
        return curve
      end
    end

    # OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.addCurve", "Adding curve '#{curve_name}' to the model.")

    # Find curve data
    data = model_find_object(standards_data['curves'], 'name' => curve_name)
    if data.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "Could not find a curve called '#{curve_name}' in the standards.")
      return nil
    end

    # Make the correct type of curve
    case data['form']
      when 'Linear'
        curve = OpenStudio::Model::CurveLinear.new(model)
        curve.setName(data['name'])
        curve.setCoefficient1Constant(data['coeff_1'])
        curve.setCoefficient2x(data['coeff_2'])
        curve.setMinimumValueofx(data['minimum_independent_variable_1']) if data['minimum_independent_variable_1']
        curve.setMaximumValueofx(data['maximum_independent_variable_1']) if data['maximum_independent_variable_1']
        curve.setMinimumCurveOutput(data['minimum_dependent_variable_output']) if data['minimum_dependent_variable_output']
        curve.setMaximumCurveOutput(data['maximum_dependent_variable_output']) if data['maximum_dependent_variable_output']
        return curve
      when 'Cubic'
        curve = OpenStudio::Model::CurveCubic.new(model)
        curve.setName(data['name'])
        curve.setCoefficient1Constant(data['coeff_1'])
        curve.setCoefficient2x(data['coeff_2'])
        curve.setCoefficient3xPOW2(data['coeff_3'])
        curve.setCoefficient4xPOW3(data['coeff_4'])
        curve.setMinimumValueofx(data['minimum_independent_variable_1']) if data['minimum_independent_variable_1']
        curve.setMaximumValueofx(data['maximum_independent_variable_1']) if data['maximum_independent_variable_1']
        curve.setMinimumCurveOutput(data['minimum_dependent_variable_output']) if data['minimum_dependent_variable_output']
        curve.setMaximumCurveOutput(data['maximum_dependent_variable_output']) if data['maximum_dependent_variable_output']
        return curve
      when 'Quadratic'
        curve = OpenStudio::Model::CurveQuadratic.new(model)
        curve.setName(data['name'])
        curve.setCoefficient1Constant(data['coeff_1'])
        curve.setCoefficient2x(data['coeff_2'])
        curve.setCoefficient3xPOW2(data['coeff_3'])
        curve.setMinimumValueofx(data['minimum_independent_variable_1']) if data['minimum_independent_variable_1']
        curve.setMaximumValueofx(data['maximum_independent_variable_1']) if data['maximum_independent_variable_1']
        curve.setMinimumCurveOutput(data['minimum_dependent_variable_output']) if data['minimum_dependent_variable_output']
        curve.setMaximumCurveOutput(data['maximum_dependent_variable_output']) if data['maximum_dependent_variable_output']
        return curve
      when 'BiCubic'
        curve = OpenStudio::Model::CurveBicubic.new(model)
        curve.setName(data['name'])
        curve.setCoefficient1Constant(data['coeff_1'])
        curve.setCoefficient2x(data['coeff_2'])
        curve.setCoefficient3xPOW2(data['coeff_3'])
        curve.setCoefficient4y(data['coeff_4'])
        curve.setCoefficient5yPOW2(data['coeff_5'])
        curve.setCoefficient6xTIMESY(data['coeff_6'])
        curve.setCoefficient7xPOW3(data['coeff_7'])
        curve.setCoefficient8yPOW3(data['coeff_8'])
        curve.setCoefficient9xPOW2TIMESY(data['coeff_9'])
        curve.setCoefficient10xTIMESYPOW2(data['coeff_10'])
        curve.setMinimumValueofx(data['minimum_independent_variable_1']) if data['minimum_independent_variable_1']
        curve.setMaximumValueofx(data['maximum_independent_variable_1']) if data['maximum_independent_variable_1']
        curve.setMinimumValueofy(data['minimum_independent_variable_2']) if data['minimum_independent_variable_2']
        curve.setMaximumValueofy(data['maximum_independent_variable_2']) if data['maximum_independent_variable_2']
        curve.setMinimumCurveOutput(data['minimum_dependent_variable_output']) if data['minimum_dependent_variable_output']
        curve.setMaximumCurveOutput(data['maximum_dependent_variable_output']) if data['maximum_dependent_variable_output']
        return curve
      when 'BiQuadratic'
        curve = OpenStudio::Model::CurveBiquadratic.new(model)
        curve.setName(data['name'])
        curve.setCoefficient1Constant(data['coeff_1'])
        curve.setCoefficient2x(data['coeff_2'])
        curve.setCoefficient3xPOW2(data['coeff_3'])
        curve.setCoefficient4y(data['coeff_4'])
        curve.setCoefficient5yPOW2(data['coeff_5'])
        curve.setCoefficient6xTIMESY(data['coeff_6'])
        curve.setMinimumValueofx(data['minimum_independent_variable_1']) if data['minimum_independent_variable_1']
        curve.setMaximumValueofx(data['maximum_independent_variable_1']) if data['maximum_independent_variable_1']
        curve.setMinimumValueofy(data['minimum_independent_variable_2']) if data['minimum_independent_variable_2']
        curve.setMaximumValueofy(data['maximum_independent_variable_2']) if data['maximum_independent_variable_2']
        curve.setMinimumCurveOutput(data['minimum_dependent_variable_output']) if data['minimum_dependent_variable_output']
        curve.setMaximumCurveOutput(data['maximum_dependent_variable_output']) if data['maximum_dependent_variable_output']
        return curve
      when 'BiLinear'
        curve = OpenStudio::Model::CurveBiquadratic.new(model)
        curve.setName(data['name'])
        curve.setCoefficient1Constant(data['coeff_1'])
        curve.setCoefficient2x(data['coeff_2'])
        curve.setCoefficient4y(data['coeff_3'])
        curve.setMinimumValueofx(data['minimum_independent_variable_1']) if data['minimum_independent_variable_1']
        curve.setMaximumValueofx(data['maximum_independent_variable_1']) if data['maximum_independent_variable_1']
        curve.setMinimumValueofy(data['minimum_independent_variable_2']) if data['minimum_independent_variable_2']
        curve.setMaximumValueofy(data['maximum_independent_variable_2']) if data['maximum_independent_variable_2']
        curve.setMinimumCurveOutput(data['minimum_dependent_variable_output']) if data['minimum_dependent_variable_output']
        curve.setMaximumCurveOutput(data['maximum_dependent_variable_output']) if data['maximum_dependent_variable_output']
        return curve
      when 'MultiVariableLookupTable'
        num_ind_var = data['number_independent_variables'].to_i
        table = OpenStudio::Model::TableMultiVariableLookup.new(model, num_ind_var)
        table.setName(data['name'])
        table.setInterpolationMethod(data['interpolation_method'])
        table.setNumberofInterpolationPoints(data['number_of_interpolation_points'])
        table.setCurveType(data['curve_type'])
        table.setTableDataFormat('SingleLineIndependentVariableWithMatrix')
        table.setNormalizationReference(data['normalization_reference'].to_f)
        table.setOutputUnitType(data['output_unit_type'])
        table.setMinimumValueofX1(data['minimum_independent_variable_1'].to_f)
        table.setMaximumValueofX1(data['maximum_independent_variable_1'].to_f)
        table.setInputUnitTypeforX1(data['input_unit_type_x1'])
        if num_ind_var == 2
          table.setMinimumValueofX2(data['minimum_independent_variable_2'].to_f)
          table.setMaximumValueofX2(data['maximum_independent_variable_2'].to_f)
          table.setInputUnitTypeforX2(data['input_unit_type_x2'])
        end
        data_points = data.each.select { |key, value| key.include? 'data_point' }
        data_points.each do |key, value|
          if num_ind_var == 1
            table.addPoint(value.split(',')[0].to_f, value.split(',')[1].to_f)
          elsif num_ind_var == 2
            table.addPoint(value.split(',')[0].to_f, value.split(',')[1].to_f, value.split(',')[2].to_f)
          end
        end
        return table
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "#{curve_name}' has an invalid form: #{data['form']}', cannot create this curve.")
        return nil
    end
  end

  # Get the full path to the weather file that is specified in the model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::OptionalPath] path to weather file
  def model_get_full_weather_file_path(model)
    full_epw_path = OpenStudio::OptionalPath.new

    if model.weatherFile.is_initialized
      epw_path = model.weatherFile.get.path
      if epw_path.is_initialized
        if File.exist?(epw_path.get.to_s)
          full_epw_path = OpenStudio::OptionalPath.new(epw_path.get)
        else
          # If this is an always-run Measure, need to check a different path
          alt_weath_path = File.expand_path(File.join(Dir.pwd, '../../resources'))
          alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
          if File.exist?(alt_epw_path)
            full_epw_path = OpenStudio::OptionalPath.new(OpenStudio::Path.new(alt_epw_path))
          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has a weather file assigned, but the weather file path has been deleted.')
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Model has not been assigned a weather file.')
    end

    return full_epw_path
  end

  # Find the legacy simulation results from a CSV of previously created results.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param building_type [String] the building type
  # @param run_type [String] design day is dd-only, otherwise annual run
  # @param lkp_template [String] The standards template, e.g.'90.1-2013'
  # @return [Hash] a hash of results for each fuel, where the keys are in the form 'End Use|Fuel Type',
  #   e.g. Heating|Electricity, Exterior Equipment|Water.  All end use/fuel type combos are present,
  #   with values of 0.0 if none of this end use/fuel type combo was used by the simulation.
  #   Returns nil if the legacy results couldn't be found.
  def model_legacy_results_by_end_use_and_fuel_type(model, climate_zone, building_type, run_type, lkp_template:nil)
    # Load the legacy idf results CSV file into a ruby hash
    top_dir = File.expand_path('../../..', File.dirname(__FILE__))
    standards_data_dir = "#{top_dir}/data/standards"
    temp = ''
    # Run differently depending on whether running from embedded filesystem in OpenStudio CLI or not
    if __dir__[0] == ':' # Running from OpenStudio CLI
      # load file from embedded files
      if run_type == 'dd-only'
        temp = load_resource_relative('../../../data/standards/test_performance_expected_dd_results.csv', 'r:UTF-8')
      else
        temp = load_resource_relative('../../../data/standards/legacy_idf_results.csv', 'r:UTF-8')
      end
    else
      # loaded gem from system path
      if run_type == 'dd-only'
        temp = File.read("#{standards_data_dir}/test_performance_expected_dd_results.csv")
      else
        temp = File.read("#{standards_data_dir}/legacy_idf_results.csv")
      end
    end
    legacy_idf_csv = CSV.new(temp, headers: true, converters: :all)
    legacy_idf_results = legacy_idf_csv.to_a.map(&:to_hash)

    if lkp_template.nil?
      lkp_template = template
    end

    # Get the results for this building
    search_criteria = {
      'Building Type' => building_type,
      'Template' => lkp_template,
      'Climate Zone' => climate_zone
    }
    energy_values = model_find_object(legacy_idf_results, search_criteria)
    if energy_values.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find legacy simulation results for #{search_criteria}")
      return {}
    end

    return energy_values
  end

  # Method to gather prototype simulation results for a specific climate zone, building type, and template
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param building_type [String] the building type
  # @param lkp_template [String] The standards template, e.g.'90.1-2013'
  # @return [Hash] Returns a hash with data presented in various bins.
  #   Returns nil if no search results
  def model_process_results_for_datapoint(model, climate_zone, building_type, lkp_template: nil)
    # Hash to store the legacy results by fuel and by end use
    legacy_results_hash = {}
    legacy_results_hash['total_legacy_energy_val'] = 0
    legacy_results_hash['total_legacy_water_val'] = 0
    legacy_results_hash['total_energy_by_fuel'] = {}
    legacy_results_hash['total_energy_by_end_use'] = {}

    # Get the legacy simulation results
    legacy_values = model_legacy_results_by_end_use_and_fuel_type(model, climate_zone, building_type, 'annual', lkp_template: lkp_template)
    if legacy_values.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find legacy idf results for #{search_criteria}")
      return legacy_results_hash
    end

    # List of all fuel types
    fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

    # List of all end uses
    end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection', 'Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

    # Sum the legacy results up by fuel and by end use
    fuel_types.each do |fuel_type|
      end_uses.each do |end_use|
        next if end_use == 'Exterior Equipment'

        legacy_val = legacy_values["#{end_use}|#{fuel_type}"]

        # Combine the exterior lighting and exterior equipment
        if end_use == 'Exterior Lighting'
          legacy_exterior_equipment = legacy_values["Exterior Equipment|#{fuel_type}"]
          unless legacy_exterior_equipment.nil?
            legacy_val += legacy_exterior_equipment
          end
        end

        if legacy_val.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "#{fuel_type} #{end_use} legacy idf value not found")
          next
        end

        # Add the energy to the total
        if fuel_type == 'Water'
          legacy_results_hash['total_legacy_water_val'] += legacy_val
        else
          legacy_results_hash['total_legacy_energy_val'] += legacy_val

          # add to fuel specific total
          if legacy_results_hash['total_energy_by_fuel'][fuel_type]
            legacy_results_hash['total_energy_by_fuel'][fuel_type] += legacy_val # add to existing counter
          else
            legacy_results_hash['total_energy_by_fuel'][fuel_type] = legacy_val # start new counter
          end

          # add to end use specific total
          if legacy_results_hash['total_energy_by_end_use'][end_use]
            legacy_results_hash['total_energy_by_end_use'][end_use] += legacy_val # add to existing counter
          else
            legacy_results_hash['total_energy_by_end_use'][end_use] = legacy_val # start new counter
          end
        end
      end
    end

    return legacy_results_hash
  end

  # Keep track of floor area for prototype buildings.
  # This is used to calculate EUI's to compare against non prototype buildings
  # Areas taken from scorecard Excel Files
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type
  # @return [Double] floor area (m^2) of prototype building for building type passed in.
  #   Returns nil if unexpected building type
  def model_find_prototype_floor_area(model, building_type)
    if building_type == 'FullServiceRestaurant' # 5502 ft^2
      result = 511
    elsif building_type == 'Hospital' # 241,410 ft^2 (including basement)
      result = 22_422
    elsif building_type == 'LargeHotel' # 122,132 ft^2
      result = 11_345
    elsif building_type == 'LargeOffice' # 498,600 ft^2
      result = 46_320
    elsif building_type == 'MediumOffice' # 53,600 ft^2
      result = 4982
    elsif building_type == 'LargeOfficeDetailed' # 498,600 ft^2
      result = 46_320
    elsif building_type == 'MediumOfficeDetailed' # 53,600 ft^2
      result = 4982
    elsif building_type == 'MidriseApartment' # 33,700 ft^2
      result = 3135
    elsif building_type == 'Office'
      result = nil
      # @todo there shouldn't be a prototype building for this
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Measures calling this should choose between SmallOffice, MediumOffice, and LargeOffice')
    elsif building_type == 'Outpatient' # 40.950 ft^2
      result = 3804
    elsif building_type == 'PrimarySchool' # 73,960 ft^2
      result = 6871
    elsif building_type == 'QuickServiceRestaurant' # 2500 ft^2
      result = 232
    elsif building_type == 'Retail' # 24,695 ft^2
      result = 2294
    elsif building_type == 'SecondarySchool' # 210,900 ft^2
      result = 19_592
    elsif building_type == 'SmallHotel' # 43,200 ft^2
      result = 4014
    elsif building_type == 'SmallOffice' # 5500 ft^2
      result = 511
    elsif building_type == 'SmallOfficeDetailed' # 5500 ft^2
      result = 511
    elsif building_type == 'StripMall' # 22,500 ft^2
      result = 2090
    elsif building_type == 'SuperMarket' # 45,002 ft2 (from legacy reference idf file)
      result = 4181
    elsif building_type == 'Warehouse' # 49,495 ft^2 (legacy ref shows 52,045, but I wil calc using 49,495)
      result = 4595
    elsif building_type == 'SmallDataCenterLowITE' || building_type == 'SmallDataCenterHighITE'  # 600 ft^2
      result = 56
    elsif building_type == 'LargeDataCenterLowITE' || building_type == 'LargeDataCenterHighITE'  # 6000 ft^2
      result = 557
    elsif building_type == 'Laboratory' # 90000 ft^2
      result = 8361
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Didn't find expected building type. As a result can't determine floor prototype floor area")
      result = nil
    end

    return result
  end

  # This is used by other methods to get the climate zone and building type from a model.
  # It has logic to break office into small,
  # medium or large based on building area that can be turned off
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param remap_office [bool] re-map small office or leave it alone
  # @return [hash] key for climate zone, building type, and standards template.  All values are strings.
  def model_get_building_properties(model, remap_office = true)
    # get climate zone from model
    climate_zone = model_standards_climate_zone(model)

    # get building type from model
    building_type = ''
    if model.getBuilding.standardsBuildingType.is_initialized
      building_type = model.getBuilding.standardsBuildingType.get
    end

    # map office building type to small medium or large
    if building_type == 'Office' && remap_office
      open_studio_area = model.getBuilding.floorArea
      building_type = model_remap_office(model, open_studio_area)
    end

    # get standards template
    if model.getBuilding.standardsTemplate.is_initialized
      standards_template = model.getBuilding.standardsTemplate.get
    end

    results = {}
    results['climate_zone'] = climate_zone
    results['building_type'] = building_type
    results['standards_template'] = standards_template

    return results
  end



  # remap office to one of the prototype buildings
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param floor_area [Double] floor area (m^2)
  # @return [String] SmallOffice, MediumOffice, LargeOffice
  def model_remap_office(model, floor_area)
    # prototype small office approx 500 m^2
    # prototype medium office approx 5000 m^2
    # prototype large office approx 50,000 m^2
    # map office building type to small medium or large
    building_type = if floor_area < 2750
                      'SmallOffice'
                    elsif floor_area < 25_250
                      'MediumOffice'
                    else
                      'LargeOffice'
                    end
  end

  # User needs to pass in template as string.
  # The building type and climate zone will come from the model.
  # If the building type or ASHRAE climate zone is not set in the model this will return nil
  # If the lookup doesn't find matching simulation results this wil return nil
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Double] EUI (MJ/m^2) for target template for given OSM. Returns nil if can't calculate EUI
  def model_find_target_eui(model)
    building_data = model_get_building_properties(model)
    climate_zone = building_data['climate_zone']
    building_type = building_data['building_type']
    building_template = building_data['standards_template']

    # look up results
    target_consumption = model_process_results_for_datapoint(model, climate_zone, building_type, lkp_template: building_template)

    # lookup target floor area for prototype buildings
    target_floor_area = model_find_prototype_floor_area(model, building_type)

    if target_consumption['total_legacy_energy_val'] > 0
      if target_floor_area > 0
        result = target_consumption['total_legacy_energy_val'] / target_floor_area
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Cannot find prototype building floor area')
        result = nil
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find target results for #{climate_zone},#{building_type},#{template}")
      result = nil # couldn't calculate EUI consumpiton lookup failed
    end

    return result
  end

  # User needs to pass in template as string.
  # The building type and climate zone will come from the model.
  # If the building type or ASHRAE climate zone is not set in the model this will return nil
  # If the lookup doesn't find matching simulation results this wil return nil
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Hash] EUI (MJ/m^2) This will return a hash of end uses. key is end use, value is eui
  def model_find_target_eui_by_end_use(model)
    building_data = model_get_building_properties(model)
    climate_zone = building_data['climate_zone']
    building_type = building_data['building_type']
    building_template = building_data['standards_template']

    # look up results
    target_consumption = model_process_results_for_datapoint(model, climate_zone, building_type, lkp_template: building_template)

    # lookup target floor area for prototype buildings
    target_floor_area = model_find_prototype_floor_area(model, building_type)

    if target_consumption['total_legacy_energy_val'] > 0
      if target_floor_area > 0
        result = {}
        target_consumption['total_energy_by_end_use'].each do |end_use, consumption|
          result[end_use] = consumption / target_floor_area
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Cannot find prototype building floor area')
        result = nil
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find target results for #{climate_zone},#{building_type},#{template}")
      result = nil # couldn't calculate EUI consumpiton lookup failed
    end

    return result
  end

  # Get a unique list of constructions with given boundary condition and a given type of surface.
  # Pulls from both default construction sets and hard-assigned constructions.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param boundary_condition [String] the desired boundary condition. valid choices are:
  #   Adiabatic
  #   Surface
  #   Outdoors
  #   Ground
  # @param type [String] the type of surface to find. valid choices are:
  #   AtticFloor
  #   AtticWall
  #   AtticRoof
  #   DemisingFloor
  #   DemisingWall
  #   DemisingRoof
  #   ExteriorFloor
  #   ExteriorWall
  #   ExteriorRoof
  #   ExteriorWindow
  #   ExteriorDoor
  #   GlassDoor
  #   GroundContactFloor
  #   GroundContactWall
  #   GroundContactRoof
  #   InteriorFloor
  #   InteriorWall
  #   InteriorCeiling
  #   InteriorPartition
  #   InteriorWindow
  #   InteriorDoor
  #   OverheadDoor
  #   Skylight
  #   TubularDaylightDome
  #   TubularDaylightDiffuser
  # return [Array<OpenStudio::Model::ConstructionBase>] an array of all constructions.
  def model_find_constructions(model, boundary_condition, type)
    constructions = []

    # From default construction sets
    model.getDefaultConstructionSets.sort.each do |const_set|
      ext_surfs = const_set.defaultExteriorSurfaceConstructions
      int_surfs = const_set.defaultInteriorSurfaceConstructions
      gnd_surfs = const_set.defaultGroundContactSurfaceConstructions
      ext_subsurfs = const_set.defaultExteriorSubSurfaceConstructions
      int_subsurfs = const_set.defaultInteriorSubSurfaceConstructions

      # Can't handle incomplete construction sets
      if ext_surfs.empty? ||
         int_surfs.empty? ||
         gnd_surfs.empty? ||
         ext_subsurfs.empty? ||
         int_subsurfs.empty?

        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Space', "Default construction set #{const_set.name} is incomplete; constructions from this set will not be reported.")
        next
      end

      ext_surfs = ext_surfs.get
      int_surfs = int_surfs.get
      gnd_surfs = gnd_surfs.get
      ext_subsurfs = ext_subsurfs.get
      int_subsurfs = int_subsurfs.get

      case type
        # Exterior Surfaces
        when 'ExteriorWall', 'AtticWall'
          constructions << ext_surfs.wallConstruction
        when 'ExteriorFloor'
          constructions << ext_surfs.floorConstruction
        when 'ExteriorRoof', 'AtticRoof'
          constructions << ext_surfs.roofCeilingConstruction
        # Interior Surfaces
        when 'InteriorWall', 'DemisingWall', 'InteriorPartition'
          constructions << int_surfs.wallConstruction
        when 'InteriorFloor', 'AtticFloor', 'DemisingFloor'
          constructions << int_surfs.floorConstruction
        when 'InteriorCeiling', 'DemisingRoof'
          constructions << int_surfs.roofCeilingConstruction
        # Ground Contact Surfaces
        when 'GroundContactWall'
          constructions << gnd_surfs.wallConstruction
        when 'GroundContactFloor'
          constructions << gnd_surfs.floorConstruction
        when 'GroundContactRoof'
          constructions << gnd_surfs.roofCeilingConstruction
        # Exterior SubSurfaces
        when 'ExteriorWindow'
          constructions << ext_subsurfs.fixedWindowConstruction
          constructions << ext_subsurfs.operableWindowConstruction
        when 'ExteriorDoor'
          constructions << ext_subsurfs.doorConstruction
        when 'GlassDoor'
          constructions << ext_subsurfs.glassDoorConstruction
        when 'OverheadDoor'
          constructions << ext_subsurfs.overheadDoorConstruction
        when 'Skylight'
          constructions << ext_subsurfs.skylightConstruction
        when 'TubularDaylightDome'
          constructions << ext_subsurfs.tubularDaylightDomeConstruction
        when 'TubularDaylightDiffuser'
          constructions << ext_subsurfs.tubularDaylightDiffuserConstruction
        # Interior SubSurfaces
        when 'InteriorWindow'
          constructions << int_subsurfs.fixedWindowConstruction
          constructions << int_subsurfs.operableWindowConstruction
        when 'InteriorDoor'
          constructions << int_subsurfs.doorConstruction
      end
    end

    # Hard-assigned surfaces
    model.getSurfaces.sort.each do |surf|
      next unless surf.outsideBoundaryCondition == boundary_condition

      surf_type = surf.surfaceType
      if surf_type == 'Floor' || surf_type == 'Wall'
        next unless type.include?(surf_type)
      elsif surf_type == 'RoofCeiling'
        next unless type.include?('Roof') || type.include?('Ceiling')
      end
      constructions << surf.construction
    end

    # Hard-assigned subsurfaces
    model.getSubSurfaces.sort.each do |surf|
      next unless surf.outsideBoundaryCondition == boundary_condition

      surf_type = surf.subSurfaceType
      if surf_type == 'FixedWindow' || surf_type == 'OperableWindow'
        next unless type == 'ExteriorWindow'
      elsif surf_type == 'Door'
        next unless type.include?('Door')
      else
        next unless surf.subSurfaceType == type
      end
      constructions << surf.construction
    end

    # Throw out the empty constructions
    all_constructions = []
    constructions.uniq.each do |const|
      next if const.empty?

      all_constructions << const.get
    end

    # Only return the unique list (should already be uniq)
    all_constructions = all_constructions.uniq

    # ConstructionBase can be sorted
    all_constructions = all_constructions.sort

    return all_constructions
  end

  # Go through the default construction sets and hard-assigned constructions.
  # Clone the existing constructions and set their intended surface type and standards construction type per the PRM.
  # For some standards, this will involve making modifications.  For others, it will not.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_apply_prm_construction_types(model)
    types_to_modify = []

    # Possible boundary conditions are
    # Adiabatic
    # Surface
    # Outdoors
    # Ground

    # Possible surface types are
    # AtticFloor
    # AtticWall
    # AtticRoof
    # DemisingFloor
    # DemisingWall
    # DemisingRoof
    # ExteriorFloor
    # ExteriorWall
    # ExteriorRoof
    # ExteriorWindow
    # ExteriorDoor
    # GlassDoor
    # GroundContactFloor
    # GroundContactWall
    # GroundContactRoof
    # InteriorFloor
    # InteriorWall
    # InteriorCeiling
    # InteriorPartition
    # InteriorWindow
    # InteriorDoor
    # OverheadDoor
    # Skylight
    # TubularDaylightDome
    # TubularDaylightDiffuser

    # Possible standards construction types
    # Mass
    # SteelFramed
    # WoodFramed
    # IEAD
    # View
    # Daylight
    # Swinging
    # NonSwinging
    # Heated
    # Unheated
    # RollUp
    # Sliding
    # Metal
    # Nonmetal framing (all)
    # Metal framing (curtainwall/storefront)
    # Metal framing (entrance door)
    # Metal framing (all other)
    # Metal Building
    # Attic and Other
    # Glass with Curb
    # Plastic with Curb
    # Without Curb

    # Create an array of types
    types_to_modify << ['Outdoors', 'ExteriorWall', 'SteelFramed']
    types_to_modify << ['Outdoors', 'ExteriorRoof', 'IEAD']
    types_to_modify << ['Outdoors', 'ExteriorFloor', 'SteelFramed']
    types_to_modify << ['Ground', 'GroundContactFloor', 'Unheated']
    types_to_modify << ['Ground', 'GroundContactWall', 'Mass']

    # Modify all constructions of each type
    types_to_modify.each do |boundary_cond, surf_type, const_type|
      constructions = model_find_constructions(model, boundary_cond, surf_type)

      constructions.sort.each do |const|
        standards_info = const.standardsInformation
        standards_info.setIntendedSurfaceType(surf_type)
        standards_info.setStandardsConstructionType(const_type)
      end
    end

    return true
  end

  # Apply the standard construction to each surface in the model, based on the construction type currently assigned.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if successful, false if not
  def model_apply_standard_constructions(model, climate_zone)
    types_to_modify = []

    # Possible boundary conditions are
    # Adiabatic
    # Surface
    # Outdoors
    # Ground

    # Possible surface types are
    # Floor
    # Wall
    # RoofCeiling
    # FixedWindow
    # OperableWindow
    # Door
    # GlassDoor
    # OverheadDoor
    # Skylight
    # TubularDaylightDome
    # TubularDaylightDiffuser

    # Create an array of surface types
    types_to_modify << ['Outdoors', 'Floor']
    types_to_modify << ['Outdoors', 'Wall']
    types_to_modify << ['Outdoors', 'RoofCeiling']
    types_to_modify << ['Outdoors', 'FixedWindow']
    types_to_modify << ['Outdoors', 'OperableWindow']
    types_to_modify << ['Outdoors', 'Door']
    types_to_modify << ['Outdoors', 'GlassDoor']
    types_to_modify << ['Outdoors', 'OverheadDoor']
    types_to_modify << ['Outdoors', 'Skylight']
    types_to_modify << ['Ground', 'Floor']
    types_to_modify << ['Ground', 'Wall']

    # Find just those surfaces
    surfaces_to_modify = []
    types_to_modify.each do |boundary_condition, surface_type|
      # Surfaces
      model.getSurfaces.sort.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.surfaceType == surface_type

        surfaces_to_modify << surf
      end

      # SubSurfaces
      model.getSubSurfaces.sort.each do |surf|
        next unless surf.outsideBoundaryCondition == boundary_condition
        next unless surf.subSurfaceType == surface_type

        surfaces_to_modify << surf
      end
    end

    # Modify these surfaces
    prev_created_consts = {}
    surfaces_to_modify.sort.each do |surf|
      prev_created_consts = planar_surface_apply_standard_construction(surf, climate_zone, prev_created_consts)
    end

    # List the unique array of constructions
    if prev_created_consts.size.zero?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'None of the constructions in your proposed model have both Intended Surface Type and Standards Construction Type')
    else
      prev_created_consts.each do |surf_type, construction|
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{surf_type.join(' ')}, applied #{construction.name}.")
      end
    end

    return true
  end

  # Returns standards data for selected construction
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param intended_surface_type [String] the surface type
  # @param standards_construction_type [String]  the type of construction
  # @param building_category [String] the type of building
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Hash] hash of construction properties
  def model_get_construction_properties(model, intended_surface_type, standards_construction_type, building_category, climate_zone = nil)
    # get climate_zone_set
    climate_zone = model_get_building_properties(model)['climate_zone'] if climate_zone.nil?
    climate_zone_set = model_find_climate_zone_set(model, climate_zone)

    # populate search hash
    search_criteria = {
      'template' => template,
      'climate_zone_set' => climate_zone_set,
      'intended_surface_type' => intended_surface_type,
      'standards_construction_type' => standards_construction_type,
      'building_category' => building_category
    }

    # switch to use this but update test in standards and measures to load this outside of the method
    construction_properties = model_find_object(standards_data['construction_properties'], search_criteria)

    if !construction_properties
      # Search again use climate zone (e.g. 3) instead of sub-climate zone (3A)
      search_criteria['climate_zone_set'] = climate_zone_set[0..-2]
      construction_properties = model_find_object(standards_data['construction_properties'], search_criteria)
    end

    return construction_properties
  end

  # Returns standards data for selected construction set
  #
  # @param building_type [String] the type of building
  # @param space_type [String] space type within the building type. Typically nil.
  # @return [Hash] hash of construction set data
  def model_get_construction_set(building_type, space_type = nil)
    # populate search hash
    search_criteria = {
      'template' => template,
      'building_type' => building_type,
      'space_type' => space_type
    }

    # Search construction sets table for the exterior wall building category and construction type
    construction_set_data = model_find_object(standards_data['construction_sets'], search_criteria)

    return construction_set_data
  end

  # Reduces the WWR to the values specified by the PRM.
  # WWR reduction will be done by moving vertices inward toward centroid.
  # This causes the least impact on the daylighting area calculations and controls placement.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if successful, false if not
  # @todo add proper support for 90.1-2013 with all those building type specific values
  # @todo support 90.1-2004 requirement that windows be modeled as horizontal bands.
  #   Currently just using existing window geometry, and shrinking as necessary if WWR is above limit.
  # @todo support semiheated spaces as a separate WWR category
  # @todo add window frame area to calculation of WWR
  def model_apply_prm_baseline_window_to_wall_ratio(model, climate_zone)
    # Loop through all spaces in the model, and
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_wind_m2 = 0
    res_wall_m2 = 0.001
    res_wind_m2 = 0
    sh_wall_m2 = 0.001
    sh_wind_m2 = 0
    total_wall_m2 = 0.001
    total_subsurface_m2 = 0.0
    # Store the space conditioning category for later use
    space_cats = {}
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      wind_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType.casecmp('wall').zero?

        # This wall's gross area (including window area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow'

          wind_area_m2 += ss.netArea * space.multiplier
        end
      end

      # Determine the space category
      # @todo This should really use the heating/cooling loads from the proposed building.
      # However, in an attempt to avoid another sizing run just for this purpose,
      # conditioned status is based on heating/cooling setpoints.
      # If heated-only, will be assumed Semiheated.
      # The full-bore method is on the next line in case needed.
      # cat = thermal_zone_conditioning_category(space, template, climate_zone)
      cooled = space_cooled?(space)
      heated = space_heated?(space)
      cat = 'Unconditioned'
      # Unconditioned
      if !heated && !cooled
        cat = 'Unconditioned'
        # Heated-Only
      elsif heated && !cooled
        cat = 'Semiheated'
        # Heated and Cooled
      else
        res = space_residential?(space)
        cat = if res
                'ResConditioned'
              else
                'NonResConditioned'
              end
      end
      space_cats[space] = cat

      # Add to the correct category
      case cat
        when 'Unconditioned'
          next # Skip unconditioned spaces
        when 'NonResConditioned'
          nr_wall_m2 += wall_area_m2
          nr_wind_m2 += wind_area_m2
        when 'ResConditioned'
          res_wall_m2 += wall_area_m2
          res_wind_m2 += wind_area_m2
        when 'Semiheated'
          sh_wall_m2 += wall_area_m2
          sh_wind_m2 += wind_area_m2
      end
    end

    # Calculate the WWR of each category
    wwr_nr = ((nr_wind_m2 / nr_wall_m2) * 100.0).round(1)
    wwr_res = ((res_wind_m2 / res_wall_m2) * 100).round(1)
    wwr_sh = ((sh_wind_m2 / sh_wall_m2) * 100).round(1)

    # Convert to IP and report
    nr_wind_ft2 = OpenStudio.convert(nr_wind_m2, 'm^2', 'ft^2').get
    nr_wall_ft2 = OpenStudio.convert(nr_wall_m2, 'm^2', 'ft^2').get

    res_wind_ft2 = OpenStudio.convert(res_wind_m2, 'm^2', 'ft^2').get
    res_wall_ft2 = OpenStudio.convert(res_wall_m2, 'm^2', 'ft^2').get

    sh_wind_ft2 = OpenStudio.convert(sh_wind_m2, 'm^2', 'ft^2').get
    sh_wall_ft2 = OpenStudio.convert(sh_wall_m2, 'm^2', 'ft^2').get

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR NonRes = #{wwr_nr.round}%; window = #{nr_wind_ft2.round} ft2, wall = #{nr_wall_ft2.round} ft2.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR Res = #{wwr_res.round}%; window = #{res_wind_ft2.round} ft2, wall = #{res_wall_ft2.round} ft2.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR Semiheated = #{wwr_sh.round}%; window = #{sh_wind_ft2.round} ft2, wall = #{sh_wall_ft2.round} ft2.")

    # WWR limit
    wwr_lim = 40.0

    # Check against WWR limit
    red_nr = wwr_nr > wwr_lim
    red_res = wwr_res > wwr_lim
    red_sh = wwr_sh > wwr_lim

    # Stop here unless windows need reducing
    return true unless red_nr || red_res || red_sh

    # Determine the factors by which to reduce the window area
    mult_nr_red = wwr_lim / wwr_nr
    mult_res_red = wwr_lim / wwr_res
    mult_sh_red = wwr_lim / wwr_sh

    # Reduce the window area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      # Determine the space category
      # from the previously stored values
      cat = space_cats[space]

      # Get the correct multiplier
      case cat
        when 'Unconditioned'
          next # Skip unconditioned spaces
        when 'NonResConditioned'
          next unless red_nr

          mult = mult_nr_red
        when 'ResConditioned'
          next unless red_res

          mult = mult_res_red
        when 'Semiheated'
          next unless red_sh

          mult = mult_sh_red
      end

      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType.casecmp('wall').zero?

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow'

          # Reduce the size of the window
          # If a vertical rectangle, raise sill height to avoid
          # impacting daylighting areas, otherwise
          # reduce toward centroid.
          red = 1.0 - mult
          if sub_surface_vertical_rectangle?(ss)
            sub_surface_reduce_area_by_percent_by_raising_sill(ss, red)
          else
            sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
          end
        end
      end
    end

    return true
  end

  # Reduces the SRR to the values specified by the PRM. SRR reduction will be done by shrinking vertices toward the centroid.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  # @todo support semiheated spaces as a separate SRR category
  # @todo add skylight frame area to calculation of SRR
  def model_apply_prm_baseline_skylight_to_roof_ratio(model)
    # Loop through all spaces in the model, and
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_sky_m2 = 0
    res_wall_m2 = 0.001
    res_sky_m2 = 0
    sh_wall_m2 = 0.001
    sh_sky_m2 = 0
    total_roof_m2 = 0.001
    total_subsurface_m2 = 0
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      sky_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # This wall's gross area (including skylight area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          sky_area_m2 += ss.netArea * space.multiplier
        end
      end

      # Determine the space category
      cat = 'NonRes'
      if space_residential?(space)
        cat = 'Res'
      end
      # if space.is_semiheated
      # cat = 'Semiheated'
      # end

      # Add to the correct category
      case cat
        when 'NonRes'
          nr_wall_m2 += wall_area_m2
          nr_sky_m2 += sky_area_m2
        when 'Res'
          res_wall_m2 += wall_area_m2
          res_sky_m2 += sky_area_m2
        when 'Semiheated'
          sh_wall_m2 += wall_area_m2
          sh_sky_m2 += sky_area_m2
      end
      total_roof_m2 += wall_area_m2
      total_subsurface_m2 += sky_area_m2
    end

    # Calculate the SRR of each category
    srr_nr = ((nr_sky_m2 / nr_wall_m2) * 100).round(1)
    srr_res = ((res_sky_m2 / res_wall_m2) * 100).round(1)
    srr_sh = ((sh_sky_m2 / sh_wall_m2) * 100).round(1)
    srr = ((total_subsurface_m2 / total_roof_m2) * 100.0).round(1)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The skylight to roof ratios (SRRs) are: NonRes: #{srr_nr.round}%, Res: #{srr_res.round}%.")

    # SRR limit
    srr_lim = model_prm_skylight_to_roof_ratio_limit(model)

    # Check against SRR limit
    red_nr = srr_nr > srr_lim
    red_res = srr_res > srr_lim
    red_sh = srr_sh > srr_lim

    # Stop here unless skylights need reducing
    return true unless red_nr || red_res || red_sh

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all skylights equally down to the limit of #{srr_lim.round}%.")

    # Determine the factors by which to reduce the skylight area
    mult_nr_red = srr_lim / srr_nr
    mult_res_red = srr_lim / srr_res
    # mult_sh_red = srr_lim / srr_sh

    # Reduce the skylight area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      # Determine the space category
      cat = 'NonRes'
      if space_residential?(space)
        cat = 'Res'
      end
      # if space.is_semiheated
      # cat = 'Semiheated'
      # end

      # Skip spaces whose skylights don't need to be reduced
      case cat
        when 'NonRes'
          next unless red_nr

          mult = mult_nr_red
        when 'Res'
          next unless red_res

          mult = mult_res_red
        when 'Semiheated'
          next unless red_sh
        # mult = mult_sh_red
      end

      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          # Reduce the size of the skylight
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end

    return true
  end

  # Determines the skylight to roof ratio limit for a given standard
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Double] the skylight to roof ratio, as a percent: 5.0 = 5%. 5% by default.
  def model_prm_skylight_to_roof_ratio_limit(model)
    srr_lim = 5.0
    return srr_lim
  end

  # Remove all HVAC that will be replaced during the performance rating method baseline generation.
  # This does not include plant loops that serve WaterUse:Equipment or Fan:ZoneExhaust
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_remove_prm_hvac(model)
    # Plant loops
    model.getPlantLoops.sort.each do |loop|
      # Don't remove service water heating loops
      next if plant_loop_swh_loop?(loop)

      loop.remove
    end

    # Air loops
    model.getAirLoopHVACs.each(&:remove)
    if model.version > OpenStudio::VersionString.new('3.1.0')
      model.getAirLoopHVACDedicatedOutdoorAirSystems.each(&:remove)
    end

    # Zone equipment
    model.getThermalZones.sort.each do |zone|
      zone.equipment.each do |zone_equipment|
        next if zone_equipment.to_FanZoneExhaust.is_initialized

        zone_equipment.remove
      end
    end

    # Outdoor VRF units (not in zone, not in loops)
    model.getAirConditionerVariableRefrigerantFlows.each(&:remove)

    return true
  end

  # Remove EMS objects that may be orphaned from removing HVAC
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_remove_prm_ems_objects(model)
    model.getEnergyManagementSystemActuators.each(&:remove)
    model.getEnergyManagementSystemConstructionIndexVariables.each(&:remove)
    model.getEnergyManagementSystemCurveOrTableIndexVariables.each(&:remove)
    model.getEnergyManagementSystemGlobalVariables.each(&:remove)
    model.getEnergyManagementSystemInternalVariables.each(&:remove)
    model.getEnergyManagementSystemMeteredOutputVariables.each(&:remove)
    model.getEnergyManagementSystemOutputVariables.each(&:remove)
    model.getEnergyManagementSystemPrograms.each(&:remove)
    model.getEnergyManagementSystemProgramCallingManagers.each(&:remove)
    model.getEnergyManagementSystemSensors.each(&:remove)
    model.getEnergyManagementSystemSubroutines.each(&:remove)
    model.getEnergyManagementSystemTrendVariables.each(&:remove)

    return true
  end

  # Remove external shading devices. Site shading will not be impacted.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_remove_external_shading_devices(model)
    shading_surfaces_removed = 0
    model.getShadingSurfaceGroups.sort.each do |shade_group|
      # Skip Site shading
      next if shade_group.shadingSurfaceType == 'Site'

      # Space shading surfaces should be removed
      shading_surfaces_removed += shade_group.shadingSurfaces.size
      shade_group.remove
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Removed #{shading_surfaces_removed} external shading devices.")

    return true
  end

  # Changes the sizing parameters to the PRM specifications.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_apply_prm_sizing_parameters(model)
    clg = 1.15
    htg = 1.25

    sizing_params = model.getSizingParameters
    sizing_params.setHeatingSizingFactor(htg)
    sizing_params.setCoolingSizingFactor(clg)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set sizing factors to #{htg} for heating and #{clg} for cooling.")
    return true
  end

  # Helper method to get the story object that corresponds to a specific minimum z value.
  # Makes a new story if none found at this height.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param minz [Double] the z value (height) of the desired story, in meters.
  # @param tolerance [Double] tolerance for comparison, in m. Default is 0.3 m ~1ft
  # @return [OpenStudio::Model::BuildingStory] the story
  def model_get_story_for_nominal_z_coordinate(model, minz, tolerance = 0.3)
    model.getBuildingStorys.sort.each do |story|
      z = building_story_minimum_z_value(story)

      if (minz - z).abs < tolerance
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "The story with a min z value of #{minz.round(2)} is #{story.name}.")
        return story
      end
    end

    story = OpenStudio::Model::BuildingStory.new(model)
    story.setNominalZCoordinate(minz)
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "No story with a min z value of #{minz.round(2)} m +/- #{tolerance} m was found, so a new story called #{story.name} was created.")

    return story
  end

  # Returns average daily hot water consumption by building type
  # recommendations from 2011 ASHRAE Handbook - HVAC Applications Table 7 section 50.14
  # Not all building types are included in lookup
  # some recommendations have multiple values based on number of units.
  # Will return an array of hashes. Many may have one array entry.
  # all values other than block size are gallons.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Array] array of hashes. Each array entry based on different capacity
  #   specific to building type. Array will be empty for some building types.
  def model_find_ashrae_hot_water_demand(model)
    # @todo for types not in table use standards area normalized swh values

    # get building type
    building_data = model_get_building_properties(model)
    building_type = building_data['building_type']

    result = []
    if building_type == 'FullServiceRestaurant'
      result << { units: 'meal', block: nil, max_hourly: 1.5, max_daily: 11.0, avg_day_unit: 2.4 }
    elsif building_type == 'Hospital'
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    elsif ['LargeHotel', 'SmallHotel'].include? building_type
      result << { units: 'unit', block: 20, max_hourly: 6.0, max_daily: 35.0, avg_day_unit: 24.0 }
      result << { units: 'unit', block: 60, max_hourly: 5.0, max_daily: 25.0, avg_day_unit: 14.0 }
      result << { units: 'unit', block: 100, max_hourly: 4.0, max_daily: 15.0, avg_day_unit: 10.0 }
    elsif building_type == 'MidriseApartment'
      result << { units: 'unit', block: 20, max_hourly: 12.0, max_daily: 80.0, avg_day_unit: 42.0 }
      result << { units: 'unit', block: 50, max_hourly: 10.0, max_daily: 73.0, avg_day_unit: 40.0 }
      result << { units: 'unit', block: 75, max_hourly: 8.5, max_daily: 66.0, avg_day_unit: 38.0 }
      result << { units: 'unit', block: 100, max_hourly: 7.0, max_daily: 60.0, avg_day_unit: 37.0 }
      result << { units: 'unit', block: 200, max_hourly: 5.0, max_daily: 50.0, avg_day_unit: 35.0 }
    elsif ['Office', 'LargeOffice', 'MediumOffice', 'SmallOffice', 'LargeOfficeDetailed', 'MediumOfficeDetailed', 'SmallOfficeDetailed'].include? building_type
      result << { units: 'person', block: nil, max_hourly: 0.4, max_daily: 2.0, avg_day_unit: 1.0 }
    elsif building_type == 'Outpatient'
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    elsif building_type == 'PrimarySchool'
      result << { units: 'student', block: nil, max_hourly: 0.6, max_daily: 1.5, avg_day_unit: 0.6 }
    elsif building_type == 'QuickServiceRestaurant'
      result << { units: 'meal', block: nil, max_hourly: 0.7, max_daily: 6.0, avg_day_unit: 0.7 }
    elsif building_type == 'Retail'
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    elsif building_type == 'SecondarySchool'
      result << { units: 'student', block: nil, max_hourly: 1.0, max_daily: 3.6, avg_day_unit: 1.8 }
    elsif building_type == 'StripMall'
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    elsif building_type == 'SuperMarket'
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    elsif building_type == 'Warehouse'
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    elsif ['SmallDataCenterLowITE', 'SmallDataCenterHighITE', 'LargeDataCenterLowITE', 'LargeDataCenterHighITE', 'Laboratory'].include? building_type
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "No SWH rules of thumbs for #{building_type}.")
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Didn't find expected building type. As a result can't determine hot water demand recommendations")
    end

    return result
  end

  # Returns average daily hot water consumption for residential buildings
  # gal/day from ICC IECC 2015 Residential Standard Reference Design
  # from Table R405.5.2(1)
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param units_per_bldg [Double] number of units in the building
  # @param bedrooms_per_unit [Double] number of bedrooms per unit
  # @return [Double] gal/day
  def model_find_icc_iecc_2015_hot_water_demand(model, units_per_bldg, bedrooms_per_unit)
    swh_gal_per_day = units_per_bldg * (30.0 + (10.0 * bedrooms_per_unit))

    return swh_gal_per_day
  end

  # Returns average daily internal loads for residential buildings from Table R405.5.2(1)
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param units_per_bldg [Double] number of units in the building
  # @param bedrooms_per_unit [Double] number of bedrooms per unit
  # @return [Hash] mech_vent_cfm, infiltration_ach, igain_btu_per_day, internal_mass_lbs
  def model_find_icc_iecc_2015_internal_loads(model, units_per_bldg, bedrooms_per_unit)
    # get total and conditioned floor area
    total_floor_area = model.getBuilding.floorArea
    if model.getBuilding.conditionedFloorArea.is_initialized
      conditioned_floor_area = model.getBuilding.conditionedFloorArea.get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'Cannot find conditioned floor area, will use total floor area.')
      conditioned_floor_area = total_floor_area
    end

    # get climate zone value
    climate_zone = model_standards_climate_zone(model)

    internal_loads = {}
    internal_loads['mech_vent_cfm'] = units_per_bldg * (0.01 * conditioned_floor_area + 7.5 * (bedrooms_per_unit + 1.0))
    internal_loads['infiltration_ach'] = if ['1A', '1B', '2A', '2B'].include? climate_zone_value
                                           5.0
                                         else
                                           3.0
                                         end
    internal_loads['igain_btu_per_day'] = units_per_bldg * (17_900.0 + 23.8 * conditioned_floor_area + 4104.0 * bedrooms_per_unit)
    internal_loads['internal_mass_lbs'] = total_floor_area * 8.0

    return internal_loads
  end

  # Helper method to make a shortened version of a name that will be readable in a GUI.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param building_type [String] the building type
  # @param spc_type [String] the space type
  # @return [String] string of the model name
  def model_make_name(model, climate_zone, building_type, spc_type)
    climate_zone = climate_zone.gsub('ClimateZone ', 'CZ')
    if climate_zone == 'CZ1-8'
      climate_zone = ''
    end

    if building_type == 'FullServiceRestaurant'
      building_type = 'FullSrvRest'
    elsif building_type == 'Hospital'
      building_type = 'Hospital'
    elsif building_type == 'LargeHotel'
      building_type = 'LrgHotel'
    elsif building_type == 'LargeOffice'
      building_type = 'LrgOffice'
    elsif building_type == 'MediumOffice'
      building_type = 'MedOffice'
    elsif building_type == 'MidriseApartment'
      building_type = 'MidApt'
    elsif building_type == 'HighriseApartment'
      building_type = 'HighApt'
    elsif building_type == 'Office'
      building_type = 'Office'
    elsif building_type == 'Outpatient'
      building_type = 'Outpatient'
    elsif building_type == 'PrimarySchool'
      building_type = 'PriSchl'
    elsif building_type == 'QuickServiceRestaurant'
      building_type = 'QckSrvRest'
    elsif building_type == 'Retail'
      building_type = 'Retail'
    elsif building_type == 'SecondarySchool'
      building_type = 'SecSchl'
    elsif building_type == 'SmallHotel'
      building_type = 'SmHotel'
    elsif building_type == 'SmallOffice'
      building_type = 'SmOffice'
    elsif building_type == 'StripMall'
      building_type = 'StMall'
    elsif building_type == 'SuperMarket'
      building_type = 'SpMarket'
    elsif building_type == 'Warehouse'
      building_type = 'Warehouse'
    elsif building_type == 'SmallDataCenterLowITE'
      building_type = 'SmDCLowITE'
    elsif building_type == 'SmallDataCenterHighITE'
      building_type = 'SmDCHighITE'
    elsif building_type == 'LargeDataCenterLowITE'
      building_type = 'LrgDCLowITE'
    elsif building_type == 'LargeDataCenterHighITE'
      building_type = 'LrgDCHighITE'
    elsif building_type == 'Laboratory'
      building_type = 'Laboratory'
    elsif building_type == 'TallBuilding'
      building_type = 'TallBldg'
    elsif building_type == 'SuperTallBuilding'
      building_type = 'SpTallBldg'
    end

    parts = [template]

    unless building_type.nil?
      parts << building_type
    end

    unless spc_type.nil?
      parts << spc_type
    end

    unless climate_zone.empty?
      parts << climate_zone
    end

    result = parts.join(' - ')

    return result
  end

  # Helper method to find out which climate zone set contains a specific climate zone.
  # Returns climate zone set name as String if success, nil if not found.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [String] climate zone set
  def model_find_climate_zone_set(model, climate_zone)
    result = nil

    possible_climate_zone_sets = []
    standards_data['climate_zone_sets'].each do |climate_zone_set|
      if climate_zone_set['climate_zones'].include?(climate_zone)
        possible_climate_zone_sets << climate_zone_set['name']
      end
    end

    # Check the results
    if possible_climate_zone_sets.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set containing #{climate_zone}.  Make sure to use ASHRAE standards with ASHRAE climate zones and DEER or CA Title 24 standards with CEC climate zones.")
    elsif possible_climate_zone_sets.size > 2
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Found more than 2 climate zone sets containing #{climate_zone}; will return last matching climate zone set.")
    end

    # Get the climate zone from the possible set
    climate_zone_set = model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)

    # Check that a climate zone set was found
    if climate_zone_set.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot find a climate zone set in standard #{template}")
    end

    return climate_zone_set
  end

  # Determine which climate zone to use.
  # Defaults to the least specific climate zone set.
  # For example, 2A and 2 both contain 2A, so use 2.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param possible_climate_zone_sets [Array] climate zone sets
  # @return [String] climate zone ses
  def model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)
    climate_zone_set = possible_climate_zone_sets.max
    return climate_zone_set
  end

  # This method ensures that all spaces with spacetypes defined contain at least a standardSpaceType appropriate for the template.
  # So, if any space with a space type defined does not have a Stnadard spacetype, or is undefined, an error will stop
  # with information that the spacetype needs to be defined.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Bool] returns true if successful, false if not
  def model_validate_standards_spacetypes_in_model(model)
    error_string = ''
    # populate search hash
    model.getSpaces.sort.each do |space|
      unless space.spaceType.empty?
        if space.spaceType.get.standardsSpaceType.empty? || space.spaceType.get.standardsBuildingType.empty?
          error_string << "Space: #{space.name} has SpaceType of #{space.spaceType.get.name} but the standardSpaceType or standardBuildingType  is undefined. Please use an appropriate standardSpaceType for #{template}\n"
          next
        else
          search_criteria = {
            'template' => template,
            'building_type' => space.spaceType.get.standardsBuildingType.get,
            'space_type' => space.spaceType.get.standardsSpaceType.get
          }
          # lookup space type properties
          space_type_properties = model_find_object(standards_data['space_types'], search_criteria)
          if space_type_properties.nil?
            error_string << "Could not find spacetype of criteria : #{search_criteria}. Please ensure you have a valid standardSpaceType and stantdardBuildingType defined.\n"
            space_type_properties = {}
          end
        end
      end
    end
    return true if error_string == ''

    # else
    OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', error_string)
    return false
  end

  # Create sorted hash of stories with data need to determine effective number of stories above and below grade
  # the key should be the story object, which would allow other measures the ability to for example loop through spaces of the bottom story
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Hash] hash of space types with data in value necessary to determine effective number of stories above and below grade
  def model_create_story_hash(model)
    story_hash = {}

    # loop through stories
    model.getBuildingStorys.sort.each do |story|
      # skip of story doesn't have any spaces
      next if story.spaces.empty?

      story_min_z = nil
      story_zone_multipliers = []
      story_spaces_part_of_floor_area = []
      story_spaces_not_part_of_floor_area = []
      story_ext_wall_area = 0.0
      story_ground_wall_area = 0.0

      # loop through space surfaces to find min z value
      story.spaces.each do |space|
        # skip of space doesn't have any geometry
        next if space.surfaces.empty?

        # get space multiplier
        story_zone_multipliers << space.multiplier

        # space part of floor area check
        if space.partofTotalFloorArea
          story_spaces_part_of_floor_area << space
        else
          story_spaces_not_part_of_floor_area << space
        end

        # update exterior wall area (not sure if this is net or gross)
        story_ext_wall_area += space.exteriorWallArea

        space_min_z = nil
        z_points = []
        space.surfaces.each do |surface|
          surface.vertices.each do |vertex|
            z_points << vertex.z
          end

          # update count of ground wall areas
          next if surface.surfaceType != 'Wall'
          next if surface.outsideBoundaryCondition != 'Ground'
          # @todo make more flexible for slab/basement model.modeling

          story_ground_wall_area += surface.grossArea
        end

        # skip if surface had no vertices
        next if z_points.empty?

        # update story min_z
        space_min_z = z_points.min + space.zOrigin
        if story_min_z.nil? || (story_min_z > space_min_z)
          story_min_z = space_min_z
        end
      end

      # update story hash
      story_hash[story] = {}
      story_hash[story][:min_z] = story_min_z
      story_hash[story][:multipliers] = story_zone_multipliers
      story_hash[story][:part_of_floor_area] = story_spaces_part_of_floor_area
      story_hash[story][:not_part_of_floor_area] = story_spaces_not_part_of_floor_area
      story_hash[story][:ext_wall_area] = story_ext_wall_area
      story_hash[story][:ground_wall_area] = story_ground_wall_area
    end

    # sort hash by min_z low to high
    story_hash = story_hash.sort_by { |k, v| v[:min_z] }

    # reassemble into hash after sorting
    hash = {}
    story_hash.each do |story, props|
      hash[story] = props
    end

    return hash
  end

  # populate this method
  # Determine the effective number of stories above and below grade
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Hash] hash with effective_num_stories_below_grade and effective_num_stories_above_grade
  def model_effective_num_stories(model)
    below_grade = 0
    above_grade = 0

    # call model_create_story_hash(model)
    story_hash = model_create_story_hash(model)

    story_hash.each do |story, hash|
      # skip if no spaces in story are included in the building area
      next if hash[:part_of_floor_area].empty?

      # only count as below grade if ground wall area is greater than ext wall area and story below is also below grade
      if above_grade.zero? && (hash[:ground_wall_area] > hash[:ext_wall_area])
        below_grade += 1 * hash[:multipliers].min
      else
        above_grade += 1 * hash[:multipliers].min
      end
    end

    # populate hash
    effective_num_stories = {}
    effective_num_stories[:below_grade] = below_grade
    effective_num_stories[:above_grade] = above_grade
    effective_num_stories[:story_hash] = story_hash

    return effective_num_stories
  end

  # create space_type_hash with info such as effective_num_spaces, num_units, num_meds, num_meals
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param trust_effective_num_spaces [Bool] defaults to false - set to true if modeled every space as a real rpp, vs. space as collection of rooms
  # @return [Hash] hash of space types with misc information
  # @todo - add code when determining number of units to makeuse of trust_effective_num_spaces arg
  def model_create_space_type_hash(model, trust_effective_num_spaces = false)
    # assumed class size to deduct teachers from occupant count for classrooms
    typical_class_size = 20.0

    space_type_hash = {}
    model.getSpaceTypes.sort.each do |space_type|
      # get standards info
      stds_bldg_type = space_type.standardsBuildingType
      stds_space_type = space_type.standardsSpaceType
      if stds_bldg_type.is_initialized && stds_space_type.is_initialized && !space_type.spaces.empty?
        stds_bldg_type = stds_bldg_type.get
        stds_space_type = stds_space_type.get
        effective_num_spaces = 0
        floor_area = 0.0
        num_people = 0.0
        num_students = 0.0
        num_units = 0.0
        num_beds = 0.0
        num_people_bldg_total = nil # may need this in future, not same as sumo of people for all space types.
        num_meals = nil
        # determine num_elevators in another method
        # determine num_parking_spots in another method

        # loop through spaces to get mis values
        space_type.spaces.sort.each do |space|
          next unless space.partofTotalFloorArea

          effective_num_spaces += space.multiplier
          floor_area += space.floorArea * space.multiplier
          num_people += space.numberOfPeople * space.multiplier
        end

        # determine number of units
        if stds_bldg_type == 'SmallHotel' && stds_space_type.include?('GuestRoom') # doesn't always == GuestRoom so use include?
          avg_unit_size = OpenStudio.convert(354.2, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'LargeHotel' && stds_space_type.include?('GuestRoom')
          avg_unit_size = OpenStudio.convert(279.7, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'MidriseApartment' && stds_space_type.include?('Apartment')
          avg_unit_size = OpenStudio.convert(949.9, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'HighriseApartment' && stds_space_type.include?('Apartment')
          avg_unit_size = OpenStudio.convert(949.9, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'StripMall'
          avg_unit_size = OpenStudio.convert(22_500.0 / 10.0, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'Htl' && (stds_space_type.include?('GuestRmOcc') || stds_space_type.include?('GuestRmUnOcc'))
          avg_unit_size = OpenStudio.convert(354.2, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'MFm' && (stds_space_type.include?('ResBedroom') || stds_space_type.include?('ResLiving'))
          avg_unit_size = OpenStudio.convert(949.9, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'Mtl' && (stds_space_type.include?('GuestRmOcc') || stds_space_type.include?('GuestRmUnOcc'))
          avg_unit_size = OpenStudio.convert(354.2, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        elsif stds_bldg_type == 'Nrs' && stds_space_type.include?('PatientRoom')
          avg_unit_size = OpenStudio.convert(354.2, 'ft^2', 'm^2').get # calculated from prototype
          num_units = floor_area / avg_unit_size
        end

        # determine number of beds
        if stds_bldg_type == 'Hospital' && ['PatRoom', 'ICU_PatRm', 'ICU_Open'].include?(stds_space_type)
          num_beds = num_people
        elsif stds_bldg_type == 'Hsp' && ['PatientRoom', 'HspSurgOutptLab', 'HspNursing'].include?(stds_space_type)
          num_beds = num_people
        end

        # determine number of students
        if ['PrimarySchool', 'SecondarySchool'].include?(stds_bldg_type) && stds_space_type == 'Classroom'
          num_students += num_people * ((typical_class_size - 1.0) / typical_class_size)
        elsif ['EPr', 'ESe', 'ERC', 'EUn', 'ECC'].include?(stds_bldg_type) && stds_space_type == 'Classroom'
          num_students += num_people * ((typical_class_size - 1.0) / typical_class_size)
        end

        space_type_hash[space_type] = {}
        space_type_hash[space_type][:stds_bldg_type] = stds_bldg_type
        space_type_hash[space_type][:stds_space_type] = stds_space_type
        space_type_hash[space_type][:effective_num_spaces] = effective_num_spaces
        space_type_hash[space_type][:floor_area] = floor_area
        space_type_hash[space_type][:num_people] = num_people
        space_type_hash[space_type][:num_students] = num_students
        space_type_hash[space_type][:num_units] = num_units
        space_type_hash[space_type][:num_beds] = num_beds

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, floor area = #{OpenStudio.convert(floor_area, 'm^2', 'ft^2').get.round} ft^2.") unless floor_area == 0.0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, number of spaces = #{effective_num_spaces}.") unless effective_num_spaces == 0.0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, number of units = #{num_units}.") unless num_units == 0.0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, number of people = #{num_people.round}.") unless num_people == 0.0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, number of students = #{num_students}.") unless num_students == 0.0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, number of beds = #{num_beds}.") unless num_beds == 0.0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "For #{space_type.name}, number of meals = #{num_meals}.") unless num_meals.nil?

      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Cannot identify standards building type and space type for #{space_type.name}, it won't be added to space_type_hash.")
      end
    end

    return space_type_hash.sort.to_h
  end

  # This method will limit the subsurface of a given surface_type ("Wall" or "RoofCeiling") to the ratio for the building.
  # This method only reduces subsurface sizes at most.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param ratio [Double] ratio
  # @param surface_type [String] surface type
  # @return [Bool] returns true if successful, false if not
  def apply_limit_to_subsurface_ratio(model, ratio, surface_type = 'Wall')
    fdwr = get_outdoor_subsurface_ratio(model, surface_type)
    if fdwr <= ratio
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Building FDWR of #{fdwr} is already lower than limit of #{ratio.round}%.")
      return true
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all windows (by shrinking to centroid) to reduce window area down to the limit of #{ratio.round}%.")
    # Determine the factors by which to reduce the window / door area
    mult = ratio / fdwr
    # Reduce the window area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == surface_type

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          # Reduce the size of the window
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end
    return true
  end

  # Converts the climate zone in the model into the format used by the openstudio-standards lookup tables.
  # For example,
  #   institution: ASHRAE, value: 6A  becomes: ASHRAE 169-2013-6A.
  #   institution: CEC, value: 3  becomes: CEC T24-CEC3.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [String] the string representation of the climate zone,
  #   empty string if no climate zone is present in the model.
  def model_standards_climate_zone(model)
    climate_zone = ''
    model.getClimateZones.climateZones.each do |cz|
      if cz.institution == 'ASHRAE'
        next if cz.value == '' # Skip blank ASHRAE climate zones put in by OpenStudio Application

        climate_zone = if cz.value == '7' || cz.value == '8'
                         "ASHRAE 169-2013-#{cz.value}A"
                       else
                         "ASHRAE 169-2013-#{cz.value}"
                       end
      elsif cz.institution == 'CEC'
        next if cz.value == '' # Skip blank ASHRAE climate zones put in by OpenStudio Application

        climate_zone = "CEC T24-CEC#{cz.value}"
      end
    end
    return climate_zone
  end

  # Sets the climate zone object in the model using
  # the correct institution based on the climate zone specified
  # in the format used by the openstudio-standards lookups.
  # Clears out any climate zones previously added to the model.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if successful, false if not
  def model_set_climate_zone(model, climate_zone)
    # Remove previous climate zones from the model
    model.getClimateZones.clear
    # Split the string into the correct institution and value
    if climate_zone.include? 'ASHRAE 169-2006-'
      model.getClimateZones.setClimateZone('ASHRAE', climate_zone.gsub('ASHRAE 169-2006-', ''))
    elsif climate_zone.include? 'ASHRAE 169-2013-'
      model.getClimateZones.setClimateZone('ASHRAE', climate_zone.gsub('ASHRAE 169-2013-', ''))
    elsif climate_zone.include? 'CEC T24-CEC'
      model.getClimateZones.setClimateZone('CEC', climate_zone.gsub('CEC T24-CEC', ''))

    end
    return true
  end

  # This method return the building ratio of subsurface_area / surface_type_area
  # where surface_type can be "Wall" or "RoofCeiling"
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param surface_type [String] surface type
  # @return [Double] surface ratio
  def get_outdoor_subsurface_ratio(model, surface_type = 'Wall')
    surface_area = 0.0
    sub_surface_area = 0
    all_surfaces = []
    all_sub_surfaces = []
    model.getSpaces.sort.each do |space|
      zone = space.thermalZone
      zone_multiplier = nil
      next if zone.empty?

      zone_multiplier = zone.get.multiplier
      space.surfaces.sort.each do |surface|
        if (surface.outsideBoundaryCondition == 'Outdoors') && (surface.surfaceType == surface_type)
          surface_area += surface.grossArea * zone_multiplier
          surface.subSurfaces.sort.each do |sub_surface|
            sub_surface_area += sub_surface.grossArea * sub_surface.multiplier * zone_multiplier
          end
        end
      end
    end
    return fdwr = (sub_surface_area / surface_area)
  end

  # Loads a osm as a starting point.
  #
  # @param osm_file [String] path to the .osm file, relative to the /data folder
  # @return [Bool] returns true if successful, false if not
  def load_initial_osm(osm_file)
    # Load the geometry .osm
    unless File.exist?(osm_file)
      raise("The initial osm path: #{osm_file} does not exist.")
    end

    osm_model_path = OpenStudio::Path.new(osm_file.to_s)
    # Upgrade version if required.
    version_translator = OpenStudio::OSVersion::VersionTranslator.new
    model = version_translator.loadModel(osm_model_path).get
    validate_initial_model(model)
    return model
  end

  # validate that model contains objects
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [Bool] returns true if valid, false if not
  def validate_initial_model(model)
    is_valid = true
    if model.getBuildingStorys.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Please assign Spaces to BuildingStorys the geometry model.')
      is_valid = false
    end
    if model.getThermalZones.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Please assign Spaces to ThermalZones the geometry model.')
      is_valid = false
    end
    if model.getBuilding.standardsNumberOfStories.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Please define Building.standardsNumberOfStories the geometry model.')
      is_valid = false
    end
    if model.getBuilding.standardsNumberOfAboveGroundStories.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Please define Building.standardsNumberOfAboveStories in the geometry model.')
      is_valid = false
    end

    if @space_type_map.nil? || @space_type_map.empty?
      @space_type_map = get_space_type_maps_from_model(model)
      if @space_type_map.nil? || @space_type_map.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign SpaceTypes in the geometry model or in standards database #{@space_type_map}.")
        is_valid = false
      else
        @space_type_map = @space_type_map.sort.to_h
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Loaded space type map from model')
      end
    end

    # ensure that model is intersected correctly.
    model.getSpaces.each { |space1| model.getSpaces.each { |space2| space1.intersectSurfaces(space2) } }
    # Get multipliers from TZ in model. Need this for HVAC contruction.
    @space_multiplier_map = {}
    model.getSpaces.sort.each do |space|
      @space_multiplier_map[space.name.get] = space.multiplier if space.multiplier > 1
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding geometry')
    unless @space_multiplier_map.empty?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Found multipliers for space #{@space_multiplier_map}")
    end
    return is_valid
  end

  # Determines how ventilation for the standard is specified.
  # When 'Sum', all min OA flow rates are added up.  Commonly used by 90.1.
  # When 'Maximum', only the biggest OA flow rate.  Used by T24.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [String] the ventilation method, either Sum or Maximum
  def model_ventilation_method(model)
    building_data = model_get_building_properties(model)
    building_type = building_data['building_type']
    if building_type != 'Laboratory' # Laboratory has multiple criteria on ventilation, pick the greatest
      ventilation_method = 'Sum'
    else
      ventilation_method = 'Maximum'
    end

    return ventilation_method
  end

  # Removes all of the unused ResourceObjects
  # (Curves, ScheduleDay, Material, etc.) from the model.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [Bool] returns true if successful, false if not
  def model_remove_unused_resource_objects(model)
    start_size = model.objects.size
    model.getResourceObjects.sort.each do |obj|
      if obj.directUseCount.zero?
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "#{obj.name} is unused; it will be removed.")
        model.removeObject(obj.handle)
      end
    end
    end_size = model.objects.size
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The model started with #{start_size} objects and finished with #{end_size} objects after removing unused resource objects.")
    return true
  end

  # This method looks at occupancy profiles for the building as a whole and generates an hours of operation default
  # schedule for the building. It also clears out any higher level hours of operation schedule assignments.
  # Spaces are organized by res and non_res. Whichever of the two groups has higher design level of people is used for building hours of operation
  # Resulting hours of operation can have as many rules as necessary to describe the operation.
  # Each ScheduleDay should be an on/off schedule with only values of 0 and 1. There should not be more than one on/off cycle per day.
  # In future this could create different hours of operation for residential vs. non-residential, by building type, story, or space type.
  # However this measure is a stop gap to convert old generic schedules to parametric schedules.
  # Future new schedules should be designed as paramtric from the start and would not need to run through this inference process
  #
  # @author David Goldwasser
  # @param model [OpenStudio::Model::Model] the model
  # @param fraction_of_daily_occ_range [Double] fraction above/below daily min range required to start and end hours of operation
  # @param invert_res [Bool] if true will reverse hours of operation for residential space types
  # @param gen_occ_profile [Bool] if true creates a merged occupancy schedule for diagnostic purposes. This schedule is added to the model but no specifically returned by this method
  # @return [ScheduleRuleset] schedule that is assigned to the building as default hours of operation
  def model_infer_hours_of_operation_building(model, fraction_of_daily_occ_range: 0.25, invert_res: true, gen_occ_profile: false)
    # create an array of non-residential and residential spaces
    res_spaces = []
    non_res_spaces = []
    res_people_design = 0
    non_res_people_design = 0
    model.getSpaces.sort.each do |space|
      if space_residential?(space)
        res_spaces << space
        res_people_design += space.numberOfPeople * space.multiplier
      else
        non_res_spaces << space
        non_res_people_design += space.numberOfPeople * space.multiplier
      end
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "Model has design level of #{non_res_people_design} people in non residential spaces and #{res_people_design} people in residential spaces.")

    # create merged schedule for prevalent type (not used but can be generated for diagnostics)
    if gen_occ_profile
      res_prevalent = false
      if res_people_design > non_res_people_design
        occ_merged = spaces_get_occupancy_schedule(res_spaces, sch_name: 'Calculated Occupancy Fraction Residential Merged')
        res_prevalent = true
      else
        occ_merged = spaces_get_occupancy_schedule(non_res_spaces, sch_name: 'Calculated Occupancy Fraction NonResidential Merged')
      end
    end

    # re-run spaces_get_occupancy_schedule with x above min occupancy to create on/off schedule
    if res_people_design > non_res_people_design
      hours_of_operation = spaces_get_occupancy_schedule(res_spaces,
                                                         sch_name: 'Building Hours of Operation Residential',
                                                         occupied_percentage_threshold: fraction_of_daily_occ_range,
                                                         threshold_calc_method: 'normalized_daily_range')
      res_prevalent = true
    else
      hours_of_operation = spaces_get_occupancy_schedule(non_res_spaces,
                                                         sch_name: 'Building Hours of Operation NonResidential',
                                                         occupied_percentage_threshold: fraction_of_daily_occ_range,
                                                         threshold_calc_method: 'normalized_daily_range')
    end

    # remove gaps resulting in multiple on off cycles for each rule in schedule so it will be valid hours of operation
    profiles = []
    profiles << hours_of_operation.defaultDaySchedule
    hours_of_operation.scheduleRules.each do |rule|
      profiles << rule.daySchedule
    end
    profiles.sort.each do |profile|
      times = profile.times
      values = profile.values
      next if times.size <= 3 # length of 1-3 should produce valid hours_of_operation profiles

      # Find the latest time where the value == 1
      latest_time = nil
      times.zip(values).each do |time, value|
        if value > 0
          latest_time = time
        end
      end
      # Skip profiles that are zero all the time
      next if latest_time.nil?

      # Calculate the duration from this point to midnight
      wrap_dur_left_hr = 0
      if values.first == 0 && values.last == 0
        wrap_dur_left_hr = 24.0 - latest_time.totalHours
      end
      occ_gap_hash = {}
      prev_time = 0
      prev_val = nil
      times.each_with_index do |time, i|
        next if time.totalHours == 0.0 # should not see this
        next if values[i] == prev_val # check if two 0 until time next to each other

        if values[i] == 0 # only store vacant segments
          if time.totalHours == 24
            occ_gap_hash[prev_time] = time.totalHours - prev_time + wrap_dur_left_hr
          else
            occ_gap_hash[prev_time] = time.totalHours - prev_time
          end
        end
        prev_time = time.totalHours
        prev_val = values[i]
      end
      profile.clearValues
      max_occ_gap_start = occ_gap_hash.key(occ_gap_hash.values.max)
      max_occ_gap_end_hr = max_occ_gap_start + occ_gap_hash[max_occ_gap_start] # can't add time and duration in hours
      if max_occ_gap_end_hr > 24.0 then max_occ_gap_end_hr -= 24.0 end

      # time for gap start
      target_start_hr = max_occ_gap_start.truncate
      target_start_min = ((max_occ_gap_start - target_start_hr) * 60.0).truncate
      max_occ_gap_start = OpenStudio::Time.new(0, target_start_hr, target_start_min, 0)

      # time for gap end
      target_end_hr = max_occ_gap_end_hr.truncate
      target_end_min = ((max_occ_gap_end_hr - target_end_hr) * 60.0).truncate
      max_occ_gap_end = OpenStudio::Time.new(0, target_end_hr, target_end_min, 0)

      profile.addValue(max_occ_gap_start, 1)
      profile.addValue(max_occ_gap_end, 0)
      os_time_24 = OpenStudio::Time.new(0, 24, 0, 0)
      if max_occ_gap_start > max_occ_gap_end
        profile.addValue(os_time_24, 0)
      else
        profile.addValue(os_time_24, 1)
      end
    end

    # reverse 1 and 0 values for res_prevalent building
    # currently spaces_get_occupancy_schedule doesn't use defaultDayProflie, so only inspecting rules for now.
    if invert_res && res_prevalent
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', 'Per argument passed in hours of operation are being inverted for buildings with more people in residential versus non-residential spaces.')
      hours_of_operation.scheduleRules.each do |rule|
        profile = rule.daySchedule
        times = profile.times
        values = profile.values
        profile.clearValues
        times.each_with_index do |time, i|
          orig_val = values[i]
          new_value = nil
          if orig_val == 0 then new_value = 1 end
          if orig_val == 1 then new_value = 0 end
          profile.addValue(time, new_value)
        end
      end
    end

    # set hours of operation for building level hours of operation
    model.getDefaultScheduleSets.each(&:resetHoursofOperationSchedule)
    if model.getBuilding.defaultScheduleSet.is_initialized
      default_sch_set = model.getBuilding.defaultScheduleSet.get
    else
      default_sch_set = OpenStudio::Model::DefaultScheduleSet.new(model)
      default_sch_set.setName('Building Default Schedule Set')
      model.getBuilding.setDefaultScheduleSet(default_sch_set)
    end
    default_sch_set.setHoursofOperationSchedule(hours_of_operation)

    return hours_of_operation
  end

  # This method users the hours of operation for a space and the existing ScheduleRuleset profiles to setup parametric schedule
  # inputs. Inputs include one or more load profile formulas. Data is stored in model attributes for downstream
  # application. This should impact all ScheduleRuleset objects in the model. Plant and Air loop hoours of operations
  # should be traced back to a space or spaces.
  #
  # @author David Goldwasser
  # @param model [OpenStudio::Model::Model] the model
  # @param step_ramp_logic [String] type of step logic to use
  # @param infer_hoo_for_non_assigned_objects [Bool] attempt to get hoo for objects like swh with and exterior lighting
  # @param gather_data_only [Bool] false (stops method before changes made if true)
  # @param hoo_var_method [String] accepts hours and fractional. Any other value value will result in hoo variables not being applied
  # @return [Hash] schedule is key, value is hash of number of objects
  def model_setup_parametric_schedules(model, step_ramp_logic: nil, infer_hoo_for_non_assigned_objects: true, gather_data_only: false, hoo_var_method: 'hours')
    parametric_inputs = {}
    default_sch_type = OpenStudio::Model::DefaultScheduleType.new('HoursofOperationSchedule')
    # thermal zones, air loops, plant loops will require some logic if they refer to more than one hours of operaiton schedule.
    # for initial use case while have same horus of operaiton so this can be pretty simple, but will have to re-visit it sometime
    # possible solution A: choose hoo that contributes the largest fraction of floor area
    # possible solution B: expand the hours of operation for a given day to include combined range of hoo objects
    # whatever approach is used for gathering parametric inputs for existing ruleset schedules should also be used for model_apply_parametric_schedules

    # loop through spaces (trace hours of operation back to space)
    gather_inputs_parametric_space_space_type_schedules(model.getSpaces, parametric_inputs, gather_data_only)

    # loop through space types (trace hours of operation back to space type).
    gather_inputs_parametric_space_space_type_schedules(model.getSpaceTypes, parametric_inputs, gather_data_only)

    # loop through thermal zones (trace hours of operation back to spaces in thermal zone)
    thermal_zone_hash = {} # key is zone and hash is hours of operation
    model.getThermalZones.sort.each do |zone|
      # identify hours of operation
      hours_of_operation = spaces_hours_of_operation(zone.spaces)
      thermal_zone_hash[zone] = hours_of_operation
      # get thermostat setpoint schedules
      if zone.thermostatSetpointDualSetpoint.is_initialized
        thermostat = zone.thermostatSetpointDualSetpoint.get
        if thermostat.heatingSetpointTemperatureSchedule.is_initialized && thermostat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.is_initialized
          schedule = thermostat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
          gather_inputs_parametric_schedules(schedule, thermostat, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
        end
        if thermostat.coolingSetpointTemperatureSchedule.is_initialized && thermostat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.is_initialized
          schedule = thermostat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
          gather_inputs_parametric_schedules(schedule, thermostat, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
        end
      end
    end

    # loop through air loops (trace hours of operation back through spaces served by air loops)
    air_loop_hash = {} # key is zone and hash is hours of operation
    model.getAirLoopHVACs.sort.each do |air_loop|
      # identify hours of operation
      air_loop_spaces = []
      air_loop.thermalZones.sort.each do |zone|
        air_loop_spaces += zone.spaces
        air_loop_spaces += zone.spaces
      end
      hours_of_operation = spaces_hours_of_operation(air_loop_spaces)
      air_loop_hash[air_loop] = hours_of_operation
      if air_loop.availabilitySchedule.to_ScheduleRuleset.is_initialized
        schedule = air_loop.availabilitySchedule.to_ScheduleRuleset.get
        gather_inputs_parametric_schedules(schedule, air_loop, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
      end
      avail_mgrs = air_loop.availabilityManagers
      avail_mgrs.sort.each do |avail_mgr|
        # @todo I'm finding availability mangers, but not any resources for them, even if I use OpenStudio::Model.getRecursiveChildren(avail_mgr)
        resources = avail_mgr.resources
        resources = OpenStudio::Model.getRecursiveResources(avail_mgr)
        resources.sort.each do |resource|
          if resource.to_ScheduleRuleset.is_initialized
            schedule = resource.to_ScheduleRuleset.get
            gather_inputs_parametric_schedules(schedule, avail_mgr, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
          end
        end
      end
    end

    # look through all model HVAC components find scheduleRuleset objects, resources, that use them and zone or air loop for hours of operation
    hvac_components = model.getHVACComponents
    hvac_components.sort.each do |component|
      # identify zone, or air loop it refers to, some may refer to plant loop, OA or other component
      thermal_zone = nil
      air_loop = nil
      plant_loop = nil
      schedules = []
      if component.to_ZoneHVACComponent.is_initialized && component.to_ZoneHVACComponent.get.thermalZone.is_initialized
        thermal_zone = component.to_ZoneHVACComponent.get.thermalZone.get
      end
      if component.airLoopHVAC.is_initialized
        air_loop = component.airLoopHVAC.get
      end
      if component.plantLoop.is_initialized
        plant_loop = component.plantLoop.get
      end
      component.resources.sort.each do |resource|
        if resource.to_ThermalZone.is_initialized
          thermal_zone = resource.to_ThermalZone.get
        elsif resource.to_ScheduleRuleset.is_initialized
          schedules << resource.to_ScheduleRuleset.get
        end
      end

      # inspect resources for children of objects found in thermal zone or plant loop
      # get objects like OA controllers and unitary object components
      next if thermal_zone.nil? && air_loop.nil?

      children = OpenStudio::Model.getRecursiveChildren(component)
      children.sort.each do |child|
        child.resources.sort.each do |sub_resource|
          if sub_resource.to_ScheduleRuleset.is_initialized
            schedules << sub_resource.to_ScheduleRuleset.get
          end
        end
      end

      # process schedules found for this component
      schedules.sort.each do |schedule|
        hours_of_operation = nil
        if !thermal_zone.nil?
          hours_of_operation = thermal_zone_hash[thermal_zone]
        elsif !air_loop.nil?
          hours_of_operation = air_loop_hash[air_loop]
        elsif !plant_loop.nil?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "#{schedule.name.get} is associated with plant loop, will not gather parametric inputs")
          next
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Cannot identify where #{component.name.get} is in system. Will not gather parametric inputs for #{schedule.name.get}")
          next
        end
        gather_inputs_parametric_schedules(schedule, component, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
      end
    end

    # @todo Service Water Heating supply side (may or may not be associated with a space)
    # @todo water use equipment definitions (temperature, sensible, latent) may be in multiple spaces, need to identify hoo, but typically constant schedules

    # water use equipment (flow rate fraction)
    # @todo address common schedules used across multiple instances
    model.getWaterUseEquipments.sort.each do |water_use_equipment|
      if water_use_equipment.flowRateFractionSchedule.is_initialized && water_use_equipment.flowRateFractionSchedule.get.to_ScheduleRuleset.is_initialized
        schedule = water_use_equipment.flowRateFractionSchedule.get.to_ScheduleRuleset.get
        next if parametric_inputs.key?(schedule)

        opt_space = water_use_equipment.space
        if opt_space.is_initialized
          space = space.get
          hours_of_operation = space_hours_of_operation(space)
          gather_inputs_parametric_schedules(schedule, water_use_equipment, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
        else
          hours_of_operation = spaces_hours_of_operation(model.getSpaces)
          if !hours_of_operation.nil?
            gather_inputs_parametric_schedules(schedule, water_use_equipment, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: hoo_var_method)
          end
        end

      end
    end
    # @todo Refrigeration (will be associated with thermal zone)
    # @todo exterior lights (will be astronomical, but like AEDG's may have reduction later at night)

    return parametric_inputs
  end

  # This method applies the hours of operation for a space and the load profile formulas in the overloaded ScheduleRulset
  # objects to update time value pairs for ScheduleDay objects. Object type specific logic will be used to generate profiles
  # for summer and winter design days.
  #
  # @note This measure will replace any prior chagnes made to ScheduleRule objects with new ScheduleRule values from
  # profile formulas
  # @author David Goldwasser
  # @param model [OpenStudio::Model::Model] the model
  # @param ramp_frequency [Double] ramp frequency in minutes. If nil method will match simulation timestep
  # @param infer_hoo_for_non_assigned_objects [Bool] # attempt to get hoo for objects like swh with and exterior lighting
  # @param error_on_out_of_order [Bool] true will error if applying formula creates out of order values
  # @return [Array] of modified ScheduleRuleset objects
  def model_apply_parametric_schedules(model, ramp_frequency: nil, infer_hoo_for_non_assigned_objects: true, error_on_out_of_order: true)
    # get ramp frequency (fractional hour) from timestep
    if ramp_frequency.nil?
      steps_per_hour = if model.getSimulationControl.timestep.is_initialized
                         model.getSimulationControl.timestep.get.numberOfTimestepsPerHour
                       else
                         6 # default OpenStudio timestep if none specified
                       end
      ramp_frequency = 1.0 / steps_per_hour.to_f
    end

    # Go through model and create parametric formulas for all schedules
    parametric_inputs = model_setup_parametric_schedules(model, gather_data_only: true)

    parametric_schedules = []
    model.getScheduleRulesets.sort.each do |sch|
      if !sch.hasAdditionalProperties || !sch.additionalProperties.hasFeature('param_sch_ver')
        # for now don't look at schedules without targets, in future can alter these by looking at building level hours of operation
        next if sch.directUseCount <= 0 # won't catch if used for space type load instance, but that space type isn't used

        # @todo address schedules that fall into this category, if they are used in the model
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "For #{sch.sources.first.name}, #{sch.name} is not setup as parametric schedule. It has #{sch.sources.size} sources.")
        next
      end

      # apply parametric inputs
      schedule_apply_parametric_inputs(sch, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order, parametric_inputs)

      # add schedule to array
      parametric_schedules << sch
    end

    return parametric_schedules
  end

  private

  # Helper method to fill in hourly values
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param day_sch [OpenStudio::Model::ScheduleDay] schedule day object
  # @param sch_type [String] Constant or Hourly
  # @param values [Array<Double>]
  # @return [Bool] returns true if successful, false if not
  def model_add_vals_to_sch(model, day_sch, sch_type, values)
    if sch_type == 'Constant'
      day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), values[0])
    elsif sch_type == 'Hourly'
      (0..23).each do |i|
        next if values[i] == values[i + 1]

        day_sch.addValue(OpenStudio::Time.new(0, i + 1, 0, 0), values[i])
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Schedule type: #{sch_type} is not recognized.  Valid choices are 'Constant' and 'Hourly'.")
    end
  end

  # Modify the existing service water heating loops to match the baseline required heating type.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param building_type [String] the building type
  # @return [Bool] returns true if successful, false if not
  # @author Julien Marrec
  def model_apply_baseline_swh_loops(model, building_type)
    model.getPlantLoops.sort.each do |plant_loop|
      # Skip non service water heating loops
      next unless plant_loop_swh_loop?(plant_loop)

      # Rename the loop to avoid accidentally hooking up the HVAC systems to this loop later.
      plant_loop.setName('Service Water Heating Loop')

      htg_fuels, combination_system, storage_capacity, total_heating_capacity = plant_loop_swh_system_type(plant_loop)

      # htg_fuels.size == 0 shoudln't happen

      electric = true

      if htg_fuels.include?('NaturalGas') ||
         htg_fuels.include?('Propane') ||
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
        plant_loop.supplyComponents.each do |component|
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

    # Set the water heater fuel types if it's 90.1-2013
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      water_heater_mixed_apply_prm_baseline_fuel_type(water_heater, building_type)
    end

    return true
  end

  # This method goes through certain types of EnergyManagementSystem variables and replaces UIDs with object names.
  # This should be done by the forward translator, and this code should be removed after this bug is fixed:
  # https://github.com/NREL/OpenStudio/issues/2598
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [Bool] returns true if successful, false if not
  # @todo remove this method after OpenStudio issue #2598 is fixed.
  def model_temp_fix_ems_references(model)
    # Internal Variables
    model.getEnergyManagementSystemInternalVariables.sort.each do |var|
      # Get the reference field value
      ref = var.internalDataIndexKeyName
      # Convert to UUID
      uid = OpenStudio.toUUID(ref)
      # Get the model object with this UID
      obj = model.getModelObject(uid)
      # If it exists, replace the UID with the object name
      if obj.is_initialized
        var.setInternalDataIndexKeyName(obj.get.name.get)
      end
    end

    return true
  end

  # Loads a geometry osm as a starting point.
  #
  # @param osm_model_path [String] path to the .osm file, relative to the /data folder
  # @return [OpenStudio::Model::Model] model object
  def load_user_geometry_osm(osm_model_path:)
    version_translator = OpenStudio::OSVersion::VersionTranslator.new
    model = version_translator.loadModel(osm_model_path)

    # Check that the model loaded successfully
    if model.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Version translation failed for #{osm_model_path}")
      return false
    end
    model = model.get

    # Check for expected characteristics of geometry model
    if model.getBuildingStorys.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign Spaces to BuildingStorys in the geometry model: #{osm_model_path}.")
    end
    if model.getThermalZones.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign Spaces to ThermalZones in the geometry model: #{osm_model_path}.")
    end
    if model.getBuilding.standardsNumberOfStories.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please define Building.standardsNumberOfStories in the geometry model #{osm_model_path}.")
    end
    if model.getBuilding.standardsNumberOfAboveGroundStories.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please define Building.standardsNumberOfAboveStories in the geometry model#{osm_model_path}.")
    end

    if @space_type_map.nil? || @space_type_map.empty?
      @space_type_map = get_space_type_maps_from_model(model)
      if @space_type_map.nil? || @space_type_map.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign SpaceTypes in the geometry model: #{osm_model_path} or in standards database #{@space_type_map}.")
      else
        @space_type_map = @space_type_map.sort.to_h
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Loaded space type map from osm file: #{osm_model_path}")
      end
    end
    return model
  end

  # Loads a osm as a starting point.
  #
  # @param osm_file [String] path to the .osm file, relative to the /data folder
  # @return [OpenStudio::Model::Model] model object, false if not
  def load_geometry_osm(osm_file)
    # Load the geometry .osm from relative to the data folder
    osm_model_path = "../../../data/#{osm_file}"

    # Load the .osm depending on whether running from normal gem location
    # or from the embedded location in the OpenStudio CLI
    if File.dirname(__FILE__)[0] == ':'
      # running from embedded location in OpenStudio CLI
      geom_model_string = load_resource_relative(osm_model_path)
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModelFromString(geom_model_string)
    else
      abs_path = File.join(File.dirname(__FILE__), osm_model_path)
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModel(abs_path)
    end

    # Check that the model loaded successfully
    if model.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Version translation failed for #{osm_model_path}")
      return false
    end
    model = model.get

    # Check for expected characteristics of geometry model
    if model.getBuildingStorys.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign Spaces to BuildingStorys in the geometry model: #{osm_model_path}.")
    end
    if model.getThermalZones.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign Spaces to ThermalZones in the geometry model: #{osm_model_path}.")
    end
    if model.getBuilding.standardsNumberOfStories.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please define Building.standardsNumberOfStories in the geometry model #{osm_model_path}.")
    end
    if model.getBuilding.standardsNumberOfAboveGroundStories.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please define Building.standardsNumberOfAboveStories in the geometry model#{osm_model_path}.")
    end

    if @space_type_map.nil? || @space_type_map.empty?
      @space_type_map = get_space_type_maps_from_model(model)
      if @space_type_map.nil? || @space_type_map.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Please assign SpaceTypes in the geometry model: #{osm_model_path} or in standards database #{@space_type_map}.")
      else
        @space_type_map = @space_type_map.sort.to_h
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Loaded space type map from osm file: #{osm_model_path}")
      end
    end
    return model
  end

  # pass array of space types or spaces
  #
  # @author David Goldwasser
  # @param space_space_types [Array] array of spaces or space types
  # @param parametric_inputs [Hash]
  # @param gather_data_only [Bool]
  # @return [Hash]
  def gather_inputs_parametric_space_space_type_schedules(space_space_types, parametric_inputs, gather_data_only)
    space_space_types.each do |space_type|
      # get hours of operation for space type once
      next if space_type.class == 'OpenStudio::Model::SpaceTypes' && space_type.floorArea == 0

      hours_of_operation = space_hours_of_operation(space_type)
      if hours_of_operation.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.Model', "Can't evaluate schedules for #{space_type.name}, doesn't have hours of operation.")
        next
      end
      # loop through internal load instances
      space_type.lights.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.luminaires.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.electricEquipment.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.gasEquipment.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.steamEquipment.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.otherEquipment.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.people.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
        if load_inst.activityLevelSchedule.is_initialized && load_inst.activityLevelSchedule.get.to_ScheduleRuleset.is_initialized
          act_sch = load_inst.activityLevelSchedule.get.to_ScheduleRuleset.get
          gather_inputs_parametric_schedules(act_sch, load_inst, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: 'hours')
        end
      end
      space_type.spaceInfiltrationDesignFlowRates.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      space_type.spaceInfiltrationEffectiveLeakageAreas.each do |load_inst|
        gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
      end
      dsgn_spec_oa = space_type.designSpecificationOutdoorAir
      if dsgn_spec_oa.is_initialized
        gather_inputs_parametric_load_inst_schedules(dsgn_spec_oa.get, parametric_inputs, hours_of_operation, gather_data_only)
      end
    end

    return parametric_inputs
  end

  # method to process load instance schedules for model_setup_parametric_schedules
  #
  # @author David Goldwasser
  # @param load_inst [OpenStudio::Model::SpaceLoadInstance]
  # @param parametric_inputs [Hash]
  # @param hours_of_operation [Hash]
  # @param gather_data_only [Bool]
  # @return [Hash]
  def gather_inputs_parametric_load_inst_schedules(load_inst, parametric_inputs, hours_of_operation, gather_data_only)
    if load_inst.class.to_s == 'OpenStudio::Model::People'
      opt_sch = load_inst.numberofPeopleSchedule
    elsif load_inst.class.to_s == 'OpenStudio::Model::DesignSpecificationOutdoorAir'
      opt_sch = load_inst.outdoorAirFlowRateFractionSchedule
    else
      opt_sch = load_inst.schedule
    end
    if !opt_sch.is_initialized || !opt_sch.get.to_ScheduleRuleset.is_initialized
      return nil
    end

    gather_inputs_parametric_schedules(opt_sch.get.to_ScheduleRuleset.get, load_inst, parametric_inputs, hours_of_operation, gather_data_only: gather_data_only, hoo_var_method: 'hours')

    return parametric_inputs
  end

  # method to process load instance schedules for model_setup_parametric_schedules
  #
  # @author David Goldwasser
  # @param sch [OpenStudio::Model::Schedule]
  # @param load_inst [OpenStudio::Model::SpaceLoadInstance]
  # @param parametric_inputs [Hash]
  # @param hours_of_operation [Hash]
  # @param ramp [Bool]
  # @param min_ramp_dur_hr [Double]
  # @param gather_data_only [Bool]
  # @param hoo_var_method [String] accepts hours and fractional. Any other value value will result in hoo variables not being applied
  # @return [Hash]
  def gather_inputs_parametric_schedules(sch, load_inst, parametric_inputs, hours_of_operation, ramp: true, min_ramp_dur_hr: 2.0, gather_data_only: false, hoo_var_method: 'hours')
    if parametric_inputs.key?(sch)
      if hours_of_operation != parametric_inputs[sch][:hoo_inputs] # don't warn if the hours of operation between old and new schedule are equivalent
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.Model', "#{load_inst.name} uses #{sch.name} but parametric inputs have already been setup based on hours of operation for #{parametric_inputs[sch][:target].name}.")
        return nil
      end
    end

    # gather and store data for scheduleRuleset
    min_max = schedule_ruleset_annual_min_max_value(sch)
    ruleset_hash = { floor: min_max['min'], ceiling: min_max['max'], target: load_inst, hoo_inputs: hours_of_operation }
    parametric_inputs[sch] = ruleset_hash

    # stop here if only gathering information otherwise will continue and generate additional parametric properties for schedules and rules
    if gather_data_only then return parametric_inputs end

    # set scheduleRuleset properties
    props = sch.additionalProperties
    props.setFeature('param_sch_ver', '0.0.1') # this is needed to see if formulas are in sync with version of standards that processes them also used to flag schedule as parametric
    props.setFeature('param_sch_floor', min_max['min'])
    props.setFeature('param_sch_ceiling', min_max['max'])

    # cleanup existing profiles
    schedule_ruleset_cleanup_profiles(sch)

    # gather profiles
    daily_flhs = [] # will be used to tag, min,medium,max operation for non typical operations
    schedule_days = {} # key is day_schedule value is hours in day (used to tag profiles)
    sch.scheduleRules.each do |rule|
      schedule_days[rule.daySchedule] = rule.ruleIndex
      daily_flhs << day_schedule_equivalent_full_load_hrs(rule.daySchedule)
    end
    schedule_days[sch.defaultDaySchedule] = -1
    daily_flhs << day_schedule_equivalent_full_load_hrs(sch.defaultDaySchedule)

    # get indices for current schedule
    year_description = sch.model.yearDescription.get
    year = year_description.assumedYear
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    indices_vector = sch.getActiveRuleIndices(year_start_date, year_end_date)

    # step through profiles and add additional properties to describe profiles
    schedule_days.each_with_index do |(schedule_day, current_rule_index), i|
      # loop through indices looking of rule in hoo that contains days in the rule
      hoo_target_index = nil
      days_used = []
      indices_vector.each_with_index do |profile_index, i|
        if profile_index == current_rule_index then days_used << i + 1 end
      end
      # find days_used in hoo profiles that contains all days used from this profile
      hoo_profile_match_hash = {}
      best_fit_check = {}
      hours_of_operation.each do |profile_index, value|
        days_for_rule_not_in_hoo_profile = days_used - value[:days_used]
        hoo_profile_match_hash[profile_index] = days_for_rule_not_in_hoo_profile
        best_fit_check[profile_index] = days_for_rule_not_in_hoo_profile.size
        if days_for_rule_not_in_hoo_profile.empty?
          hoo_target_index = profile_index
        end
      end
      # if schedule day days used can't be mapped to single hours of operation then do not use hoo variables, otherwise would have ot split rule and alter model
      if hoo_target_index.nil?
        hoo_start = nil
        hoo_end = nil
        occ = nil
        vac = nil
        # @todo issue warning when this happens on any profile that isn't a constant value
      else
        # get hours of operation for this specific profile
        hoo_start = hours_of_operation[hoo_target_index][:hoo_start]
        hoo_end = hours_of_operation[hoo_target_index][:hoo_end]
        occ = hours_of_operation[hoo_target_index][:hoo_hours]
        vac = 24.0 - hours_of_operation[hoo_target_index][:hoo_hours]
      end

      props = schedule_day.additionalProperties
      par_val_time_hash = {} # time is key, value is value in and optional value out as a one or two object array
      times = schedule_day.times
      values = schedule_day.values
      values.each_with_index do |value, j|
        # don't add value until 24 if it is the same as first value for non constant profiles
        if values.size > 1 && j == values.size - 1 && value == values.first
          next
        end

        current_time = times[j].totalHours
        # if step height goes floor to ceiling then do not ramp.
        if !ramp || (values.uniq.size < 3)
          # this will result in steps like old profiles, update to ramp in most cases
          if j == values.size - 1
            par_val_time_hash[current_time] = [value, values.first]
          else
            par_val_time_hash[current_time] = [value, values[j + 1]]
          end
        else
          if j == 0
            prev_time = times.last.totalHours - 24 # e.g. 24 would show as until 0
          else
            prev_time = times[j - 1].totalHours
          end
          if j == values.size - 1
            next_time = times.first.totalHours + 24 # e.g. 6 would show as until 30
            next_value = values.first

            # do nothing if value is same as first value
            if value == next_value
              next
            end

          else
            next_time = times[j + 1].totalHours
            next_value = values[j + 1]
          end
          # delta time is min min_ramp_dur_hr, half of previous dur, half of next dur
          # todo - would be nice to change to 0.25 for vally less than 2 hours
          multiplier = 0.5
          delta = [min_ramp_dur_hr, (current_time - prev_time) * multiplier, (next_time - current_time) * multiplier].min
          # add value to left if not already added
          if !par_val_time_hash.key?(current_time - delta)
            time_left = current_time - delta
            if time_left < 0.0 then time_left += 24.0 end
            par_val_time_hash[time_left] = [value]
          end
          # add value to right
          time_right = current_time + delta
          if time_right > 24.0 then time_right -= 24.0 end
          par_val_time_hash[time_right] = [next_value]
        end
      end

      # sort hash by keys
      par_val_time_hash.sort.to_h

      # calculate estimated value (not including any secondary logic)
      est_daily_flh = 0.0
      prev_time = par_val_time_hash.keys.max - 24.0
      prev_value = par_val_time_hash.values.last.last # last value in last optional pair of values
      par_val_time_hash.sort.each do |time, value_array|
        segment_length = time - prev_time
        avg_value = (value_array.first + prev_value) * 0.5
        est_daily_flh += segment_length * avg_value
        prev_time = time
        prev_value = value_array.last
      end

      # test expected value against estimated value
      daily_flh = day_schedule_equivalent_full_load_hrs(schedule_day)
      percent_change = ((daily_flh - est_daily_flh) / daily_flh) * 100.0
      if percent_change.abs > 0.05
        # @todo this estimation can have flaws. Fix or remove it, make sure to update for secondary logic (if we implement that here)
        # post application checks compares against actual instead of estimated values
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "For day schedule #{schedule_day.name} in #{sch.name} there was a #{percent_change.round(4)}% change. Expected full load hours is #{daily_flh.round(4)}, but estimated value is #{est_daily_flh.round(4)}")
      end

      raw_string = []
      par_val_time_hash.sort.each do |time, value_array|
        # add in value variables
        # not currently using range, only using min max for constant schedules or schedules with just two values
        value_array_var = []
        value_array.each do |val|
          if val == min_max['min'] && values.uniq.size < 3
            value_array_var << 'val_flr'
          elsif val == min_max['max'] && values.uniq.size < 3
            value_array_var << 'val_clg'
          else
            value_array_var << val
          end
        end

        # add in hoo variables when matching profile found
        if !hoo_start.nil?

          # identify which identifier (star,mid,end) time is closest to, which will impact formula structure
          # includes code to identify delta for wrap around of 24
          formula_identifier = {}
          start_delta_array = [hoo_start - time, hoo_start - time + 24, hoo_start - time - 24]
          start_delta_array_abs = [(hoo_start - time).abs, (hoo_start - time + 24).abs, (hoo_start - time - 24).abs]
          start_delta_h = start_delta_array[start_delta_array_abs.index(start_delta_array_abs.min)]
          formula_identifier['start'] = start_delta_h
          mid_calc = hoo_start + occ * 0.5
          mid_delta_array = [mid_calc - time, mid_calc - time + 24, mid_calc - time - 24]
          mid_delta_array_abs = [(mid_calc - time).abs, (mid_calc - time + 24).abs, (mid_calc - time - 24).abs]
          mid_delta_h = mid_delta_array[mid_delta_array_abs.index(mid_delta_array_abs.min)]
          formula_identifier['mid'] = mid_delta_h
          end_delta_array = [hoo_end - time, hoo_end - time + 24, hoo_end - time - 24]
          end_delta_array_abs = [(hoo_end - time).abs, (hoo_end - time + 24).abs, (hoo_end - time - 24).abs]
          end_delta_h = end_delta_array[end_delta_array_abs.index(end_delta_array_abs.min)]
          formula_identifier['end'] = end_delta_h

          # need to store min absolute value to pick the best fit
          formula_identifier_min_abs = {}
          formula_identifier.each do |k, v|
            formula_identifier_min_abs[k] = v.abs
          end

          # pick from possible formula approaches for any datapoint where x is hour value
          min_key = formula_identifier_min_abs.key(formula_identifier_min_abs.values.min)
          min_value = formula_identifier[min_key]

          if hoo_var_method == 'hours'
            # minimize x, which should be no greater than 12, see if rounding to 2 decimal places works
            min_value = min_value.round(2)
            if min_key == 'start'
              if min_value == 0
                time = 'hoo_start'
              elsif min_value < 0
                time = "hoo_start + #{min_value.abs}"
              else # greater than 0
                time = "hoo_start - #{min_value}"
              end
            elsif min_key == 'mid'
              if min_value == 0
                time = 'mid'
                # converted to variable for simplicity but could also be described like this
                # time = "hoo_start + occ * 0.5"
              elsif min_value < 0
                time = "mid + #{min_value.abs}"
              else # greater than 0
                time = "mid - #{min_value}"
              end
            else # min_key == "end"
              if min_value == 0
                time = 'hoo_end'
              elsif min_value < 0
                time = "hoo_end + #{min_value.abs}"
              else # greater than 0
                time = "hoo_end - #{min_value}"
              end
            end

          elsif hoo_var_method == 'fractional'

            # minimize x(hour before converted to fraction), which should be no greater than 0.5 as fraction, see if rounding to 3 decimal places works
            if occ > 0
              min_value_occ_fract = min_value.abs / occ
            else
              min_value_occ_fract = 0.0
            end
            if vac > 0
              min_value_vac_fract = min_value.abs / vac
            else
              min_value_vac_fract = 0.0
            end
            if min_key == 'start'
              if min_value == 0
                time = 'hoo_start'
              elsif min_value < 0
                time = "hoo_start + occ * #{min_value_occ_fract.round(3)}"
              else # greater than 0
                time = "hoo_start - vac * #{min_value_vac_fract.round(3)}"
              end
            elsif min_key == 'mid'
              # @todo see what is going wrong with after mid in formula
              if min_value == 0
                time = 'mid'
                # converted to variable for simplicity but could also be described like this
                # time = "hoo_start + occ * 0.5"
              elsif min_value < 0
                time = "mid + occ * #{min_value_occ_fract.round(3)}"
              else # greater than 0
                time = "mid - occ * #{min_value_occ_fract.round(3)}"
              end
            else # min_key == "end"
              if min_value == 0
                time = 'hoo_end'
              elsif min_value < 0
                time = "hoo_end + vac * #{min_value_vac_fract.round(3)}"
              else # greater than 0
                time = "hoo_end - occ * #{min_value_occ_fract.round(3)}"
              end
            end

          end

        end

        # populate string
        if value_array_var.size == 1
          raw_string << "#{time} ~ #{value_array_var.first}"
        else # should only have 1 or two values (value in and optional value out)
          raw_string << "#{time} ~ #{value_array_var.first} ~ #{value_array_var.last}"
        end
      end

      # store profile formula with hoo and value variables
      props.setFeature('param_day_profile', raw_string.join(' | '))

      # @todo not used yet, but will add methods described below and others
      # @todo lower infiltration based on air loop hours of operation if air loop has outdoor air object
      # @todo lower lighting or plug loads based on occupancy at given time steps in a space
      # @todo set elevator fraction based multiple factors such as trips, occupants per trip, and elevator type to determine floor consumption when not in use.
      props.setFeature('param_day_secondary_logic', '') # secondary logic method such as occupancy impacting schedule values
      props.setFeature('param_day_secondary_logic_arg_val', '') # optional argument used for some secondary logic applied to values

      # tag profile type
      # may be useful for parametric changes to tag typical, medium, minimal, or same ones with off_peak prefix
      # todo - I would like to use these same tags for hours of operation and have parametric tags then ignore the days of week and date range from the rule object
      # tagging min/max makes sense in fractional schedules but not temperature schedules like thermostats (specifically cooling setpoints)
      # todo - I think these tags should come from occpancy schedule for space(s) schedule. That way all schedules in a space will refer to same profile from hours of operation
      # todo - add school specific logic hear or in post processing, currently default profile for school may not be most prevalent one
      if current_rule_index == -1
        props.setFeature('param_day_tag', 'typical_operation')
      elsif daily_flh == daily_flhs.min
        props.setFeature('param_day_tag', 'minimal_operation')
      elsif daily_flh == daily_flhs.max
        props.setFeature('param_day_tag', 'maximum_operation') # normally this should not be used as typical should be the most active day
      else
        props.setFeature('param_day_tag', 'medium_operation') # not min max or typical
      end
    end

    return parametric_inputs
  end

  # Determine the surface range of a baseline model.
  # The method calculates the window to wall ratio (assuming all spaces are conditioned)
  # and select the range based on the calculated window to wall ratio
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param intended_surface_type [String] surface type
  def model_get_percent_of_surface_range(model, intended_surface_type)
    return { 'minimum_percent_of_surface' => nil, 'maximum_percent_of_surface' => nil }
  end

  # Default SAT reset type
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @return [String] Returns type of SAT reset
  def air_loop_hvac_supply_air_temperature_reset_type(air_loop_hvac)
    return 'warmest_zone'
  end
end
