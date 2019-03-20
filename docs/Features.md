# Features

This library has been developed with three main use-cases in mind:

1. Create the DOE Prototype Buildings in OpenStudio format
2. Create a code baseline model from a proposed model
3. Check a model against a code/standard (not yet implemented)

These three things are all highly related, and share many common subtasks.  For example, since the DOE Prototype Buildings are supposed to be minimally code-compliant buildings, you need to set DX coil efficiencies.  When you are creating a code baseline model, you also need to set DX coil efficiencies.  When you are checking against a code/standard, you need to look up these same DX coil efficiencies. Additionally, all of these methods require access to the information about the minimum efficiencies, u-values, etc. that are defined in the `/data/standards` directory.

The code has been structured such that several higher level methods may all call the same lower level method. For example, both of the methods below eventually call `space_type_add_loads`.  Rather than having two copies of this code inside of the two top level methods, there is one method.

	model_create_prototype_building('Small Office, '90.1-2010', 'ASHRAE 169-2006-5A')
		model_add_schedules
			space_type_add_schedules
		model_apply_standard
			space_type_add_loads(people = true, lights = true, plug_loads = true)
	
	model_create_prm_baseline_building('Small Office', '90.1-2010', 'ASHRAE 169-2006-5A', 'Xcel Energy CO EDA', Dir.pwd, false)
		model_add_baseline_hvac_systems
		model_apply_standard
			space_type_add_loads(people = true, lights = true, plug_loads = false)

Where a method needs to operate **slightly differently** in two different situations, instead of duplicating the code, we make an input argument to tell that method what to do.  In the example above, `space_type_add_loads` is called with `plug_loads = true` when creating the prototype building, but `plug_loads = false` when creating the baseline model, since plug loads stay the same as the proposed model in Appendix G.

Where a method needs to operate **very differently** in two different situations, it should be broken out into a separate method. 

## Outline of the main methods

### `model_create_prototype_model()`**
  - **`load_geometry()`** Loads an `.osm` containing the geomety (including Spaces and SpaceTypes with types assigned) of the model.
  - **`model_add_loads()`** For each `SpaceType` in the model:
    - **`space_type_apply_internal_loads()`** Looks up internal loads from the `OpenStudio_Standards_space_types.json` and sets them
    - **`space_type_apply_internal_load_schedules()`** Looks up internal load schedules from the `OpenStudio_Standards_space_types.json` and sets them
  - **`model_apply_infiltration_standard()`** For each `Space` in the model:
    - **`space_apply_infiltration_rate()`** Sets the infiltration rate for this `Space` based on its exterior surface area.
  - **`model_modify_infiltration_coefficients()`** Sets the terrain and infiltration velocity coefficients.
  - **`model_modify_surface_convection_algorithm()`** Sets the correct simulation settings for surface convection.
  - **`model_add_constructions()`** Creates some generic constructions used by all Prototype models (interior walls, internal mass, etc.).
    - **`model_add_construction_set()`** Looks up the construction set for this building type from `OpenStudio_Standards_construction_sets.json` and adds all constructions in it to the model.
    - **`model_add_construction_set()`** Looks up the construction set for each `SpaceType` from `OpenStudio_Standards_construction_sets.json` and adds all constructions in it to the model.  `SpaceTypes` only have construction sets where they differ from the overall building construction set.
  - **`model_create_thermal_zones()`** Creates one `ThermalZone` with a `ThermostatSetpointDualSetpoint` for each `Space` in the model.  Also sets zone multipliers if defined in `/prototypes/Prototype.large_office.rb`. 
  - **`model_add_hvac()`**
    - **`model_define_hvac_system_map()`** Get a map of HVAC system types from `/prototypes/Prototype.large_office.rb`
    - For each system type listed in the map, create the system using methods like `model_add_cw_loop()` and `model_add_psz_ac()`.  **Note that these methods only create the basic system layout; component efficiencies and code-mandated controls are applied later. Some of the inputs, like which type of heating or cooling fuel to use for these methods are pulled from `OpenStudio_Standards_prototype_inputs.json`.**
  - **`model_custom_hvac_tweaks()`** Some building types have unique HVAC system characteristics.  Rather than putting lots of special conditions for each building type into methods like `model_add_psz_ac`, the changes are defined in isolation for each building type and are made after adding the systems.
  - **`model_add_swh()`** For each service water type (main, booster, laundry) listed in `OpenStudio_Standards_prototype_inputs.json`.  **NOTE: this method is complex because of the inconsistencies in the way water use equipment is specified between different building types.  There is opportunity here to streamline the approach**
    - **`model_add_swh_loop()`** Adds a hot water loop
    - **`model_add_swh_end_uses()`** Adds `WaterUseEquipment` as specified in `OpenStudio_Standards_prototype_inputs.json`.
    - **`model_add_swh_end_uses_by_space()`** Adds `WaterUseEquipment` on a space-by-space basis based on the information in `OpenStudio_Standards_space_types.json`
  - **`model_add_exterior_lights()`** Adds `Exteriorlights` to the model as specified in `OpenStudio_Standards_prototype_inputs.json`.
  - **`model_add_occupancy_sensors()`** Adds lighting power reductions on a space-by-space basis based on `SpaceType`.  **NOTE: This method requires pre-computed assumptions about how much of each `SpaceType` exists in some models.  It would be better to make this more generic.**
  - **`model_add_design_days_and_weather_file()`** Adds the correct design days and weather file for the specified climate zone.
  - **`model_apply_sizing_parameters()`** Sets the heating and cooling sizing factors.  **NOTE: These are not consistent between building types.  Why?**
  - **`model_run_sizing_run()`** Runs the first sizing run.  Equipment sizes (mainly flow rates) are necessary for some of the subsequent steps.
  - **`model_apply_multizone_vav_outdoor_air_sizing()`** Reset damper positions on VAV systems to achieve a 60% ventilation effectiveness based on the 62.1 multizone calculations.
  - **`model_apply_prototype_hvac_assumptions()`** Apply Prototype-building-specific assumptions.  These are things not governed by the Standard.
    - **`fan_apply_prototype_fan_pressure_rise()`** For each `Fan` (all types) set the pressure rise.
    - **`fan_apply_prototype_fan_efficiency()`** For each `Fan` (all types) set the fan efficiency.
    - **`air_loop_hvac_economizer_required?()`** Determine if an economizer is required.  If it is, apply the type specified by the Prototype.
  - **`model_apply_hvac_efficiency_standard()`** Apply the HVAC efficiency standard
    - **`air_loop_hvac_apply_standard_controls()`** For each `AirLoopHVAC` apply the standard-mandated controls
      - **`air_loop_hvac_energy_recovery_ventilator_required?()`** Checks if ERV is required.
        - **`air_loop_hvac_apply_energy_recovery_ventilator()`** Applies ERV.
      - **`air_loop_hvac_apply_economizer_limits()`** Sets the economizer limits based on previously-assigned type.
      - **`air_loop_hvac_apply_economizer_integration()`** Sets economizer as integrated or non-integrated.
      - **`air_loop_hvac_multizone_vav_system?()`** For multizone VAV systems:
          - **`air_loop_hvac_apply_vav_damper_action()`** Sets damper action
          - **`air_loop_hvac_multizone_vav_optimization_required?()`** Checks if multizone VAV optimization is required.
              - **`air_loop_hvac_enable_multizone_vav_optimization()`** Enables multizone VAV optimization.
          - **`air_loop_hvac_static_pressure_reset_required?()`** Checks if static pressure reset is required.
              - **`fan_set_control_type()`** Applies static pressure reset to the fan.
      - **`air_loop_hvac_apply_single_zone_controls()`** Applies single-zone system controls.
      - **`air_loop_hvac_demand_control_ventilation_required?()`** Checks if DCV is required.
          - **`air_loop_hvac_enable_demand_control_ventilation()`** Applies DCV.
      - **`air_loop_hvac_supply_air_temperature_reset_required?()`** Checks if SAT reset is required.
          - **`air_loop_hvac_enable_supply_air_temperature_reset_warmest_zone()`** Enables worst-case zone based SAT reset.  **NOTE: PRM RM requires this method, but Prototypes use OAT-base reset.  Why?**
      - **`air_loop_hvac_unoccupied_fan_shutoff_required?()`** Checks if unoccupied hours fan shutoff is required.
          - **`air_loop_hvac_enable_unoccupied_fan_shutoff()`** Shuts off fan during unoccupied hours, otherwise set to Always-On.
      - **`air_loop_hvac_motorized_oa_damper_required?()`** Checks if motorized OA damper is required.
          - **`air_loop_hvac_add_motorized_oa_damper()`** Adds motorized OA damper.
    - **`fan_apply_standard_minimum_motor_efficiency()`** Sets fan motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`pump_apply_standard_minimum_motor_efficiency()`** Sets pump motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`coil_cooling_dx_two_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`coil_cooling_dx_single_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`coil_heating_dx_single_speed_.apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_heat_pumps_heating.json`.
    - **`chiller_electric_eir_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_chillers.json`.
    - **`boiler_hot_water_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_boilers.json`.
    - **`water_heater_mixed_apply_efficiency()`** Sets efficiencies and curves.
    - **`cooling_tower_single_speeapply_efficiency_and_curves()`** Sets efficiencies and curves.
    - **`cooling_tower_two_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves.
    - **`cooling_tower_variable_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves.  
  - **`model_custom_swh_tweaks()`** Some building types have even more unique SWH characteristics.  This approach keeps them isolated, which makes the already-complex methods `model_add_swh()` as simple as possible.
  - **`model_add_daylighting_controls()`** Adds daylighting controls to the model.  **NOTE: This should probably be moved before the first sizing run.**

### `model_create_prm_baseline_building()`**

  - **`model_getBuilding.setName()`** Sets the name of the building to let you know what standard was applied.
  - **`model_remove_external_shading_devices()`** Removes external shading devices.
  - **`model_apply_performance_rating_method_baseline_window_to_wall_ratio()`** Reduces WWR, if necessary.
  - **`model_apply_performance_rating_method_baseline_skylight_to_roof_ratio()`** Reduces SRR, if necessary.
  - **`model_assign_spaces_to_stories()`** If the user has not grouped their `Spaces` by `BuildingStory`, infer stories based on Z-height of `Space` floor surfaces.  Stories are necessary for baseline system addition.
  - 'space_type_apply_internal_loads()`**  For each `SpaceType`, modify the lighting loads, keeping all other user-defined loads.  For this to work, the user must set the `standardsBuildingType` and `standardsSpaceType` properties for all `SpaceTypes` in their model.
  - **`model_apply_performance_rating_method_construction_types()`** For each `Construction`, apply the standard construction types (e.g. IEAD, SteelFramed, WoodFramed) based on the types of `Surfaces` it is used on.
  - **`model_apply_standard_constructions()`** For each `Construction`, look up the construction properties from `OpenStudio_Standards_construction_properties.json`, create constructions representing these properties, and assign to the appropriate `Surfaces`.
  - **`model_performance_rating_method_baseline_system_groups()`** Group the zones based on fuel type and occupancy type.
  - **`model_remove_performance_rating_method_hvac()`** Remove the HVAC from the model.  Don't remove SWH loops.
  - **`water_heater_mixed_apply_performance_rating_method_baseline_fuel_type()`** For each 'water_heater_mixed_' set the fuel type.
  - **`model_performance_rating_method_baseline_system_type()`** For each Group of zones, determine the baseline system type.
    - **`model_add_performance_rating_method_baseline_system()`** For each Group of zones, add the baseline HVAC system.
      - 'model_add_hw_loop(), model_add_pvav_pfp_boxes(), etc` There is a method for each type of system.  These are also used by the `model_create_prototype_building()`**.
  - **`ThermalZone.apply_performance_rating_method_baseline_supply_temperatures()`** For each `ThermalZone`, set the zone sizing SAT based on the thermosat setpoints.
  - **`air_loop_hvac_apply_performance_rating_method_baseline_controls()`** For each `AirLoopHVAC`, apply the controls specified in the baseline model that are not mandated by the standard.
    - **`air_loop_hvac_performance_rating_method_baseline_economizer_required?()`** Check if PRM requires an economizer.
      - **`air_loop_hvac_apply_performance_rating_method_baseline_economizer(template, climate_zone)` Apply the economizer.
    - **`air_loop_hvac_supply_air_temperature_reset_required?()`** Checks if SAT reset is required.
      - **`air_loop_hvac_enable_supply_air_temperature_reset_warmest_zone()`** Enables worst-case zone based SAT reset.
    - **`air_loop_hvac_self.enable_unoccupied_fan_shutoff()`** Schedule fans off when not occupied.
  - **`air_loop_hvac_apply_minimum_vav_damper_positions()`** For each `AirLoopHVAC`, apply the minimum damper positions, assuming no DDC control of VAV terminals
  - **`plant_loop_apply_performance_rating_method_baseline_temperatures()`** For each `PlantLoop`, apply the baseline system setpoint temperatures.
  - **`model_run_sizing_run()`** Runs the first sizing run.  Equipment sizes (mainly flow rates) are necessary for some of the subsequent steps. 
  - **`model_apply_multizone_vav_outdoor_air_sizing()`** Reset damper positions on VAV systems to achieve a 60% ventilation effectiveness based on the 62.1 multizone calculations.
  - **`air_loop_hvac_apply_performance_rating_method_baseline_fan_power()`** For each `AirLoopHVAC`, set the baseline fan power.
  - **`plant_loop_apply_performance_rating_method_number_of_boilers()`** For each `PlantLoop`, set the number of boilers.
  - **`plant_loop_apply_performance_rating_method_number_of_chillers()`** For each `PlantLoop`, set the number of chillers.
  - **`plant_loop_apply_performance_rating_method_number_of_cooling_towers()`** For each `PlantLoop`, set the number of cooling towers.
  - **`model_run_sizing_run()`** Runs the second sizing run with new chillers, boilers, and cooling towers to determine capacities.    
  - **`plant_loop_apply_performance_rating_method_baseline_pump_power()`** For each `PlantLoop`, set the pumping power.
  - **`plant_loop_apply_performance_rating_method_baseline_pumping_type()`** For each `PlantLoop`, set the pumping control type.
  - **`model_apply_hvac_efficiency_standard()`** Apply the HVAC efficiency standard
    - **`air_loop_hvac_apply_standard_controls()`** For each `AirLoopHVAC` apply the standard-mandated controls
      - **`air_loop_hvac_energy_recovery_ventilator_required?()`** Checks if ERV is required.
        - **`air_loop_hvac_apply_energy_recovery_ventilator()`** Applies ERV.
      - **`air_loop_hvac_apply_economizer_limits()`** Sets the economizer limits based on previously-assigned type.
      - **`air_loop_hvac_apply_economizer_integration()`** Sets economizer as integrated or non-integrated.
      - **`air_loop_hvac_multizone_vav_system?()`** For multizone VAV systems:
          - **`air_loop_hvac_apply_vav_damper_action()`** Sets damper action
          - **`air_loop_hvac_multizone_vav_optimization_required?()`** Checks if multizone VAV optimization is required.
              - **`air_loop_hvac_enable_multizone_vav_optimization()`** Enables multizone VAV optimization.
          - **`air_loop_hvac_static_pressure_reset_required?()`** Checks if static pressure reset is required.
              - **`fan_set_control_type()`** Applies static pressure reset to the fan.
      - **`air_loop_hvac_apply_single_zone_controls()`** Applies single-zone system controls.
      - **`air_loop_hvac_demand_control_ventilation_required?()`** Checks if DCV is required.
          - **`air_loop_hvac_enable_demand_control_ventilation()`** Applies DCV.
      - **`air_loop_hvac_supply_air_temperature_reset_required?()`** Checks if SAT reset is required.
          - **`air_loop_hvac_enable_supply_air_temperature_reset_warmest_zone()`** Enables worst-case zone based SAT reset.  **NOTE: PRM RM requires this method, but Prototypes use OAT-base reset.  Why?**
      - **`air_loop_hvac_unoccupied_fan_shutoff_required?()`** Checks if unoccupied hours fan shutoff is required.
          - **`air_loop_hvac_enable_unoccupied_fan_shutoff()`** Shuts off fan during unoccupied hours, otherwise set to Always-On.
      - **`air_loop_hvac_motorized_oa_damper_required?()`** Checks if motorized OA damper is required.
          - **`air_loop_hvac_add_motorized_oa_damper()`** Adds motorized OA damper.
    - **`fan_apply_standard_minimum_motor_efficiency()`** Sets fan motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`pump_apply_standard_minimum_motor_efficiency()`** Sets pump motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`coil_cooling_dx_two_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`coil_cooling_dx_single_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`coil_heating_dx_single_speed_.apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_heat_pumps_heating.json`.
    - **`chiller_electric_eir_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_chillers.json`.
    - **`boiler_hot_water_apply_efficiency_and_curves()`** Sets efficiencies and curves from `OpenStudio_Standards_boilers.json`.
    - **`water_heater_mixed_apply_efficiency()`** Sets efficiencies and curves.
    - **`cooling_tower_single_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves.
    - **`cooling_tower_two_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves.
    - **`cooling_tower_variable_speed_apply_efficiency_and_curves()`** Sets efficiencies and curves.  
  - **`model_add_daylighting_controls()`** Adds daylighting controls to the model.  **NOTE: This should probably be moved before the first sizing run.**
