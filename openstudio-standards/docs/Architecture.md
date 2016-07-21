# Architecture

This library has been developed with three main use-cases in mind:

1. Create the DOE Prototype Buildings in OpenStudio format
2. Create a code baseline model from a proposed model
3. Check a model against a code/standard (not yet implemented)

These three things are all highly related, and share many common subtasks.  For example, since the DOE Prototype Buildings are supposed to be minimally code-compliant buildings, you need to set DX coil efficiencies.  When you are creating a code baseline model, you also need to set DX coil efficiencies.  When you are checking against a code/standard, you need to look up these same DX coil efficiencies. Additionally, all of these methods require access to the information about  the minimum efficiencies, u-values, etc. that are defined in the `/data/standards` directory.

The code has been structured such that several higher level methods may all call the same lower level method. For example, both of the methods below eventually call `SpaceType.add_loads`.  Rather than having two copies of this code inside of the two top level methods, there is one method.

	Model.create_prototype_building('Small Office, '90.1-2010', 'ASHRAE 169-2006-5A')
		Model.add_schedules
			SpaceType.add_schedules
		Model.apply_standard
			SpaceType.add_loads(people = true, lights = true, plug_loads = true)
	
	Model.create_baseline_building('90.1-2010', 'Appendix G')
		Model.add_baseline_hvac_systems
		Model.apply_standard
			SpaceType.add_loads(people = true, lights = true, plug_loads = false)

Where a method needs to operate **slightly differently** in two different situations, instead of duplicating the code, we make an input argument to tell that method what to do.  In the example above, `SpaceType.add_loads` is called with `plug_loads = true` when creating the prototype building, but `plug_loads = false` when creating the baseline model, since plug loads stay the same as the proposed model in Appendix G.

Where a method needs to operate **very differently** in two different situations, it should be broken out into a separate method. 

## Outline of the main methods

### `Model.create_prototype_building()`**
  - **`Model.find_object()`** Gets a hash of prototype model input characteristics for later use.  These are characteristics that vary by building type and vintage.  They are stored in `OpenStudio_Standards_prototype_inputs.json`.
  - **`Model.load_building_type_methods()`** Each building type has a file in `/prototypes`.that contains a few methods specifically tailored to that building type.  This loads that file, e.g. `/prototypes/Prototype.secondary_school.rb`
  - **`Model.load_geometry()`** Loads an `.osm` containing just the geomety (including Spaces) of the model.
  - **`Model.define_space_type_map()`** Loads the map between `SpaceTypes` (Open Office) and `Spaces` (Office 101) for a particular building type.  This map is defined in the file for this building type, e.g. `Prototype.secondary_school.rb`.
  - **`Model.assign_space_type_stubs()`** Creates a `SpaceType` for each one listed in the map and assigns the correct `SpaceType` to each `Space` in the model.  These `SpaceTypes` do not have loads or schedules assigned.
  - **`Model.add_loads()`** For each `SpaceType` in the model:
    - **`SpaceType.set_internal_loads()`** Looks up internal loads from the `OpenStudio_Standards_space_types.json` and sets them
    - **`SpaceType.set_internal_load_schedules()`** Looks up internal load schedules from the `OpenStudio_Standards_space_types.json` and sets them
  - **`Model.apply_infiltration_standard()`** For each `Space` in the model:
    - **`Space.set_infiltration_rate()`** Sets the infiltration rate for this `Space` based on its exterior surface area.
  - **`Model.modify_infiltration_coefficients()`** Sets the terrain and infiltration velocity coefficients.
  - **`Model.modify_surface_convection_algorithm()`** Sets the correct simulation settings for surface convection.
  - **`Model.add_constructions()`** Creates some generic constructions used by all Prototype models (interior walls, internal mass, etc.).
    - **`Model.add_construction_set()`** Looks up the construction set for this building type from `OpenStudio_Standards_construction_sets.json` and adds all constructions in it to the model.
    - **`Model.add_construction_set()`** Looks up the construction set for each `SpaceType` from `OpenStudio_Standards_construction_sets.json` and adds all constructions in it to the model.  `SpaceTypes` only have construction sets where they differ from the overall building construction set.
  - **`Model.create_thermal_zones()`** Creates one `ThermalZone` with a `ThermostatSetpointDualSetpoint` for each `Space` in the model.  Also sets zone multipliers if defined in `/prototypes/Prototype.large_office.rb`. 
  - **`Model.add_hvac()`**
    - **`Model.define_hvac_system_map()`** Get a map of HVAC system types from `/prototypes/Prototype.large_office.rb`
    - For each system type listed in the map, create the system using methods like `Model.add_cw_loop()`** and `Model.add_psz_ac()`**.  Note that these methods only create the basic system layout; component efficiencies and code-mandated controls are applied later. Some of the inputs, like which type of heating or cooling fuel to use for these methods are pulled from `OpenStudio_Standards_prototype_inputs.json`.  
  - **`Model.custom_hvac_tweaks()`** Some building types have unique HVAC system characteristics.  Rather than putting lots of special conditions for each building type into methods like `Model.add_psz_ac`, the changes are defined in isolation for each building type and are made after adding the systems.
  - **`Model.add_swh()`** For each service water type (main, booster, laundry) listed in `OpenStudio_Standards_prototype_inputs.json`.  **NOTE: this method is complex because of the inconsistencies in the way water use equipment is specified between different building types.  There is opportunity here to streamline the approach**
    - **`Model.add_swh_loop()`** Adds a hot water loop
    - **`Model.add_swh_end_uses()`** Adds `WaterUseEquipment` as specified in `OpenStudio_Standards_prototype_inputs.json`.
    - **`Model.add_swh_end_uses_by_space()`** Adds `WaterUseEquipment` on a space-by-space basis based on the information in `OpenStudio_Standards_space_types.json`
  - **`Model.custom_swh_tweaks()`** Some building types have even more unique SWH characteristics.  This approach keeps them isolated, which makes the already-complex methods `Model.add_swh()`** as simple as possible.
  - **`Model.add_exterior_lights()`** Adds `Exteriorlights` to the model as specified in `OpenStudio_Standards_prototype_inputs.json`.
  - **`Model.add_occupancy_sensors()`** Adds lighting power reductions on a space-by-space basis based on `SpaceType`.  **NOTE: This method requires pre-computed assumptions about how much of each `SpaceType` exists in some models.  It would be better to make this more generic.**
  - **`Model.add_design_days_and_weather_file()`** Adds the correct design days and weather file for the specified climate zone.
  - **`Model.set_sizing_parameters()`** Sets the heating and cooling sizing factors.  **NOTE: These are not consistent between building types.  Why?**
  - **`Model.runSizingRun()`** Runs the first sizing run.  Equipment sizes (mainly flow rates) are necessary for some of the subsequent steps.
  - **`Model.apply_multizone_vav_outdoor_air_sizing()`** Reset damper positions on VAV systems to achieve a 60% ventilation effectiveness based on the 62.1 multizone calculations.
  - **`Model.applyPrototypeHVACAssumptions()`** Apply Prototype-building-specific assumptions.  These are things not governed by the Standard.
    - **`Fan.setPrototypeFanPressureRise()`** For each `Fan` (all types) set the pressure rise.
    - **`Fan.set_prototype_fan_efficiency()`** For each `Fan` (all types) set the fan efficiency.
    - **`AirLoopHVAC.is_economizer_required()`** Determine if an economizer is required.  If it is, apply the type specified by the Prototype.
  - **`Model.applyHVACEfficiencyStandard()`** Apply the HVAC efficiency standard
    - **`AirLoopHVAC.apply_standard_controls()`** For each `AirLoopHVAC` apply the standard-mandated controls
      - **`AirLoopHVAC.is_energy_recovery_ventilator_required()`** Checks if ERV is required.
        - **`AirLoopHVAC.apply_energy_recovery_ventilator()`** Applies ERV.
      - **`AirLoopHVAC.set_economizer_limits()`** Sets the economizer limits based on previously-assigned type.
      - **`AirLoopHVAC.set_economizer_integration()`** Sets economizer as integrated or non-integrated.
      - **`AirLoopHVAC.is_multizone_vav_system()`** For multizone VAV systems:
          - **`AirLoopHVAC.set_vav_damper_action()`** Sets damper action
          - **`AirLoopHVAC.is_multizone_vav_optimization_required()`** Checks if multizone VAV optimization is required.
              - **`AirLoopHVAC.enable_multizone_vav_optimization()`** Enables multizone VAV optimization.
          - **`AirLoopHVAC.is_static_pressure_reset_required()`** Checks if static pressure reset is required.
              - **`Fan.set_control_type()`** Applies static pressure reset to the fan.
      - **`AirLoopHVAC.apply_single_zone_controls()`** Applies single-zone system controls.  **NOTE: This method is currently disabled until EMS is supported by OpenStudio or EnergyPlus fixed DX Coil/Economizer interactions.**
      - **`AirLoopHVAC.is_demand_control_ventilation_required()`** Checks if DCV is required.
          - **`AirLoopHVAC.enable_demand_control_ventilation()`** Applies DCV.
      - **`AirLoopHVAC.is_supply_air_temperature_reset_required()`** Checks if SAT reset is required.
          - **`AirLoopHVAC.enable_supply_air_temperature_reset_warmest_zone()`** Enables worst-case zone based SAT reset.  **NOTE: PRM RM requires this method, but Prototypes use OAT-base reset.  Why?**
      - **`AirLoopHVAC.is_unoccupied_fan_shutoff_required()`** Checks if unoccupied hours fan shutoff is required.
          - **`AirLoopHVAC.enable_unoccupied_fan_shutoff()`** Shuts off fan during unoccupied hours, otherwise set to Always-On.
      - **`AirLoopHVAC.is_motorized_oa_damper_required()`** Checks if motorized OA damper is required.
          - **`AirLoopHVAC.add_motorized_oa_damper()`** Adds motorized OA damper.
    - **`Fan.set_standard_minimum_motor_efficiency()`** Sets fan motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`Pump.set_standard_minimum_motor_efficiency()`** Sets pump motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`CoilCoolingDXTwoSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`CoilCoolingDXSingleSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`CoilHeatingDXSingleSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_heat_pumps_heating.json`.
    - **`ChillerElectricEIR.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_chillers.json`.
    - **`BoilerHotWater.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_boilers.json`.
    - **`WaterHeaterMixed.setStandardEfficiency()`** Sets efficiencies and curves.
    - **`CoolingTowerSingleSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves.
    - **`CoolingTowerTwoSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves.
    - **`CoolingTowerVariableSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves.  
  - **`Model.add_daylighting_controls()`** Adds daylighting controls to the model.  **NOTE: This should probably be moved before the first sizing run.**

### `Model.create_performance_rating_method_baseline_building()`**

  - **`Model.getBuilding.setName()`** Sets the name of the building to let you know what standard was applied.
  - **`Model.remove_external_shading_devices()`** Removes external shading devices.
  - **`Model.apply_performance_rating_method_baseline_window_to_wall_ratio()`** Reduces WWR, if necessary.
  - **`Model.apply_performance_rating_method_baseline_skylight_to_roof_ratio()`** Reduces SRR, if necessary.
  - **`Model.assign_spaces_to_stories()`** If the user has not grouped their `Spaces` by `BuildingStory`, infer stories based on Z-height of `Space` floor surfaces.  Stories are necessary for baseline system addition.
  - 'SpaceType.set_internal_loads()`**  For each `SpaceType`, modify the lighting loads, keeping all other user-defined loads.  For this to work, the user must set the `standardsBuildingType` and `standardsSpaceType` properties for all `SpaceTypes` in their model.
  - **`Model.apply_performance_rating_method_construction_types()`** For each `Construction`, apply the standard construction types (e.g. IEAD, SteelFramed, WoodFramed) based on the types of `Surfaces` it is used on.
  - **`Model.apply_standard_constructions()`** For each `Construction`, look up the construction properties from `OpenStudio_Standards_construction_properties.json`, create constructions representing these properties, and assign to the appropriate `Surfaces`.
  - **`Model.performance_rating_method_baseline_system_groups()`** Group the zones based on fuel type and occupancy type.
  - **`Model.remove_performance_rating_method_hvac()`** Remove the HVAC from the model.  Don't remove SWH loops.
  - **`WaterHeaterMixed.apply_performance_rating_method_baseline_fuel_type()`** For each 'WaterHeaterMixed' set the fuel type.
  - **`Model.performance_rating_method_baseline_system_type()`** For each Group of zones, determine the baseline system type.
    - **`Model.add_performance_rating_method_baseline_system()`** For each Group of zones, add the baseline HVAC system.
      - 'Model.add_hw_loop(), Model.add_pvav_pfp_boxes(), etc` There is a method for each type of system.  These are also used by the `Model.create_prototype_building()`**.
  - **`ThermalZone.set_performance_rating_method_baseline_supply_temperatures()`** For each `ThermalZone`, set the zone sizing SAT based on the thermosat setpoints.
  - **`AirLoopHVAC.apply_performance_rating_method_baseline_controls()`** For each `AirLoopHVAC`, apply the controls specified in the baseline model that are not mandated by the standard.
    - **`AirLoopHVAC.is_performance_rating_method_baseline_economizer_required()`** Check if PRM requires an economizer.
      - **`AirLoopHVAC.apply_performance_rating_method_baseline_economizer(template, climate_zone)` Apply the economizer.
    - **`AirLoopHVAC.is_supply_air_temperature_reset_required()`** Checks if SAT reset is required.
      - **`AirLoopHVAC.enable_supply_air_temperature_reset_warmest_zone()`** Enables worst-case zone based SAT reset.
    - **`AirLoopHVAC.self.enable_unoccupied_fan_shutoff()`** Schedule fans off when not occupied.
  - **`AirLoopHVAC.set_minimum_vav_damper_positions()`** For each `AirLoopHVAC`, apply the minimum damper positions, assuming no DDC control of VAV terminals
  - **`PlantLoop.apply_performance_rating_method_baseline_temperatures()`** For each `PlantLoop`, apply the baseline system setpoint temperatures.
  - **`Model.runSizingRun()`** Runs the first sizing run.  Equipment sizes (mainly flow rates) are necessary for some of the subsequent steps. 
  - **`Model.apply_multizone_vav_outdoor_air_sizing()`** Reset damper positions on VAV systems to achieve a 60% ventilation effectiveness based on the 62.1 multizone calculations.
  - **`AirLoopHVAC.set_performance_rating_method_baseline_fan_power()`** For each `AirLoopHVAC`, set the baseline fan power.
  - **`PlantLoop.apply_performance_rating_method_number_of_boilers()`** For each `PlantLoop`, set the number of boilers.
  - **`PlantLoop.apply_performance_rating_method_number_of_chillers()`** For each `PlantLoop`, set the number of chillers.
  - **`PlantLoop.apply_performance_rating_method_number_of_cooling_towers()`** For each `PlantLoop`, set the number of cooling towers.
  - **`Model.runSizingRun()`** Runs the second sizing run with new chillers, boilers, and cooling towers to determine capacities.    
  - **`PlantLoop.apply_performance_rating_method_baseline_pump_power()`** For each `PlantLoop`, set the pumping power.
  - **`PlantLoop.apply_performance_rating_method_baseline_pumping_type()`** For each `PlantLoop`, set the pumping control type.
  - **`Model.applyHVACEfficiencyStandard()`** Apply the HVAC efficiency standard
    - **`AirLoopHVAC.apply_standard_controls()`** For each `AirLoopHVAC` apply the standard-mandated controls
      - **`AirLoopHVAC.is_energy_recovery_ventilator_required()`** Checks if ERV is required.
        - **`AirLoopHVAC.apply_energy_recovery_ventilator()`** Applies ERV.
      - **`AirLoopHVAC.set_economizer_limits()`** Sets the economizer limits based on previously-assigned type.
      - **`AirLoopHVAC.set_economizer_integration()`** Sets economizer as integrated or non-integrated.
      - **`AirLoopHVAC.is_multizone_vav_system()`** For multizone VAV systems:
          - **`AirLoopHVAC.set_vav_damper_action()`** Sets damper action
          - **`AirLoopHVAC.is_multizone_vav_optimization_required()`** Checks if multizone VAV optimization is required.
              - **`AirLoopHVAC.enable_multizone_vav_optimization()`** Enables multizone VAV optimization.
          - **`AirLoopHVAC.is_static_pressure_reset_required()`** Checks if static pressure reset is required.
              - **`Fan.set_control_type()`** Applies static pressure reset to the fan.
      - **`AirLoopHVAC.apply_single_zone_controls()`** Applies single-zone system controls.  **NOTE: This method is currently disabled until EMS is supported by OpenStudio or EnergyPlus fixed DX Coil/Economizer interactions.**
      - **`AirLoopHVAC.is_demand_control_ventilation_required()`** Checks if DCV is required.
          - **`AirLoopHVAC.enable_demand_control_ventilation()`** Applies DCV.
      - **`AirLoopHVAC.is_supply_air_temperature_reset_required()`** Checks if SAT reset is required.
          - **`AirLoopHVAC.enable_supply_air_temperature_reset_warmest_zone()`** Enables worst-case zone based SAT reset.  **NOTE: PRM RM requires this method, but Prototypes use OAT-base reset.  Why?**
      - **`AirLoopHVAC.is_unoccupied_fan_shutoff_required()`** Checks if unoccupied hours fan shutoff is required.
          - **`AirLoopHVAC.enable_unoccupied_fan_shutoff()`** Shuts off fan during unoccupied hours, otherwise set to Always-On.
      - **`AirLoopHVAC.is_motorized_oa_damper_required()`** Checks if motorized OA damper is required.
          - **`AirLoopHVAC.add_motorized_oa_damper()`** Adds motorized OA damper.
    - **`Fan.set_standard_minimum_motor_efficiency()`** Sets fan motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`Pump.set_standard_minimum_motor_efficiency()`** Sets pump motor efficiencies from `OpenStudio_Standards_motors.json`.
    - **`CoilCoolingDXTwoSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`CoilCoolingDXSingleSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_unitary_acs.json`.
    - **`CoilHeatingDXSingleSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_heat_pumps_heating.json`.
    - **`ChillerElectricEIR.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_chillers.json`.
    - **`BoilerHotWater.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves from `OpenStudio_Standards_boilers.json`.
    - **`WaterHeaterMixed.setStandardEfficiency()`** Sets efficiencies and curves.
    - **`CoolingTowerSingleSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves.
    - **`CoolingTowerTwoSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves.
    - **`CoolingTowerVariableSpeed.setStandardEfficiencyAndCurves()`** Sets efficiencies and curves.  
  - **`Model.add_daylighting_controls()`** Adds daylighting controls to the model.  **NOTE: This should probably be moved before the first sizing run.**
